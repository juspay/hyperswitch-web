@react.component
let make = (~paymentMethodType) => {
  open Utils
  let {publishableKey, clientSecret, iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let setShowFields = Recoil.useSetRecoilState(RecoilAtoms.showCardFieldsAtom)

  let pmAuthConnectorsArr =
    PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(
      paymentMethodListValue.payment_methods,
    )->PmAuthConnectorUtils.getAllRequiredPmAuthConnectors

  React.useEffect0(() => {
    let onPlaidCallback = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let dict = json->Utils.getDictFromJson
      if dict->getBool("isPlaid", false) {
        let publicToken = dict->getDictFromDict("data")->getString("publicToken", "")
        if publicToken->String.length > 0 {
          PaymentHelpers.callAuthExchange(
            ~publicToken,
            ~clientSecret,
            ~paymentMethodType,
            ~publishableKey,
          )
          ->Promise.then(_ => {
            setShowFields(_ => false)
            JSON.Encode.null->Promise.resolve
          })
          ->Promise.catch(_ => JSON.Encode.null->Promise.resolve)
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
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      postFailedSubmitResponse(
        ~errortype="validation_error",
        ~message="Payment cannot be performed. Please go to saved PM Screen to update your payment method.",
      )
    }
  }, [])
  useSubmitPaymentData(submitCallback)

  <button
    onClick={_ =>
      PaymentHelpers.callAuthLink(
        ~publishableKey,
        ~clientSecret,
        ~iframeId,
        ~paymentMethodType,
        ~pmAuthConnectorsArr,
      )->ignore}
    style={
      width: "100%",
      padding: "20px",
      cursor: "pointer",
      borderRadius: themeObj.borderRadius,
      borderColor: themeObj.borderColor,
      borderWidth: "2px",
    }>
    {React.string("Verify Bank Details")}
  </button>
}
