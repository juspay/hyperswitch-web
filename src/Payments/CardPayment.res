type target = {checked: bool}
type event = {target: target}

@react.component
let make = (
  ~cardProps,
  ~expiryProps,
  ~cvcProps,
  ~isBancontact=false,
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
) => {
  open PaymentType
  open PaymentModeType
  open Utils
  open UtilityHooks

  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let (nickname, setNickname) = React.useState(_ => "")

  let (
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
  ) = cardProps

  let cardBrand = React.useMemo(() => {
    cardNumber->CardUtils.getCardBrand
  }, [cardNumber])

  let (
    isExpiryValid,
    setIsExpiryValid,
    cardExpiry,
    changeCardExpiry,
    handleExpiryBlur,
    expiryRef,
    _,
    expiryError,
    setExpiryError,
  ) = expiryProps

  let (
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    _,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    _,
    cvcError,
    setCvcError,
  ) = cvcProps
  let {displaySavedPaymentMethodsCheckbox} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let showFields = Recoil.useRecoilValueFromAtom(RecoilAtoms.showCardFieldsAtom)
  let setComplete = Recoil.useSetRecoilState(RecoilAtoms.fieldsComplete)
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ => false)

  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
  }

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Dict.make())

  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)

  let complete = isAllValid(isCardValid, isCVCValid, isExpiryValid, true, "payment")
  let empty = cardNumber == "" || cardExpiry == "" || cvcNumber == ""
  React.useEffect(() => {
    setComplete(_ => complete)
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
    ~list,
    ~isGuestCustomer,
  )

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->JSON.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let (month, year) = CardUtils.getExpiryDates(cardExpiry)

    let onSessionBody = [("customer_acceptance", PaymentBody.customerAcceptanceBody)]
    let cardNetwork = {
      if cardBrand != "" {
        [("card_network", cardBrand->JSON.Encode.string)]
      } else {
        []
      }
    }
    let defaultCardBody = PaymentBody.cardPaymentBody(
      ~cardNumber,
      ~month,
      ~year,
      ~cardHolderName="",
      ~cvcNumber,
      ~cardBrand=cardNetwork,
      ~nickname,
      (),
    )
    let banContactBody = PaymentBody.bancontactBody()
    let cardBody = if isCustomerAcceptanceRequired {
      defaultCardBody->Array.concat(onSessionBody)
    } else {
      defaultCardBody
    }
    if confirm.doSubmit {
      let validFormat =
        (isBancontact ||
        (isCVCValid->Option.getOr(false) &&
        isCardValid->Option.getOr(false) &&
        isCardSupported->Option.getOr(false) &&
        isExpiryValid->Option.getOr(false))) && areRequiredFieldsValid
      if validFormat && (showFields || isBancontact) {
        intent(
          ~bodyArr={
            (isBancontact ? banContactBody : cardBody)
            ->Dict.fromArray
            ->JSON.Encode.object
            ->flattenObject(true)
            ->mergeTwoFlattenedJsonDicts(requiredFieldsBody)
            ->getArrayOfTupleFromDict
          },
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          (),
        )
      } else {
        if cardNumber === "" {
          setCardError(_ => localeString.cardNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if cardExpiry === "" {
          setExpiryError(_ => localeString.cardExpiryDateEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if !isBancontact && cvcNumber === "" {
          setCvcError(_ => localeString.cvcNumberEmptyText)
          setUserError(localeString.enterFieldsText)
        }
        if isCardSupported->Option.getOr(false)->not {
          setCardError(_ => "Unsupported Card")
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
  ))
  useSubmitPaymentData(submitCallback)

  let paymentMethod = isBancontact ? "bank_redirect" : "card"
  let paymentMethodType = isBancontact ? "bancontact_card" : "debit"
  let conditionsForShowingSaveCardCheckbox =
    list.mandate_payment->Option.isNone &&
    !isGuestCustomer &&
    list.payment_type !== SETUP_MANDATE &&
    options.displaySavedPaymentMethodsCheckbox &&
    !isBancontact

  let nicknameFieldClassName = conditionsForShowingSaveCardCheckbox ? "pt-2" : "pt-5"

  <div className="animate-slowShow">
    <RenderIf condition={showFields || isBancontact}>
      <div
        className="flex flex-col"
        style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
        <div className="w-full">
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
              paymentType
              type_="tel"
              appearance=config.appearance
              maxLength=maxCardLength
              inputRef=cardRef
              placeholder="1234 1234 1234 1234"
            />
            <div
              className="flex flex-row w-full place-content-between"
              style={ReactDOMStyle.make(
                ~marginTop=themeObj.spacingGridColumn,
                ~gridColumnGap=themeObj.spacingGridRow,
                (),
              )}>
              <div className="w-[45%]">
                <PaymentInputField
                  fieldName=localeString.validThruText
                  isValid=isExpiryValid
                  setIsValid=setIsExpiryValid
                  value=cardExpiry
                  onChange=changeCardExpiry
                  onBlur=handleExpiryBlur
                  errorString=expiryError
                  paymentType
                  type_="tel"
                  appearance=config.appearance
                  maxLength=7
                  inputRef=expiryRef
                  placeholder="MM / YY"
                />
              </div>
              <div className="w-[45%]">
                <PaymentInputField
                  fieldName=localeString.cvcTextLabel
                  isValid=isCVCValid
                  setIsValid=setIsCVCValid
                  value=cvcNumber
                  onChange=changeCVCNumber
                  onBlur=handleCVCBlur
                  errorString=cvcError
                  paymentType
                  rightIcon={CardUtils.setRightIconForCvc(
                    ~cardComplete,
                    ~cardEmpty,
                    ~cardInvalid,
                    ~color=themeObj.colorIconCardCvcError,
                  )}
                  appearance=config.appearance
                  type_="tel"
                  className="tracking-widest w-full"
                  maxLength=4
                  inputRef=cvcRef
                  placeholder="123"
                />
              </div>
            </div>
          </RenderIf>
          <DynamicFields
            paymentType
            list
            paymentMethod
            paymentMethodType
            setRequiredFieldsBody
            cardProps={Some(cardProps)}
            expiryProps={Some(expiryProps)}
            cvcProps={Some(cvcProps)}
            isBancontact
          />
          <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
            <div className="pt-4 pb-2 flex items-center justify-start">
              <SaveDetailsCheckbox
                isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked
              />
            </div>
          </RenderIf>
          <RenderIf condition={isCustomerAcceptanceRequired}>
            <div className={`pb-2 ${nicknameFieldClassName}`}>
              <NicknamePaymentInput paymentType value=nickname setValue=setNickname />
            </div>
          </RenderIf>
        </div>
      </div>
    </RenderIf>
    <RenderIf condition={showFields || isBancontact}>
      <Surcharge
        list paymentMethod paymentMethodType cardBrand={cardBrand->CardUtils.getCardType}
      />
    </RenderIf>
    <RenderIf condition={!isBancontact}>
      {switch (list.mandate_payment, options.terms.card, list.payment_type) {
      | (Some(_), Auto, NEW_MANDATE)
      | (Some(_), Auto, SETUP_MANDATE)
      | (_, Always, NEW_MANDATE)
      | (_, Always, SETUP_MANDATE)
      | (_, _, SETUP_MANDATE)
      | (_, _, NEW_MANDATE) =>
        <div
          className="opacity-50 text-xs mb-2 text-left"
          style={ReactDOMStyle.make(
            ~color=themeObj.colorText,
            ~marginTop=themeObj.spacingGridColumn,
            (),
          )}>
          <Terms mode={Card} />
        </div>
      | (_, _, _) => React.null
      }}
    </RenderIf>
  </div>
}
