module Loader = {
  @react.component
  let make = () => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    <div className="w-full flex items-center justify-center">
      <div className="w-8 h-8 animate-spin" style={color: themeObj.colorTextSecondary}>
        <Icon size=28 name="loader" />
      </div>
    </div>
  }
}

@react.component
let make = (~paymentMethodType) => {
  open Utils
  open Promise
  let {publishableKey, clientSecret, iframeId, sdkAuthorization} = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.keys,
  )
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let setOptionValue = Recoil.useSetRecoilState(RecoilAtoms.optionAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let setShowPaymentMethodsScreen = Recoil.useSetRecoilState(RecoilAtoms.showPaymentMethodsScreen)
  let (showLoader, setShowLoader) = React.useState(() => false)
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let pmAuthConnectorsArr =
    PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(
      paymentMethodListValue.payment_methods,
    )->PmAuthConnectorUtils.getAllRequiredPmAuthConnectors

  React.useEffect0(() => {
    let onPlaidCallback = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->Utils.getDictFromJson
      if dict->getBool("isPlaid", false) {
        let publicToken = dict->getDictFromDict("data")->getString("publicToken", "")
        let isExited = dict->getDictFromDict("data")->getBool("isExited", false)
        setShowLoader(_ => !isExited)
        if publicToken->String.length > 0 {
          PaymentHelpers.callAuthExchange(
            ~publicToken,
            ~clientSecret,
            ~paymentMethodType,
            ~publishableKey,
            ~setOptionValue,
            ~logger,
            ~sdkAuthorization,
          )
          ->then(_ => {
            messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
            setShowPaymentMethodsScreen(_ => false)
            JSON.Encode.null->resolve
          })
          ->catch(_ => JSON.Encode.null->resolve)
          ->ignore
        }
      }
    }

    Window.addEventListener("message", onPlaidCallback)
    Some(
      () => {
        Window.removeEventListener("message", ev => onPlaidCallback(ev))
      },
    )
  })

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message="Please add Bank Details and then confirm payment with the added payment methods.",
      )
    }
  }, [])
  useSubmitPaymentData(submitCallback)

  let onClickHandler = () => {
    setShowLoader(_ => true)
    PaymentHelpers.callAuthLink(
      ~publishableKey,
      ~clientSecret,
      ~iframeId,
      ~paymentMethodType,
      ~pmAuthConnectorsArr,
      ~logger,
      ~sdkAuthorization,
    )->ignore
  }

  <>
    <button
      onClick={_ => onClickHandler()}
      disabled={showLoader}
      style={
        width: "100%",
        padding: "10px",
        borderRadius: themeObj.borderRadius,
        borderColor: themeObj.borderColor,
        borderWidth: "2px",
      }>
      {if showLoader {
        <Loader />
      } else {
        {React.string(localeString.addBankDetailsButtonText)}
      }}
    </button>
    <div className="opacity-50 text-xs mb-2 text-left mt-8" style={color: themeObj.colorText}>
      {React.string(localeString.bankDebitStepsText(paymentMethodType->String.toUpperCase))}
      <ul className="list-disc px-5 py-2">
        <li> {React.string(localeString.bankDebitStep1Text)} </li>
        <li> {React.string(localeString.bankDebitStep2Text)} </li>
      </ul>
    </div>
  </>
}
