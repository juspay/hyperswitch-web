open RecoilAtoms
open RecoilAtomTypes
open Utils

let formatSortCode = sortcode => {
  let formatted = sortcode->Js.String2.replaceByRe(%re("/\D+/g"), "")
  let firstPart = formatted->CardUtils.slice(0, 2)
  let secondPart = formatted->CardUtils.slice(2, 4)
  let thirdpart = formatted->CardUtils.slice(4, 6)

  if formatted->Js.String2.length <= 2 {
    firstPart
  } else if formatted->Js.String2.length > 2 && formatted->Js.String2.length <= 4 {
    `${firstPart}-${secondPart}`
  } else if formatted->Js.String2.length > 4 && formatted->Js.String2.length <= 6 {
    `${firstPart}-${secondPart}-${thirdpart}`
  } else {
    formatted
  }
}
let cleanSortCode = str => str->Js.String2.replaceByRe(%re("/-/g"), "")

@react.component
let make = (~paymentType: CardThemeType.mode, ~list: PaymentMethodsRecord.list) => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)

  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankDebits)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let (line1, _) = Recoil.useLoggedRecoilState(userAddressline1, "line1", loggerState)
  let (line2, _) = Recoil.useLoggedRecoilState(userAddressline2, "line2", loggerState)
  let (country, _) = Recoil.useLoggedRecoilState(userAddressCountry, "country", loggerState)
  let (city, _) = Recoil.useLoggedRecoilState(userAddressCity, "city", loggerState)
  let (postalCode, _) = Recoil.useLoggedRecoilState(userAddressPincode, "postal_code", loggerState)
  let (state, _) = Recoil.useLoggedRecoilState(userAddressState, "state", loggerState)
  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let (sortcode, setSortcode) = React.useState(_ => "")
  let (accountNumber, setAccountNumber) = React.useState(_ => "")

  let (sortCodeError, setSortCodeError) = React.useState(_ => "")

  let sortCodeRef = React.useRef(Js.Nullable.null)
  let accNumRef = React.useRef(Js.Nullable.null)

  let complete =
    email.value != "" &&
    email.isValid->Belt.Option.getWithDefault(false) &&
    sortcode->cleanSortCode->Js.String2.length == 6 &&
    accountNumber != "" &&
    fullName.value != "" &&
    isAddressComplete(line1, state, city, country, postalCode) &&
    postalCode.isValid->Belt.Option.getWithDefault(false)

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

  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="bacs_bank_debit", ~loggerState)
    None
  }, (empty, complete))

  React.useEffect1(() => {
    setComplete(._ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper

    if confirm.doSubmit {
      if complete {
        let body = PaymentBody.bacsBankDebitBody(
          ~email=email.value,
          ~accNum=accountNumber,
          ~sortCode=sortcode,
          ~line1=line1.value,
          ~line2=line2.value,
          ~city=city.value,
          ~zip=postalCode.value,
          ~state=state.value,
          ~country=getCountryCode(country.value).isoAlpha2,
          ~bankAccountHolderName=fullName.value,
        )
        intent(~bodyArr=body, ~confirmParam=confirm.confirmParams, ~handleUserError=false, ())
        ()
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  })
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
    if val->Js.String2.length != 6 && val->Js.String2.length > 0 {
      setSortCodeError(_ => "Your sort code is invalid.")
    }
  }

  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
    <div className="flex flex-row" style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridRow, ())}>
      <PaymentInputField
        fieldName=localeString.sortCodeText
        value=sortcode
        onChange=changeSortCode
        paymentType
        errorString=sortCodeError
        isValid={sortCodeError == "" ? None : Some(false)}
        type_="tel"
        appearance=config.appearance
        maxLength=8
        onBlur=sortcodeBlur
        inputRef=sortCodeRef
        placeholder="10-80-00"
      />
      <PaymentInputField
        fieldName=localeString.accountNumberText
        value=accountNumber
        onChange=changeAccNum
        paymentType
        type_="text"
        appearance=config.appearance
        inputRef=accNumRef
        placeholder="00012345"
      />
    </div>
    <EmailPaymentInput paymentType />
    <FullNamePaymentInput paymentType={paymentType} customFieldName=Some("Bank Holder Name") />
    <AddressPaymentInput paymentType />
    <Surcharge list paymentMethod="bank_debit" paymentMethodType="bacs" />
  </div>
}

let default = make
