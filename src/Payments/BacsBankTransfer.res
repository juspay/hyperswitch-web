open RecoilAtoms
open Utils

let default = (paymentType: CardThemeType.mode) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let complete = email.value != "" && fullName.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == "" || fullName.value == ""

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
        let (connectors, _) = paymentMethodListValue->PaymentUtils.getConnectors(BankTransfer(Bacs))
        intent(
          ~bodyArr=PaymentBody.bacsBankTransferBody(
            ~email=email.value,
            ~name=fullName.value,
            ~connectors,
          ),
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~iframeId,
          (),
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, [email, fullName])
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <EmailPaymentInput paymentType />
    <FullNamePaymentInput paymentType />
    <Surcharge paymentMethod="bank_transfer" paymentMethodType="bacs" />
    <InfoElement />
  </div>
}
