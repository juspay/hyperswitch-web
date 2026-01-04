open RecoilAtoms
open RecoilAtomTypes
open PaymentTypeContext
open Utils

@react.component
let make = (~paymentMethodName: string) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let loggerState = Recoil.useRecoilValueFromAtom(loggerAtom)
  let blikCode = Recoil.useRecoilValueFromAtom(userBlikCode)
  let phoneNumber = Recoil.useRecoilValueFromAtom(userPhoneNumber)
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Other)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let paymentManagementList = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentManagementListValue)
  let paymentMethodListValueV2 = Recoil.useRecoilValueFromAtom(
    RecoilAtomsV2.paymentMethodListValueV2,
  )
  let contextPaymentType = usePaymentType()
  let listValue = switch contextPaymentType {
  | PaymentMethodsManagement => paymentManagementList
  | _ => paymentMethodListValueV2
  }
  let optionPaymentMethodDetails =
    paymentMethodListValue
    ->PaymentMethodsRecord.buildFromPaymentList(~localeString)
    ->Array.find(x =>
      x.paymentMethodName ===
        PaymentUtils.getPaymentMethodName(~paymentMethodType=x.methodType, ~paymentMethodName)
    )
  let optionPaymentMethodDetailsV2 =
    listValue
    ->PaymentMethodsRecordV2.buildFromPaymentListV2(~localeString)
    ->Array.find(x =>
      x.paymentMethodName ===
        PaymentUtils.getPaymentMethodName(~paymentMethodType=x.methodType, ~paymentMethodName)
    )
  let paymentMethodDetails = switch GlobalVars.sdkVersion {
  | V1 => optionPaymentMethodDetails->Option.getOr(PaymentMethodsRecord.defaultPaymentMethodContent)
  | V2 =>
    optionPaymentMethodDetailsV2->Option.getOr(PaymentMethodsRecord.defaultPaymentMethodContent)
  }
  let paymentFlow =
    paymentMethodDetails.paymentFlow
    ->Array.get(0)
    ->Option.flatMap(((flow, _connector)) => {
      Some(flow)
    })
    ->Option.getOr(RedirectToURL)
  let fullName = Recoil.useRecoilValueFromAtom(userFullName)
  let email = Recoil.useRecoilValueFromAtom(userEmailAddress)
  let currency = Recoil.useRecoilValueFromAtom(userCurrency)
  let (country, _) = Recoil.useRecoilState(userCountry)
  let (selectedBank, _) = Recoil.useRecoilState(userBank)
  let setFieldComplete = Recoil.useSetRecoilState(fieldsComplete)
  let cleanPhoneNumber = str => str->String.replaceRegExp(%re("/\s/g"), "")

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(areRequiredFieldsValid)
  let areRequiredFieldsEmpty = Recoil.useRecoilValueFromAtom(areRequiredFieldsEmpty)
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

        let paymentBody = switch GlobalVars.sdkVersion {
        | V2 =>
          PaymentBodyV2.getPaymentBody(
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
          )
        | V1 =>
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
          )
        }
        let body = paymentBody->mergeAndFlattenToTuples(requiredFieldsBody)

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
