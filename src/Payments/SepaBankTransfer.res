open RecoilAtoms
open Utils

@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
  ~countryProps: (string, array<string>),
) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), BankTransfer)
  let (country, setCountry) = React.useState(_ => "France")
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let showAddressDetails = PaymentType.getShowAddressDetails(
    ~billingDetails=fields.billingDetails,
    ~logger=loggerState,
  )
  let (_clientCountry, countryNames) = countryProps
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let clientCountryCode =
    Country.country
    ->Js.Array2.find(item => item.countryName == country)
    ->Belt.Option.getWithDefault(Country.defaultTimeZone)
  let complete =
    email.value != "" && fullName.value != "" && email.isValid->Belt.Option.getWithDefault(false)
  let empty = email.value == "" || fullName.value == ""

  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="bank_transfer", ~loggerState)
    None
  }, (empty, complete))
  React.useEffect1(() => {
    setComplete(._ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback3((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        let (connectors, _) = list->PaymentUtils.getConnectors(BankTransfer(Sepa))
        intent(
          ~bodyArr=PaymentBody.sepaBankTransferBody(
            ~email=email.value,
            ~name=fullName.value,
            ~country=clientCountryCode.isoAlpha2,
            ~connectors,
          ),
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~iframeId,
          (),
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, fullName, country))
  submitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingTab, ())}>
    <EmailPaymentInput paymentType />
    <FullNamePaymentInput paymentType={paymentType} />
    <RenderIf condition={showAddressDetails.country == Auto}>
      <DropdownField
        appearance=config.appearance
        fieldName=localeString.countryLabel
        value=country
        setValue=setCountry
        disabled=false
        options=countryNames
      />
    </RenderIf>
    <InfoElement />
  </div>
}

let default = make
