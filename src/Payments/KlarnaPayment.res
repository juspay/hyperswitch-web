open PaymentType
open RecoilAtoms
@react.component
let make = (~paymentType, ~countryProps, ~list: PaymentMethodsRecord.list) => {
  let (loggerState, _setLoggerState) = Recoil.useRecoilState(loggerAtom)
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), KlarnaRedirect)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)

  let showAddressDetails = getShowAddressDetails(
    ~billingDetails=fields.billingDetails,
    ~logger=loggerState,
  )
  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)

  let (_clientCountry, countryNames) = countryProps

  let (country, setCountry) = Recoil.useRecoilState(userCountry)
  let setCountry = val => {
    setCountry(. val)
  }

  open Utils
  let clientCountryCode =
    Country.country
    ->Js.Array2.find(item => item.countryName == country)
    ->Belt.Option.getWithDefault(Country.defaultTimeZone)

  let complete =
    email.value != "" && fullName.value != "" && email.isValid->Belt.Option.getWithDefault(false)
  let empty = email.value == "" || fullName.value == ""
  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="klarna", ~loggerState)
    None
  }, (empty, complete))
  React.useEffect1(() => {
    setComplete(._ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback3((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    let (connectors, _) = list->PaymentUtils.getConnectors(PayLater(Klarna(Redirect)))
    let body = PaymentBody.klarnaRedirectionBody(
      ~fullName=fullName.value,
      ~email=email.value,
      ~country=clientCountryCode.isoAlpha2,
      ~connectors,
    )
    if confirm.doSubmit {
      if complete {
        intent(~bodyArr=body, ~confirmParam=confirm.confirmParams, ~handleUserError=false, ())
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, fullName, country))
  useSubmitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
    <EmailPaymentInput paymentType={paymentType} />
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
    <Surcharge list paymentMethod="pay_later" paymentMethodType="klarna" />
    <InfoElement />
  </div>
}

let default = make
