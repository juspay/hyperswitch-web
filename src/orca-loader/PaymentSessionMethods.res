open Types

external customerSavedPaymentMethodsToJson: getCustomerSavedPaymentMethods => JSON.t = "%identity"

let getCustomerSavedPaymentMethods = (
  ~clientSecret,
  ~publishableKey,
  ~endpoint,
  ~logger,
  ~switchToCustomPod,
) => {
  open Promise
  PaymentHelpers.fetchCustomerDetails(
    ~clientSecret,
    ~publishableKey,
    ~endpoint,
    ~switchToCustomPod,
    ~optLogger=Some(logger),
  )
  ->then(customerDetails => {
    let customerPaymentMethods =
      customerDetails
      ->JSON.Decode.object
      ->Option.flatMap(x => x->Dict.get("customer_payment_methods"))
      ->Option.flatMap(JSON.Decode.array)
      ->Option.getOr([])
      ->Array.filter(customerPaymentMethod => {
        customerPaymentMethod
        ->JSON.Decode.object
        ->Option.flatMap(x => x->Dict.get("default_payment_method_set"))
        ->Option.flatMap(JSON.Decode.bool)
        ->Option.getOr(false)
      })

    switch customerPaymentMethods->Array.get(0) {
    | Some(customerDefaultPaymentMethod) =>
      let getCustomerDefaultSavedPaymentMethodData = () => {
        customerDefaultPaymentMethod
      }

      let confirmWithCustomerDefaultPaymentMethod = payload => {
        let customerPaymentMethod =
          customerDefaultPaymentMethod->JSON.Decode.object->Option.getOr(Dict.make())
        let paymentToken =
          customerPaymentMethod->Utils.getJsonFromDict("payment_token", JSON.Encode.null)
        let paymentMethod =
          customerPaymentMethod->Utils.getJsonFromDict("payment_method", JSON.Encode.null)
        let paymentMethodType =
          customerPaymentMethod->Utils.getJsonFromDict("payment_method_type", JSON.Encode.null)

        let confirmParams =
          payload
          ->JSON.Decode.object
          ->Option.flatMap(x => x->Dict.get("confirmParams"))
          ->Option.getOr(JSON.Encode.null)

        let redirect =
          payload
          ->JSON.Decode.object
          ->Option.flatMap(x => x->Dict.get("redirect"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("if_required")

        let returnUrl =
          confirmParams
          ->JSON.Decode.object
          ->Option.flatMap(x => x->Dict.get("return_url"))
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")

        let confirmParam: ConfirmType.confirmParams = {
          return_url: returnUrl,
          publishableKey,
        }

        let paymentIntentID = String.split(clientSecret, "_secret_")[0]->Option.getOr("")
        let endpoint = ApiEndpoint.getApiEndPoint(
          ~publishableKey=confirmParam.publishableKey,
          ~isConfirmCall=true,
          (),
        )
        let uri = `${endpoint}/payments/${paymentIntentID}/confirm`
        let headers = [
          ("Content-Type", "application/json"),
          ("api-key", confirmParam.publishableKey),
        ]

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

        let bodyStr =
          body->Array.concat(broswerInfo)->Dict.fromArray->JSON.Encode.object->JSON.stringify

        PaymentHelpers.intentCall(
          ~fetchApi=Utils.fetchApi,
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
          ~paymentSessionRedirect=redirect,
          (),
        )
      }

      {
        getCustomerDefaultSavedPaymentMethodData,
        confirmWithCustomerDefaultPaymentMethod,
      }
      ->customerSavedPaymentMethodsToJson
      ->resolve
    | None => {
        let updatedCustomerDetails =
          [
            (
              "error",
              [
                ("type", "no_data"->JSON.Encode.string),
                (
                  "message",
                  "There is no customer default saved payment method data"->JSON.Encode.string,
                ),
              ]
              ->Dict.fromArray
              ->JSON.Encode.object,
            ),
          ]
          ->Dict.fromArray
          ->JSON.Encode.object
        updatedCustomerDetails->resolve
      }
    }
  })
  ->catch(err => {
    let exceptionMessage = err->Utils.formatException->JSON.stringify
    let updatedCustomerDetails =
      [
        (
          "error",
          [
            ("type", "server_error"->JSON.Encode.string),
            ("message", exceptionMessage->JSON.Encode.string),
          ]
          ->Dict.fromArray
          ->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
    updatedCustomerDetails->resolve
  })
}
