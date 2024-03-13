open Types

external customerSavedPaymentMethodsToJson: getCustomerSavedPaymentMethods => Js.Json.t =
  "%identity"

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
      ->Js.Json.decodeObject
      ->Belt.Option.flatMap(x => x->Js.Dict.get("customer_payment_methods"))
      ->Belt.Option.flatMap(Js.Json.decodeArray)
      ->Belt.Option.getWithDefault([])
      ->Js.Array2.filter(customerPaymentMethod => {
        customerPaymentMethod
        ->Js.Json.decodeObject
        ->Belt.Option.flatMap(x => x->Js.Dict.get("default_payment_method_set"))
        ->Belt.Option.flatMap(Js.Json.decodeBoolean)
        ->Belt.Option.getWithDefault(false)
      })

    switch customerPaymentMethods->Belt.Array.get(0) {
    | Some(customerDefaultPaymentMethod) =>
      let getCustomerDefaultSavedPaymentMethodData = () => {
        customerDefaultPaymentMethod
      }

      let confirmWithCustomerDefaultPaymentMethod = payload => {
        let customerPaymentMethod =
          customerDefaultPaymentMethod
          ->Js.Json.decodeObject
          ->Belt.Option.getWithDefault(Js.Dict.empty())
        let paymentToken =
          customerPaymentMethod->Utils.getJsonFromDict("payment_token", Js.Json.null)
        let paymentMethod =
          customerPaymentMethod->Utils.getJsonFromDict("payment_method", Js.Json.null)
        let paymentMethodType =
          customerPaymentMethod->Utils.getJsonFromDict("payment_method_type", Js.Json.null)

        let confirmParams =
          payload
          ->Js.Json.decodeObject
          ->Belt.Option.flatMap(x => x->Js.Dict.get("confirmParams"))
          ->Belt.Option.getWithDefault(Js.Json.null)

        let redirect =
          payload
          ->Js.Json.decodeObject
          ->Belt.Option.flatMap(x => x->Js.Dict.get("redirect"))
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault("if_required")

        let returnUrl =
          confirmParams
          ->Js.Json.decodeObject
          ->Belt.Option.flatMap(x => x->Js.Dict.get("return_url"))
          ->Belt.Option.flatMap(Js.Json.decodeString)
          ->Belt.Option.getWithDefault("")

        let confirmParam: ConfirmType.confirmParams = {
          return_url: returnUrl,
          publishableKey,
        }

        let paymentIntentID = Js.String2.split(clientSecret, "_secret_")[0]->Option.getOr("")
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
        ->Js.Json.decodeString
        ->Belt.Option.getWithDefault("") {
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
          ("client_secret", clientSecret->Js.Json.string),
          ("payment_method", paymentMethod),
          ("payment_token", paymentToken),
          ("payment_method_type", paymentMethodType),
        ]

        let bodyStr =
          body->Js.Array2.concat(broswerInfo)->Js.Dict.fromArray->Js.Json.object_->Js.Json.stringify

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
          ~setIsManualRetryEnabled={(. _) => ()},
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
                ("type", "no_data"->Js.Json.string),
                (
                  "message",
                  "There is no customer default saved payment method data"->Js.Json.string,
                ),
              ]
              ->Js.Dict.fromArray
              ->Js.Json.object_,
            ),
          ]
          ->Js.Dict.fromArray
          ->Js.Json.object_
        updatedCustomerDetails->resolve
      }
    }
  })
  ->catch(err => {
    let exceptionMessage = err->Utils.formatException->Js.Json.stringify
    let updatedCustomerDetails =
      [
        (
          "error",
          [("type", "server_error"->Js.Json.string), ("message", exceptionMessage->Js.Json.string)]
          ->Js.Dict.fromArray
          ->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_
    updatedCustomerDetails->resolve
  })
}
