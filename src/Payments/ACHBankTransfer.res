open RecoilAtoms
open Utils

@react.component
let make = (~paymentType: CardThemeType.mode) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let complete = email.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == ""

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="bank_transfer")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        let (connectors, _) = paymentMethodListValue->PaymentUtils.getConnectors(BankTransfer(ACH))
        intent(
          ~bodyArr=PaymentBody.achBankTransferBody(~email=email.value, ~connectors),
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~iframeId,
          ~manualRetry=isManualRetryEnabled,
          (),
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, isManualRetryEnabled))
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <EmailPaymentInput paymentType />
    <Surcharge paymentMethod="bank_transfer" paymentMethodType="ach" />
    <InfoElement />
  </div>
}

let default = make
