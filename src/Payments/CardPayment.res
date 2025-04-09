type target = {checked: bool}
type event = {target: target}

@react.component
let make = (
  ~cardProps: CardUtils.cardProps,
  ~expiryProps: CardUtils.expiryProps,
  ~cvcProps: CardUtils.cvcProps,
  ~isBancontact=false,
) => {
  open PaymentType
  open PaymentModeType
  open Utils
  open UtilityHooks
  open Promise
  open PaymentTypeContext
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {innerLayout} = config.appearance
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let email = Recoil.useRecoilValueFromAtom(RecoilAtoms.userEmailAddress)
  let phoneNumber = Recoil.useRecoilValueFromAtom(RecoilAtoms.userPhoneNumber)
  let (isSaveDetailsWithClickToPay, setIsSaveDetailsWithClickToPay) = React.useState(_ => false)
  let clickToPayConfig = Recoil.useRecoilValueFromAtom(RecoilAtoms.clickToPayConfig)
  let (clickToPayCardBrand, setClickToPayCardBrand) = React.useState(_ => "")
  let (clickToPayRememberMe, setClickToPayRememberMe) = React.useState(_ => false)

  let nickname = Recoil.useRecoilValueFromAtom(RecoilAtoms.userCardNickName)
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
  let {displaySavedPaymentMethodsCheckbox} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let saveCard = PaymentHelpersV2.useSaveCard(Some(loggerState), Card)
  let showFields = Recoil.useRecoilValueFromAtom(RecoilAtoms.showCardFieldsAtom)
  let setShowFields = Recoil.useSetRecoilState(RecoilAtoms.showCardFieldsAtom)
  let setComplete = Recoil.useSetRecoilState(RecoilAtoms.fieldsComplete)
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ => false)

  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
  }

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
    setShowFields(_ => true)
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
    let defaultCardBody = if isPMMFlow {
      PaymentManagementBody.saveCardBody(
        ~cardNumber,
        ~month,
        ~year,
        ~cardHolderName=None,
        ~cvcNumber,
        ~cardBrand=cardNetwork,
        ~nickname=nickname.value,
      )
    } else {
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
    let cardBody = if isCustomerAcceptanceRequired {
      defaultCardBody->Array.concat(onSessionBody)
    } else {
      defaultCardBody
    }

    let isRecognizedClickToPayPayment =
      clickToPayConfig.clickToPayCards->Option.getOr([])->Array.length > 0 &&
        clickToPayCardBrand !== ""

    let isUnrecognizedClickToPayPayment = isSaveDetailsWithClickToPay

    if confirm.doSubmit {
      let isCardDetailsValid =
        isCVCValid->Option.getOr(false) &&
        isCardValid->Option.getOr(false) &&
        isCardSupported->Option.getOr(false) &&
        isExpiryValid->Option.getOr(false)

      let isNicknameValid = nickname.value === "" || nickname.isValid->Option.getOr(false)

      let validFormat =
        (isBancontact || isCardDetailsValid) && isNicknameValid && areRequiredFieldsValid

      if validFormat && (showFields || isBancontact) {
        if isRecognizedClickToPayPayment || isUnrecognizedClickToPayPayment {
          ClickToPayHelpers.handleOpenClickToPayWindow()

          ClickToPayHelpers.encryptCardForClickToPay(
            ~cardNumber=cardNumber->CardUtils.clearSpaces,
            ~expiryMonth=month,
            ~expiryYear=year->CardUtils.formatExpiryToTwoDigit,
            ~cvcNumber,
            ~logger=loggerState,
          )
          ->then(res => {
            switch res {
            | Ok(res) =>
              ClickToPayHelpers.handleProceedToPay(
                ~encryptedCard=res,
                ~isCheckoutWithNewCard=true,
                ~isUnrecognizedUser={
                  clickToPayConfig.clickToPayCards->Option.getOr([])->Array.length == 0
                },
                ~email=email.value,
                ~phoneNumber=phoneNumber.value,
                ~countryCode=phoneNumber.countryCode->Option.getOr("")->String.replace("+", ""),
                ~rememberMe=clickToPayRememberMe,
                ~logger=loggerState,
              )
              ->then(
                resp => {
                  let dict = resp.payload->Utils.getDictFromJson
                  let headers = dict->Utils.getDictFromDict("headers")
                  let merchantTransactionId =
                    headers->Utils.getString("merchant-transaction-id", "")
                  let xSrcFlowId = headers->Utils.getString("x-src-cx-flow-id", "")
                  let correlationId =
                    dict
                    ->Utils.getDictFromDict("checkoutResponseData")
                    ->Utils.getString("srcCorrelationId", "")

                  let clickToPayBody = PaymentBody.clickToPayBody(
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
                  resolve()
                },
              )
              ->catch(_ => resolve())
              ->ignore
            | Error(err) =>
              loggerState.setLogError(
                ~value=`Error during checkout - ${err->Utils.formatException->JSON.stringify}`,
                ~eventName=CLICK_TO_PAY_FLOW,
              )
            }
            resolve()
          })
          ->catch(err => {
            loggerState.setLogError(
              ~value=`Error during checkout - ${err->Utils.formatException->JSON.stringify}`,
              ~eventName=CLICK_TO_PAY_FLOW,
            )
            resolve()
          })
          ->ignore
        } else if isPMMFlow {
          saveCard(
            ~bodyArr=cardBody->mergeAndFlattenToTuples(requiredFieldsBody),
            ~confirmParam={
              return_url: options.sdkHandleSavePayment.confirmParams.return_url,
              publishableKey,
            },
            ~handleUserError=true,
          )
        } else {
          intent(
            ~bodyArr={
              (isBancontact ? banContactBody : cardBody)->mergeAndFlattenToTuples(
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
    clickToPayRememberMe,
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

  <div className="animate-slowShow">
    <RenderIf condition={showFields || isBancontact}>
      <div className="flex flex-col" style={gridGap: themeObj.spacingGridColumn}>
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
    <RenderIf condition={showFields || isBancontact}>
      <Surcharge paymentMethod paymentMethodType cardBrand={cardBrand->CardUtils.getCardType} />
    </RenderIf>
    <RenderIf condition={!isBancontact}>
      {switch (
        paymentMethodListValue.mandate_payment,
        options.terms.card,
        paymentMethodListValue.payment_type,
      ) {
      | (Some(_), Auto, NEW_MANDATE)
      | (Some(_), Auto, SETUP_MANDATE)
      | (_, Always, NEW_MANDATE)
      | (_, Always, SETUP_MANDATE)
      | (_, _, SETUP_MANDATE)
      | (_, _, NEW_MANDATE) =>
        <Terms
          mode={Card}
          styles={
            marginTop: themeObj.spacingGridColumn,
          }
        />
      | (_, _, _) => React.null
      }}
    </RenderIf>
    <RenderIf condition={clickToPayCardBrand !== ""}>
      <div className="space-y-3 mt-2">
        <ClickToPayHelpers.SrcMark cardBrands=clickToPayCardBrand height="32" />
        <ClickToPayDetails
          isSaveDetailsWithClickToPay
          setIsSaveDetailsWithClickToPay
          clickToPayCardBrand
          clickToPayRememberMe
          setClickToPayRememberMe
        />
      </div>
    </RenderIf>
  </div>
}
