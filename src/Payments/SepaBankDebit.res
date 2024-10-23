open RecoilAtoms
open Utils
open PaymentModeType

@react.component
let make = (~paymentType: CardThemeType.mode) => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(isManualRetryEnabled)
  let {config} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)

  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)

  let (modalData, setModalData) = React.useState(_ => None)

  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)

  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let pmAuthMapper = React.useMemo1(
    () =>
      PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(paymentMethodListValue.payment_methods),
    [paymentMethodListValue.payment_methods],
  )

  let isVerifyPMAuthConnectorConfigured =
    displaySavedPaymentMethods && pmAuthMapper->Dict.get("sepa")->Option.isSome

  let complete = switch modalData {
  | Some(data: ACHTypes.data) =>
    data.requiredFieldsBody
    ->Option.getOr(Dict.make())
    ->Dict.valuesToArray
    ->Array.reduce(true, (acc, ele) => acc && ele !== ""->JSON.Encode.string)
  | None => false
  }

  let empty = switch modalData {
  | Some(data: ACHTypes.data) =>
    data.requiredFieldsBody
    ->Option.getOr(Dict.make())
    ->Dict.valuesToArray
    ->Array.reduce(true, (acc, ele) => acc && ele !== ""->JSON.Encode.string)
  | None => true
  }

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="sepa_bank_debit")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if complete {
        switch modalData {
        | Some(data: ACHTypes.data) =>
          let bodyFields = data.requiredFieldsBody->Option.getOr(Dict.make())
          let sepaBody =
            PaymentBody.dynamicPaymentBody("bank_debit", "sepa")
            ->Dict.fromArray
            ->JSON.Encode.object
            ->flattenObject(true)
            ->mergeTwoFlattenedJsonDicts(bodyFields)
            ->getArrayOfTupleFromDict
          intent(
            ~bodyArr=sepaBody,
            ~confirmParam=confirm.confirmParams,
            ~handleUserError=false,
            ~manualRetry=isManualRetryEnabled,
          )
        | None => ()
        }
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, fullName, modalData, isManualRetryEnabled))
  useSubmitPaymentData(submitCallback)

  isVerifyPMAuthConnectorConfigured
    ? <AddBankDetails paymentMethodType="sepa" />
    : <div
        className="flex flex-col animate-slowShow"
        style={
          gridGap: {config.appearance.innerLayout === Spaced ? themeObj.spacingGridColumn : ""},
        }>
        <AddBankAccount modalData setModalData />
        <FullScreenPortal>
          <BankDebitModal setModalData paymentType />
        </FullScreenPortal>
        <Surcharge paymentMethod="bank_debit" paymentMethodType="sepa" />
        <Terms mode=SepaBankDebit />
      </div>
}

let default = make
