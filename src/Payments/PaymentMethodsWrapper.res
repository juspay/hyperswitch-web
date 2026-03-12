open JotaiAtomTypes
open Utils

@react.component
let make = (~paymentMethodName: string) => {
  let {iframeId} = Jotai.useAtomValue(JotaiAtoms.keys)
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let blikCode = Jotai.useAtomValue(JotaiAtoms.userBlikCode)
  let phoneNumber = Jotai.useAtomValue(JotaiAtoms.userPhoneNumber)
  let {themeObj, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let optionPaymentMethodDetails =
    paymentMethodListValue
    ->PaymentMethodsRecord.buildFromPaymentList(~localeString)
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
  let fullName = Jotai.useAtomValue(JotaiAtoms.userFullName)
  let email = Jotai.useAtomValue(JotaiAtoms.userEmailAddress)
  let currency = Jotai.useAtomValue(JotaiAtoms.userCurrency)
  let (country, _) = Jotai.useAtom(JotaiAtoms.userCountry)
  let (selectedBank, _) = Jotai.useAtom(JotaiAtoms.userBank)
  let setFieldComplete = Jotai.useSetAtom(JotaiAtoms.fieldsComplete)
  let cleanPhoneNumber = str => str->String.replaceRegExp(%re("/\s/g"), "")

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let areRequiredFieldsValid = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsEmpty)
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
  ))
  useSubmitPaymentData(submitCallback)
  let paymentMethod = paymentMethodDetails.methodType

  <div
    className="DynamicFields flex flex-col animate-slowShow"
    style={gridGap: themeObj.spacingGridColumn}>
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
