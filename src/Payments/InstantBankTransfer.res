open RecoilAtoms
open Utils

@react.component
let make = () => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let (areRequiredFieldsValid, setAreRequiredFieldsValid) = React.useState(_ => true)
  let (areRequiredFieldsEmpty, setAreRequiredFieldsEmpty) = React.useState(_ => false)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid && !areRequiredFieldsEmpty,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="bank_transfer",
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit && !isGiftCardOnlyPayment {
      if areRequiredFieldsValid && !areRequiredFieldsEmpty {
        let bodyArr =
          PaymentBody.dynamicPaymentBody(
            "bank_transfer",
            "instant_bank_transfer",
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
    requiredFieldsBody,
    areRequiredFieldsValid,
    areRequiredFieldsEmpty,
    isManualRetryEnabled,
    isGiftCardOnlyPayment,
  ))
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <DynamicFields
      paymentMethod="bank_transfer"
      paymentMethodType="instant_bank_transfer"
      setRequiredFieldsBody
      setAreRequiredFieldsValid
      setAreRequiredFieldsEmpty
    />
    <Surcharge paymentMethod="bank_transfer" paymentMethodType="instant" />
    <InfoElement />
  </div>
}

let default = make
