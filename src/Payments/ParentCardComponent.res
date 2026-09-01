open Utils
open UtilityHooks
open PaymentType

let innerIframeContainerDivId = "parent-card-inner-iframe-container"
let tokenResponseListenerActivity = "onParentCardTokenResponse"

@react.component
let make = (
  ~isSavedCardFlow=false,
  ~containerId=innerIframeContainerDivId,
  ~setExternalIframeRef: option<Nullable.t<Dom.element> => unit>=?,
  ~onSavedCardCvcStateChange: option<CardIframeProtocol.savedCardCvcState => unit>=?,
  ~savedCardBrand="",
  ~cardCollectionMode="tokenise",
  ~isBancontact=false,
  ~flowType=CardThemeType.Payment,
  ~isActive=true,
) => {
  let {
    clientSecret,
    publishableKey,
    iframeId,
    paymentId,
    sdkHandleOneClickConfirmPayment,
  } = Jotai.useAtomValue(JotaiAtoms.keys)
  let sessionId = Jotai.useAtomValue(JotaiAtoms.sessionId)
  let customPodUri = Jotai.useAtomValue(JotaiAtoms.customPodUri)
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)
  let isManualRetryEnabled = Jotai.useAtomValue(JotaiAtoms.isManualRetryEnabled)
  let options = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let config = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let isConfigReady = Jotai.useAtomValue(JotaiAtoms.isConfigReady)
  let nickname = Jotai.useAtomValue(JotaiAtoms.userCardNickName)
  let email = Jotai.useAtomValue(JotaiAtoms.userEmailAddress)
  let fullName = Jotai.useAtomValue(JotaiAtoms.userFullName)
  let phoneNumber = Jotai.useAtomValue(JotaiAtoms.userPhoneNumber)
  let clickToPayConfig = Jotai.useAtomValue(JotaiAtoms.clickToPayConfig)
  let areRequiredFieldsValid = Jotai.useAtomValue(JotaiAtoms.areRequiredFieldsValid)
  let sessions = Jotai.useAtomValue(JotaiAtoms.sessions)
  let optionsJson = Jotai.useAtomValue(JotaiAtoms.optionsJsonAtom)
  let paymentOptionsJson = Jotai.useAtomValue(JotaiAtoms.paymentOptionsJsonAtom)
  let redirectionFlags = Jotai.useAtomValue(JotaiAtoms.redirectionFlagsAtom)
  let setComplete = Jotai.useSetAtom(JotaiAtoms.fieldsComplete)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Jotai.useAtom(
    JotaiAtoms.showPaymentMethodsScreen,
  )

  let {
    displaySavedPaymentMethodsCheckbox,
    savedPaymentMethodsCheckboxCheckedByDefault,
    alwaysSendCustomerAcceptance,
    hideCardNicknameField,
    layout,
  } = options
  let layoutClass = CardUtils.getLayoutClass(layout)
  let {themeObj, localeString} = config
  let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.vaultSdkDomainUrl).origin
  let isRawMode = cardCollectionMode === "raw"
  let isRawNewCardFlow = isRawMode && !isSavedCardFlow
  let isPMMFlow = flowType === CardThemeType.PaymentMethodsManagement
  let loggerSource =
    "hyper_" ++
    flowType
    ->CardThemeType.getPaymentModeToStrMapper
    ->LoggerUtils.toSnakeCaseWithSeparator("_")
  let paymentMethod = isBancontact ? "bank_redirect" : "card"
  let paymentMethodType = isBancontact ? "bancontact_card" : "debit"

  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let saveCard = PaymentHelpersV2.useSaveCard(Some(loggerState), Card)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ =>
    savedPaymentMethodsCheckboxCheckedByDefault
  )
  let (selectedInstallmentPlan, setSelectedInstallmentPlan) = React.useState(_ => None)
  let (showInstallments, setShowInstallments) = React.useState(_ => false)
  let (installmentsError, setInstallmentsError) = React.useState(_ => "")
  let isInstallmentValid = !showInstallments || selectedInstallmentPlan->Option.isSome
  let (isSaveDetailsWithClickToPay, setIsSaveDetailsWithClickToPay) = React.useState(_ => false)
  let (isClickToPayRememberMe, setIsClickToPayRememberMe) = React.useState(_ => false)

  let iframeRef = React.useRef(Nullable.null)
  let (iframeMounted, setIframeMounted) = React.useState(_ => false)
  let (innerCardState, setInnerCardState) = React.useState(_ => CardIframeProtocol.initialState)
  let (savedCardCvcState, setSavedCardCvcState) = React.useState(_ =>
    CardIframeProtocol.initialSavedCardCvcState
  )
  let (innerIframeHeight, setInnerIframeHeight) = React.useState(_ => 0.0)
  let isCvcReady = savedCardCvcState.ready && innerIframeHeight > 0.0

  let {
    cardBrand,
    rawCardNumber,
    cardFieldsComplete,
    cardFieldsEmpty,
    isCvcEmpty,
    isCvcComplete,
    hasCardFieldStatus,
    isCardValid,
    isExpiryValid,
    isCvcValid,
    hasCardValidationStatus,
    hasExpiryValidationStatus,
    hasCvcValidationStatus,
    cardInfo,
  } = innerCardState
  let isCardFormReady =
    hasCardFieldStatus && (isBancontact || innerIframeHeight > CardIframeProtocol.emptyFrameHeight)
  let setIsVgsScriptReady = Jotai.useSetAtom(JotaiAtoms.isVgsScriptReady)

  let mountConfigRef = React.useRef((
    optionsJson,
    paymentOptionsJson,
    publishableKey,
    sessionId,
    customPodUri,
    paymentId,
    sdkHandleOneClickConfirmPayment,
    loggerSource,
    isSavedCardFlow,
    savedCardBrand,
    cardCollectionMode,
    isBancontact,
    flowType,
  ))
  React.useEffect(() => {
    mountConfigRef.current = (
      optionsJson,
      paymentOptionsJson,
      publishableKey,
      sessionId,
      customPodUri,
      paymentId,
      sdkHandleOneClickConfirmPayment,
      loggerSource,
      isSavedCardFlow,
      savedCardBrand,
      cardCollectionMode,
      isBancontact,
      flowType,
    )
    None
  }, (
    optionsJson,
    paymentOptionsJson,
    publishableKey,
    sessionId,
    customPodUri,
    paymentId,
    sdkHandleOneClickConfirmPayment,
    loggerSource,
    isSavedCardFlow,
    savedCardBrand,
    cardCollectionMode,
    isBancontact,
    flowType,
  ))

  let isGuestCustomer = useIsGuestCustomer()
  let isCustomerAcceptanceFromHook = useIsCustomerAcceptanceRequired(
    ~displaySavedPaymentMethodsCheckbox,
    ~isSaveCardsChecked,
    ~isGuestCustomer,
  )
  let isCustomerAcceptanceRequired =
    (!isGuestCustomer && alwaysSendCustomerAcceptance) || isCustomerAcceptanceFromHook
  let conditionsForShowingSaveCardCheckbox =
    paymentMethodListValue.mandate_payment->Option.isNone &&
    !isGuestCustomer &&
    paymentMethodListValue.payment_type !== SETUP_MANDATE &&
    displaySavedPaymentMethodsCheckbox &&
    !isBancontact

  let supportedCardBrands = React.useMemo(() => {
    paymentMethodListValue->PaymentUtils.getSupportedCardBrands
  }, [paymentMethodListValue])
  let supportedCardBrandsRef = React.useRef(supportedCardBrands)
  supportedCardBrandsRef.current = supportedCardBrands
  let lastPostedOptionsRef = React.useRef("")
  let cardSupportState = React.useMemo(() => {
    if isRawNewCardFlow && !isBancontact {
      let clearCardNumber = rawCardNumber->CardValidations.clearSpaces
      let detectedBrand = clearCardNumber->CardUtils.getCardBrand
      let effectiveBrand = cardBrand === "" ? detectedBrand : cardBrand
      PaymentUtils.checkIsCardSupported(clearCardNumber, effectiveBrand, supportedCardBrands)
    } else {
      None
    }
  }, (rawCardNumber, cardBrand, isRawNewCardFlow, isBancontact, supportedCardBrands))
  let {
    cardEligibilityError,
    eligibilitySurchargeDetails,
    eligibilityOfferDetails,
    isEligibilityPending,
    triggerOnCardNumberChange,
    resetEligibilityState: _,
  } = UseCardEligibility.useCardEligibility(
    ~logger=loggerState,
    ~runEligibility=isRawNewCardFlow && !isBancontact,
  )

  let selectedOfferQuoteIds =
    eligibilityOfferDetails
    ->Option.map((offerDetails: EligibilityHelpers.eligibilityOfferDetails) =>
      offerDetails.offerQuoteIds
    )
    ->Option.getOr([])

  React.useEffect(() => {
    if isRawNewCardFlow && !isBancontact {
      let clearCardNumber = rawCardNumber->CardValidations.clearSpaces
      triggerOnCardNumberChange(
        ~cardNumber=clearCardNumber,
        ~isCardSupportedAndValid=cardSupportState->Option.getOr(false),
      )
    }
    None
  }, (
    rawCardNumber,
    isRawNewCardFlow,
    isBancontact,
    cardSupportState,
    paymentMethodListValue.sdk_next_action,
    clientSecret,
  ))

  React.useEffect(() => {
    if isRawNewCardFlow && iframeMounted {
      let supportState =
        [
          ("hasStatus", cardSupportState->Option.isSome->JSON.Encode.bool),
          ("supported", cardSupportState->Option.getOr(true)->JSON.Encode.bool),
        ]->Dict.fromArray
      iframeRef.current->Window.iframePostMessage(
        [("cardSupportStateUpdate", supportState->JSON.Encode.object)]->Dict.fromArray,
        ~targetOrigin=innerIframeOrigin,
      )
    }
    None
  }, (
    isRawNewCardFlow,
    iframeMounted,
    cardSupportState,
    cardBrand,
    rawCardNumber,
    supportedCardBrands,
  ))

  React.useEffect(() => {
    if isSavedCardFlow && iframeMounted {
      iframeRef.current->Window.iframePostMessage(
        [
          ("savedCardBrand", savedCardBrand->CardUtils.normalizeCardBrand->JSON.Encode.string),
        ]->Dict.fromArray,
        ~targetOrigin=innerIframeOrigin,
      )
    }
    None
  }, (isSavedCardFlow, iframeMounted, savedCardBrand))

  React.useEffect(() => {
    if isRawNewCardFlow && iframeMounted {
      let eligibilityState =
        [
          ("hasError", cardEligibilityError->Option.isSome->JSON.Encode.bool),
          ("error", cardEligibilityError->Option.getOr("")->JSON.Encode.string),
        ]->Dict.fromArray
      iframeRef.current->Window.iframePostMessage(
        [("cardEligibilityStateUpdate", eligibilityState->JSON.Encode.object)]->Dict.fromArray,
        ~targetOrigin=innerIframeOrigin,
      )
    }
    None
  }, (isRawNewCardFlow, iframeMounted, cardEligibilityError))

  let ctpCards = clickToPayConfig.clickToPayCards->Option.getOr([])
  let clickToPayCardBrand =
    isRawNewCardFlow &&
    !isBancontact &&
    !isPMMFlow &&
    cardBrand !== "" &&
    clickToPayConfig.availableCardBrands->Array.includes(cardBrand->String.toLowerCase)
      ? cardBrand
      : ""

  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  let {country, state, pinCode} = PaymentUtils.useNonPiiAddressData()
  let (cardBin, cardLast4, infoCardBrand, cardExpiryMonth, cardExpiryYear) = switch cardInfo {
  | Some(info) => (
      info.bin->Option.getOr(""),
      info.last4->Option.getOr(""),
      info.brand->Option.getOr(cardBrand),
      info.expiryMonth->Option.getOr(""),
      info.expiryYear->Option.getOr(""),
    )
  | None => ("", "", cardBrand, "", "")
  }

  // Preserve the pre-split, unconditional `paymentMethodInfo` message. The
  // legacy top-level hook cannot observe nested card state, so Card now emits
  // it here while all non-card methods continue using that hook.
  React.useEffect(() => {
    if !isSavedCardFlow && !isBancontact {
      switch cardInfo {
      | Some(info)
        if isCardValid && isExpiryValid && info.isCardNumberValid && info.isExpiryValid =>
        PaymentUtils.emitPaymentMethodInfo(
          ~paymentMethod="card",
          ~paymentMethodType="debit",
          ~cardBrand=infoCardBrand->CardUtils.getCardType,
          ~cardLast4,
          ~cardBin,
          ~cardExpiryMonth,
          ~cardExpiryYear,
          ~country,
          ~state,
          ~pinCode,
          ~isCvcEmpty,
        )
      | _ =>
        PaymentUtils.emitPaymentMethodInfo(
          ~paymentMethod="card",
          ~paymentMethodType="debit",
          ~country,
          ~state,
          ~pinCode,
        )
      }
    }
    None
  }, (
    isSavedCardFlow,
    cardBin,
    cardLast4,
    infoCardBrand,
    cardExpiryMonth,
    cardExpiryYear,
    cardBrand,
    isCardValid,
    isExpiryValid,
    isCvcEmpty,
    country,
    state,
    pinCode,
    isBancontact,
  ))

  UtilityHooks.useHandlePostMessages(
    ~complete=cardFieldsComplete && isInstallmentValid && areRequiredFieldsValid,
    ~empty=cardFieldsEmpty,
    ~paymentType="card",
    ~enabled=!isSavedCardFlow && isActive,
  )
  SubscriptionEventHooks.useEmitFormStatus(
    ~empty=cardFieldsEmpty,
    ~complete=cardFieldsComplete && isInstallmentValid && areRequiredFieldsValid,
    ~enabled=!isSavedCardFlow && isActive,
  )
  SubscriptionEventHooks.useEmitSurchargeInfo(~surchargeDetails=eligibilitySurchargeDetails)
  SubscriptionEventHooks.useEmitAppliedOffersInfo(~offerDetails=eligibilityOfferDetails)

  React.useEffect(() => {
    if !isSavedCardFlow {
      cardInfo->Option.forEach(info => emitter.emitCardInfo(~cardInfo=info))
    }
    None
  }, (cardInfo, isSavedCardFlow))

  React.useEffect(() => {
    if !isSavedCardFlow && hasCardFieldStatus {
      emitter.emitCvcStatus(~iframeId, ~isCvcEmpty, ~isCvcComplete)
    }
    None
  }, (isSavedCardFlow, hasCardFieldStatus, isCvcEmpty, isCvcComplete, iframeId))

  React.useEffect(() => {
    if isSavedCardFlow {
      onSavedCardCvcStateChange->Option.forEach(callback => callback(savedCardCvcState))
      if savedCardCvcState.ready {
        emitter.emitCvcStatus(
          ~iframeId,
          ~isCvcEmpty=savedCardCvcState.empty,
          ~isCvcComplete=savedCardCvcState.complete,
        )
      }
    }
    None
  }, (isSavedCardFlow, savedCardCvcState, iframeId))

  React.useEffect(() => {
    if !isSavedCardFlow && hasCardFieldStatus {
      setComplete(_ => cardFieldsComplete && isInstallmentValid)
      setShowPaymentMethodsScreen(_ => true)
    }
    None
  }, (isSavedCardFlow, hasCardFieldStatus, cardFieldsComplete, isInstallmentValid))

  // The legacy direct Card flow emitted this only after all three validation
  // states had resolved. Preserve that timing at the public iframe boundary.
  React.useEffect(() => {
    if (
      !isSavedCardFlow &&
      hasCardValidationStatus &&
      hasExpiryValidationStatus &&
      hasCvcValidationStatus
    ) {
      CardUtils.emitIsFormReadyForSubmission(
        isCardValid && isExpiryValid && isCvcValid && areRequiredFieldsValid,
      )
    }
    None
  }, (
    isSavedCardFlow,
    hasCardValidationStatus,
    hasExpiryValidationStatus,
    hasCvcValidationStatus,
    isCardValid,
    isExpiryValid,
    isCvcValid,
    areRequiredFieldsValid,
  ))

  let mountPostMessage = React.useCallback(
    (mountedIframeRef, selectorString, _sdkHandleOneClickConfirmPayment) => {
      let (
        currentOptionsJson,
        currentPaymentOptionsJson,
        currentPublishableKey,
        currentSessionId,
        currentCustomPodUri,
        currentPaymentId,
        currentHandleOneClickConfirmPayment,
        currentLoggerSource,
        currentIsSavedCardFlow,
        currentSavedCardBrand,
        currentCardCollectionMode,
        currentIsBancontact,
        currentFlowType,
      ) = mountConfigRef.current
      let endpoint = ApiEndpoint.getVaultEndPoint(~publishableKey=currentPublishableKey)
      lastPostedOptionsRef.current = currentOptionsJson->JSON.stringify
      let supportedCardBrandEntries = switch supportedCardBrandsRef.current {
      | Some(brands) => [
          ("supportedCardBrands", brands->Array.map(JSON.Encode.string)->JSON.Encode.array),
        ]
      | None => []
      }
      let message =
        [
          ("paymentElementCreate", true->JSON.Encode.bool),
          ("paymentOptions", currentPaymentOptionsJson),
          ("options", currentOptionsJson),
          ("iframeId", selectorString->JSON.Encode.string),
          ("publishableKey", currentPublishableKey->JSON.Encode.string),
          ("endpoint", endpoint->JSON.Encode.string),
          ("sdkSessionId", currentSessionId->JSON.Encode.string),
          ("customPodUri", currentCustomPodUri->JSON.Encode.string),
          ("paymentId", currentPaymentId->JSON.Encode.string),
          ("parentURL", Window.Location.origin->JSON.Encode.string),
          (
            "sdkHandleOneClickConfirmPayment",
            currentHandleOneClickConfirmPayment->JSON.Encode.bool,
          ),
          ("launchTime", Date.now()->JSON.Encode.float),
          ("loggerSource", currentLoggerSource->JSON.Encode.string),
          ("isSavedCardCvcFlow", currentIsSavedCardFlow->JSON.Encode.bool),
          ("savedCardBrand", currentSavedCardBrand->JSON.Encode.string),
          ("cardCollectionMode", currentCardCollectionMode->JSON.Encode.string),
          ("isBancontactCardFlow", currentIsBancontact->JSON.Encode.bool),
          (
            "cardFlowType",
            currentFlowType->CardThemeType.getPaymentModeToString->JSON.Encode.string,
          ),
        ]
        ->Array.concat(supportedCardBrandEntries)
        ->Dict.fromArray
      mountedIframeRef->Window.iframePostMessage(message, ~targetOrigin=innerIframeOrigin)
      setIframeMounted(_ => true)
    },
    [],
  )

  React.useEffect(() => {
    if isConfigReady {
      let setIframeRefFn = ref => {
        iframeRef.current = ref
        switch setExternalIframeRef {
        | Some(fn) => fn(ref)
        | None => ()
        }
      }
      let element = LoaderPaymentElement.make(
        "paymentMethodsSDK",
        Dict.make()->JSON.Encode.object,
        setIframeRefFn,
        [],
        mountPostMessage,
        ~appearance=Dict.make()->JSON.Encode.object,
        ~redirectionFlags,
        ~sdkDomainUrl=ApiEndpoint.vaultSdkDomainUrl,
        ~logger=Some(loggerState),
        ~confirmPayment=_json => Promise.resolve(JSON.Encode.null),
        ~animateResize=false,
      )
      element.mount(`#${containerId}`)
      Some(
        () => {
          element.unmount()
          setExternalIframeRef->Option.forEach(callback => callback(Nullable.null))
          setIframeMounted(_ => false)
        },
      )
    } else {
      None
    }
  }, [isConfigReady])

  React.useEffect(() => {
    switch (iframeMounted, sessions) {
    | (true, Loaded(s)) =>
      iframeRef.current->Window.iframePostMessage(
        [("sessions", s)]->Dict.fromArray,
        ~targetOrigin=innerIframeOrigin,
      )
    | _ => ()
    }
    None
  }, (iframeMounted, sessions))

  React.useEffect(() => {
    switch (iframeMounted, supportedCardBrands) {
    | (true, Some(brands)) =>
      iframeRef.current->Window.iframePostMessage(
        [
          ("supportedCardBrands", brands->Array.map(JSON.Encode.string)->JSON.Encode.array),
        ]->Dict.fromArray,
        ~targetOrigin=innerIframeOrigin,
      )
    | _ => ()
    }
    None
  }, (iframeMounted, supportedCardBrands))

  React.useEffect(() => {
    if iframeMounted {
      iframeRef.current->Window.iframePostMessage(
        [
          ("paymentElementCreate", false->JSON.Encode.bool),
          ("paymentOptions", paymentOptionsJson),
        ]->Dict.fromArray,
        ~targetOrigin=innerIframeOrigin,
      )
    }
    None
  }, (iframeMounted, paymentOptionsJson))

  React.useEffect(() => {
    let serializedOptions = optionsJson->JSON.stringify
    if iframeMounted && serializedOptions !== lastPostedOptionsRef.current {
      iframeRef.current->Window.iframePostMessage(
        [
          ("paymentElementsUpdate", true->JSON.Encode.bool),
          ("options", optionsJson),
        ]->Dict.fromArray,
        ~targetOrigin=innerIframeOrigin,
      )
      lastPostedOptionsRef.current = serializedOptions
    }
    None
  }, (iframeMounted, optionsJson))

  React.useEffect(() => {
    let handleMessage = (ev: Window.event) => {
      let dict = ev.data->Identity.anyTypeToJson->getDictFromJson
      let isInnerCardMessage =
        iframeRef.current
        ->Nullable.toOption
        ->Option.map(innerIframe =>
          ev.source === innerIframe->Window.contentWindow && ev.origin === innerIframeOrigin
        )
        ->Option.getOr(false)
      if (
        ev.source === iframeParent &&
        iframeMounted &&
        (dict->Dict.get("doBlur")->Option.isSome ||
        dict->Dict.get("doFocus")->Option.isSome ||
        dict->Dict.get("doClearValues")->Option.isSome)
      ) {
        iframeRef.current->Window.iframePostMessage(dict, ~targetOrigin=innerIframeOrigin)
      }
      if isInnerCardMessage {
        let reportedHeight = CardIframeProtocol.decodeIframeHeight(dict)
        if reportedHeight > 0.0 {
          setInnerIframeHeight(_ => reportedHeight)
        }
        if isSavedCardFlow {
          switch CardIframeProtocol.decodeSavedCardCvcState(dict) {
          | Some(status) => setSavedCardCvcState(_ => status)
          | None => ()
          }
        }
        switch CardIframeProtocol.decodeStateUpdate(
          ~dict,
          ~allowRawCardNumber=isRawMode,
          ~allowFullCardState=!isSavedCardFlow,
        ) {
        | Some(update) =>
          setInnerCardState(previous => CardIframeProtocol.applyStateUpdate(previous, update))
        | None => ()
        }
      }

      // Native card fields used to live directly in this iframe, so these
      // messages reached the merchant without another hop. Re-emit the same
      // public interaction payloads and normalize identity to this outer
      // Payment Element (the nested iframe id is an implementation detail).
      let publicElementType = flowType->CardThemeType.getPaymentModeToString
      if isInnerCardMessage && dict->Dict.get("focus")->Option.isSome {
        messageParentWindow([
          ("focus", dict->getBool("focus", true)->JSON.Encode.bool),
          ("elementType", publicElementType->JSON.Encode.string),
          ("iframeId", iframeId->JSON.Encode.string),
        ])
      }
      if isInnerCardMessage && dict->Dict.get("blur")->Option.isSome {
        messageParentWindow([
          ("blur", dict->getBool("blur", true)->JSON.Encode.bool),
          ("elementType", publicElementType->JSON.Encode.string),
          ("iframeId", iframeId->JSON.Encode.string),
        ])
      }
      if isInnerCardMessage && dict->Dict.get("clickTriggered")->Option.isSome {
        messageParentWindow([
          ("clickTriggered", dict->getBool("clickTriggered", true)->JSON.Encode.bool),
          ("event", dict->getString("event", "")->JSON.Encode.string),
        ])
      }
      if isInnerCardMessage && dict->Dict.get("expiryDate")->Option.isSome {
        messageParentWindow([("expiryDate", dict->getString("expiryDate", "")->JSON.Encode.string)])
      }
      if isInnerCardMessage && dict->Dict.get("vgsScriptLoadFailed")->Option.isSome {
        loggerState.setLogError(
          ~value=`Error during loading VGS script`->Identity.anyTypeToJson->JSON.stringify,
          ~eventName=VGS_VAULT_FLOW,
        )
        setIsVgsScriptReady(_ => false)
      }
    }
    Window.addEventListener("message", handleMessage)
    Some(() => Window.removeEventListener("message", handleMessage))
  }, (iframeMounted, isRawMode, isSavedCardFlow, flowType, iframeId))

  let confirmBody = (
    baseBody,
    ~confirmParams,
    ~includeAcceptance=true,
    ~includeInstallments=true,
    ~save=false,
  ) => {
    let onSessionBody = [("customer_acceptance", PaymentBody.customerAcceptanceBody)]
    let bodyWithAcceptance =
      includeAcceptance && isCustomerAcceptanceRequired
        ? baseBody->Array.concat(onSessionBody)
        : baseBody
    let installmentBody = includeInstallments
      ? selectedInstallmentPlan->PaymentBody.installmentBody
      : []
    let offerDetailsBody = PaymentBody.offerDetailsBody(~offerQuoteIds=selectedOfferQuoteIds)
    let finalBody =
      bodyWithAcceptance
      ->Array.concat(installmentBody)
      ->Array.concat(offerDetailsBody)
      ->mergeAndFlattenToTuples(requiredFieldsBody)
    if save {
      saveCard(~bodyArr=finalBody, ~confirmParam=confirmParams, ~handleUserError=true)
    } else {
      intent(
        ~bodyArr=finalBody,
        ~confirmParam=confirmParams,
        ~handleUserError=false,
        ~manualRetry=isManualRetryEnabled,
      )
    }
  }

  let handleClickToPay = (~rawCardData, ~confirmParams) => {
    let cardNumber = rawCardData->getString("cardNumber", "")
    let month = rawCardData->getString("month", "")
    let year = rawCardData->getString("year", "")
    let cvcNumber = rawCardData->getString("cvcNumber", "")
    let {clickToPayProvider} = clickToPayConfig
    ClickToPayHelpers.handleOpenClickToPayWindow()

    switch clickToPayProvider {
    | MASTERCARD =>
      try {
        (
          async () => {
            let encryptedResult = await ClickToPayHelpers.encryptCardForClickToPay(
              ~cardNumber=cardNumber->CardValidations.clearSpaces,
              ~expiryMonth=month,
              ~expiryYear=year->CardUtils.formatExpiryToTwoDigit,
              ~cvcNumber,
              ~logger=loggerState,
            )
            switch encryptedResult {
            | Ok(encryptedCard) =>
              let response = await ClickToPayHelpers.handleProceedToPay(
                ~encryptedCard,
                ~isCheckoutWithNewCard=true,
                ~isUnrecognizedUser=ctpCards->Array.length == 0,
                ~email=email.value,
                ~phoneNumber=phoneNumber.value,
                ~countryCode=phoneNumber.countryCode
                ->Option.getOr("")
                ->String.replace("+", ""),
                ~rememberMe=isClickToPayRememberMe,
                ~logger=loggerState,
                ~clickToPayProvider,
                ~clickToPayToken=clickToPayConfig.clickToPayToken,
              )
              let responseDict = response.payload->getDictFromJson
              let headers = responseDict->getDictFromDict("headers")
              let checkoutResponseData = responseDict->getDictFromDict("checkoutResponseData")
              confirmBody(
                PaymentBody.mastercardClickToPayBody(
                  ~merchantTransactionId=headers->getString("merchant-transaction-id", ""),
                  ~correlationId=checkoutResponseData->getString("srcCorrelationId", ""),
                  ~xSrcFlowId=headers->getString("x-src-cx-flow-id", ""),
                ),
                ~confirmParams,
                ~includeAcceptance=false,
              )
            | Error(err) =>
              loggerState.setLogError(
                ~value={
                  "message": `Error during checkout - ${err->formatException->JSON.stringify}`,
                  "scheme": clickToPayProvider,
                }
                ->JSON.stringifyAny
                ->Option.getOr(""),
                ~eventName=CLICK_TO_PAY_FLOW,
              )
            }
          }
        )()->ignore
      } catch {
      | err =>
        loggerState.setLogError(
          ~value={
            "message": `Error during checkout - ${err->formatException->JSON.stringify}`,
            "scheme": clickToPayProvider,
          }
          ->JSON.stringifyAny
          ->Option.getOr(""),
          ~eventName=CLICK_TO_PAY_FLOW,
        )
      }
    | VISA =>
      let payload = [
        convertKeyValueToJsonStringPair(
          "primaryAccountNumber",
          cardNumber->String.replaceAll(" ", ""),
        ),
        convertKeyValueToJsonStringPair("panExpirationMonth", month),
        convertKeyValueToJsonStringPair("panExpirationYear", year),
        convertKeyValueToJsonStringPair("cardSecurityCode", cvcNumber->String.trim),
        convertKeyValueToJsonStringPair("cardHolderName", fullName.value->String.trim),
      ]
      let cardPayload = Dict.make()
      payload->Array.forEach(((key, value)) => Dict.set(cardPayload, key, value))

      (
        async () => {
          let encryptedCard = await cardPayload
          ->JSON.Encode.object
          ->ClickToPayCardEncryption.getEncryptedCard
          try {
            let response = await ClickToPayHelpers.handleProceedToPay(
              ~visaEncryptedCard=encryptedCard,
              ~isCheckoutWithNewCard=true,
              ~isUnrecognizedUser=ctpCards->Array.length == 0,
              ~email=email.value,
              ~phoneNumber=phoneNumber.value,
              ~countryCode=phoneNumber.countryCode
              ->Option.getOr("")
              ->String.replace("+", ""),
              ~rememberMe=isClickToPayRememberMe,
              ~logger=loggerState,
              ~clickToPayProvider,
              ~clickToPayToken=clickToPayConfig.clickToPayToken,
              ~orderId=clientSecret->Option.getOr(""),
              ~fullName=fullName.value,
            )
            let responseDict = response.payload->getDictFromJson
            confirmBody(
              PaymentBody.visaClickToPayBody(
                ~email=clickToPayConfig.email,
                ~encryptedPayload=responseDict->getString("checkoutResponse", ""),
              ),
              ~confirmParams,
              ~includeAcceptance=false,
            )
          } catch {
          | err =>
            loggerState.setLogError(
              ~value={
                "message": `Error during checkout - ${err->formatException->JSON.stringify}`,
                "scheme": clickToPayProvider,
              }
              ->JSON.stringifyAny
              ->Option.getOr(""),
              ~eventName=CLICK_TO_PAY_FLOW,
            )
          }
        }
      )()->ignore
    | NONE => ()
    }
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    if !isSavedCardFlow && isActive {
      let json = ev.data->safeParse
      let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
      if confirm.doSubmit && !hasCardFieldStatus {
        // The public Payment Element can become ready before the nested collector has
        // installed its submit listener. Settle the merchant promise instead of posting a
        // message that could be dropped during that startup window.
        postFailedSubmitResponse(
          ~errortype="validation_error",
          ~message=localeString.enterFieldsText,
        )
      } else if confirm.doSubmit {
        let isNicknameValid = nickname.value === "" || nickname.isValid->Option.getOr(false)
        let outerValid =
          areRequiredFieldsValid &&
          isNicknameValid &&
          isInstallmentValid &&
          cardEligibilityError->Option.isNone &&
          !(paymentMethodListValue.should_block_confirm && isEligibilityPending)
        let innerMessage = json->getDictFromJson
        innerMessage->Dict.set("isOuterValid", outerValid->JSON.Encode.bool)

        if outerValid {
          let handle = (tokenEvent: Types.event) => {
            let dict = tokenEvent.data->Identity.anyTypeToJson->getDictFromJson
            let isInnerCardMessage =
              iframeRef.current
              ->Nullable.toOption
              ->Option.map(innerIframe =>
                tokenEvent.source === innerIframe->Window.contentWindow &&
                  tokenEvent.origin === innerIframeOrigin
              )
              ->Option.getOr(false)
            if !isInnerCardMessage {
              ()
            } else if dict->Dict.get("rawCardEvent")->Option.isSome && isRawMode {
              let rawCardData = dict->getJsonObjectFromDict("rawCardData")->getDictFromJson
              let cardNumber = rawCardData->getString("cardNumber", "")
              let month = rawCardData->getString("month", "")
              let year = rawCardData->getString("year", "")
              let cvcNumber = rawCardData->getString("cvcNumber", "")
              let rawBrand = rawCardData->getString("cardBrand", "")
              let cardNetwork = [
                ("card_network", rawBrand !== "" ? rawBrand->JSON.Encode.string : JSON.Encode.null),
              ]
              let rawClickToPayBrand =
                rawBrand !== "" &&
                  clickToPayConfig.availableCardBrands->Array.includes(rawBrand->String.toLowerCase)
                  ? rawBrand
                  : ""
              let isClickToPay =
                (ctpCards->Array.length > 0 && rawClickToPayBrand !== "") ||
                  isSaveDetailsWithClickToPay
              if isClickToPay && !isBancontact && !isPMMFlow {
                handleClickToPay(~rawCardData, ~confirmParams=confirm.confirmParams)
              } else if isPMMFlow {
                confirmBody(
                  PaymentManagementBody.saveCardBody(
                    ~cardNumber,
                    ~month,
                    ~year,
                    ~cardHolderName=None,
                    ~cvcNumber,
                    ~cardBrand=cardNetwork,
                    ~nickname=nickname.value,
                  ),
                  ~confirmParams=confirm.confirmParams,
                  ~includeInstallments=false,
                  ~save=true,
                )
              } else if isBancontact {
                confirmBody(
                  PaymentBody.bancontactBody(),
                  ~confirmParams=confirm.confirmParams,
                  ~includeAcceptance=false,
                )
              } else {
                confirmBody(
                  PaymentBody.cardPaymentBody(
                    ~cardNumber,
                    ~month,
                    ~year,
                    ~cardHolderName=None,
                    ~cvcNumber,
                    ~cardBrand=cardNetwork,
                    ~nickname=nickname.value,
                  ),
                  ~confirmParams=confirm.confirmParams,
                )
              }
            } else if dict->Dict.get("cardTokenEvent")->Option.isSome {
              let vaultResponse = dict->getJsonObjectFromDict("vaultResponse")
              let {
                token,
                last4Digits,
                binNumber,
                expiryMonth,
                expiryYear,
              } = VaultHelpers.decodeVaultTokenData(vaultResponse)
              if token !== "" {
                let vaultBody = GlobalVars.isPciCompliant
                  ? PaymentBody.vaultCardBody(~token)
                  : PaymentBody.vaultExternalCardBody(
                      ~token,
                      ~last4Digits,
                      ~binNumber,
                      ~expiryMonth,
                      ~expiryYear,
                    )
                confirmBody(vaultBody, ~confirmParams=confirm.confirmParams)
              } else {
                Console.error("ParentCardComponent: payment token not found in vaultResponse")
              }
            } else if dict->Dict.get("vgsTokenEvent")->Option.isSome {
              let vgsCardData = dict->getJsonObjectFromDict("vgsCardData")->getDictFromJson
              let cardNumber = vgsCardData->getString("cardNumber", "")
              confirmBody(
                PaymentBody.vgsVaultCardBody(
                  ~cardNumber,
                  ~month=vgsCardData->getString("month", ""),
                  ~year=vgsCardData->getString("year", ""),
                  ~cvcNumber=vgsCardData->getString("cvcNumber", ""),
                  ~last4Digits=cardNumber->CardUtils.getCardLast4,
                  ~binNumber=cardNumber->CardUtils.getCardBin,
                ),
                ~confirmParams=confirm.confirmParams,
              )
            } else if dict->Dict.get("cardTokenFail")->Option.isSome {
              postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
            }
            if isInnerCardMessage && dict->Dict.get("submitSuccessful")->Option.isSome {
              messageParentWindow(dict->Dict.toArray)
            }
            if (
              isInnerCardMessage &&
              (dict->Dict.get("rawCardEvent")->Option.isSome ||
              dict->Dict.get("cardTokenEvent")->Option.isSome ||
              dict->Dict.get("vgsTokenEvent")->Option.isSome ||
              dict->Dict.get("cardTokenFail")->Option.isSome ||
              dict->Dict.get("submitSuccessful")->Option.isSome)
            ) {
              EventListenerManager.removeSmartEventListener(
                "message",
                tokenResponseListenerActivity,
              )
            }
          }
          EventListenerManager.addSmartEventListener(
            "message",
            handle,
            tokenResponseListenerActivity,
          )
        }

        iframeRef.current->Window.iframePostMessage(innerMessage, ~targetOrigin=innerIframeOrigin)
        if !outerValid {
          let setUserError = message =>
            postFailedSubmitResponse(~errortype="validation_error", ~message)
          if !areRequiredFieldsValid || !isNicknameValid {
            setUserError(localeString.enterValidDetailsText)
          } else if !isInstallmentValid {
            setUserError(localeString.installmentSelectPlanError)
          } else if isEligibilityPending && paymentMethodListValue.should_block_confirm {
            setUserError(localeString.paymentDetailsBeingCheckedText)
          } else if cardEligibilityError->Option.isSome {
            setUserError(
              EligibilityHelpers.getCardEligibilityErrorText(~cardEligibilityError, ~localeString),
            )
          } else {
            setUserError(localeString.enterValidDetailsText)
          }
        }
      }
    }
  }, (
    iframeRef,
    isActive,
    areRequiredFieldsValid,
    isCustomerAcceptanceRequired,
    selectedInstallmentPlan,
    showInstallments,
    nickname,
    requiredFieldsBody,
    isManualRetryEnabled,
    localeString,
    intent,
    saveCard,
    isSavedCardFlow,
    hasCardFieldStatus,
    isRawMode,
    isPMMFlow,
    isBancontact,
    cardEligibilityError,
    selectedOfferQuoteIds,
    isEligibilityPending,
    paymentMethodListValue.should_block_confirm,
    clickToPayCardBrand,
    isSaveDetailsWithClickToPay,
    isClickToPayRememberMe,
    clickToPayConfig,
    ctpCards,
    email,
    phoneNumber,
    fullName,
    clientSecret,
  ))
  useSubmitPaymentDataFromParent(submitCallback)

  let accordionMarginClass = layoutClass.\"type" === Accordion ? "mt-4" : ""
  let showNickname = (!hideCardNicknameField && isCustomerAcceptanceRequired) || isPMMFlow

  isSavedCardFlow
    ? <div className="relative w-full" style={minHeight: SavedCardCvcStyles.reservedBoxHeight}>
        <div
          id=containerId
          className={`relative ${isCvcReady ? "opacity-100" : "opacity-0 pointer-events-none"}`}
        />
        <RenderIf condition={!isCvcReady}>
          <SavedCardCvcFieldSkeleton />
        </RenderIf>
      </div>
    : <div
        className={`ParentCardComponent flex flex-col w-full ${accordionMarginClass} ${isRawMode
            ? "animate-slowShow"
            : ""}`}
        style={gridGap: themeObj.spacingGridColumn}
      >
        <div className="relative w-full">
          <div
            id=containerId
            style={position: "relative", visibility: isCardFormReady ? "visible" : "hidden"}
          />
          <RenderIf condition={!isCardFormReady && !isBancontact}>
            <PaymentElementShimmer />
          </RenderIf>
        </div>
        <RenderIf
          condition={hasCardFieldStatus && (showPaymentMethodsScreen || isBancontact || !isRawMode)}
        >
          {<>
            <CardBusinessFields
              paymentMethod
              paymentMethodType
              setRequiredFieldsBody
              isBancontact
              isSaveDetailsWithClickToPay
              showSaveCardCheckbox={conditionsForShowingSaveCardCheckbox &&
              !alwaysSendCustomerAcceptance}
              isSaveCardsChecked
              setIsSaveCardsChecked
              showNickname
              setSelectedInstallmentPlan
              showInstallments
              setShowInstallments
              installmentsError
              setInstallmentsError
              eligibilityOfferDetails
              isEligibilityPending
            />
            <RenderIf condition=isRawMode>
              <EligibilityNotice
                eligibilitySurchargeDetails eligibilityError=None isEligibilityPending
              />
            </RenderIf>
            <RenderIf condition={cardBrand !== "" || isRawMode}>
              <Surcharge
                paymentMethod paymentMethodType cardBrand={cardBrand->CardUtils.getCardType}
              />
            </RenderIf>
            <RenderIf condition={!isBancontact}>
              <Terms paymentMethod paymentMethodType />
            </RenderIf>
            <RenderIf condition={clickToPayCardBrand !== ""}>
              <div className="space-y-3 mt-2">
                <ClickToPayHelpers.SrcMark cardBrands=clickToPayCardBrand height="32" />
                <ClickToPayDetails
                  isSaveDetailsWithClickToPay
                  setIsSaveDetailsWithClickToPay
                  clickToPayCardBrand
                  isClickToPayRememberMe
                  setIsClickToPayRememberMe
                />
              </div>
            </RenderIf>
          </>}
        </RenderIf>
      </div>
}
