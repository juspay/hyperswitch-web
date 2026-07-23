open JotaiAtoms
open JotaiAtomTypes
open Utils

@react.component
let make = (~paymentMethodName: string) => {
  let {iframeId, sdkAuthorization} = Jotai.useAtomValue(keys)
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let blikCode = Jotai.useAtomValue(userBlikCode)
  let phoneNumber = Jotai.useAtomValue(userPhoneNumber)
  let {themeObj} = Jotai.useAtomValue(configAtom)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let {layout} = Jotai.useAtomValue(optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let optionPaymentMethodDetails =
    paymentMethodListValue
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
  let fullName = Jotai.useAtomValue(userFullName)
  let email = Jotai.useAtomValue(userEmailAddress)
  let currency = Jotai.useAtomValue(userCurrency)
  let (country, _) = Jotai.useAtom(userCountry)
  let (selectedBank, _) = Jotai.useAtom(userBank)
  let setFieldComplete = Jotai.useSetAtom(fieldsComplete)
  let cleanPhoneNumber = str => str->String.replaceRegExp(%re("/\s/g"), "")

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let areRequiredFieldsValid = Jotai.useAtomValue(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(areRequiredFieldsEmpty)
  let countryList = CountryStateDataRefs.countryDataRef.contents

  React.useEffect(() => {
    setFieldComplete(_ => areRequiredFieldsValid)
    None
  }, [areRequiredFieldsValid])

  let empty = areRequiredFieldsEmpty

  UtilityHooks.useHandlePostMessages(
    ~complete=areRequiredFieldsValid,
    ~empty,
    ~paymentType=paymentMethodDetails.paymentMethodName,
  )
  SubscriptionEventHooks.useEmitFormStatus(~empty, ~complete=areRequiredFieldsValid)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    if confirm.doSubmit {
      if areRequiredFieldsValid {
        let countryCode =
          Country.getCountry(paymentMethodName, countryList)
          ->Array.filter(item => item.countryName == country)
          ->Array.get(0)
          ->Option.getOr(Country.defaultTimeZone)

        let bank =
          Bank.getBanks(paymentMethodName)
          ->Array.filter(item => item.displayName == selectedBank)
          ->Array.get(0)
          ->Option.getOr(Bank.defaultBank)

        let body =
          PaymentBody.getPaymentBody(
            ~paymentMethod=paymentMethodDetails.methodType,
            ~paymentMethodType=paymentMethodName,
            ~country=countryCode.isoAlpha2,
            ~fullName=fullName.value,
            ~email=email.value,
            ~bank=bank.value,
            ~blikCode=blikCode.value->removeHyphen,
            ~phoneNumber=cleanPhoneNumber(
              phoneNumber.countryCode->Option.getOr("") ++ phoneNumber.value,
            ),
            ~paymentExperience=paymentFlow,
          )->mergeAndFlattenToTuples(requiredFieldsBody)

        intent(
          ~bodyArr=body,
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          ~iframeId,
          ~manualRetry=isManualRetryEnabled,
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
    isManualRetryEnabled,
    phoneNumber.value,
    selectedBank,
    currency,
    requiredFieldsBody,
    areRequiredFieldsValid,
    sdkAuthorization,
  ))
  useSubmitPaymentData(submitCallback)
  let paymentMethod = paymentMethodDetails.methodType

  <div
    className="DynamicFields flex flex-col animate-slowShow"
    style={gridGap: themeObj.spacingGridColumn}>
    <RenderIf condition={layoutClass.\"type" === Accordion}>
      <Space height="0" />
    </RenderIf>
    <DynamicFields paymentMethod paymentMethodType=paymentMethodName setRequiredFieldsBody />
    <Terms
      paymentMethodType={PaymentUtils.getPaymentMethodName(
        ~paymentMethodType=paymentMethod,
        ~paymentMethodName,
      )}
      paymentMethod
    />
  </div>
}

let default = make
