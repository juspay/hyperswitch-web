open Utils

let getGooglePayBodyFromResponse = (
  ~gPayResponse,
  ~paymentMethodListValue=PaymentMethodsRecord.defaultList,
  ~connectors,
  ~requiredFields=[],
  ~isPaymentSession=false,
  ~isSavedMethodsFlow=false,
) => {
  let obj = gPayResponse->getDictFromJson->GooglePayType.itemToObjMapper
  let gPayBody = PaymentUtils.appendedCustomerAcceptance(
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

  let requiredFieldsBody = if isPaymentSession || isSavedMethodsFlow {
    DynamicFieldsUtils.getGooglePayRequiredFields(~billingContact, ~shippingContact, ~email)
  } else {
    DynamicFieldsUtils.getGooglePayRequiredFields(
      ~billingContact,
      ~shippingContact,
      ~requiredFields,
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
) => {
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let paymentMethodTypes = DynamicFieldsUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod="wallet",
    ~paymentMethodType="google_pay",
  )

  React.useEffect(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson
      if dict->Dict.get("gpayResponse")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("gpayResponse")
        let body = getGooglePayBodyFromResponse(
          ~gPayResponse=metadata,
          ~paymentMethodListValue,
          ~connectors,
          ~requiredFields=paymentMethodTypes.required_fields,
          ~isSavedMethodsFlow,
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
  }, (paymentMethodTypes, isManualRetryEnabled, requiredFieldsBody, isWallet))
}

let handleGooglePayClicked = (~sessionObj, ~componentName, ~iframeId, ~readOnly) => {
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
    ])
  }
}

let useSubmitCallback = (~isWallet, ~sessionObj, ~componentName) => {
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

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
