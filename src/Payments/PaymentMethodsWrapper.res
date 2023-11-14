open RecoilAtoms
open RecoilAtomTypes
open Utils

type props = {
  paymentType: CardThemeType.mode,
  list: PaymentMethodsRecord.list,
  paymentMethodName: string,
}

let default = (props: props) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let blikCode = Recoil.useRecoilValueFromAtom(userBlikCode)
  let phoneNumber = Recoil.useRecoilValueFromAtom(userPhoneNumber)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
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
  let (currency, _) = Recoil.useLoggedRecoilState(userCurrency, "currency", loggerState)
  let (country, _) = Recoil.useRecoilState(userCountry)
  let (selectedBank, _) = Recoil.useRecoilState(userBank)
  let setFieldComplete = Recoil.useSetRecoilState(fieldsComplete)
  let cleanBlik = str => str->Js.String2.replaceByRe(%re("/-/g"), "")
  let cleanPhoneNumber = str => str->Js.String2.replaceByRe(%re("/\s/g"), "")

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Js.Dict.empty())
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsEmpty)

  let complete = areRequiredFieldsValid

  React.useEffect1(() => {
    setFieldComplete(._ => complete)
    None
  }, [complete])

  let empty = areRequiredFieldsEmpty

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
          )
          ->Js.Dict.fromArray
          ->Js.Json.object_
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
    props.paymentMethodName,
    phoneNumber.value,
    (selectedBank, currency, requiredFieldsBody),
  ))
  submitPaymentData(submitCallback)
  <div
    className="flex flex-col animate-slowShow"
    style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
    <RenderIf condition={props.list.payment_methods->Js.Array.length !== 0}>
      <DynamicFields
        paymentType=props.paymentType
        list=props.list
        paymentMethod=paymentMethodDetails.methodType
        paymentMethodType=paymentMethodDetails.paymentMethodName
        setRequiredFieldsBody
      />
    </RenderIf>
  </div>
}
