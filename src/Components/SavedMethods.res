let savedCardCvcResponseListenerActivity = "onSavedCardCvcResponse"

@react.component
let make = (
  ~paymentToken: JotaiAtomTypes.paymentToken,
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

  let clickToPayConfig = Jotai.useAtomValue(JotaiAtoms.clickToPayConfig)

  let {clickToPayProvider} = clickToPayConfig
  let customerMethods =
    clickToPayConfig.clickToPayCards
    ->Option.getOr([])
    ->Array.map(obj => obj->PaymentType.convertClickToPayCardToCustomerMethod(clickToPayProvider))

  let {themeObj, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Jotai.useAtom(
    JotaiAtoms.showPaymentMethodsScreen,
  )
  let areRequiredFieldsValid = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsValid)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)
  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
    loggerState.setLogError(~value=message, ~eventName=INVALID_FORMAT)
  }
  let {
    displaySavedPaymentMethodsCheckbox,
    readOnly,
    savedPaymentMethodsCheckboxCheckedByDefault,
    layout,
    alwaysSendCustomerAcceptance,
  } = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ =>
    savedPaymentMethodsCheckboxCheckedByDefault
  )
  let isGuestCustomer = useIsGuestCustomer()

  let {iframeId, clientSecret, sdkAuthorization, publishableKey} = Jotai.useAtomValue(
    JotaiAtoms.keys,
  )
  let customPodUri = Jotai.useAtomValue(JotaiAtoms.customPodUri)
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)
  let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.vaultSdkDomainUrl).origin
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
  let (eligibilitySurchargeDetails, setEligibilitySurchargeDetails) = React.useState(_ => None)
  let (eligibilityError, setEligibilityError) = React.useState(_ => None)
  let (isEligibilityPending, setIsEligibilityPending) = React.useState(_ => false)
  let eligibilityControllerRef = React.useRef(None)

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let savedCardlength = savedMethods->Array.length
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let {paymentToken: paymentTokenVal, customerId} = paymentToken
  let layoutClass = CardUtils.getLayoutClass(layout)
  let {
    displayInSeparateScreen,
    groupByPaymentMethods,
  } = layoutClass.savedMethodCustomization.groupingBehavior
  let groupSavedMethodsWithPaymentMethods = !displayInSeparateScreen && groupByPaymentMethods

  let groupSavedMethodsSeparately = !displayInSeparateScreen && !groupByPaymentMethods

  let maxItems = layoutClass.savedMethodCustomization.maxItems
  let selectedOption = Jotai.useAtomValue(JotaiAtoms.selectedOptionAtom)

  let (selectedInstallmentPlan, setSelectedInstallmentPlan) = React.useState(_ => None)
  let (showInstallments, setShowInstallments) = React.useState(_ => false)
  let (isCollapsed, setIsCollapsed) = React.useState(_ => true)

  let shouldShowClickToPaySection =
    clickToPayConfig.isReady == Some(true) &&
      (!groupSavedMethodsWithPaymentMethods || selectedOption == "card")
  let (installmentsError, setInstallmentsError) = React.useState(_ => "")

  // Saved-card (return user) CVC collection always uses the nested
  // ParentCardComponent. The vault flag only selects whether submit returns a raw
  // CVC or a vault token; SavedMethods remains the confirm owner.
  let isTokenize = Jotai.useAtomValue(JotaiAtoms.isTokenize)
  let sessionToken = Jotai.useAtomValue(JotaiAtoms.sessions)
  let vaultCredentials = React.useMemo(
    () => VaultHelpers.getVaultCredentialsFromSessions(sessionToken),
    [sessionToken],
  )
  // Either vault (VGS or Hyperswitch) collects + tokenises the saved-card CVC inside
  // the nested iframe (ParentCardComponent saved-card mode); SavedMethods stays the
  // submit owner. The vault provider only changes what renders inside that iframe —
  // SavedMethods' forward-doSubmit / await-token / confirm logic is identical — so a
  // single flag covers both.
  let isVaultCvcFlow =
    isTokenize &&
    switch vaultCredentials {
    | VGS(_) | HyperswitchVault(_) => true
    | NoVault => false
    }

  let isHyperswitchVault = switch vaultCredentials {
  | HyperswitchVault(_) => true
  | _ => false
  }
  let cvcIframeRef = React.useRef(Nullable.null)
  let setCvcIframeRef = React.useCallback(ref => {
    cvcIframeRef.current = ref
  }, [])
  let (savedCardCvcState, setSavedCardCvcState) = React.useState(_ =>
    CardIframeProtocol.initialSavedCardCvcState
  )

  React.useEffect0(() => Some(
    () =>
      EventListenerManager.removeSmartEventListener(
        "message",
        savedCardCvcResponseListenerActivity,
      ),
  ))

  React.useEffect(() => {
    setSavedCardCvcState(_ => CardIframeProtocol.initialSavedCardCvcState)
    None
  }, (paymentTokenVal, isVaultCvcFlow))

  let hasMoreSavedMethods = savedCardlength > maxItems
  let visibleSavedMethods = if hasMoreSavedMethods && isCollapsed {
    savedMethods->Array.slice(~start=0, ~end=maxItems)
  } else {
    savedMethods
  }

  let bottomElement = {
    <div
      className="PickerItemContainer" tabIndex={0} role="region" ariaLabel="Saved payment methods">
      {visibleSavedMethods
      ->Array.mapWithIndex((obj, i) => {
        let isActive = paymentTokenVal == obj.paymentToken
        let (eligibilitySurchargeDetails, eligibilityError, isEligibilityPending) = isActive
          ? (
              eligibilitySurchargeDetails,
              eligibilityError,
              isEligibilityPending && paymentMethodListValue.should_block_confirm,
            )
          : (None, None, false)
        <SavedCardItem
          key={i->Int.toString}
          setPaymentToken
          isActive
          paymentItem=obj
          brandIcon={obj->getPaymentMethodBrand}
          index=i
          savedCardlength
          setRequiredFieldsBody
          setSelectedInstallmentPlan
          showInstallments
          setShowInstallments
          installmentsError
          setInstallmentsError
          eligibilitySurchargeDetails
          eligibilityError
          isEligibilityPending
          isVaultCvcFlow
          setCvcIframeRef
          setSavedCardCvcState={state => setSavedCardCvcState(_ => state)}
        />
      })
      ->React.array}
      <RenderIf condition={hasMoreSavedMethods}>
        <ShowMoreToggle isCollapsed setIsCollapsed />
      </RenderIf>
      <RenderIf condition={shouldShowClickToPaySection}>
        <ClickToPayAuthenticate
          loggerState
          savedMethods
          isClickToPayAuthenticateError
          setIsClickToPayAuthenticateError
          setPaymentToken
          paymentTokenVal
          getVisaCards
          setIsClickToPayRememberMe
          closeComponentIfSavedMethodsAreEmpty
          setSelectedInstallmentPlan
          showInstallments
          setShowInstallments
          installmentsError
          setInstallmentsError
        />
      </RenderIf>
    </div>
  }

  let {isCVCValid, cvcNumber, setCvcError} = cvcProps
  let customerMethod = React.useMemo(_ =>
    savedMethods
    ->Array.concat(customerMethods)
    ->Array.filter(savedMethod => savedMethod.paymentToken === paymentTokenVal)
    ->Array.get(0)
    ->Option.getOr(PaymentType.defaultCustomerMethods)
  , [paymentTokenVal])
  let isUnknownPaymentMethod = customerMethod.paymentMethod === ""
  let isCardPaymentMethod = customerMethod.paymentMethod === "card"
  let isSavedCardCvcFlow = isCardPaymentMethod && customerMethod.requiresCvv
  let empty = isSavedCardCvcFlow ? savedCardCvcState.empty : cvcNumber == ""
  let isCardPaymentMethodValid =
    !customerMethod.requiresCvv || (savedCardCvcState.valid && !savedCardCvcState.empty)
  let isInstallmentValid = !showInstallments || selectedInstallmentPlan->Option.isSome

  let shouldDoEligibility = paymentMethodListValue.sdk_next_action === Some("eligibility_check")

  React.useEffect(() => {
    if shouldDoEligibility && isCardPaymentMethod && paymentTokenVal !== "" {
      setEligibilityError(_ => None)
      let eligibilityBody = [
        ("payment_method_type", "card"->JSON.Encode.string),
        ("payment_token", paymentTokenVal->JSON.Encode.string),
      ]

      EligibilityHelpers.startEligibilityCheck(
        ~controllerRef=eligibilityControllerRef,
        ~clientSecret,
        ~publishableKey,
        ~logger=loggerState,
        ~customPodUri,
        ~bodyArr=eligibilityBody,
        ~sdkAuthorization,
        ~endpoint,
        ~shouldBlockConfirm=paymentMethodListValue.should_block_confirm,
        ~setIsEligibilityPending,
        ~setEligibilitySurchargeDetails,
        ~setEligibilityError=Some(setEligibilityError),
        ~errorLogMessage="Saved card payment eligibility check failed",
        ~fetchEligibility={
          (
            ~clientSecret,
            ~publishableKey,
            ~logger,
            ~customPodUri,
            ~bodyArr,
            ~sdkAuthorization,
            ~endpoint,
            ~signal,
          ) =>
            PaymentHelpers.fetchPaymentMethodEligibility(
              ~clientSecret,
              ~publishableKey,
              ~logger,
              ~customPodUri,
              ~bodyArr,
              ~sdkAuthorization,
              ~endpoint,
              ~signal,
            )
        },
      )->ignore
    } else {
      eligibilityControllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
      setEligibilitySurchargeDetails(_ => None)
      setEligibilityError(_ => None)
      setIsEligibilityPending(_ => false)
    }
    Some(
      () => {
        eligibilityControllerRef.current->Option.forEach(c => Fetch.AbortController.abort(c))
      },
    )
  }, (
    paymentTokenVal,
    shouldDoEligibility,
    isCardPaymentMethod,
    clientSecret,
    publishableKey,
    sdkAuthorization,
    endpoint,
    customPodUri,
    paymentMethodListValue.should_block_confirm,
  ))

  let complete =
    areRequiredFieldsValid &&
    !isUnknownPaymentMethod &&
    (!isCardPaymentMethod || isCardPaymentMethodValid) &&
    isInstallmentValid &&
    !isEligibilityPending &&
    eligibilityError->Option.isNone
  // The outer iframe owns required fields, installments and eligibility; the
  // nested saved-card iframe owns CVC validation. Submit must reach the nested
  // iframe even while its CVC is invalid so it can surface the legacy errors.
  let completeForSubmit = if isSavedCardCvcFlow {
    areRequiredFieldsValid &&
    !isUnknownPaymentMethod &&
    isInstallmentValid &&
    !isEligibilityPending &&
    eligibilityError->Option.isNone &&
    savedCardCvcState.ready
  } else {
    complete
  }

  let paymentMethodType =
    customerMethod.paymentMethodType->Option.getOr(customerMethod.paymentMethod)

  useHandlePostMessages(~complete, ~empty, ~paymentType=paymentMethodType, ~savedMethod=true)
  SubscriptionEventHooks.useEmitFormStatus(~empty, ~complete)
  SubscriptionEventHooks.useEmitSurchargeInfo(~surchargeDetails=eligibilitySurchargeDetails)
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()

  React.useEffect(() => {
    if isCardPaymentMethod {
      let card = customerMethod.card
      let cardInfo = PaymentEventData.buildCardInfoFromSavedCard(
        ~bin=card.cardBin,
        ~last4=card.last4Digits,
        ~brand=card.scheme->Option.getOr(""),
        ~expiryMonth=card.expiryMonth,
        ~expiryYear=card.expiryYear,
        ~isCvcComplete=complete,
      )
      emitter.emitCardInfo(~cardInfo)
    }
    None
  }, (customerMethod, isCardPaymentMethod, complete))

  GooglePayHelpers.useHandleGooglePayResponse(
    ~connectors=[],
    ~intent,
    ~isSavedMethodsFlow=true,
    ~sdkAuthorization,
  )

  ApplePayHelpers.useHandleApplePayResponse(
    ~connectors=[],
    ~intent,
    ~isSavedMethodsFlow=true,
    ~sdkAuthorization,
  )

  SamsungPayHelpers.useHandleSamsungPayResponse(~intent, ~isSavedMethodsFlow=true)

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper

    let isCustomerAcceptanceRequired =
      alwaysSendCustomerAcceptance || customerMethod.recurringEnabled->not || isSaveCardsChecked
    let installmentBody = selectedInstallmentPlan->PaymentBody.installmentBody

    let buildSavedPaymentMethodBody = cvc =>
      switch customerMethod.paymentMethod {
      | "card" =>
        PaymentBody.savedCardBody(
          ~paymentToken=paymentTokenVal,
          ~customerId,
          ~cvcNumber=cvc,
          ~requiresCvv=customerMethod.requiresCvv,
          ~isCustomerAcceptanceRequired,
        )->Array.concat(installmentBody)
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
    let savedPaymentMethodBody = buildSavedPaymentMethodBody(cvcNumber)

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

          let clickToPayBody = switch clickToPayProvider {
          | MASTERCARD => {
              let headers = dict->Utils.getDictFromDict("headers")
              let merchantTransactionId = headers->Utils.getString("merchant-transaction-id", "")
              let xSrcFlowId = headers->Utils.getString("x-src-cx-flow-id", "")
              let correlationId =
                dict
                ->Utils.getDictFromDict("checkoutResponseData")
                ->Utils.getString("srcCorrelationId", "")

              PaymentBody.mastercardClickToPayBody(
                ~merchantTransactionId,
                ~correlationId,
                ~xSrcFlowId,
              )
            }
          | VISA =>
            PaymentBody.visaClickToPayBody(
              ~email=clickToPayConfig.email,
              ~encryptedPayload=dict->Utils.getString("checkoutResponse", ""),
            )
          | NONE => []
          }

          intent(
            ~bodyArr=clickToPayBody
            ->Array.concat(installmentBody)
            ->mergeAndFlattenToTuples(requiredFieldsBody),
            ~confirmParam=confirm.confirmParams,
            ~handleUserError=false,
            ~manualRetry=isManualRetryEnabled,
          )
          resolve(resp)
        })
        ->catch(_ =>
          resolve({
            ClickToPayHelpers.status: ERROR,
            payload: JSON.Encode.null,
          })
        )
        ->ignore
      } else if completeForSubmit && confirm.confirmTimestamp >= confirm.readyTimestamp {
        switch customerMethod.paymentMethodType {
        | Some("google_pay") =>
          switch gPayToken {
          | OtherTokenOptional(optToken) =>
            GooglePayHelpers.handleGooglePayClicked(
              ~sessionObj=optToken,
              ~componentName,
              ~iframeId,
              ~readOnly,
              ~isSavedMethodsFlow=true,
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
              ~isSavedMethodsFlow=true,
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
              ~isSavedMethodsFlow=true,
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
          if isSavedCardCvcFlow {
            // Every saved-card CVC now uses the same nested collector. Vault-backed
            // collectors return a token; raw collectors return the CVC. SavedMethods
            // remains the sole payment-confirm owner in both cases.
            let innerMsg = json->getDictFromJson
            innerMsg->Dict.set("isOuterValid", true->JSON.Encode.bool)
            innerMsg->Dict.set("paymentToken", paymentTokenVal->JSON.Encode.string)
            let handle = (ev: Types.event) => {
              let dict = ev.data->Identity.anyTypeToJson->getDictFromJson
              let isInnerCardMessage =
                cvcIframeRef.current
                ->Nullable.toOption
                ->Option.map(innerIframe =>
                  ev.source === innerIframe->Window.contentWindow && ev.origin === innerIframeOrigin
                )
                ->Option.getOr(false)
              let hasToken = dict->Dict.get("savedCardCvcTokenEvent")->Option.isSome
              let hasRawCvc = dict->Dict.get("savedCardCvcDataEvent")->Option.isSome
              let hasSubmitResponse = dict->Dict.get("submitSuccessful")->Option.isSome

              if isInnerCardMessage && (hasToken || hasRawCvc || hasSubmitResponse) {
                EventListenerManager.removeSmartEventListener(
                  "message",
                  savedCardCvcResponseListenerActivity,
                )
              }

              if isInnerCardMessage && hasToken && isVaultCvcFlow {
                let cvcToken = dict->getString("cvcToken", "")
                let cvcConfirmBody =
                  isHyperswitchVault && GlobalVars.isPciCompliant
                    ? PaymentBody.savedCardVaultCvcBody(
                        ~paymentToken=paymentTokenVal,
                        ~customerId,
                        ~cvcToken,
                        ~isCustomerAcceptanceRequired,
                      )
                    : PaymentBody.externalSavedCardVaultCvcBody(
                        ~paymentToken=paymentTokenVal,
                        ~customerId,
                        ~cvcToken,
                        ~isCustomerAcceptanceRequired,
                      )
                let vaultBody = cvcConfirmBody->Array.concat(installmentBody)
                intent(
                  ~bodyArr=vaultBody->mergeAndFlattenToTuples(requiredFieldsBody),
                  ~confirmParam=confirm.confirmParams,
                  ~handleUserError=false,
                  ~manualRetry=isManualRetryEnabled,
                )
              }

              if isInnerCardMessage && hasRawCvc && !isVaultCvcFlow {
                let rawSavedCardBody = buildSavedPaymentMethodBody(dict->getString("cvcNumber", ""))
                intent(
                  ~bodyArr=rawSavedCardBody->mergeAndFlattenToTuples(requiredFieldsBody),
                  ~confirmParam=confirm.confirmParams,
                  ~handleUserError=false,
                  ~manualRetry=isManualRetryEnabled,
                )
              }

              // Validation/tokenisation failures from the inner iframe keep the
              // public confirmPayment rejection contract unchanged.
              if isInnerCardMessage && hasSubmitResponse {
                messageParentWindow(dict->Dict.toArray)
              }
            }
            EventListenerManager.addSmartEventListener(
              "message",
              handle,
              savedCardCvcResponseListenerActivity,
            )
            cvcIframeRef.current->Window.iframePostMessage(
              innerMsg,
              ~targetOrigin=innerIframeOrigin,
            )
          } else {
            intent(
              ~bodyArr=savedPaymentMethodBody->mergeAndFlattenToTuples(requiredFieldsBody),
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        }
      } else {
        if isEligibilityPending && paymentMethodListValue.should_block_confirm {
          setUserError(localeString.paymentDetailsBeingCheckedText)
        }
        eligibilityError->Option.forEach(error =>
          setUserError(
            EligibilityHelpers.getCardEligibilityErrorText(
              ~cardEligibilityError=Some(error),
              ~localeString,
            ),
          )
        )
        if isUnknownPaymentMethod || confirm.confirmTimestamp < confirm.readyTimestamp {
          setUserError(localeString.selectPaymentMethodText)
        }
        if customerMethod.requiresCvv && !isSavedCardCvcFlow {
          if !isUnknownPaymentMethod && cvcNumber === "" {
            setCvcError(_ => localeString.cvcNumberEmptyText)
            setUserError(localeString.enterFieldsText)
          } else if !(isCVCValid->Option.getOr(false)) {
            setCvcError(_ => localeString.inCompleteCVCErrorText)
            setUserError(localeString.enterValidDetailsText)
          }
        }
        if isSavedCardCvcFlow && !savedCardCvcState.ready {
          setUserError(localeString.enterFieldsText)
        }
        if !areRequiredFieldsValid {
          setUserError(localeString.enterValidDetailsText)
        }
        if !isInstallmentValid {
          setUserError(localeString.installmentSelectPlanError)
          setInstallmentsError(_ => localeString.installmentSelectPlanError)
        }
      }
    }
  }, (
    areRequiredFieldsValid,
    requiredFieldsBody,
    empty,
    complete,
    completeForSubmit,
    savedCardCvcState.ready,
    customerMethod,
    applePayToken,
    gPayToken,
    isManualRetryEnabled,
    selectedInstallmentPlan,
    showInstallments,
    sdkAuthorization,
    isEligibilityPending,
    eligibilityError,
    isHyperswitchVault,
    isSavedCardCvcFlow,
    isVaultCvcFlow,
    innerIframeOrigin,
    paymentTokenVal,
    customerId,
  ))
  useSubmitPaymentData(submitCallback)

  let conditionsForShowingSaveCardCheckbox = React.useMemo(() => {
    !isGuestCustomer &&
    paymentMethodListValue.payment_type === NEW_MANDATE &&
    displaySavedPaymentMethodsCheckbox &&
    customerMethod.requiresCvv
  }, (
    isGuestCustomer,
    paymentMethodListValue.payment_type,
    displaySavedPaymentMethodsCheckbox,
    customerMethod,
  ))

  let showSavedCards = groupSavedMethodsSeparately || !showPaymentMethodsScreen

  let enableSavedPaymentShimmer = React.useMemo(() => {
    savedCardlength === 0 &&
    !showPaymentMethodsScreen &&
    (loadSavedCards === PaymentType.LoadingSavedCards || clickToPayConfig.isReady->Option.isNone)
  }, (savedCardlength, loadSavedCards, showPaymentMethodsScreen, clickToPayConfig.isReady))

  <div className="flex flex-col overflow-auto h-auto no-scrollbar animate-slowShow">
    {if enableSavedPaymentShimmer {
      <PaymentElementShimmer.SavedPaymentCardShimmer />
    } else {
      <RenderIf condition=showSavedCards> {bottomElement} </RenderIf>
    }}
    <RenderIf condition={conditionsForShowingSaveCardCheckbox && !alwaysSendCustomerAcceptance}>
      <div className="pt-4 pb-2 flex items-center justify-start">
        <SaveDetailsCheckbox isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked />
      </div>
    </RenderIf>
    <RenderIf
      condition={alwaysSendCustomerAcceptance ||
      (displaySavedPaymentMethodsCheckbox &&
      paymentMethodListValue.payment_type === SETUP_MANDATE)}>
      <Terms
        styles={
          marginTop: themeObj.spacingGridColumn,
        }
        paymentMethod="card"
        paymentMethodType="debit"
      />
    </RenderIf>
    <RenderIf condition={!enableSavedPaymentShimmer && !groupSavedMethodsSeparately}>
      <SwitchViewButton
        onClick={_ => setShowPaymentMethodsScreen(_ => true)}
        icon={<Icon name="circle-plus" size=22 />}
        title={localeString.newPaymentMethods}
        ariaLabel="Click to use new payment methods"
        dataTestId={TestUtils.addNewCardIcon}
        onKeyDown={event => {
          let key = JsxEvent.Keyboard.key(event)
          let keyCode = JsxEvent.Keyboard.keyCode(event)
          if key == "Enter" || keyCode == 13 {
            setShowPaymentMethodsScreen(_ => true)
          }
        }}
      />
    </RenderIf>
  </div>
}
