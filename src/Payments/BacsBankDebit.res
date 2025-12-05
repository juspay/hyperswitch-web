open RecoilAtoms
open RecoilAtomTypes
open Utils

let formatSortCode = sortcode => {
  let formatted = sortcode->String.replaceRegExp(%re("/\D+/g"), "")
  let firstPart = formatted->String.slice(~start=0, ~end=2)
  let secondPart = formatted->String.slice(~start=2, ~end=4)
  let thirdpart = formatted->String.slice(~start=4, ~end=6)

  if formatted->String.length <= 2 {
    firstPart
  } else if formatted->String.length > 2 && formatted->String.length <= 4 {
    `${firstPart}-${secondPart}`
  } else if formatted->String.length > 4 && formatted->String.length <= 6 {
    `${firstPart}-${secondPart}-${thirdpart}`
  } else {
    formatted
  }
}
let cleanSortCode = str => str->String.replaceRegExp(%re("/-/g"), "")

@react.component
let make = () => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {displaySavedPaymentMethods} = Recoil.useRecoilValueFromAtom(optionAtom)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let line1 = Recoil.useRecoilValueFromAtom(userAddressline1)
  let line2 = Recoil.useRecoilValueFromAtom(userAddressline2)
  let country = Recoil.useRecoilValueFromAtom(userAddressCountry)
  let city = Recoil.useRecoilValueFromAtom(userAddressCity)
  let postalCode = Recoil.useRecoilValueFromAtom(userAddressPincode)
  let state = Recoil.useRecoilValueFromAtom(userAddressState)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let (sortcode, setSortcode) = React.useState(_ => "")
  let (accountNumber, setAccountNumber) = React.useState(_ => "")
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let isGiftCardOnlyPayment = GiftCardHook.useIsGiftCardOnlyPayment()
  let countryCode = Utils.getCountryCode(country.value).isoAlpha2
  let stateCode = Utils.getStateCodeFromStateName(state.value, countryCode)

  let (sortCodeError, setSortCodeError) = React.useState(_ => "")

  let sortCodeRef = React.useRef(Nullable.null)
  let accNumRef = React.useRef(Nullable.null)

  let pmAuthMapper = React.useMemo1(
    () =>
      PmAuthConnectorUtils.findPmAuthAllPMAuthConnectors(paymentMethodListValue.payment_methods),
    [paymentMethodListValue.payment_methods],
  )

  let isVerifyPMAuthConnectorConfigured =
    displaySavedPaymentMethods && pmAuthMapper->Dict.get("sepa")->Option.isSome

  let complete =
    email.value != "" &&
    email.isValid->Option.getOr(false) &&
    sortcode->cleanSortCode->String.length == 6 &&
    accountNumber != "" &&
    fullName.value != "" &&
    isAddressComplete(line1, state, city, country, postalCode) &&
    postalCode.isValid->Option.getOr(false)

  let empty =
    email.value == "" ||
    sortcode == "" ||
    fullName.value != "" ||
    accountNumber == "" ||
    line1.value == "" && line2.value == "" ||
    city.value == "" ||
    postalCode.value == "" ||
    country.value == "" ||
    state.value == ""

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="bacs_bank_debit")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = (ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if isGiftCardOnlyPayment {
        ()
      } else if complete {
        let body = PaymentBody.bacsBankDebitBody(
          ~email=email.value,
          ~accNum=accountNumber,
          ~sortCode=sortcode,
          ~line1=line1.value,
          ~line2=line2.value,
          ~city=city.value,
          ~zip=postalCode.value,
          ~stateCode,
          ~country=countryCode,
          ~bankAccountHolderName=fullName.value,
        )
        intent(
          ~bodyArr=body,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~manualRetry=isManualRetryEnabled,
        )
        ()
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }
  useSubmitPaymentData(submitCallback)

  let changeSortCode = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    setSortCodeError(_ => "")
    setSortcode(_ => val->formatSortCode)
  }
  let changeAccNum = ev => {
    let val = ReactEvent.Form.target(ev)["value"]
    setAccountNumber(_ => val->onlyDigits)
  }
  let sortcodeBlur = ev => {
    let val = ReactEvent.Focus.target(ev)["value"]->cleanSortCode
    if val->String.length != 6 && val->String.length > 0 {
      setSortCodeError(_ => "Your sort code is invalid.")
    }
  }

  <>
    <RenderIf condition={isVerifyPMAuthConnectorConfigured}>
      <AddBankDetails paymentMethodType="bacs" />
    </RenderIf>
    <RenderIf condition={!isVerifyPMAuthConnectorConfigured}>
      <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingGridColumn}>
        <div className="flex flex-row" style={gridGap: themeObj.spacingGridRow}>
          <PaymentInputField
            fieldName=localeString.sortCodeText
            value=sortcode
            onChange=changeSortCode
            errorString=sortCodeError
            isValid={sortCodeError == "" ? None : Some(false)}
            type_="tel"
            maxLength=8
            onBlur=sortcodeBlur
            inputRef=sortCodeRef
            placeholder="10-80-00"
          />
          <PaymentInputField
            fieldName=localeString.accountNumberText
            value=accountNumber
            onChange=changeAccNum
            type_="text"
            inputRef=accNumRef
            placeholder="00012345"
          />
        </div>
        <EmailPaymentInput />
        <FullNamePaymentInput customFieldName=Some("Bank Holder Name") />
        <AddressPaymentInput />
        <Surcharge paymentMethod="bank_debit" paymentMethodType="bacs" />
      </div>
    </RenderIf>
  </>
}

let default = make
