open RecoilAtoms
open Utils
@react.component
let make = () => {
  let (loggerState, _setLoggerState) = Recoil.useRecoilState(loggerAtom)
  let {config, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), KlarnaRedirect)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)

  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  UtilityHooks.useHandlePostMessages(
    ~complete=!areRequiredFieldsEmpty && areRequiredFieldsValid,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="klarna",
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    let body = PaymentBody.klarnaRedirectionBody()
    if confirm.doSubmit {
      if areRequiredFieldsValid && !areRequiredFieldsEmpty {
        intent(
          ~bodyArr=body->mergeAndFlattenToTuples(requiredFieldsBody),
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~manualRetry=isManualRetryEnabled,
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (isManualRetryEnabled, areRequiredFieldsEmpty, areRequiredFieldsValid, requiredFieldsBody))
  useSubmitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={
      gridGap: config.appearance.innerLayout === Spaced ? themeObj.spacingGridColumn : "",
    }>
    <DynamicFields paymentMethod="pay_later" paymentMethodType="klarna" setRequiredFieldsBody />
    <Surcharge paymentMethod="pay_later" paymentMethodType="klarna" />
    <InfoElement />
  </div>
}

let default = make
