type target = {checked: bool}
type event = {target: target}
open PaymentType
open PaymentModeType

@react.component
let make = (
  ~cardProps,
  ~expiryProps,
  ~cvcProps,
  ~isBancontact=false,
  ~paymentType: CardThemeType.mode,
  ~list: PaymentMethodsRecord.list,
) => {
  open Utils
  let {config, themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let (
    isCardValid,
    setIsCardValid,
    cardNumber,
    changeCardNumber,
    handleCardBlur,
    cardRef,
    icon,
    cardError,
    setCardError,
    maxCardLength,
  ) = cardProps

  let cardBrand = React.useMemo1(() => {
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
  let {customerPaymentMethods, disableSaveCards} = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.optionAtom,
  )
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Card)
  let (savedMethods, setSavedMethods) = React.useState(_ => [])
  let (showFields, setShowFields) = Recoil.useRecoilState(RecoilAtoms.showCardFeildsAtom)
  let (paymentToken, setPaymentToken) = Recoil.useRecoilState(RecoilAtoms.paymentTokenAtom)
  let (token, _) = paymentToken
  let cardHolderName = Recoil.useRecoilValueFromAtom(RecoilAtoms.userFullName)
  let setComplete = Recoil.useSetRecoilState(RecoilAtoms.fieldsComplete)
  let (
    loadSavedCards: PaymentType.savedCardsLoadState,
    setLoadSavedCards: (PaymentType.savedCardsLoadState => PaymentType.savedCardsLoadState) => unit,
  ) = React.useState(_ => PaymentType.LoadingSavedCards)
  let (isSaveCardsChecked, setIsSaveCardsChecked) = React.useState(_ => false)

  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
  }

  let (requiredFieldsBody, setRequiredFieldsBody) = React.useState(_ => Js.Dict.empty())

  let areRequiredFieldsValid = Recoil.useRecoilValueFromAtom(RecoilAtoms.areRequiredFieldsValid)

  React.useEffect1(() => {
    switch customerPaymentMethods {
    | LoadingSavedCards => ()
    | LoadedSavedCards(arr) => {
        let savedCards = arr->Js.Array2.filter((item: PaymentType.customerMethods) => {
          item.paymentMethod == "card"
        })
        setSavedMethods(_ => savedCards)
        setLoadSavedCards(_ =>
          savedCards->Js.Array2.length == 0 ? NoResult : LoadedSavedCards(savedCards)
        )
        setShowFields(.prev => savedCards->Js.Array2.length == 0 || prev)
      }
    | NoResult => {
        setLoadSavedCards(_ => NoResult)
        setShowFields(._ => true)
      }
    }

    None
  }, [customerPaymentMethods])

  React.useEffect1(() => {
    if disableSaveCards {
      setShowFields(._ => true)
      setLoadSavedCards(_ => LoadedSavedCards([]))
    }
    None
  }, [disableSaveCards])

  React.useEffect1(() => {
    let tokenobj =
      savedMethods->Js.Array2.length > 0
        ? Some(savedMethods->Belt.Array.get(0)->Belt.Option.getWithDefault(defaultCustomerMethods))
        : None

    switch tokenobj {
    | Some(obj) => setPaymentToken(._ => (obj.paymentToken, obj.customerId))
    | None => ()
    }
    None
  }, [savedMethods])

  let complete = showFields
    ? isAllValid(isCardValid, isCVCValid, isExpiryValid, true, "payment")
    : switch isCVCValid {
      | Some(val) => token !== "" && !isBancontact && val
      | _ => false
      }
  let empty = showFields ? cardNumber == "" || cardExpiry == "" || cvcNumber == "" : cvcNumber == ""
  React.useEffect1(() => {
    setComplete(._ => complete)
    None
  }, [complete])

  React.useEffect2(() => {
    handlePostMessageEvents(~complete, ~empty, ~paymentType="card", ~loggerState)
    None
  }, (empty, complete))

  let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
  let (cardEmpty, cardComplete, cardInvalid) = React.useMemo3(() => {
    let isCardDetailsEmpty = Js.String2.length(cvcNumber) == 0
    let isCardDetailsValid = isCvcValidValue == "valid"
    let isCardDetailsInvalid = isCvcValidValue == "invalid"
    (isCardDetailsEmpty, isCardDetailsValid, isCardDetailsInvalid)
  }, (cvcNumber, isCvcValidValue, isCVCValid))

  let setRightIconForCvc = () => {
    if cardEmpty {
      <Icon size=28 name="cvc-empty" />
    } else if cardInvalid {
      <div style={ReactDOMStyle.make(~color=themeObj.colorIconCardCvcError, ())}>
        <Icon size=28 name="cvc-invalid" />
      </div>
    } else if cardComplete {
      <Icon size=28 name="cvc-complete" />
    } else {
      <Icon size=28 name="cvc-empty" />
    }
  }

  let submitCallback = React.useCallback((ev: Window.event) => {
    let json = ev.data->Js.Json.parseExn
    let confirm = json->getDictFromJson->ConfirmType.itemToObjMapper
    let (month, year) = CardUtils.getExpiryDates(cardExpiry)
    let (token, customerId) = paymentToken
    let savedCardBody = PaymentBody.savedCardBody(~paymentToken=token, ~customerId, ~cvcNumber)

    let onSessionBody = [("setup_future_usage", "on_session"->Js.Json.string)]
    let cardNetwork = {
      if cardBrand != "" {
        [("card_network", cardBrand->Js.Json.string)]
      } else {
        []
      }
    }
    let deafultCardBody = PaymentBody.cardPaymentBody(
      ~cardNumber,
      ~month,
      ~year,
      ~cardHolderName="",
      ~cvcNumber,
      ~cardBrand=cardNetwork,
    )
    let banContactBody = PaymentBody.bancontactBody(
      ~cardNumber,
      ~month,
      ~year,
      ~cardHolderName=cardHolderName.value,
    )
    let cardBody = isSaveCardsChecked
      ? deafultCardBody->Js.Array2.concat(onSessionBody)
      : deafultCardBody
    if confirm.doSubmit {
      let validFormat =
        isCardValid->Belt.Option.getWithDefault(false) &&
        isExpiryValid->Belt.Option.getWithDefault(false) &&
        (isBancontact || isCVCValid->Belt.Option.getWithDefault(false)) &&
        areRequiredFieldsValid
      if validFormat && (showFields || isBancontact) {
        intent(
          ~bodyArr={
            (isBancontact ? banContactBody : cardBody)
            ->Js.Dict.fromArray
            ->Js.Json.object_
            ->OrcaUtils.flattenObject(true)
            ->OrcaUtils.mergeTwoFlattenedJsonDicts(requiredFieldsBody)
            ->OrcaUtils.getArrayOfTupleFromDict
          },
          ~confirmParam=confirm.confirmParams,
          ~handleUserError=false,
          (),
        )
      } else if complete && !empty {
        intent(
          ~bodyArr=savedCardBody
          ->Js.Dict.fromArray
          ->Js.Json.object_
          ->OrcaUtils.flattenObject(true)
          ->OrcaUtils.mergeTwoFlattenedJsonDicts(requiredFieldsBody)
          ->OrcaUtils.getArrayOfTupleFromDict,
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
        if !validFormat {
          setUserError(localeString.enterValidDetailsText)
        }
      }
    }
  })
  submitPaymentData(submitCallback)

  let paymentMethod = isBancontact ? "bank_redirect" : "card"
  let paymentMethodType = isBancontact ? "bancontact_card" : "debit"

  <div className="animate-slowShow">
    <RenderIf condition={!showFields && !isBancontact}>
      <SavedMethods
        paymentToken setPaymentToken savedMethods loadSavedCards cvcProps paymentType list
      />
    </RenderIf>
    <RenderIf condition={showFields || isBancontact}>
      <div
        className="flex flex-col"
        style={ReactDOMStyle.make(~gridGap=themeObj.spacingGridColumn, ())}>
        <div className="w-full">
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
            pattern="[\d| ]{16,22}"
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
            <RenderIf condition={isBancontact}>
              <div className="w-[45%]"> <FullNamePaymentInput paymentType={paymentType} /> </div>
            </RenderIf>
            <RenderIf condition={!isBancontact}>
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
                  rightIcon={setRightIconForCvc()}
                  appearance=config.appearance
                  type_="tel"
                  className="tracking-widest w-full"
                  maxLength=4
                  inputRef=cvcRef
                  placeholder="123"
                />
              </div>
            </RenderIf>
          </div>
          <RenderIf condition={list.payment_methods->Js.Array.length !== 0}>
            <DynamicFields
              paymentType list paymentMethod="card" paymentMethodType="debit" setRequiredFieldsBody
            />
          </RenderIf>
          <RenderIf condition={!isBancontact && !options.disableSaveCards}>
            <div className="pt-4 pb-2 flex items-center justify-start">
              <AnimatedCheckbox isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked />
            </div>
          </RenderIf>
          <RenderIf condition={savedMethods->Js.Array2.length > 0 && !isBancontact}>
            <div
              className="Label flex flex-row gap-3 items-end cursor-pointer"
              style={ReactDOMStyle.make(
                ~fontSize="14px",
                ~color=themeObj.colorPrimary,
                ~fontWeight="400",
                ~marginTop="14px",
                (),
              )}
              onClick={_ => {
                setShowFields(._ => false)
              }}>
              <Icon name="card-2" size=22 width=24 />
              {React.string(localeString.useExisitingSavedCards)}
            </div>
          </RenderIf>
        </div>
      </div>
    </RenderIf>
    <RenderIf condition={showFields || isBancontact}>
      <Surcharge list paymentMethod paymentMethodType cardBrand={cardBrand->CardUtils.cardType} />
    </RenderIf>
    <RenderIf condition={!isBancontact}>
      {switch (list.mandate_payment, options.terms.card) {
      | (Some(_), Auto)
      | (_, Always) =>
        <div
          className="opacity-50 text-xs mb-2 text-left"
          style={ReactDOMStyle.make(
            ~color=themeObj.colorText,
            ~marginTop=themeObj.spacingGridColumn->addSize(10.0, Pixel),
            (),
          )}>
          <Terms mode={Card} />
        </div>
      | (_, _) => React.null
      }}
    </RenderIf>
  </div>
}
