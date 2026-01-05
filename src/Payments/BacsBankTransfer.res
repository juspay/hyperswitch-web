open RecoilAtoms
open Utils

@react.component
let default = () => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let complete = email.value != "" && fullName.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == "" || fullName.value == ""

  let paymentMethodType = "bacs"
  let paymentMethod = "bank_transfer"

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType=paymentMethod)

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        let bodyArr =
          PaymentBody.dynamicPaymentBody(paymentMethod, paymentMethodType)->mergeAndFlattenToTuples(
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
  }, (isManualRetryEnabled, email, fullName))
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <DynamicFields paymentMethod paymentMethodType setRequiredFieldsBody />
    <Surcharge paymentMethod paymentMethodType />
    <InfoElement />
    <Terms paymentMethodType paymentMethod />
  </div>
}
