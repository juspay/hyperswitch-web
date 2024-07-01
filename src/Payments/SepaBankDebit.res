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
  let (modalData, setModalData) = React.useState(_ => None)

  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let (line1, _) = Recoil.useLoggedRecoilState(userAddressline1, "line1", loggerState)
  let (line2, _) = Recoil.useLoggedRecoilState(userAddressline2, "line2", loggerState)
  let (country, _) = Recoil.useLoggedRecoilState(userAddressCountry, "country", loggerState)
  let (city, _) = Recoil.useLoggedRecoilState(userAddressCity, "city", loggerState)
  let (postalCode, _) = Recoil.useLoggedRecoilState(userAddressPincode, "postal_code", loggerState)
  let (state, _) = Recoil.useLoggedRecoilState(userAddressState, "state", loggerState)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)

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

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if complete {
        switch modalData {
        | Some(data: ACHTypes.data) => {
            let body = PaymentBody.sepaBankDebitBody(
              ~fullName=fullName.value,
              ~email=email.value,
              ~data,
              ~line1=line1.value,
              ~line2=line2.value,
              ~country=getCountryCode(country.value).isoAlpha2,
              ~city=city.value,
              ~postalCode=postalCode.value,
              ~state=state.value,
            )
            intent(
              ~bodyArr=body,
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
              (),
            )
          }
        | None => ()
        }
        ()
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, fullName, modalData, isManualRetryEnabled))
  useSubmitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={
      gridGap: {config.appearance.innerLayout === Spaced ? themeObj.spacingGridColumn : ""},
    }>
    <EmailPaymentInput paymentType />
    <FullNamePaymentInput paymentType />
    <AddBankAccount modalData setModalData />
    <FullScreenPortal>
      <BankDebitModal setModalData />
    </FullScreenPortal>
    <Surcharge paymentMethod="bank_debit" paymentMethodType="sepa" />
    <Terms mode=SepaBankDebit />
  </div>
}

let default = make
