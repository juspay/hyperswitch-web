open Utils

let getGooglePayBodyFromResponse = (
  ~gPayResponse,
  ~isGuestCustomer,
  ~paymentMethodListValue=PaymentMethodsRecord.defaultList,
  ~connectors,
  ~requiredFields=[],
  ~stateJson,
  ~isPaymentSession=false,
) => {
  let obj = gPayResponse->getDictFromJson->GooglePayType.itemToObjMapper
  let gPayBody = PaymentUtils.appendedCustomerAcceptance(
    ~isGuestCustomer,
    ~paymentType=paymentMethodListValue.payment_type,
    ~body=PaymentBody.gpayBody(~payObj=obj, ~connectors),
  )

  let billingContact =
    obj.paymentMethodData.info
    ->getDictFromJson
    ->getJsonObjectFromDict("billingAddress")
    ->getDictFromJson
    ->GooglePayType.billingContactItemToObjMapper

  let shippingContact =
    gPayResponse
    ->getDictFromJson
    ->getJsonObjectFromDict("shippingAddress")
    ->getDictFromJson
    ->GooglePayType.billingContactItemToObjMapper

  let email =
    gPayResponse
    ->getDictFromJson
    ->getString("email", "")

  let requiredFieldsBody = if isPaymentSession {
    DynamicFieldsUtils.getGooglePayRequiredFields(
      ~billingContact,
      ~shippingContact,
      ~statesList=stateJson,
      ~email,
    )
  } else {
    DynamicFieldsUtils.getGooglePayRequiredFields(
      ~billingContact,
      ~shippingContact,
      ~requiredFields,
      ~statesList=stateJson,
      ~email,
    )
  }

  gPayBody
  ->getJsonFromArrayOfJson
  ->flattenObject(true)
  ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
  ->getArrayOfTupleFromDict
}

let processPayment = (
  ~body: array<(string, JSON.t)>,
  ~isThirdPartyFlow=false,
  ~intent: PaymentHelpers.paymentIntent,
  ~options: PaymentType.options,
  ~publishableKey,
) => {
  intent(
    ~bodyArr=body,
    ~confirmParam={
      return_url: options.wallets.walletReturnUrl,
      publishableKey,
    },
    ~handleUserError=true,
    ~isThirdPartyFlow,
    (),
  )
}

let useHandleGooglePayResponse = (~connectors, ~intent) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  let (stateJson, setStatesJson) = React.useState(_ => JSON.Encode.null)

  PaymentUtils.useStatesJson(setStatesJson)

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="google_pay",
  )

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      let json = try {
        ev.data->JSON.parseExn
      } catch {
      | _ => Dict.make()->JSON.Encode.object
      }
      let dict = json->getDictFromJson
      if dict->Dict.get("gpayResponse")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("gpayResponse")
        let body = getGooglePayBodyFromResponse(
          ~gPayResponse=metadata,
          ~isGuestCustomer,
          ~paymentMethodListValue,
          ~connectors,
          ~requiredFields=paymentMethodTypes.required_fields,
          ~stateJson,
        )
        processPayment(
          ~body,
          ~isThirdPartyFlow=false,
          ~intent,
          ~options: PaymentType.options,
          ~publishableKey,
        )
      }
      if dict->Dict.get("gpayError")->Option.isSome {
        handlePostMessage([("fullscreen", false->JSON.Encode.bool)])
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  }, (paymentMethodTypes, stateJson))
}

let handleGooglePayClicked = (~sessionObj, ~componentName, ~iframeId, ~readOnly) => {
  let paymentDataRequest = GooglePayType.getPaymentDataFromSession(~sessionObj, ~componentName)
  handlePostMessage([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", "paymentloader"->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
  ])
  if !readOnly {
    handlePostMessage([
      ("GpayClicked", true->JSON.Encode.bool),
      ("GpayPaymentDataRequest", paymentDataRequest->Identity.anyTypeToJson),
    ])
  }
}
