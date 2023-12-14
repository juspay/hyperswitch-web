open RecoilAtoms
open RecoilAtomTypes
open Utils
open PaymentModeType

@react.component
let make = (~paymentType: CardThemeType.mode, ~list: PaymentMethodsRecord.list) => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
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
    email.isValid->Belt.Option.getWithDefault(false) &&
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

  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="sepa_bank_debit", ~loggerState)
    None
  }, (empty, complete))

  React.useEffect1(() => {
    setComplete(._ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback3((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
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
            intent(~bodyArr=body, ~confirmParam=confirm.confirmParams, ~handleUserError=false, ())
          }
        | None => ()
        }
        ()
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, fullName, modalData))
  submitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
    <EmailPaymentInput paymentType />
    <FullNamePaymentInput paymentType />
    <AddBankAccount modalData setModalData />
    <FullScreenPortal>
      <BankDebitModal setModalData />
    </FullScreenPortal>
    <Surcharge list paymentMethod="bank_debit" paymentMethodType="sepa" />
    <Terms mode=SepaBankDebit />
  </div>
}

let default = make
