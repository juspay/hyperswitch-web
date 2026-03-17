open RecoilAtoms
open Utils

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

  let paymentMethodType = "sepa"
  let paymentMethod = "bank_debit"

  let isVerifyPMAuthConnectorConfigured =
    displaySavedPaymentMethods && pmAuthMapper->Dict.get(paymentMethodType)->Option.isSome

  let empty = areRequiredFieldsEmpty
  let complete = areRequiredFieldsValid
  SubscriptionEventHooks.useFormStatus(~empty, ~complete)

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="sepa_bank_debit")

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
