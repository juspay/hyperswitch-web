open PaymentType
open RecoilAtoms
@react.component
let make = () => {
  let (loggerState, _setLoggerState) = Recoil.useRecoilState(loggerAtom)
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), KlarnaRedirect)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let showAddressDetails = getShowAddressDetails(~billingDetails=fields.billingDetails)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)

  let countryData = CountryStateDataRefs.countryDataRef.contents
  let countryNames =
    Utils.getCountryNames(countryData)->DropdownField.updateArrayOfStringToOptionsTypeArray

  let (country, setCountry) = Recoil.useRecoilState(userCountry)
  let setCountry = val => {
    setCountry(val)
  }

  open Utils
  let clientCountryCode =
    countryData
    ->Array.find(item => item.countryName == country)
    ->Option.getOr(Country.defaultTimeZone)

  let complete = email.value != "" && fullName.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == "" || fullName.value == ""

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="klarna")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->Utils.getDictFromJson->ConfirmType.itemToObjMapper
    let (connectors, _) =
      paymentMethodListValue->PaymentUtils.getConnectors(PayLater(Klarna(Redirect)))
    let body = PaymentBody.klarnaRedirectionBody(
      ~fullName=fullName.value,
      ~email=email.value,
      ~country=clientCountryCode.isoAlpha2,
      ~connectors,
    )
    if confirm.doSubmit {
      if complete {
        intent(
          ~bodyArr=body,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~manualRetry=isManualRetryEnabled,
        )
      } else {
        postFailedSubmitResponse(~errortype="validation_error", ~message="Please enter all fields")
      }
    }
  }, (email, fullName, country, isManualRetryEnabled))
  useSubmitPaymentData(submitCallback)

  <div
    className="flex flex-col animate-slowShow"
    style={
      gridGap: config.appearance.innerLayout === Spaced ? themeObj.spacingGridColumn : "",
    }>
    <EmailPaymentInput />
    <FullNamePaymentInput />
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
    <Surcharge paymentMethod="pay_later" paymentMethodType="klarna" />
    <InfoElement />
  </div>
}

let default = make
