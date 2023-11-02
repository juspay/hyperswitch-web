open RecoilAtoms
open RecoilAtomTypes
open Utils

type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
  paymentMethodName: string,
}

let default = (props: props) => {
  let {publishableKey, iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let blikCode = Recoil.useRecoilValueFromAtom(userBlikCode)
  let phoneNumber = Recoil.useRecoilValueFromAtom(userPhoneNumber)
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let optionPaymentMethodDetails =
    props.list
    ->PaymentMethodsRecord.buildFromPaymentList
    ->Js.Array2.find(x => x.paymentMethodName === props.paymentMethodName)
  let paymentMethodDetails =
    optionPaymentMethodDetails->Belt.Option.getWithDefault(
      PaymentMethodsRecord.defaultPaymentMethodContent,
    )
  let paymentFlow =
    paymentMethodDetails.paymentFlow
    ->Belt.Array.get(0)
    ->Belt.Option.flatMap(((flow, _connector)) => {
      Some(flow)
    })
    ->Belt.Option.getWithDefault(RedirectToURL)
  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let (currency, setCurrency) = Recoil.useLoggedRecoilState(userCurrency, "currency", loggerState)
  let (country, setCountry) = Recoil.useRecoilState(userCountry)
  let (selectedBank, setSelectedBank) = Recoil.useRecoilState(userBank)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let setFieldComplete = Recoil.useSetRecoilState(fieldsComplete)
  let showDetails = PaymentType.getShowAddressDetails(
    ~billingDetails=fields.billingDetails,
    ~logger=loggerState,
  )
  let countryNames = Utils.getCountryNames(Country.getCountry(props.paymentMethodName))
  let bankNames =
    Bank.getBanks(props.paymentMethodName)->Utils.getBankNames(paymentMethodDetails.bankNames)
  let setCountry = val => {
    setCountry(. val)
  }
  let setCurrency = val => {
    setCurrency(. val)
  }
  let setSelectedBank = val => {
    setSelectedBank(. val)
  }
  let cleanBlik = str => str->Js.String2.replaceByRe(%re("/-/g"), "")
  let cleanPhoneNumber = str => str->Js.String2.replaceByRe(%re("/\s/g"), "")
  React.useEffect0(() => {
    let clientTimeZone = dateTimeFormat(.).resolvedOptions(.).timeZone
    let clientCountry = getClientCountry(clientTimeZone)
    setCountry(_ => clientCountry.countryName)
    let bank = bankNames->Belt.Array.get(0)->Belt.Option.getWithDefault("")
    setSelectedBank(_ => bank)
    None
  })
  //<...>//
  let requiredField =
    PaymentMethodsRecord.getPaymentMethodTypeFromList(
      ~list=props.list,
      ~paymentMethod=paymentMethodDetails.methodType,
      ~paymentMethodType=paymentMethodDetails.paymentMethodName,
    )->Belt.Option.getWithDefault(PaymentMethodsRecord.defaultPaymentMethodType)
  let fieldsArr =
    props.paymentMethodName->PaymentMethodsRecord.getPaymentMethodFields(
      requiredField.required_fields,
    )
  //<...>//
  let complete = React.useMemo4(() => {
    fieldsArr
    ->Js.Array2.map(field => {
      switch field {
      | Email => email.value != "" && email.isValid->Belt.Option.getWithDefault(false)
      | FullName => fullName.value !== ""
      | Country => country !== ""
      | _ => true
      }
    })
    ->Js.Array2.reduce((acc, condition) => {
      acc && condition
    }, true)
  }, (props.paymentMethodName, email, fullName, country))

  React.useEffect1(() => {
    setFieldComplete(._ => complete)
    None
  }, [complete])

  let empty = React.useMemo4(() => {
    props.paymentMethodName
    ->PaymentMethodsRecord.getPaymentMethodFields(requiredField.required_fields)
    ->Js.Array2.map(field => {
      switch field {
      | Email => email.value == ""
      | FullName => fullName.value == ""
      | Country => country == ""
      | _ => false
      }
    })
    ->Js.Array2.reduce((acc, condition) => {
      acc || condition
    }, false)
  }, (props.paymentMethodName, email, fullName, country))

  React.useEffect2(() => {
    handlePostMessageEvents(
      ~complete,
      ~empty,
      ~paymentType=paymentMethodDetails.paymentMethodName,
      ~loggerState,
    )
    None
  }, (empty, complete))

  let submitCallback = React.useCallback7((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        let countryCode =
          Country.getCountry(props.paymentMethodName)
          ->Js.Array2.filter(item => item.countryName == country)
          ->Belt.Array.get(0)
          ->Belt.Option.getWithDefault(Country.defaultTimeZone)

        let bank =
          Bank.getBanks(props.paymentMethodName)
          ->Js.Array2.filter(item => item.displayName == selectedBank)
          ->Belt.Array.get(0)
          ->Belt.Option.getWithDefault(Bank.defaultBank)
        intent(
          ~bodyArr=PaymentBody.getPaymentBody(
            ~paymentMethod=props.paymentMethodName,
            ~country=countryCode.isoAlpha2,
            ~fullName=fullName.value,
            ~email=email.value,
            ~bank=bank.hyperSwitch,
            ~blikCode=blikCode.value->cleanBlik,
            ~phoneNumber=phoneNumber.value->cleanPhoneNumber,
            ~paymentExperience=paymentFlow,
            ~currency,
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
  }, (
    fullName,
    email,
    country,
    blikCode,
    props.paymentMethodName,
    phoneNumber.value,
    (selectedBank, currency),
  ))
  submitPaymentData(submitCallback)
  let bottomElement = <InfoElement />
  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
    {fieldsArr
    ->Js.Array2.map(field => {
      switch field {
      | Email => <EmailPaymentInput paymentType={props.paymentType} />
      | FullName => <FullNamePaymentInput paymentType={props.paymentType} />
      | Country =>
        <RenderIf condition={showDetails.country == Auto}>
          <DropdownField
            appearance=config.appearance
            fieldName=localeString.countryLabel
            value=country
            setValue=setCountry
            disabled=false
            options=countryNames
          />
        </RenderIf>
      | Bank =>
        <DropdownField
          appearance=config.appearance
          fieldName=localeString.bankLabel
          value=selectedBank
          setValue=setSelectedBank
          disabled=false
          options=bankNames
        />
      | SpecialField(element) => element
      | InfoElement => <>
          <Surcharge
            list=props.list
            paymentMethod=paymentMethodDetails.methodType
            paymentMethodType=paymentMethodDetails.paymentMethodName
          />
          {if fieldsArr->Js.Array2.length > 1 {
            <InfoElement />
          } else {
            <Block bottomElement />
          }}
        </>
      | Currency(currencyArr) =>
        <DropdownField
          appearance=config.appearance
          fieldName=localeString.currencyLabel
          value=currency
          setValue=setCurrency
          disabled=false
          options=currencyArr
        />
      | _ => React.null
      }
    })
    ->React.array}
  </div>
}
