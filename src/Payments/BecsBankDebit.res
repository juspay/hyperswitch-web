open RecoilAtoms
open RecoilAtomTypes
open Utils

@react.component
let make = () => {
  let cleanBSB = str => str->String.replaceRegExp(%re("/-/g"), "")

  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let (modalData, setModalData) = React.useState(_ => None)

  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let line1 = Recoil.useRecoilValueFromAtom(userAddressline1)
  let line2 = Recoil.useRecoilValueFromAtom(userAddressline2)
  let country = Recoil.useRecoilValueFromAtom(userAddressCountry)
  let city = Recoil.useRecoilValueFromAtom(userAddressCity)
  let postalCode = Recoil.useRecoilValueFromAtom(userAddressPincode)
  let state = Recoil.useRecoilValueFromAtom(userAddressState)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let countryCode = Utils.getCountryCode(country.value).isoAlpha2
  let stateCode = Utils.getStateCodeFromStateName(state.value, countryCode)

  let complete =
    email.value != "" &&
    fullName.value != "" &&
    email.isValid->Option.getOr(false) &&
    switch modalData {
    | Some(data: ACHTypes.data) =>
      data.accountNumber->String.length == 9 && data.sortCode->cleanBSB->String.length == 6
    | None => false
    }

  let empty =
    email.value == "" ||
    fullName.value == "" ||
    switch modalData {
    | Some(data: ACHTypes.data) => data.accountNumber == "" && data.sortCode == ""
    | None => true
    }

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="becs_bank_debit")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if isGiftCardOnlyPayment {
        ()
      } else if complete {
        switch modalData {
        | Some(data: ACHTypes.data) => {
            let body = PaymentBody.becsBankDebitBody(
              ~fullName=fullName.value,
              ~email=email.value,
              ~data,
              ~line1=line1.value,
              ~line2=line2.value,
              ~country=countryCode,
              ~city=city.value,
              ~postalCode=postalCode.value,
              ~stateCode,
            )
            intent(
              ~bodyArr=body,
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        | None => ()
        }
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, fullName, modalData, isManualRetryEnabled, isGiftCardOnlyPayment))
  useSubmitPaymentData(submitCallback)

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingGridColumn}>
    <EmailPaymentInput />
    <FullNamePaymentInput />
    <AddBankAccount modalData setModalData />
    <FullScreenPortal>
      <BankDebitModal setModalData />
    </FullScreenPortal>
    <Surcharge paymentMethod="bank_debit" paymentMethodType="becs" />
    <Terms mode=PaymentModeType.BecsBankDebit />
  </div>
}

let default = make
