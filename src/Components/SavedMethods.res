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

  // ── VGS saved-card (return user) CVC flow ───────────────────────────────────
  // When the profile uses card tokenisation (isTokenize) and the session's vault
  // is VGS, the selected card's CVC is collected + tokenised inside a nested
  // iframe (hosted by ParentCardComponent in saved-card mode) instead of a plain
  // input. SavedMethods stays the submit owner: it forwards the doSubmit message
  // to that iframe and confirms with the vault_card_token_data body.
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
        let (eligibilitySurchargeDetails, isEligibilityPending) = isActive
          ? (
              eligibilitySurchargeDetails,
              isEligibilityPending && paymentMethodListValue.should_block_confirm,
            )
          : (None, false)
        <SavedCardItem
          key={i->Int.toString}
          setPaymentToken
          isActive
          paymentItem=obj
          brandIcon={obj->getPaymentMethodBrand}
          index=i
          savedCardlength
          cvcProps
          setRequiredFieldsBody
          setSelectedInstallmentPlan
          showInstallments
          setShowInstallments
          installmentsError
          setInstallmentsError
          eligibilitySurchargeDetails
          isEligibilityPending
          isVaultCvcFlow
          setCvcIframeRef
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
          cvcProps
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
  let complete = switch isCVCValid {
  | Some(val) => paymentTokenVal !== "" && val
  | _ => false
  }
  // VGS collects + validates the CVC inside the iframe, so the outer plain-CVC
  // "empty" signal is not meaningful — treat it as filled.
  let empty = isVaultCvcFlow ? false : cvcNumber == ""
  let customerMethod = React.useMemo(_ =>
    savedMethods
    ->Array.concat(customerMethods)
    ->Array.filter(savedMethod => savedMethod.paymentToken === paymentTokenVal)
    ->Array.get(0)
    ->Option.getOr(PaymentType.defaultCustomerMethods)
  , [paymentTokenVal])
  let isUnknownPaymentMethod = customerMethod.paymentMethod === ""
  let isCardPaymentMethod = customerMethod.paymentMethod === "card"
  // For the VGS saved-card flow the CVC lives in the iframe (validated there on
  // submit), so outer validity does not depend on the plain CVC field — mirroring
  // how the new-card flow lets the inner iframe gate the card fields.
  let isCardPaymentMethodValid =
    isVaultCvcFlow && isCardPaymentMethod
      ? true
      : !customerMethod.requiresCvv || (complete && !empty)
  let isInstallmentValid = !showInstallments || selectedInstallmentPlan->Option.isSome

  let shouldDoEligibility = paymentMethodListValue.sdk_next_action === Some("eligibility_check")

  React.useEffect(() => {
    if shouldDoEligibility && isCardPaymentMethod && paymentTokenVal !== "" {
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
        ~setEligibilityError=None,
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
    !isEligibilityPending

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

    let savedPaymentMethodBody = switch customerMethod.paymentMethod {
    | "card" =>
      PaymentBody.savedCardBody(
        ~paymentToken=paymentTokenVal,
        ~customerId,
        ~cvcNumber,
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
      } else if complete && confirm.confirmTimestamp >= confirm.readyTimestamp {
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
          if (
            isVaultCvcFlow && customerMethod.paymentMethod === "card" && customerMethod.requiresCvv
          ) {
            // Vault saved-card flow (VGS or Hyperswitch): forward the validated
            // doSubmit to the CVC iframe. It tokenises the CVC and posts
            // `savedCardCvcTokenEvent` back; we then confirm with the
            // vault_card_token_data body (otherwise identical to the plain saved-card
            // confirm — same business-logic merge). The Hyperswitch tokeniser needs
            // the selected card's payment_token, so forward it in the message.
            let innerMsg = json->getDictFromJson
            innerMsg->Dict.set("isOuterValid", true->JSON.Encode.bool)
            innerMsg->Dict.set("paymentToken", paymentTokenVal->JSON.Encode.string)
            cvcIframeRef.current->Window.iframePostMessage(innerMsg)
            let handle = (ev: Types.event) => {
              let dict = ev.data->Identity.anyTypeToJson->getDictFromJson
              if dict->Dict.get("savedCardCvcTokenEvent")->Option.isSome {
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

              // Tokenisation / validation error from the inner iframe — forward to
              // Hyper.res so it can reject the merchant's confirmPayment() promise.
              if dict->Dict.get("submitSuccessful")->Option.isSome {
                messageParentWindow(dict->Dict.toArray)
              }
            }
            EventListenerManager.addSmartEventListener(
              "message",
              handle,
              "onSavedCardCvcTokenResponse",
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
        if isUnknownPaymentMethod || confirm.confirmTimestamp < confirm.readyTimestamp {
          setUserError(localeString.selectPaymentMethodText)
        }
        if customerMethod.requiresCvv {
          if !isUnknownPaymentMethod && cvcNumber === "" {
            setCvcError(_ => localeString.cvcNumberEmptyText)
            setUserError(localeString.enterFieldsText)
          } else if !(isCVCValid->Option.getOr(false)) {
            setCvcError(_ => localeString.inCompleteCVCErrorText)
            setUserError(localeString.enterValidDetailsText)
          }
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
    customerMethod,
    applePayToken,
    gPayToken,
    isManualRetryEnabled,
    selectedInstallmentPlan,
    showInstallments,
    sdkAuthorization,
    isEligibilityPending,
    isHyperswitchVault,
    isVaultCvcFlow,
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
