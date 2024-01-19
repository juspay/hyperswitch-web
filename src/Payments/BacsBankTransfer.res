open RecoilAtoms
open Utils

type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
}

let default = (props: props) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)

  let complete =
    email.value != "" && fullName.value != "" && email.isValid->Belt.Option.getWithDefault(false)
  let empty = email.value == "" || fullName.value == ""

  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="bank_transfer", ~loggerState)
    None
  }, (empty, complete))

  React.useEffect1(() => {
    setComplete(._ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback1((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        let (connectors, _) = props.list->PaymentUtils.getConnectors(BankTransfer(Bacs))
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
  submitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingTab, ())}>
    <EmailPaymentInput paymentType=props.paymentType />
    <FullNamePaymentInput paymentType={props.paymentType} />
    <Surcharge list=props.list paymentMethod="bank_transfer" paymentMethodType="bacs" />
    <InfoElement />
  </div>
}
