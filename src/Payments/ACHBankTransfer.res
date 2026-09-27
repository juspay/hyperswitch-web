open JotaiAtoms
open Utils

@react.component
let make = () => {
  let {iframeId, sdkAuthorization} = Jotai.useAtomValue(keys)
  let isManualRetryEnabled = Jotai.useAtomValue(isManualRetryEnabled)
  let {layout} = Jotai.useAtomValue(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let {themeObj} = Jotai.useAtomValue(configAtom)
  let areRequiredFieldsValid = Jotai.useAtomValue(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(areRequiredFieldsEmpty)
  let intent = PaymentHelpers.usePaymentIntent(BankTransfer)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let complete = areRequiredFieldsValid && !areRequiredFieldsEmpty
  let empty = areRequiredFieldsEmpty

  UtilityHooks.useHandlePostMessages(
    ~complete,
    ~empty,
    ~paymentType="bank_transfer",
    ~loggedPaymentMethod=?LoggerPaymentMethod.fromPair(~method="bank_transfer", ~methodType="ach"),
  )
  SubscriptionEventHooks.useEmitFormStatus(~empty, ~complete)

  let paymentMethodType = "ach"
  let paymentMethod = "bank_transfer"
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
        let message = "Please enter all fields"
        SdkLogger.logLifecycle(
          ~event=FormValidationFailed({reason: "Please enter all fields"}),
          ~paymentMethod=?LoggerPaymentMethod.fromPair(
            ~method=paymentMethod,
            ~methodType=paymentMethodType,
          ),
          ~message,
        )
        postFailedSubmitResponse(~errortype="validation_error", ~message)
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
