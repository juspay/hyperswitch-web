open JotaiAtoms
open Utils

@react.component
let make = () => {
  let {iframeId, sdkAuthorization} = Jotai.useAtomValue(keys)
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let {themeObj} = Jotai.useAtomValue(configAtom)
  let {layout} = Jotai.useAtomValue(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let isManualRetryEnabled = Jotai.useAtomValue(isManualRetryEnabled)
  let areRequiredFieldsValid = Jotai.useAtomValue(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(areRequiredFieldsEmpty)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid && !areRequiredFieldsEmpty,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="bank_transfer",
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if areRequiredFieldsValid && !areRequiredFieldsEmpty {
        let bodyArr =
          PaymentBody.dynamicPaymentBody(
            "bank_transfer",
            "sepa_bank_transfer",
          )->mergeAndFlattenToTuples(requiredFieldsBody)

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

  let paymentMethodType = "sepa_bank_transfer"
  let paymentMethod = "bank_transfer"

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
