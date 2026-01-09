type target = {checked: bool}
type event = {target: target}

@react.component
let make = (
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~isBancontact=false,
  ~isVault=None,
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
  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let (clickToPayCardBrand, setClickToPayCardBrand) = React.useState(_ => "")
  let (isClickToPayRememberMe, setIsClickToPayRememberMe) = React.useState(_ => false)
  let ctpCards = clickToPayConfig.clickToPayCards->Option.getOr([])
  let nickname = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCardNickName)
  let {clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let paymentTypeFromUrl = componentName->CardThemeType.getPaymentMode
  let giftCardInfo = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.giftCardInfoAtom)
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
  } = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let saveCard = PaymentHelpersV2.useSaveCard(Some(loggerState), Card)
  let (showPaymentMethodsScreen, setShowPaymentMethodsScreen) = Recoil.useRecoilState(
    RecoilAtoms.showPaymentMethodsScreen,
  )
  let setComplete = Recoil.useSetRecoilState(RecoilAtoms.fieldsComplete)
  let blockedBinsList = Recoil.useRecoilValueFromAtom(RecoilAtoms.blockedBins)
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

  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)

  let complete = isAllValid(
    isCardValid,
    isCardSupported,
    isCVCValid,
    isExpiryValid,
    true,
    "payment",
  )
  let empty = cardNumber == "" || cardExpiry == "" || cvcNumber == ""
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

  let isCustomerAcceptanceRequired = useIsCustomerAcceptanceRequired(
    ~displaySavedPaymentMethodsCheckbox,
    ~isSaveCardsChecked,
    ~isGuestCustomer,
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->safeParse
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let (month, year) = CardUtils.getExpiryDates(cardExpiry)

    let onSessionBody = [("customer_acceptance", PaymentBody.customerAcceptanceBody)]
    let cardNetwork = [
      ("card_network", cardBrand != "" ? cardBrand->JSON.Encode.string : JSON.Encode.null),
    ]

    let defaultCardBody = switch GlobalVars.sdkVersion {
    | V1 =>
      PaymentBody.cardPaymentBody(
        ~cardNumber,
        ~month,
        ~year,
        ~cardHolderName=None,
        ~cvcNumber,
        ~cardBrand=cardNetwork,
        ~nickname=nickname.value,
      )
    | V2 =>
      PaymentManagementBody.saveCardBody(
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
    let cardBody = if isCustomerAcceptanceRequired {
      defaultCardBody->Array.concat(onSessionBody)
    } else {
      defaultCardBody
    }

    let isRecognizedClickToPayPayment = ctpCards->Array.length > 0 && clickToPayCardBrand !== ""

    let isUnrecognizedClickToPayPayment = isSaveDetailsWithClickToPay

    if confirm.doSubmit {
      let isCardDetailsValid =
        isCVCValid->Option.getOr(false) &&
        isCardValid->Option.getOr(false) &&
        isCardSupported->Option.getOr(false) &&
        isExpiryValid->Option.getOr(false)

      let isNicknameValid = nickname.value === "" || nickname.isValid->Option.getOr(false)

      // Check if card is blocked
      let isCardBlocked = CardUtils.checkIfCardBinIsBlocked(
        cardNumber->CardValidations.clearSpaces,
        blockedBinsList,
      )

      let validFormat =
        (isBancontact || isCardDetailsValid) &&
        isNicknameValid &&
        areRequiredFieldsValid &&
        !isCardBlocked

      if validFormat && (showPaymentMethodsScreen || isBancontact) {
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
                        ~bodyArr=clickToPayBody->mergeAndFlattenToTuples(requiredFieldsBody),
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
                      ~bodyArr=clickToPayBody,
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
          let hasGiftCards = giftCardInfo.appliedGiftCards->Array.length > 0
          let modifiedCardBody = if hasGiftCards {
            let splitPaymentBody =
              PaymentBodyV2.splitPaymentBody(~appliedGiftCards=giftCardInfo.appliedGiftCards)
              ->getJsonFromArrayOfJson
              ->getDictFromJson

            cardBody->mergeAndFlattenToTuples(splitPaymentBody)
          } else {
            cardBody
          }

          intent(
            ~bodyArr={
              (isBancontact ? banContactBody : modifiedCardBody)->mergeAndFlattenToTuples(
                requiredFieldsBody,
              )
            },
            ~confirmParam=confirm.confirmParams,
            ~handleUserError=false,
            ~manualRetry=isManualRetryEnabled,
          )
        }
      } else {
        if cardNumber === "" {
          setCardError(_ => localeString.cardNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        } else if isCardBlocked {
          setCardError(_ => localeString.blockedCardText)
          setUserError(localeString.blockedCardText)
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
        if !validFormat {
          setUserError(localeString.enterValidDetailsText)
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
    blockedBinsList,
    giftCardInfo,
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
  let vaultClass = switch isVault {
  | Some(_) => "mb-[4px] mr-[4px] ml-[4px] mt-[4px]"
  | None => ""
  }

  <div className="animate-slowShow">
    <RenderIf condition={showPaymentMethodsScreen || isBancontact}>
      <div className={`flex flex-col ${vaultClass}`} style={gridGap: themeObj.spacingGridColumn}>
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
          <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
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
        </div>
      </div>
    </RenderIf>
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
  </div>
}
