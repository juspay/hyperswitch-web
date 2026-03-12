open Utils

@react.component
let make = () => {
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)
  let {config, themeObj} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)
  let {displaySavedPaymentMethods} = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let areRequiredFieldsValid = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsEmpty)

  let pmAuthMapper = React.useMemo1(
    () =>
      PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(paymentMethodListValue.payment_methods),
    [paymentMethodListValue.payment_methods],
  )

  let paymentMethodType = "sepa"
  let paymentMethod = "bank_debit"

  let isVerifyPMAuthConnectorConfigured =
    displaySavedPaymentMethods && pmAuthMapper->Dict.get(paymentMethodType)->Option.isSome

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="sepa_bank_debit",
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let body = PaymentBody.dynamicPaymentBody(paymentMethod, paymentMethodType)

    if confirm.doSubmit {
      if areRequiredFieldsValid && !areRequiredFieldsEmpty {
        let sepaBody =
          body
          ->getJsonFromArrayOfJson
          ->flattenObject(true)
          ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->getArrayOfTupleFromDict
        intent(
          ~bodyArr=sepaBody,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~manualRetry=isManualRetryEnabled,
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (isManualRetryEnabled, areRequiredFieldsValid, areRequiredFieldsEmpty, requiredFieldsBody))

  useSubmitPaymentData(submitCallback)

  isVerifyPMAuthConnectorConfigured
    ? <AddBankDetails paymentMethodType />
    : <div
        className="flex flex-col animate-slowShow"
        style={
          gridGap: {config.appearance.innerLayout === Spaced ? themeObj.spacingGridColumn : ""},
        }>
        <DynamicFields paymentMethod paymentMethodType setRequiredFieldsBody />
        <Surcharge paymentMethod paymentMethodType />
        <Terms paymentMethod paymentMethodType />
      </div>
}

let default = make
