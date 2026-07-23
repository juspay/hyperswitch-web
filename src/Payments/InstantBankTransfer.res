open JotaiAtoms
open Utils

@react.component
let make = () => {
  let {iframeId, sdkAuthorization} = Jotai.useAtomValue(keys)
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let {themeObj} = Jotai.useAtomValue(configAtom)
  let areRequiredFieldsValid = Jotai.useAtomValue(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(areRequiredFieldsEmpty)
  let isManualRetryEnabled = Jotai.useAtomValue(isManualRetryEnabled)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let {layout} = Jotai.useAtomValue(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let paymentMethodType = "instant_bank_transfer"
  let paymentMethod = "bank_transfer"

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid && !areRequiredFieldsEmpty,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType=paymentMethod,
  )
  SubscriptionEventHooks.useEmitFormStatus(
    ~empty=areRequiredFieldsEmpty,
    ~complete=areRequiredFieldsValid && !areRequiredFieldsEmpty,
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if areRequiredFieldsValid && !areRequiredFieldsEmpty {
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
  }, (
    requiredFieldsBody,
    areRequiredFieldsValid,
    areRequiredFieldsEmpty,
    isManualRetryEnabled,
    sdkAuthorization,
  ))
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

let default = make
