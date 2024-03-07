open Types

let make = (options, ~clientSecret, ~publishableKey, ~logger: option<OrcaLogger.loggerMake>) => {
  open Promise
  let logger = logger->Belt.Option.getWithDefault(OrcaLogger.defaultLoggerConfig)
  let switchToCustomPod =
    GlobalVars.isInteg &&
    options
    ->Js.Json.decodeObject
    ->Belt.Option.flatMap(x => x->Js.Dict.get("switchToCustomPod"))
    ->Belt.Option.flatMap(Js.Json.decodeBoolean)
    ->Belt.Option.getWithDefault(false)
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey, ())

  let defaultPaymentMethodList = ref(Js.Json.null)

  let customerDetailsPromise = PaymentHelpers.useCustomerDetails(
    ~clientSecret,
    ~publishableKey,
    ~endpoint,
    ~switchToCustomPod,
    ~optLogger=Some(logger),
  )

  let getDefaultPaymentMethod = () => {
    customerDetailsPromise
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
      let isGuestCustomer =
        customerDetails
        ->Js.Json.decodeObject
        ->Belt.Option.flatMap(x => x->Js.Dict.get("is_guest_customer"))
        ->Belt.Option.getWithDefault(Js.Json.null)
      let updatedCustomerDetails =
        [
          ("customer_payment_methods", customerPaymentMethods->Js.Json.array),
          ("is_guest_customer", isGuestCustomer),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_
      defaultPaymentMethodList := updatedCustomerDetails
      updatedCustomerDetails->resolve
    })
    ->catch(_err => {
      let dict =
        [("customer_payment_methods", []->Js.Json.array)]->Js.Dict.fromArray->Js.Json.object_
      let msg = [("customerPaymentMethods", dict)]->Js.Dict.fromArray
      resolve(msg->Js.Json.object_)
    })
  }

  let confirmWithDefault = payload => {
    let customerPaymentMethod =
      defaultPaymentMethodList.contents
      ->Utils.getDictFromJson
      ->Js.Dict.get("customer_payment_methods")
      ->Belt.Option.flatMap(Js.Json.decodeArray)
      ->Belt.Option.getWithDefault([])
      ->Belt.Array.get(0)
      ->Belt.Option.flatMap(Js.Json.decodeObject)
      ->Belt.Option.getWithDefault(Js.Dict.empty())
    let paymentToken = customerPaymentMethod->Utils.getJsonFromDict("payment_token", Js.Json.null)
    let paymentMethod = customerPaymentMethod->Utils.getJsonFromDict("payment_method", Js.Json.null)
    let paymentMethodType =
      customerPaymentMethod->Utils.getJsonFromDict("payment_method_type", Js.Json.null)

    let confirmParams =
      payload
      ->Js.Json.decodeObject
      ->Belt.Option.flatMap(x => x->Js.Dict.get("confirmParams"))
      ->Belt.Option.getWithDefault(Js.Json.null)

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

    let paymentIntentID = Js.String2.split(clientSecret, "_secret_")[0]
    let endpoint = ApiEndpoint.getApiEndPoint(
      ~publishableKey=confirmParam.publishableKey,
      ~isConfirmCall=true,
      (),
    )
    let uri = `${endpoint}/payments/${paymentIntentID}/confirm`
    let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]

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
      ~fetchMethod=Fetch.Post,
      ~setIsManualRetryEnabled={(. _) => ()},
      ~switchToCustomPod=false,
      ~sdkHandleOneClickConfirmPayment=false,
      ~counter=0,
      ~isPaymentSession=true,
      (),
    )
  }

  let returnObject = {
    getDefaultPaymentMethod,
    confirmWithDefault,
  }
  returnObject
}
