let sortFunctions = (a, b) => {
  open Utils
  let temp1 = Date.fromString(a->getDictFromJson->getString("last_used_at", ""))
  let temp2 = Date.fromString(b->getDictFromJson->getString("last_used_at", ""))

  if temp1 === temp2 {
    0.
  } else if temp1 > temp2 {
    -1.
  } else {
    1.
  }
}

let getCustomerSavedPaymentMethods = (
  ~clientSecret,
  ~publishableKey,
  ~endpoint,
  ~logger,
  ~switchToCustomPod,
) => {
  open Promise
  open Types
  open Utils
  PaymentHelpers.fetchCustomerPaymentMethodList(
    ~clientSecret,
    ~publishableKey,
    ~endpoint,
    ~switchToCustomPod,
    ~optLogger=Some(logger),
    ~isPaymentSession=true,
  )
  ->then(customerDetails => {
    let customerDetailsArray =
      customerDetails
      ->JSON.Decode.object
      ->Option.flatMap(x => x->Dict.get("customer_payment_methods"))
      ->Option.flatMap(JSON.Decode.array)
      ->Option.getOr([])

    let customerPaymentMethods = customerDetailsArray->Array.filter(customerPaymentMethod => {
      customerPaymentMethod
      ->JSON.Decode.object
      ->Option.flatMap(x => x->Dict.get("default_payment_method_set"))
      ->Option.flatMap(JSON.Decode.bool)
      ->Option.getOr(false)
    })

    let paymentNotExist = (
      ~message="There is no default saved payment method data for this customer",
    ) =>
      [
        (
          "error",
          [
            ("type", "no_data"->JSON.Encode.string),
            ("message", message->JSON.Encode.string),
          ]->getJsonFromArrayOfJson,
        ),
      ]->getJsonFromArrayOfJson

    let getCustomerDefaultSavedPaymentMethodData = () =>
      switch customerPaymentMethods->Array.get(0) {
      | Some(customerDefaultPaymentMethod) => customerDefaultPaymentMethod
      | None => paymentNotExist()
      }

    let getCustomerLastUsedPaymentMethodData = () => {
      let customerPaymentMethodsCopy = customerDetailsArray->Array.copy
      customerPaymentMethodsCopy->Array.sort(sortFunctions)

      switch customerPaymentMethodsCopy->Array.get(0) {
      | Some(customerLastPaymentUsed) => customerLastPaymentUsed
      | None => paymentNotExist(~message="No recent payments found for this customer.")
      }
    }

    let confirmCallForParticularPaymentObject = (~paymentMethodObject, ~payload) => {
      let customerPaymentMethod = paymentMethodObject->getDictFromJson

      let paymentToken = customerPaymentMethod->getJsonFromDict("payment_token", JSON.Encode.null)

      let paymentMethod = customerPaymentMethod->getJsonFromDict("payment_method", JSON.Encode.null)

      let paymentMethodType =
        customerPaymentMethod->getJsonFromDict("payment_method_type", JSON.Encode.null)

      let confirmParams =
        payload
        ->getDictFromJson
        ->getDictFromDict("confirmParams")

      let redirect = confirmParams->getString("redirect", "if_required")

      let returnUrl = confirmParams->getString("return_url", "")

      let confirmParam: ConfirmType.confirmParams = {
        return_url: returnUrl,
        publishableKey,
        redirect,
      }

      let paymentIntentID = String.split(clientSecret, "_secret_")[0]->Option.getOr("")

      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=true,
        (),
      )
      let uri = `${endpoint}/payments/${paymentIntentID}/confirm`
      let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]

      let paymentType: PaymentHelpers.payment = switch paymentMethodType
      ->JSON.Decode.string
      ->Option.getOr("") {
      | "apple_pay" => Applepay
      | "google_pay" => Gpay
      | "debit"
      | "credit"
      | "" =>
        Card
      | _ => Other
      }

      let broswerInfo = BrowserSpec.broswerInfo()

      let body = [
        ("client_secret", clientSecret->JSON.Encode.string),
        ("payment_method", paymentMethod),
        ("payment_token", paymentToken),
        ("payment_method_type", paymentMethodType),
      ]

      let bodyStr = body->Array.concat(broswerInfo)->getJsonFromArrayOfJson->JSON.stringify

      PaymentHelpers.intentCall(
        ~fetchApi,
        ~uri,
        ~headers,
        ~bodyStr,
        ~confirmParam: ConfirmType.confirmParams,
        ~clientSecret,
        ~optLogger=Some(logger),
        ~handleUserError=false,
        ~paymentType,
        ~iframeId="",
        ~fetchMethod=#POST,
        ~setIsManualRetryEnabled={_ => ()},
        ~switchToCustomPod=false,
        ~sdkHandleOneClickConfirmPayment=false,
        ~counter=0,
        ~isPaymentSession=true,
        (),
      )
    }

    let confirmWithCustomerDefaultPaymentMethod = payload => {
      switch customerPaymentMethods->Array.get(0) {
      | Some(customerDefaultPaymentMethod) =>
        confirmCallForParticularPaymentObject(
          ~paymentMethodObject=customerDefaultPaymentMethod,
          ~payload,
        )
      | None => paymentNotExist()->resolve
      }
    }

    let confirmWithLastUsedPaymentMethod = payload => {
      let customerPaymentMethodsCopy = customerDetailsArray->Array.copy
      customerPaymentMethodsCopy->Array.sort(sortFunctions)

      switch customerPaymentMethodsCopy->Array.get(0) {
      | Some(customerLastPaymentUsed) =>
        confirmCallForParticularPaymentObject(
          ~paymentMethodObject=customerLastPaymentUsed,
          ~payload,
        )
      | None => paymentNotExist(~message="No recent payments found for this customer.")->resolve
      }
    }

    {
      getCustomerDefaultSavedPaymentMethodData,
      getCustomerLastUsedPaymentMethodData,
      confirmWithCustomerDefaultPaymentMethod,
      confirmWithLastUsedPaymentMethod,
    }
    ->Identity.anyTypeToJson
    ->resolve
  })
  ->catch(err => {
    let exceptionMessage = err->formatException->JSON.stringify
    let updatedCustomerDetails =
      [
        (
          "error",
          [
            ("type", "server_error"->JSON.Encode.string),
            ("message", exceptionMessage->JSON.Encode.string),
          ]->getJsonFromArrayOfJson,
        ),
      ]->getJsonFromArrayOfJson
    updatedCustomerDetails->resolve
  })
}
