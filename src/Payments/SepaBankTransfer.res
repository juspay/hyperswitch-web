open RecoilAtoms
open Utils

@react.component
let make = () => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid && !areRequiredFieldsEmpty,
    ~empty=areRequiredFieldsEmpty,
    ~paymentType="bank_transfer",
  )

  let paymentMethod = "bank_transfer"
  let paymentMethodType = "sepa_bank_transfer"

  let submitCallback = (ev: Window.event, mergedValues, values) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let paymentBody = PaymentBody.buildSuperpositionBody(
      ~paymentMethod,
      ~paymentMethodType,
      ~paymentMethodData=mergedValues,
    )
    intent(
      ~bodyArr=paymentBody,
      ~confirmParam=confirm.confirmParams,
      ~handleUserError=false,
      ~iframeId,
      ~manualRetry=isManualRetryEnabled,
    )
    Console.log2("SEPA Bank Transfer Submit Callback Invoked", (mergedValues, values))
    ()
  }
  // useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <DynamicFieldsSuperposition paymentMethod paymentMethodType submitCallback />
    <Surcharge paymentMethod paymentMethodType />
    <InfoElement />
  </div>
}

let default = make
