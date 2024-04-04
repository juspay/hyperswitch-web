open RecoilAtoms
open RecoilAtomTypes
open Utils

@react.component
let make = (
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
  ~paymentMethodName: string,
) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let blikCode = Recoil.useRecoilValueFromAtom(userBlikCode)
  let phoneNumber = Recoil.useRecoilValueFromAtom(userPhoneNumber)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let optionPaymentMethodDetails =
    list
    ->PaymentMethodsRecord.buildFromPaymentList
    ->Array.find(x =>
      x.paymentMethodName ===
        PaymentUtils.getPaymentMethodName(~paymentMethodType=x.methodType, ~paymentMethodName)
    )
  let paymentMethodDetails =
    optionPaymentMethodDetails->Option.getOr(PaymentMethodsRecord.defaultPaymentMethodContent)
  let paymentFlow =
    paymentMethodDetails.paymentFlow
    ->Array.get(0)
    ->Option.flatMap(((flow, _connector)) => {
      Some(flow)
    })
    ->Option.getOr(RedirectToURL)
  let (fullName, _) = Recoil.useLoggedRecoilState(userFullName, "fullName", loggerState)
  let (email, _) = Recoil.useLoggedRecoilState(userEmailAddress, "email", loggerState)
  let (currency, _) = Recoil.useLoggedRecoilState(userCurrency, "currency", loggerState)
  let (country, _) = Recoil.useRecoilState(userCountry)
  let (selectedBank, _) = Recoil.useRecoilState(userBank)
  let setFieldComplete = Recoil.useSetRecoilState(fieldsComplete)
  let cleanBlik = str => str->String.replaceRegExp(%re("/-/g"), "")
  let cleanPhoneNumber = str => str->String.replaceRegExp(%re("/\s/g"), "")

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)

  let complete = areRequiredFieldsValid

  React.useEffect(() => {
    setFieldComplete(_ => complete)
    None
  }, [complete])

  let empty = areRequiredFieldsEmpty

  React.useEffect(() => {
    handlePostMessageEvents(
      ~complete,
      ~empty,
      ~paymentType=paymentMethodDetails.paymentMethodName,
      ~loggerState,
    )
    None
  }, (empty, complete))

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if complete {
        let countryCode =
          Country.getCountry(paymentMethodName)
          ->Array.filter(item => item.countryName == country)
          ->Array.get(0)
          ->Option.getOr(Country.defaultTimeZone)

        let bank =
          Bank.getBanks(paymentMethodName)
          ->Array.filter(item => item.displayName == selectedBank)
          ->Array.get(0)
          ->Option.getOr(Bank.defaultBank)
        intent(
          ~bodyArr=PaymentBody.getPaymentBody(
            ~paymentMethod=paymentMethodName,
            ~country=countryCode.isoAlpha2,
            ~fullName=fullName.value,
            ~email=email.value,
            ~bank=bank.hyperSwitch,
            ~blikCode=blikCode.value->cleanBlik,
            ~phoneNumber=phoneNumber.value->cleanPhoneNumber,
            ~paymentExperience=paymentFlow,
            ~currency,
          )
          ->Dict.fromArray
          ->JSON.Encode.object
          ->OrcaUtils.flattenObject(true)
          ->OrcaUtils.mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->OrcaUtils.getArrayOfTupleFromDict,
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
    paymentMethodName,
    phoneNumber.value,
    (selectedBank, currency, requiredFieldsBody),
  ))
  useSubmitPaymentData(submitCallback)
  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
    <DynamicFields
      paymentType
      list
      paymentMethod=paymentMethodDetails.methodType
      paymentMethodType=paymentMethodName
      setRequiredFieldsBody
    />
  </div>
}

let default = make
