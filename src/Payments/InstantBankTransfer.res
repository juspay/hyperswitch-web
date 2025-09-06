open RecoilAtoms
open Utils

@react.component
let make = () => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let paymentExperienceArray =
    paymentMethodListValue.payment_methods
    ->Array.find(ele => ele.payment_method === "card")
    ->Option.map(ele =>
      ele.payment_method_types
      ->Array.find(ele => ele.payment_method_type == "credit")
      ->Option.map(ele => ele.payment_experience)
      ->Option.getOr([])
    )
    ->Option.getOr([])

  let eligibleConnectors =
    paymentExperienceArray
    ->Array.at(0)
    ->Option.map(ele => ele.eligible_connectors)
    ->Option.getOr([])

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
  }, (requiredFieldsBody, areRequiredFieldsValid, areRequiredFieldsEmpty, isManualRetryEnabled))
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <DynamicFieldWrapper
      eligibleConnectors
      paymentMethod="bank_transfer"
      paymentMethodType="instant_bank_transfer"
      setRequiredFieldsBody
    />
    <Surcharge paymentMethod="bank_transfer" paymentMethodType="instant" />
    <InfoElement />
  </div>
}

let default = make
