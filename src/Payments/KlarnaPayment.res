open RecoilAtoms
@react.component
let make = (~paymentType) => {
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), KlarnaRedirect)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)

  let country = Recoil.useRecoilValueFromAtom(userCountry)
  let (_, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  open Utils
  let clientCountryCode =
    Country.country
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

    if confirm.doSubmit {
      if complete {
        let bodyArr = PaymentBody.klarnaRedirectionBody(
          ~fullName=fullName.value,
          ~email=email.value,
          ~country=clientCountryCode.isoAlpha2,
          ~connectors,
        )

        intent(
          ~bodyArr,
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

  <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingTab}>
    <DynamicFields
      paymentType paymentMethod="pay_later" paymentMethodType="klarna" setRequiredFieldsBody
    />
    <Surcharge paymentMethod="pay_later" paymentMethodType="klarna" />
    <InfoElement />
  </div>
}

let default = make
