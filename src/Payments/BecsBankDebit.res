open RecoilAtoms
open Utils
open PaymentModeType

@react.component
let make = () => {
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let {config, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)
  let {displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)

  let pmAuthMapper = React.useMemo1(
    () =>
      PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(paymentMethodListValue.payment_methods),
    [paymentMethodListValue.payment_methods],
  )

  let isVerifyPMAuthConnectorConfigured =
    displaySavedPaymentMethods && pmAuthMapper->Dict.get("becs")->Option.isSome

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="becs_bank_debit",
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let body = PaymentBody.dynamicPaymentBody("bank_debit", "becs")

    if confirm.doSubmit {
      if areRequiredFieldsValid && !areRequiredFieldsEmpty {
        let becsBody =
          body
          ->getJsonFromArrayOfJson
          ->flattenObject(true)
          ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->getArrayOfTupleFromDict
        intent(
          ~bodyArr=becsBody,
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
    ? <AddBankDetails paymentMethodType="becs" />
    : <div
        className="flex flex-col animate-slowShow"
        style={
          gridGap: {config.appearance.innerLayout === Spaced ? themeObj.spacingGridColumn : ""},
        }>
        <DynamicFields paymentMethod="bank_debit" paymentMethodType="becs" setRequiredFieldsBody />
        <Surcharge paymentMethod="bank_debit" paymentMethodType="becs" />
        <Terms mode={BecsBankDebit} />
      </div>
}

let default = make
