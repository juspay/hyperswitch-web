open Utils

let getGooglePayBodyFromResponse = (
  ~gPayResponse,
  ~isGuestCustomer,
  ~paymentMethodListValue=PaymentMethodsRecord.defaultList,
  ~connectors,
  ~requiredFields: array<SuperpositionTypes.fieldConfig>=[],
  ~isPaymentSession=false,
  ~isSavedMethodsFlow=false,
  ~alwaysSend=false,
) => {
  let obj = gPayResponse->getDictFromJson->GooglePayType.itemToObjMapper
  let gPayBody = PaymentUtils.appendedCustomerAcceptance(
    ~isGuestCustomer,
    ~paymentType=paymentMethodListValue.payment_type,
    ~body=PaymentBody.gpayBody(~payObj=obj, ~connectors),
    ~alwaysSend,
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

  let requiredFieldsBody = if isPaymentSession || isSavedMethodsFlow {
    DynamicFieldsUtils.getGooglePayRequiredFields(~billingContact, ~shippingContact, ~email)
  } else {
    DynamicFieldsUtils.getGooglePayRequiredFields(
      ~billingContact,
      ~shippingContact,
      ~requiredFieldPaths=requiredFields->Array.map(fieldConfig =>
        fieldConfig.confirmRequestWritePath
      ),
      ~email,
    )
  }

  gPayBody->mergeAndFlattenToTuples(requiredFieldsBody)
}

let processPayment = (
  ~body: array<(string, JSON.t)>,
  ~isThirdPartyFlow=false,
  ~intent: PaymentHelpersTypes.paymentIntent,
  ~options: PaymentType.options,
  ~publishableKey,
  ~isManualRetryEnabled,
) => {
  intent(
    ~bodyArr=body,
    ~confirmParam={
      return_url: options.wallets.walletReturnUrl,
      publishableKey,
    },
    ~handleUserError=true,
    ~isThirdPartyFlow,
    ~manualRetry=isManualRetryEnabled,
  )
}

let useHandleGooglePayResponse = (
  ~connectors,
  ~intent,
  ~isSavedMethodsFlow=false,
  ~isWallet=true,
  ~requiredFieldsBody=Dict.make(),
  ~requiredFields: array<SuperpositionTypes.fieldConfig>=[],
  ~sdkAuthorization,
) => {
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let {publishableKey} = Jotai.useAtomValue(JotaiAtoms.keys)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)

  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson

      if (
        dict->Dict.get("gpayResponse")->Option.isSome &&
          dict->Utils.getBool("isSavedMethodsFlow", false) === isSavedMethodsFlow
      ) {
        let metadata = dict->getJsonObjectFromDict("gpayResponse")
        let body = getGooglePayBodyFromResponse(
          ~gPayResponse=metadata,
          ~isGuestCustomer,
          ~paymentMethodListValue,
          ~connectors,
          ~requiredFields,
          ~isSavedMethodsFlow,
          ~alwaysSend=options.alwaysSendCustomerAcceptance,
        )

        let googlePayBody = if isWallet {
          body
        } else {
          body->mergeAndFlattenToTuples(requiredFieldsBody)
        }

        processPayment(
          ~body=googlePayBody,
          ~isThirdPartyFlow=false,
          ~intent,
          ~options: PaymentType.options,
          ~publishableKey,
          ~isManualRetryEnabled,
        )
      }
      if dict->Dict.get("gpayError")->Option.isSome {
        messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
        if isSavedMethodsFlow || !isWallet {
          postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
        }
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  }, (
    requiredFields,
    isManualRetryEnabled,
    requiredFieldsBody,
    isWallet,
    isSavedMethodsFlow,
    sdkAuthorization,
  ))
}

let handleGooglePayClicked = (
  ~sessionObj,
  ~componentName,
  ~iframeId,
  ~readOnly,
  ~isSavedMethodsFlow=false,
) => {
  let paymentDataRequest = GooglePayType.getPaymentDataFromSession(~sessionObj, ~componentName)
  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", "paymentloader"->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
  ])
  if !readOnly {
    messageParentWindow([
      ("GpayClicked", true->JSON.Encode.bool),
      ("GpayPaymentDataRequest", paymentDataRequest->Identity.anyTypeToJson),
      ("isSavedMethodsFlow", isSavedMethodsFlow->JSON.Encode.bool),
    ])
  }
}

let useSubmitCallback = (~isWallet, ~sessionObj, ~componentName) => {
  let areRequiredFieldsValid = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsEmpty)
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let {localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let {iframeId} = Jotai.useAtomValue(JotaiAtoms.keys)

  React.useCallback((ev: Window.event) => {
    if !isWallet {
      let json = ev.data->safeParse
      let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
      if confirm.doSubmit && areRequiredFieldsValid && !areRequiredFieldsEmpty {
        handleGooglePayClicked(~sessionObj, ~componentName, ~iframeId, ~readOnly=options.readOnly)
      } else if areRequiredFieldsEmpty {
        postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message=localeString.enterFieldsText,
        )
      } else if !areRequiredFieldsValid {
        postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message=localeString.enterValidDetailsText,
        )
      }
    }
  }, (
    areRequiredFieldsValid,
    areRequiredFieldsEmpty,
    isWallet,
    sessionObj,
    componentName,
    iframeId,
  ))
}
