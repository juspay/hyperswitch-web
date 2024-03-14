open RecoilAtoms
open Utils

@react.component
let make = (~paymentType: CardThemeType.mode, ~list: PaymentMethodsRecord.list) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)

  let complete = email.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == ""

  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="bank_transfer", ~loggerState)
    None
  }, (empty, complete))

  React.useEffect1(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback1((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        let (connectors, _) = list->PaymentUtils.getConnectors(BankTransfer(ACH))
        intent(
          ~bodyArr=PaymentBody.achBankTransferBody(~email=email.value, ~connectors),
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~iframeId,
          (),
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, [email])
  useSubmitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingTab, ())}>
    <EmailPaymentInput paymentType />
    <Surcharge list paymentMethod="bank_transfer" paymentMethodType="ach" />
    <InfoElement />
  </div>
}

let default = make
