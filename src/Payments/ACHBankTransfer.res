open RecoilAtoms
open Utils

@react.component
let make = () => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (_, setAreRequiredFieldsValid) = React.useState(_ => true)
  let (_, setAreRequiredFieldsEmpty) = React.useState(_ => false)

  let complete = email.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == ""

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="bank_transfer")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if isGiftCardOnlyPayment {
        ()
      } else if complete {
        let bodyArr =
          PaymentBody.dynamicPaymentBody("bank_transfer", "ach")->mergeAndFlattenToTuples(
            requiredFieldsBody,
          )
        intent(
          ~bodyArr,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~iframeId,
          ~manualRetry=isManualRetryEnabled,
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, isManualRetryEnabled, isGiftCardOnlyPayment))
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <DynamicFields
      paymentMethod="bank_transfer"
      paymentMethodType="ach"
      setRequiredFieldsBody
      setAreRequiredFieldsValid
      setAreRequiredFieldsEmpty
    />
    <Surcharge paymentMethod="bank_transfer" paymentMethodType="ach" />
    <InfoElement />
  </div>
}

let default = make
