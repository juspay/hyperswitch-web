type target = {checked: bool}
type event = {target: target}

@react.component
let make = (
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~isBancontact=false,
  // When true this component is rendered inside the Cards SDK iframe.
  // In that context:
  //   • submit / intent logic is handled by PaymentMethodsSDK (outside the iframe)
  //     so the submitCallback registered here is a deliberate no-op.
  //   • business-logic UI (DynamicFields, save-card checkbox, nickname,
  //     installments, ClickToPay, Surcharge) is hidden — those features rely
  //     on Recoil atoms that are not populated inside the iframe.
  //   • useHandlePostMessages still runs so complete / empty state is reported
  //     to the parent window (PaymentMethodsSDK can forward it if needed).
  ~isInsideCardSDK=false,
) => {
  open PaymentType
  open Utils
  open UtilityHooks
  open PaymentTypeContext
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {innerLayout} = config.appearance
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let email = Recoil.useRecoilValueFromAtom(RecoilAtoms.userEmailAddress)
  let fullName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userFullName)
  let phoneNumber = Recoil.useRecoilValueFromAtom(RecoilAtoms.userPhoneNumber)
  let (isSaveDetailsWithClickToPay, setIsSaveDetailsWithClickToPay) = React.useState(_ => false)
  let (selectedInstallmentPlan, setSelectedInstallmentPlan) = React.useState(_ => None)
  let (showInstallments, setShowInstallments) = React.useState(_ => false)
  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let (clickToPayCardBrand, setClickToPayCardBrand) = React.useState(_ => "")
  let (isClickToPayRememberMe, setIsClickToPayRememberMe) = React.useState(_ => false)
  let ctpCards = clickToPayConfig.clickToPayCards->Option.getOr([])
  let nickname = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCardNickName)
  let {clientSecret, sdkAuthorization} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let vaultCredentials = Recoil.useRecoilValueFromAtom(RecoilAtoms.vaultCredentials)
  let customPodUri = Recoil.useRecoilValueFromAtom(RecoilAtoms.customPodUri)
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let paymentTypeFromUrl = componentName->CardThemeType.getPaymentMode
  let isPMMFlow = switch paymentTypeFromUrl {
  | PaymentMethodsManagement => true
  | _ => false
  }
  let paymentType = usePaymentType()
  let {
    isCardValid,
    setIsCardValid,
    isCardSupported,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    icon,
    cardError,
    setCardError,
    maxCardLength,
    cardBrand,
    cardEligibilityError,
    eligibilitySurchargeDetails,
    isEligibilityPending,
  } = cardProps

  let {
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    expiryError,
    setExpiryError,
  } = expiryProps

  let {
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    cvcError,
    setCvcError,
  } = cvcProps
  let {
    displaySavedPaymentMethodsCheckbox,
    savedPaymentMethodsCheckboxCheckedByDefault,
    alwaysSendCustomerAcceptance,
    layout,
  } = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let layoutClass = CardUtils.getLayoutClass(layout)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let saveCard = PaymentHelpersV2.useSaveCard(Some(loggerState), Card)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Recoil.useRecoilState(
    RecoilAtoms.showPaymentMethodsScreen,
  )
  let setComplete = Recoil.useSetRecoilState(RecoilAtoms.fieldsComplete)
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ =>
    savedPaymentMethodsCheckboxCheckedByDefault
  )

  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
  }
  let {clickToPayProvider} = clickToPayConfig
  React.useEffect(() => {
    if (
      cardBrand === "" ||
        clickToPayConfig.availableCardBrands->Array.includes(cardBrand->String.toLowerCase)->not
    ) {
      setClickToPayCardBrand(_ => "")
    } else if cardBrand !== clickToPayCardBrand {
      setClickToPayCardBrand(_ => cardBrand)
    }
    None
  }, (cardBrand, clickToPayConfig.availableCardBrands))

  let combinedCardNetworks = React.useMemo1(() => {
    let cardPaymentMethod =
      paymentMethodListValue.payment_methods
      ->Array.find(ele => ele.payment_method === "card")
      ->Option.getOr(PaymentMethodsRecord.defaultMethods)

    let cardNetworks = cardPaymentMethod.payment_method_types->Array.map(ele => ele.card_networks)

    let cardNetworkNames =
      cardNetworks->Array.map(ele =>
        ele->Array.map(val => val.card_network->CardUtils.getCardStringFromType->String.toLowerCase)
      )

    cardNetworkNames
    ->Array.reduce([], (acc, ele) => acc->Array.concat(ele))
    ->Utils.getUniqueArray
  }, [paymentMethodListValue])
  let isCardBrandValid = combinedCardNetworks->Array.includes(cardBrand->String.toLowerCase)

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())
  let (installmentsError, setInstallmentsError) = React.useState(_ => "")
  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)

  let isInstallmentValid = !showInstallments || selectedInstallmentPlan->Option.isSome

  let complete =
    isAllValid(isCardValid, isCardSupported, isCVCValid, isExpiryValid, true, "payment") &&
    isInstallmentValid

  let empty = cardNumber == "" || cardExpiry == "" || cvcNumber == ""
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  SubscriptionEventHooks.useEmitFormStatus(~empty, ~complete=complete && areRequiredFieldsValid)
  SubscriptionEventHooks.useEmitSurchargeInfo(~surchargeDetails=eligibilitySurchargeDetails)
  React.useEffect(() => {
    let cardInfo = PaymentEventData.buildCardInfo(
      ~cardNumber,
      ~expiry=cardExpiry,
      ~cvc=cvcNumber,
      ~brand=cardBrand,
    )
    emitter.emitCardInfo(~cardInfo)
    None
  }, (cardNumber, cardExpiry, cvcNumber, cardBrand))
  React.useEffect(() => {
    setComplete(_ => complete)
    setShowPaymentMethodsScreen(_ => true)
    None
  }, [complete])

  useHandlePostMessages(~complete=complete && areRequiredFieldsValid, ~empty, ~paymentType="card")

  let isGuestCustomer = useIsGuestCustomer()
  let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
  let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
    ~cvcNumber,
    ~isCVCValid,
    ~isCvcValidValue,
  )

  let isCustomerAcceptanceFromHook = useIsCustomerAcceptanceRequired(
    ~displaySavedPaymentMethodsCheckbox,
    ~isSaveCardsChecked,
    ~isGuestCustomer,
  )

  // ── When inside the paymentMethodsSDK iframe: report live card brand to parent
  // so ParentCardComponent can render the Surcharge widget correctly.
  React.useEffect(() => {
    if isInsideCardSDK {
      messageParentWindow([("cardBrandUpdate", cardBrand->JSON.Encode.string)])
    }
    None
  }, (cardBrand, isInsideCardSDK))

  let isCustomerAcceptanceRequired =
    (!isGuestCustomer && alwaysSendCustomerAcceptance) || isCustomerAcceptanceFromHook

  let handleSaveCard = async () => {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
    ])
    let (pmSessionId, sdkAuthorization) = switch vaultCredentials {
    | HyperswitchVault(creds) => (creds.pmSessionId, creds.sdkAuthorization)
    | _ => ("", "")
    }
    let (month, year) = CardUtils.getExpiryDates(cardExpiry)
    try {
      let res = await PaymentHelpersV2.savePaymentMethod(
        ~bodyArr=PaymentBody.cardTokenizationBody(~cardNumber, ~cvcNumber, ~month, ~year),
        ~pmSessionId,
        ~sdkAuthorization,
        ~logger=loggerState,
      )

      // Forward the full vault API response to ParentCardComponent (or merchant).
      // Token extraction is intentionally left to the receiver so that future
      // merchant-direct flows (PaymentMethodsSDK exposed without ParentCardComponent)
      // can handle the response according to their own logic.
      messageParentWindow([("cardTokenEvent", true->JSON.Encode.bool), ("vaultResponse", res)])
    } catch {
    | err =>
      let exceptionMessage = err->formatException->JSON.stringify
      messageParentWindow([("cardTokenFail", true->JSON.Encode.bool)])
      Console.error2("Unable to Save Card ", exceptionMessage)
    }
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let isOuterValid = json->getDictFromJson->getBool("isOuterValid", true)
    if confirm.doSubmit {
      // ── Shared: card field validation ─────────────────────────────────────
      let isCardDetailsValid =
        isCVCValid->Option.getOr(false) &&
        isCardValid->Option.getOr(false) &&
        isCardSupported->Option.getOr(false) &&
        isExpiryValid->Option.getOr(false)

      // ── Shared: card field error reporting ────────────────────────────────
      // Called by both the inner-SDK path and the standard path when card
      // fields are incomplete or invalid.
      let reportCardFieldErrors = () => {
        if cardNumber === "" {
          setCardError(_ => localeString.cardNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        } else if isCardSupported->Option.getOr(true)->not {
          if cardBrand == "" {
            setCardError(_ => localeString.enterValidCardNumberErrorText)
            setUserError(localeString.enterValidDetailsText)
          } else {
            setCardError(_ => localeString.cardBrandConfiguredErrorText(cardBrand))
            setUserError(localeString.cardBrandConfiguredErrorText(cardBrand))
          }
        }
        if cardExpiry === "" {
          setExpiryError(_ => localeString.cardExpiryDateEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if cvcNumber === "" {
          setCvcError(_ => localeString.cvcNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if !isCardDetailsValid {
          setUserError(localeString.enterValidDetailsText)
        }
      }

      if isInsideCardSDK {
        // ── Inside Cards SDK iframe ───────────────────────────────────────────
        // Validate card fields. If valid, tokenize and send cardTokenEvent +
        // vaultResponse back to ParentCardComponent, which calls intent.
        if isCardDetailsValid && isOuterValid {
          handleSaveCard()->ignore
        } else {
          reportCardFieldErrors()
        }
      } else {
        // ── Standard (non-SDK) flow ───────────────────────────────────────────
        let (month, year) = CardUtils.getExpiryDates(cardExpiry)
        let onSessionBody = [("customer_acceptance", PaymentBody.customerAcceptanceBody)]
        let cardNetwork = [
          ("card_network", cardBrand != "" ? cardBrand->JSON.Encode.string : JSON.Encode.null),
        ]

        let defaultCardBody = switch paymentType {
        | PaymentMethodsManagement =>
          PaymentManagementBody.saveCardBody(
            ~cardNumber,
            ~month,
            ~year,
            ~cardHolderName=None,
            ~cvcNumber,
            ~cardBrand=cardNetwork,
            ~nickname=nickname.value,
          )
        | _ =>
          PaymentBody.cardPaymentBody(
            ~cardNumber,
            ~month,
            ~year,
            ~cardHolderName=None,
            ~cvcNumber,
            ~cardBrand=cardNetwork,
            ~nickname=nickname.value,
          )
        }

        let banContactBody = PaymentBody.bancontactBody()
        let cardBody = isCustomerAcceptanceRequired
          ? defaultCardBody->Array.concat(onSessionBody)
          : defaultCardBody

        let isNicknameValid = nickname.value === "" || nickname.isValid->Option.getOr(false)
        let isRecognizedClickToPayPayment = ctpCards->Array.length > 0 && clickToPayCardBrand !== ""
        let isUnrecognizedClickToPayPayment = isSaveDetailsWithClickToPay

        let validFormat =
          (isBancontact || isCardDetailsValid) &&
          isNicknameValid &&
          areRequiredFieldsValid &&
          cardEligibilityError->Option.isNone &&
          isInstallmentValid &&
          !isEligibilityPending

        if validFormat && (showPaymentMethodsScreen || isBancontact) {
          let installmentBody = selectedInstallmentPlan->PaymentBody.installmentBody

          if isRecognizedClickToPayPayment || isUnrecognizedClickToPayPayment {
            ClickToPayHelpers.handleOpenClickToPayWindow()

            switch clickToPayProvider {
            | MASTERCARD =>
              try {
                (
                  async () => {
                    let res = await ClickToPayHelpers.encryptCardForClickToPay(
                      ~cardNumber=cardNumber->CardValidations.clearSpaces,
                      ~expiryMonth=month,
                      ~expiryYear=year->CardUtils.formatExpiryToTwoDigit,
                      ~cvcNumber,
                      ~logger=loggerState,
                    )

                    switch res {
                    | Ok(res) => {
                        let resp = await ClickToPayHelpers.handleProceedToPay(
                          ~encryptedCard=res,
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
                        let dict = resp.payload->Utils.getDictFromJson
                        let headers = dict->Utils.getDictFromDict("headers")
                        let merchantTransactionId =
                          headers->Utils.getString("merchant-transaction-id", "")
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
                          ~bodyArr=clickToPayBody
                          ->Array.concat(installmentBody)
                          ->mergeAndFlattenToTuples(requiredFieldsBody),
                          ~confirmParam=confirm.confirmParams,
                          ~handleUserError=false,
                          ~manualRetry=isManualRetryEnabled,
                        )
                      }
                    | Error(err) =>
                      loggerState.setLogError(
                        ~value={
                          "message": `Error during checkout - ${err
                            ->Utils.formatException
                            ->JSON.stringify}`,
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
                    "message": `Error during checkout - ${err
                      ->Utils.formatException
                      ->JSON.stringify}`,
                    "scheme": clickToPayProvider,
                  }
                  ->JSON.stringifyAny
                  ->Option.getOr(""),
                  ~eventName=CLICK_TO_PAY_FLOW,
                )
              }

            | VISA => {
                let expiry = cardExpiry->String.split("/")->Array.map(String.trim)
                let month = expiry->Array.at(0)->Option.getOr("")
                let year = "20" ++ expiry->Array.at(1)->Option.getOr("")
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

                let dict = Dict.make()
                payload->Array.forEach(((key, value)) => Dict.set(dict, key, value))
                let cardPayloadJson = JSON.Encode.object(dict)

                (
                  async () => {
                    let encryptedCard =
                      await cardPayloadJson->ClickToPayCardEncryption.getEncryptedCard

                    try {
                      let res = await ClickToPayHelpers.handleProceedToPay(
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
                      let dict = res.payload->Utils.getDictFromJson
                      let clickToPayBody = PaymentBody.visaClickToPayBody(
                        ~email=clickToPayConfig.email,
                        ~encryptedPayload=dict->Utils.getString("checkoutResponse", ""),
                      )
                      intent(
                        ~bodyArr=clickToPayBody
                        ->Array.concat(installmentBody)
                        ->mergeAndFlattenToTuples(requiredFieldsBody),
                        ~confirmParam=confirm.confirmParams,
                        ~handleUserError=false,
                        ~manualRetry=isManualRetryEnabled,
                      )
                    } catch {
                    | err =>
                      loggerState.setLogError(
                        ~value={
                          "message": `Error during checkout - ${err
                            ->Utils.formatException
                            ->JSON.stringify}`,
                          "scheme": clickToPayProvider,
                        }
                        ->JSON.stringifyAny
                        ->Option.getOr(""),
                        ~eventName=CLICK_TO_PAY_FLOW,
                      )
                    }
                  }
                )()->ignore
              }
            | NONE => ()
            }
          } else if isPMMFlow {
            saveCard(
              ~bodyArr=cardBody->mergeAndFlattenToTuples(requiredFieldsBody),
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=true,
            )
          } else {
            intent(
              ~bodyArr={
                (isBancontact ? banContactBody : cardBody)
                ->Array.concat(installmentBody)
                ->mergeAndFlattenToTuples(requiredFieldsBody)
              },
              ~confirmParam=confirm.confirmParams,
              ~handleUserError=false,
              ~manualRetry=isManualRetryEnabled,
            )
          }
        } else {
          // Card field errors (also checked via shared reportCardFieldErrors above
          // but the standard path has additional eligibility / installment checks).
          if cardNumber === "" {
            setCardError(_ => localeString.cardNumberEmptyText)
            setUserError(localeString.enterFieldsText)
          } else if cardEligibilityError->Option.isSome {
            let msg = EligibilityHelpers.getCardEligibilityErrorText(
              ~cardEligibilityError,
              ~localeString,
            )
            setCardError(_ => msg)
            setUserError(msg)
          } else if isCardSupported->Option.getOr(true)->not {
            if cardBrand == "" {
              setCardError(_ => localeString.enterValidCardNumberErrorText)
              setUserError(localeString.enterValidDetailsText)
            } else {
              setCardError(_ => localeString.cardBrandConfiguredErrorText(cardBrand))
              setUserError(localeString.cardBrandConfiguredErrorText(cardBrand))
            }
          }
          if cardExpiry === "" {
            setExpiryError(_ => localeString.cardExpiryDateEmptyText)
            setUserError(localeString.enterFieldsText)
          }
          if !isBancontact && cvcNumber === "" {
            setCvcError(_ => localeString.cvcNumberEmptyText)
            setUserError(localeString.enterFieldsText)
          }
          if !isInstallmentValid {
            setUserError(localeString.installmentSelectPlanError)
            setInstallmentsError(_ => localeString.installmentSelectPlanError)
          }
          if isEligibilityPending && paymentMethodListValue.should_block_confirm {
            setUserError(localeString.paymentDetailsBeingCheckedText)
          } else if !validFormat {
            setUserError(localeString.enterValidDetailsText)
          }
        }
      }
    }
  }, (
    areRequiredFieldsValid,
    requiredFieldsBody,
    empty,
    complete,
    isCustomerAcceptanceRequired,
    nickname,
    isCardBrandValid,
    isManualRetryEnabled,
    cardProps,
    clickToPayConfig,
    clickToPayCardBrand,
    isClickToPayRememberMe,
    selectedInstallmentPlan,
    showInstallments,
    cardEligibilityError,
    sdkAuthorization,
    isInsideCardSDK,
    customPodUri,
    clientSecret,
    isEligibilityPending,
    eligibilitySurchargeDetails,
  ))
  useSubmitPaymentData(submitCallback)

  let paymentMethod = isBancontact ? "bank_redirect" : "card"
  let paymentMethodType = isBancontact ? "bancontact_card" : "debit"
  let conditionsForShowingSaveCardCheckbox =
    paymentMethodListValue.mandate_payment->Option.isNone &&
    !isGuestCustomer &&
    paymentMethodListValue.payment_type !== SETUP_MANDATE &&
    options.displaySavedPaymentMethodsCheckbox &&
    !isBancontact

  let compressedLayoutStyleForCvcError =
    innerLayout === Compressed && cvcError->String.length > 0 ? "!border-l-0" : ""
  let accordionMarginClass = layoutClass.\"type" === Accordion && !isInsideCardSDK ? "mt-4" : ""
  <div className="animate-slowShow">
    <RenderIf condition={showPaymentMethodsScreen || isBancontact}>
      <div
        className={`flex flex-col  ${accordionMarginClass}`}
        style={gridGap: themeObj.spacingGridColumn}>
        <div className="flex flex-col w-full" style={gridGap: themeObj.spacingGridColumn}>
          <RenderIf condition={innerLayout === Compressed}>
            <div
              style={
                marginBottom: "5px",
                fontSize: themeObj.fontSizeLg,
                opacity: "0.6",
              }>
              {React.string(localeString.cardHeader)}
            </div>
          </RenderIf>
          <RenderIf condition={!isBancontact}>
            <PaymentInputField
              fieldName=localeString.cardNumberLabel
              isValid=isCardValid
              setIsValid=setIsCardValid
              value=cardNumber
              onChange=changeCardNumber
              onBlur=handleCardBlur
              rightIcon={icon}
              errorString=cardError
              type_="tel"
              maxLength=maxCardLength
              inputRef=cardRef
              placeholder="1234 1234 1234 1234"
              className={innerLayout === Compressed && cardError->String.length > 0
                ? "border-b-0"
                : ""}
              name=TestUtils.cardNoInputTestId
              autocomplete="cc-number"
            />
            <div
              className="flex flex-row w-full place-content-between"
              style={
                gridColumnGap: {innerLayout === Spaced ? themeObj.spacingGridRow : ""},
              }>
              <div className={innerLayout === Spaced ? "w-[47%]" : "w-[50%]"}>
                <PaymentInputField
                  fieldName=localeString.validThruText
                  isValid=isExpiryValid
                  setIsValid=setIsExpiryValid
                  value=cardExpiry
                  onChange=changeCardExpiry
                  onBlur=handleExpiryBlur
                  errorString=expiryError
                  type_="tel"
                  maxLength=7
                  inputRef=expiryRef
                  placeholder=localeString.expiryPlaceholder
                  name=TestUtils.expiryInputTestId
                  autocomplete="cc-exp"
                />
              </div>
              <div className={innerLayout === Spaced ? "w-[47%]" : "w-[50%]"}>
                <PaymentInputField
                  fieldName=localeString.cvcTextLabel
                  isValid=isCVCValid
                  setIsValid=setIsCVCValid
                  value=cvcNumber
                  onChange=changeCVCNumber
                  onBlur=handleCVCBlur
                  errorString=cvcError
                  rightIcon={CardUtils.setRightIconForCvc(
                    ~cardComplete,
                    ~cardEmpty,
                    ~cardInvalid,
                    ~color=themeObj.colorIconCardCvcError,
                    ~cvcIcon=layoutClass.cvcIcon,
                  )}
                  type_="tel"
                  className={`tracking-widest w-full ${compressedLayoutStyleForCvcError}`}
                  maxLength=4
                  inputRef=cvcRef
                  placeholder="123"
                  name=TestUtils.cardCVVInputTestId
                  autocomplete="cc-csc"
                />
              </div>
            </div>
            <RenderIf
              condition={innerLayout === Compressed &&
                (cardError->String.length > 0 ||
                cvcError->String.length > 0 ||
                expiryError->String.length > 0)}>
              <div
                className="Error pt-1"
                style={
                  color: themeObj.colorDangerText,
                  fontSize: themeObj.fontSizeSm,
                  alignSelf: "start",
                  textAlign: "left",
                }>
                {React.string("Invalid input")}
              </div>
            </RenderIf>
          </RenderIf>
          // Business-logic UI is hidden inside the Cards SDK iframe (those features
          // rely on Recoil atoms not populated there); shown for the standard flow.
          <RenderIf condition={!isInsideCardSDK}>
            {<>
              <DynamicFields
                paymentMethod
                paymentMethodType
                setRequiredFieldsBody
                cardProps={Some(cardProps)}
                expiryProps={Some(expiryProps)}
                cvcProps={Some(cvcProps)}
                isBancontact
                isSaveDetailsWithClickToPay
              />
              <RenderIf
                condition={conditionsForShowingSaveCardCheckbox && !alwaysSendCustomerAcceptance}>
                <div className="flex items-center justify-start">
                  <SaveDetailsCheckbox
                    isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked
                  />
                </div>
              </RenderIf>
              <RenderIf
                condition={(!options.hideCardNicknameField && isCustomerAcceptanceRequired) ||
                  paymentType == PaymentMethodsManagement}>
                <NicknamePaymentInput />
              </RenderIf>
              <InstallmentOptions
                setSelectedInstallmentPlan
                showInstallments
                setShowInstallments
                paymentMethod
                errorString=installmentsError
                setErrorString=setInstallmentsError
              />
            </>}
          </RenderIf>
          <SurchargeEligibilityNotice
            eligibilitySurchargeDetails
            isEligibilityPending={isEligibilityPending &&
            paymentMethodListValue.should_block_confirm}
          />
        </div>
      </div>
    </RenderIf>
    // Surcharge / Terms / ClickToPay are part of the standard flow only — hidden
    // inside the Cards SDK iframe.
    <RenderIf condition={!isInsideCardSDK}>
      {<>
        <RenderIf condition={showPaymentMethodsScreen || isBancontact}>
          <Surcharge paymentMethod paymentMethodType cardBrand={cardBrand->CardUtils.getCardType} />
        </RenderIf>
        <RenderIf condition={!isBancontact}>
          <Terms
            styles={
              marginTop: themeObj.spacingGridColumn,
            }
            paymentMethod
            paymentMethodType
          />
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
