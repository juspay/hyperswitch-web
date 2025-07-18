@react.component
let make = (
  ~paymentToken: RecoilAtomTypes.paymentToken,
  ~setPaymentToken,
  ~savedMethods: array<PaymentType.customerMethods>,
  ~loadSavedCards: PaymentType.savedCardsLoadState,
  ~cvcProps,
  ~sessions,
  ~isClickToPayAuthenticateError,
  ~setIsClickToPayAuthenticateError,
  ~getVisaCards,
  ~closeComponentIfSavedMethodsAreEmpty,
) => {
  open CardUtils
  open Utils
  open UtilityHooks
  open Promise

  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)

  let {clickToPayProvider} = clickToPayConfig
  let customerMethods =
    clickToPayConfig.clickToPayCards
    ->Option.getOr([])
    ->Array.map(obj => obj->PaymentType.convertClickToPayCardToCustomerMethod(clickToPayProvider))

  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Recoil.useRecoilState(
    RecoilAtoms.showPaymentMethodsScreen,
  )
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

  let {iframeId, clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")

  let dict = sessions->Utils.getDictFromJson
  let sessionObj = React.useMemo(() => SessionsType.itemToObjMapper(dict, Others), [dict])

  let gPayToken = SessionsType.getPaymentSessionObj(sessionObj.sessionsToken, Gpay)

  let applePaySessionObj = SessionsType.itemToObjMapper(dict, ApplePayObject)
  let applePayToken = SessionsType.getPaymentSessionObj(applePaySessionObj.sessionsToken, ApplePay)

  let samsungPaySessionObj = SessionsType.itemToObjMapper(dict, SamsungPayObject)
  let samsungPayToken = SessionsType.getPaymentSessionObj(
    samsungPaySessionObj.sessionsToken,
    SamsungPay,
  )
  let (isClickToPayRememberMe, setIsClickToPayRememberMe) = React.useState(_ => false)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let savedCardlength = savedMethods->Array.length
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let {paymentToken: paymentTokenVal, customerId} = paymentToken

  let bottomElement = {
    <div
      className="PickerItemContainer" tabIndex={0} role="region" ariaLabel="Saved payment methods">
      {savedMethods
      ->Array.mapWithIndex((obj, i) =>
        <SavedCardItem
          key={i->Int.toString}
          setPaymentToken
          isActive={paymentTokenVal == obj.paymentToken}
          paymentItem=obj
          brandIcon={obj->getPaymentMethodBrand}
          index=i
          savedCardlength
          cvcProps
          setRequiredFieldsBody
        />
      )
      ->React.array}
      <RenderIf condition={clickToPayConfig.isReady == Some(true)}>
        <ClickToPayAuthenticate
          loggerState
          savedMethods
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
          setPaymentToken
          paymentTokenVal
          cvcProps
          getVisaCards
          setIsClickToPayRememberMe
          closeComponentIfSavedMethodsAreEmpty
        />
      </RenderIf>
    </div>
  }

  let {isCVCValid, cvcNumber, setCvcError} = cvcProps
  let complete = switch isCVCValid {
  | Some(val) => paymentTokenVal !== "" && val
  | _ => false
  }
  let empty = cvcNumber == ""
  let customerMethod = React.useMemo(_ =>
    savedMethods
    ->Array.concat(customerMethods)
    ->Array.filter(savedMethod => savedMethod.paymentToken === paymentTokenVal)
    ->Array.get(0)
    ->Option.getOr(PaymentType.defaultCustomerMethods)
  , [paymentTokenVal])
  let isUnknownPaymentMethod = customerMethod.paymentMethod === ""
  let isCardPaymentMethod = customerMethod.paymentMethod === "card"
  let isCardPaymentMethodValid = !customerMethod.requiresCvv || (complete && !empty)

  let complete =
    areRequiredFieldsValid &&
    !isUnknownPaymentMethod &&
    (!isCardPaymentMethod || isCardPaymentMethodValid)

  let paymentMethodType =
    customerMethod.paymentMethodType->Option.getOr(customerMethod.paymentMethod)

  useHandlePostMessages(~complete, ~empty, ~paymentType=paymentMethodType, ~savedMethod=true)

  GooglePayHelpers.useHandleGooglePayResponse(~connectors=[], ~intent, ~isSavedMethodsFlow=true)

  ApplePayHelpers.useHandleApplePayResponse(~connectors=[], ~intent, ~isSavedMethodsFlow=true)

  SamsungPayHelpers.useHandleSamsungPayResponse(~intent, ~isSavedMethodsFlow=true)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    let isCustomerAcceptanceRequired = customerMethod.recurringEnabled->not || isSaveCardsChecked

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
      if customerMethod.card.isClickToPayCard {
        ClickToPayHelpers.handleProceedToPay(
          ~srcDigitalCardId=customerMethod.paymentToken,
          ~logger=loggerState,
          ~clickToPayProvider,
          ~isClickToPayRememberMe,
          ~clickToPayToken=clickToPayConfig.clickToPayToken,
          ~orderId=clientSecret->Option.getOr(""),
        )
        ->then(resp => {
          let dict = resp.payload->Utils.getDictFromJson

          switch clickToPayProvider {
          | MASTERCARD => {
              let headers = dict->Utils.getDictFromDict("headers")
              let merchantTransactionId = headers->Utils.getString("merchant-transaction-id", "")
              let xSrcFlowId = headers->Utils.getString("x-src-cx-flow-id", "")
              let correlationId =
                dict
                ->Utils.getDictFromDict("checkoutResponseData")
                ->Utils.getString("srcCorrelationId", "")

              let clickToPayBody = PaymentBody.mastercardClickToPayBody(
                ~merchantTransactionId,
                ~correlationId,
                ~xSrcFlowId,
              )
              intent(
                ~bodyArr=clickToPayBody->mergeAndFlattenToTuples(requiredFieldsBody),
                ~confirmParam=confirm.confirmParams,
                ~handleUserError=false,
                ~manualRetry=isManualRetryEnabled,
              )
            }
          | VISA => {
              let clickToPayBody = PaymentBody.visaClickToPayBody(
                ~email=clickToPayConfig.email,
                ~encryptedPayload=dict->Utils.getString("checkoutResponse", ""),
              )
              intent(
                ~bodyArr=clickToPayBody,
                ~confirmParam=confirm.confirmParams,
                ~handleUserError=false,
                ~manualRetry=isManualRetryEnabled,
              )
            }
          | NONE => ()
          }
          resolve(resp)
        })
        ->catch(_ =>
          resolve({
            ClickToPayHelpers.status: ERROR,
            payload: JSON.Encode.null,
          })
        )
        ->ignore
      } else if (
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
              ~bodyArr=savedPaymentMethodBody->mergeAndFlattenToTuples(requiredFieldsBody),
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        | Some("apple_pay") =>
          switch applePayToken {
          | ApplePayTokenOptional(optToken) =>
            ApplePayHelpers.handleApplePayButtonClicked(
              ~sessionObj=optToken,
              ~componentName,
              ~paymentMethodListValue,
            )
          | _ =>
            // TODO - To be replaced with proper error message
            intent(
              ~bodyArr=savedPaymentMethodBody->mergeAndFlattenToTuples(requiredFieldsBody),
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        | Some("samsung_pay") =>
          switch samsungPayToken {
          | SamsungPayTokenOptional(optToken) =>
            SamsungPayHelpers.handleSamsungPayClicked(
              ~componentName,
              ~sessionObj=optToken->Option.getOr(JSON.Encode.null)->getDictFromJson,
              ~iframeId,
              ~readOnly,
            )
          | _ =>
            // TODO - To be replaced with proper error message
            intent(
              ~bodyArr=savedPaymentMethodBody->mergeAndFlattenToTuples(requiredFieldsBody),
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        | _ =>
          intent(
            ~bodyArr=savedPaymentMethodBody->mergeAndFlattenToTuples(requiredFieldsBody),
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

  let enableSavedPaymentShimmer = React.useMemo(() => {
    savedCardlength === 0 &&
      (loadSavedCards === PaymentType.LoadingSavedCards ||
      !showPaymentMethodsScreen ||
      clickToPayConfig.isReady->Option.isNone)
  }, (savedCardlength, loadSavedCards, showPaymentMethodsScreen, clickToPayConfig.isReady))

  <div className="flex flex-col overflow-auto h-auto no-scrollbar animate-slowShow">
    {if enableSavedPaymentShimmer {
      <PaymentElementShimmer.SavedPaymentCardShimmer />
    } else {
      <RenderIf condition={!showPaymentMethodsScreen}> {bottomElement} </RenderIf>
    }}
    <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
      <div className="pt-4 pb-2 flex items-center justify-start">
        <SaveDetailsCheckbox isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked />
      </div>
    </RenderIf>
    <RenderIf
      condition={displaySavedPaymentMethodsCheckbox &&
      paymentMethodListValue.payment_type === SETUP_MANDATE}>
      <Terms
        mode={Card}
        styles={
          marginTop: themeObj.spacingGridColumn,
        }
      />
    </RenderIf>
    <RenderIf condition={!enableSavedPaymentShimmer}>
      <div
        className="Label flex flex-row gap-3 items-end cursor-pointer mt-4"
        style={
          fontSize: "14px",
          float: "left",
          fontWeight: "500",
          width: "fit-content",
          color: themeObj.colorPrimary,
        }
        role="button"
        ariaLabel="Click to use more payment methods"
        tabIndex=0
        onKeyDown={event => {
          let key = JsxEvent.Keyboard.key(event)
          let keyCode = JsxEvent.Keyboard.keyCode(event)
          if key == "Enter" || keyCode == 13 {
            setShowPaymentMethodsScreen(_ => true)
          }
        }}
        dataTestId={TestUtils.addNewCardIcon}
        onClick={_ => setShowPaymentMethodsScreen(_ => true)}>
        <Icon name="circle-plus" size=22 />
        {React.string(localeString.morePaymentMethods)}
      </div>
    </RenderIf>
  </div>
}
