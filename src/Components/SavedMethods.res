@react.component
let make = (
  ~paymentToken: RecoilAtomTypes.paymentToken,
  ~setPaymentToken,
  ~savedMethods: array<PaymentType.customerMethods>,
  ~loadSavedCards: PaymentType.savedCardsLoadState,
  ~cvcProps,
  ~paymentType,
  ~sessions,
) => {
  open CardUtils
  open Utils
  open UtilityHooks
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (showFields, setShowFields) = Recoil.useRecoilState(RecoilAtoms.showCardFieldsAtom)
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
    loggerState.setLogError(~value=message, ~eventName=INVALID_FORMAT)
  }
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ => false)
  let {displaySavedPaymentMethodsCheckbox, readOnly} = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.optionAtom,
  )
  let isGuestCustomer = useIsGuestCustomer()

  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")

  let dict = sessions->Utils.getDictFromJson
  let sessionObj = React.useMemo(() => SessionsType.itemToObjMapper(dict, Others), [dict])

  let gPayToken = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Gpay)

  let applePaySessionObj = SessionsType.itemToObjMapper(dict, ApplePayObject)
  let applePayToken = SessionsType.getPaymentSessionObj(applePaySessionObj.sessionsToken, ApplePay)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let savedCardlength = savedMethods->Array.length
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let {paymentToken: paymentTokenVal, customerId} = paymentToken

  let bottomElement = {
    savedMethods
    ->Array.mapWithIndex((obj, i) => {
      let brandIcon = obj->getPaymentMethodBrand
      let isActive = paymentTokenVal == obj.paymentToken
      <SavedCardItem
        key={i->Int.toString}
        setPaymentToken
        isActive
        paymentItem=obj
        brandIcon
        index=i
        savedCardlength
        cvcProps
        paymentType
        setRequiredFieldsBody
      />
    })
    ->React.array
  }

  let (isCVCValid, _, cvcNumber, _, _, _, _, _, _, setCvcError) = cvcProps
  let complete = switch isCVCValid {
  | Some(val) => paymentTokenVal !== "" && val
  | _ => false
  }
  let empty = cvcNumber == ""
  let customerMethod =
    savedMethods
    ->Array.filter(savedMethod => {
      savedMethod.paymentToken === paymentTokenVal
    })
    ->Array.get(0)
    ->Option.getOr(PaymentType.defaultCustomerMethods)
  let isUnknownPaymentMethod = customerMethod.paymentMethod === ""
  let isCardPaymentMethod = customerMethod.paymentMethod === "card"
  let isCardPaymentMethodValid = !customerMethod.requiresCvv || (complete && !empty)

  let complete =
    areRequiredFieldsValid &&
    !isUnknownPaymentMethod &&
    (!isCardPaymentMethod || isCardPaymentMethodValid)

  let paymentType = customerMethod.paymentMethodType->Option.getOr(customerMethod.paymentMethod)

  useHandlePostMessages(~complete, ~empty, ~paymentType, ~savedMethod=true)

  GooglePayHelpers.useHandleGooglePayResponse(~connectors=[], ~intent, ~isSavedMethodsFlow=true)

  ApplePayHelpers.useHandleApplePayResponse(~connectors=[], ~intent, ~isSavedMethodsFlow=true)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    let isCustomerAcceptanceRequired = customerMethod.recurringEnabled->not

    let savedPaymentMethodBody = switch customerMethod.paymentMethod {
    | "card" =>
      PaymentBody.savedCardBody(
        ~paymentToken=paymentTokenVal,
        ~customerId,
        ~cvcNumber,
        ~requiresCvv=customerMethod.requiresCvv,
        ~isCustomerAcceptanceRequired,
      )
    | _ => {
        let paymentMethodType = switch customerMethod.paymentMethodType {
        | Some("")
        | None => JSON.Encode.null
        | Some(paymentMethodType) => paymentMethodType->JSON.Encode.string
        }
        PaymentBody.savedPaymentMethodBody(
          ~paymentToken=paymentTokenVal,
          ~customerId,
          ~paymentMethod=customerMethod.paymentMethod,
          ~paymentMethodType,
          ~isCustomerAcceptanceRequired,
        )
      }
    }

    if confirm.doSubmit {
      if (
        areRequiredFieldsValid &&
        !isUnknownPaymentMethod &&
        (!isCardPaymentMethod || isCardPaymentMethodValid) &&
        confirm.confirmTimestamp >= confirm.readyTimestamp
      ) {
        switch customerMethod.paymentMethodType {
        | Some("google_pay") =>
          switch gPayToken {
          | OtherTokenOptional(optToken) =>
            GooglePayHelpers.handleGooglePayClicked(
              ~sessionObj=optToken,
              ~componentName,
              ~iframeId,
              ~readOnly,
            )
          | _ =>
            // TODO - To be replaced with proper error message
            intent(
              ~bodyArr=savedPaymentMethodBody
              ->getJsonFromArrayOfJson
              ->flattenObject(true)
              ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
              ->getArrayOfTupleFromDict,
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        | Some("apple_pay") =>
          switch applePayToken {
          | ApplePayTokenOptional(optToken) =>
            ApplePayHelpers.handleApplePayButtonClicked(~sessionObj=optToken, ~componentName)
          | _ =>
            // TODO - To be replaced with proper error message
            intent(
              ~bodyArr=savedPaymentMethodBody
              ->getJsonFromArrayOfJson
              ->flattenObject(true)
              ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
              ->getArrayOfTupleFromDict,
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        | _ =>
          intent(
            ~bodyArr=savedPaymentMethodBody
            ->getJsonFromArrayOfJson
            ->flattenObject(true)
            ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
            ->getArrayOfTupleFromDict,
            ~confirmParam=confirm.confirmParams,
            ~handleUserError=false,
            ~manualRetry=isManualRetryEnabled,
          )
        }
      } else {
        if isUnknownPaymentMethod || confirm.confirmTimestamp < confirm.readyTimestamp {
          setUserError(localeString.selectPaymentMethodText)
        }
        if !isUnknownPaymentMethod && cvcNumber === "" {
          setCvcError(_ => localeString.cvcNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if !(isCVCValid->Option.getOr(false)) {
          setUserError(localeString.enterValidDetailsText)
        }
        if !areRequiredFieldsValid {
          setUserError(localeString.enterValidDetailsText)
        }
      }
    }
  }, (
    areRequiredFieldsValid,
    requiredFieldsBody,
    empty,
    complete,
    customerMethod,
    applePayToken,
    gPayToken,
    isManualRetryEnabled,
  ))
  useSubmitPaymentData(submitCallback)

  let conditionsForShowingSaveCardCheckbox = React.useMemo(() => {
    !isGuestCustomer &&
    paymentMethodListValue.payment_type === NEW_MANDATE &&
    displaySavedPaymentMethodsCheckbox &&
    savedMethods->Array.some(ele => {
      ele.paymentMethod === "card" && ele.requiresCvv
    })
  }, (
    isGuestCustomer,
    paymentMethodListValue.payment_type,
    displaySavedPaymentMethodsCheckbox,
    savedMethods,
  ))

  <div className="flex flex-col overflow-auto h-auto no-scrollbar animate-slowShow">
    {if savedCardlength === 0 && (loadSavedCards === PaymentType.LoadingSavedCards || !showFields) {
      <div
        className="Label flex flex-row gap-3 items-end cursor-pointer"
        style={
          fontSize: "14px",
          color: themeObj.colorPrimary,
          fontWeight: "400",
          marginTop: "25px",
        }>
        <PaymentElementShimmer.SavedPaymentShimmer />
      </div>
    } else {
      <RenderIf condition={!showFields}> {bottomElement} </RenderIf>
    }}
    <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
      <div className="pt-4 pb-2 flex items-center justify-start">
        <SaveDetailsCheckbox isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked />
      </div>
    </RenderIf>
    <RenderIf
      condition={displaySavedPaymentMethodsCheckbox &&
      paymentMethodListValue.payment_type === SETUP_MANDATE}>
      <div
        className="opacity-50 text-xs mb-2 text-left"
        style={
          color: themeObj.colorText,
          marginTop: themeObj.spacingGridColumn,
        }>
        <Terms mode={Card} />
      </div>
    </RenderIf>
    <RenderIf condition={!showFields}>
      <div
        className="Label flex flex-row gap-3 items-end cursor-pointer mt-4"
        style={
          fontSize: "14px",
          float: "left",
          fontWeight: "500",
          width: "fit-content",
          color: themeObj.colorPrimary,
        }
        dataTestId={TestUtils.addNewCardIcon}
        onClick={_ => setShowFields(_ => true)}>
        <Icon name="circle-plus" size=22 />
        {React.string(localeString.morePaymentMethods)}
      </div>
    </RenderIf>
  </div>
}
