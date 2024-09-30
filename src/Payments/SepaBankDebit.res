open RecoilAtoms
open RecoilAtomTypes
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

  let complete =
    email.value != "" &&
    fullName.value != "" &&
    email.isValid->Option.getOr(false) &&
    switch modalData {
    | Some(val: ACHTypes.data) => val.iban !== "" || val.accountHolderName !== ""
    | None => false
    }
  let empty =
    email.value == "" ||
    fullName.value == "" ||
    switch modalData {
    | Some(val: ACHTypes.data) => val.iban === "" || val.accountHolderName === ""
    | None => true
    }

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="sepa_bank_debit")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let makeSepaBody = bodyFields => {
    let address =
      [
        (
          "address",
          [
            (
              "first_name",
              bodyFields->getJsonObjectFromDict("payment_method_data.billing.address.first_name"),
            ),
            (
              "last_name",
              bodyFields->getJsonObjectFromDict("payment_method_data.billing.address.last_name"),
            ),
          ]->getJsonFromArrayOfJson,
        ),
      ]->getJsonFromArrayOfJson

    let bankDebitBody =
      [
        (
          "sepa_bank_debit",
          [
            ("iban", bodyFields->getJsonObjectFromDict("payment_method_data.bank_debit.sepa.iban")),
          ]->getJsonFromArrayOfJson,
        ),
      ]->getJsonFromArrayOfJson

    let sepaBankBody = [
      (
        "payment_method_data",
        [("billing", address), ("bank_debit", bankDebitBody)]->getJsonFromArrayOfJson,
      ),
    ]

    PaymentBody.bankDebitsCommonBody("sepa")->Array.concat(sepaBankBody)
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if complete {
        switch modalData {
        | Some(data: ACHTypes.data) =>
          let bodyFields = data.requiredFieldsBody->Option.getOr(Dict.make())

          intent(
            ~bodyArr=makeSepaBody(bodyFields),
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
