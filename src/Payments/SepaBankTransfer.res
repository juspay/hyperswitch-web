open RecoilAtoms
open Utils

@react.component
let make = (~paymentType) => {
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
  let countryNames = Utils.getCountryNames(Country.country)
  let setComplete = Recoil.useSetRecoilState(fieldsComplete)
  let clientCountryCode =
    Country.country
    ->Array.find(item => item.countryName == country)
    ->Option.getOr(Country.defaultTimeZone)
  let complete = email.value != "" && fullName.value != "" && email.isValid->Option.getOr(false)
  let empty = email.value == "" || fullName.value == ""
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  UtilityHooks.useHandlePostMessages(~complete, ~empty, ~paymentType="bank_transfer")

  React.useEffect(() => {
    setComplete(_ => complete)
    None
  }, [complete])

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        let (connectors, _) = paymentMethodListValue->PaymentUtils.getConnectors(BankTransfer(Sepa))
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
  useSubmitPaymentData(submitCallback)

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
    <Surcharge paymentMethod="bank_transfer" paymentMethodType="sepa" />
    <InfoElement />
  </div>
}

let default = make
