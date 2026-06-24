open RecoilAtoms
open Utils

@react.component
let make = () => {
  let {iframeId, sdkAuthorization} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let {layout} = Recoil.useRecoilValueFromAtom(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let complete = areRequiredFieldsValid && !areRequiredFieldsEmpty
  let empty = areRequiredFieldsEmpty

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="bank_transfer")
  SubscriptionEventHooks.useEmitFormStatus(~empty, ~complete)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if areRequiredFieldsValid && !areRequiredFieldsEmpty {
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
  }, (
    areRequiredFieldsValid,
    areRequiredFieldsEmpty,
    isManualRetryEnabled,
    requiredFieldsBody,
    sdkAuthorization,
  ))
  useSubmitPaymentData(submitCallback)

  let paymentMethodType = "ach"
  let paymentMethod = "bank_transfer"

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <RenderIf condition={layoutClass.\"type" === Accordion}>
      <Space height="0" />
    </RenderIf>
    <DynamicFields paymentMethodType paymentMethod setRequiredFieldsBody />
    <Surcharge paymentMethodType paymentMethod />
    <InfoElement />
    <Terms paymentMethodType paymentMethod />
  </div>
}

let default = make
