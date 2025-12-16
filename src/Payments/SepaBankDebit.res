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
  let (areRequiredFieldsValid, setAreRequiredFieldsValid) = React.useState(_ => true)
  let (areRequiredFieldsEmpty, setAreRequiredFieldsEmpty) = React.useState(_ => false)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let pmAuthMapper = React.useMemo1(
    () =>
      PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(paymentMethodListValue.payment_methods),
    [paymentMethodListValue.payment_methods],
  )

  let isVerifyPMAuthConnectorConfigured =
    displaySavedPaymentMethods && pmAuthMapper->Dict.get("sepa")->Option.isSome

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="sepa_bank_debit",
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let body = switch GlobalVars.sdkVersion {
    | V1 => PaymentBody.dynamicPaymentBody("bank_debit", "sepa")
    | V2 => PaymentBodyV2.dynamicPaymentBodyV2("bank_debit", "sepa")
    }
    if confirm.doSubmit && !isGiftCardOnlyPayment {
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
  }, (
    isManualRetryEnabled,
    areRequiredFieldsValid,
    areRequiredFieldsEmpty,
    requiredFieldsBody,
    isGiftCardOnlyPayment,
  ))

  useSubmitPaymentData(submitCallback)

  isVerifyPMAuthConnectorConfigured
    ? <AddBankDetails paymentMethodType="sepa" />
    : <div
        className="flex flex-col animate-slowShow"
        style={
          gridGap: {config.appearance.innerLayout === Spaced ? themeObj.spacingGridColumn : ""},
        }>
        <DynamicFields
          paymentMethod="bank_debit"
          paymentMethodType="sepa"
          setRequiredFieldsBody
          setAreRequiredFieldsValid
          setAreRequiredFieldsEmpty
        />
        <Surcharge paymentMethod="bank_debit" paymentMethodType="sepa" />
        <Terms mode=SepaBankDebit />
      </div>
}

let default = make
