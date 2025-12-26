open RecoilAtoms
open Utils

@react.component
let default = () => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (_, setAreRequiredFieldsValid) = React.useState(_ => true)
  let (_, setAreRequiredFieldsEmpty) = React.useState(_ => false)

  let complete = email.value != "" && fullName.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == "" || fullName.value == ""

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="bank_transfer")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit && !isGiftCardOnlyPayment {
      if complete {
        let bodyArr =
          PaymentBody.dynamicPaymentBody("bank_transfer", "bacs")->mergeAndFlattenToTuples(
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
  }, (isManualRetryEnabled, email, fullName, isGiftCardOnlyPayment))
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <DynamicFields
      paymentMethod="bank_transfer"
      paymentMethodType="bacs"
      setRequiredFieldsBody
      setAreRequiredFieldsValid
      setAreRequiredFieldsEmpty
    />
    <Surcharge paymentMethod="bank_transfer" paymentMethodType="bacs" />
    <InfoElement />
  </div>
}
