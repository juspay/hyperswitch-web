open JotaiAtoms
open Utils

@react.component
let default = () => {
  let {iframeId, sdkAuthorization} = Jotai.useAtomValue(keys)
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let {themeObj} = Jotai.useAtomValue(configAtom)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let email = Jotai.useAtomValue(userEmailAddress)
  let fullName = Jotai.useAtomValue(userFullName)
  let setComplete = Jotai.useSetAtom(fieldsComplete)
  let {layout} = Jotai.useAtomValue(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let complete = email.value != "" && fullName.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == "" || fullName.value == ""

  let paymentMethodType = "bacs"
  let paymentMethod = "bank_transfer"

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType=paymentMethod)
  SubscriptionEventHooks.useEmitFormStatus(~empty, ~complete)

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
  }, (isManualRetryEnabled, email, fullName, sdkAuthorization, requiredFieldsBody))
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <RenderIf condition={layoutClass.\"type" === Accordion}>
      <Space height="0" />
    </RenderIf>
    <DynamicFields paymentMethod paymentMethodType setRequiredFieldsBody />
    <Surcharge paymentMethod paymentMethodType />
    <InfoElement />
    <Terms paymentMethodType paymentMethod />
  </div>
}
