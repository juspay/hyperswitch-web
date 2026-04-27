open RecoilAtoms
open Utils
open ACHTypes

@react.component
let make = () => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let pmAuthMapper = React.useMemo1(
    () =>
      PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(paymentMethodListValue.payment_methods),
    [paymentMethodListValue.payment_methods],
  )

  let isVerifyPMAuthConnectorConfigured =
    displaySavedPaymentMethods && pmAuthMapper->Dict.get("ach")->Option.isSome

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let complete = areRequiredFieldsValid && !areRequiredFieldsEmpty
  let empty = areRequiredFieldsEmpty

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="ach_bank_debit")

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if complete {
        let body =
          PaymentBody.dynamicPaymentBody("bank_debit", "ach")
          ->getJsonFromArrayOfJson
          ->flattenObject(true)
          ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->getArrayOfTupleFromDict
        intent(
          ~bodyArr=body,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~manualRetry=isManualRetryEnabled,
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (isManualRetryEnabled, requiredFieldsBody, areRequiredFieldsValid, areRequiredFieldsEmpty))
  useSubmitPaymentData(submitCallback)

  let paymentMethodType = "ach"
  let paymentMethod = "bank_debit"

  <>
    <RenderIf condition={isVerifyPMAuthConnectorConfigured}>
      <AddBankDetails paymentMethodType />
    </RenderIf>
    <RenderIf condition={!isVerifyPMAuthConnectorConfigured}>
      <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingGridColumn}>
        <DynamicFields paymentMethod paymentMethodType setRequiredFieldsBody />
        <Surcharge paymentMethod paymentMethodType />
        <Terms paymentMethod paymentMethodType />
      </div>
    </RenderIf>
  </>
}

let default = make
