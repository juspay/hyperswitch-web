// VGSCollect.res
open Utils

@react.component
let make = () => {
  let (configAtom, setConfig) = Recoil.useRecoilState(RecoilAtoms.configAtom)
  let {config, themeObj, localeString} = configAtom
  // Console.log2("Config from recoil==>", config)
  let {innerLayout} = config.appearance
  let (logger, _initTimestamp) = React.useMemo0(() => {
    (HyperLogger.make(~source=Elements(PaymentMethodsManagement)), Date.now())
  })

  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  // Console.log2("PAYMENTMETHODLISTVALUE===>", paymentMethodListValue)
  let (cardBrand, setCardBrand) = Recoil.useRecoilState(RecoilAtoms.cardBrand)
  let supportedCardBrands = React.useMemo(() => {
    paymentMethodListValue->PaymentUtils.getSupportedCardBrands
  }, [paymentMethodListValue])
  let cardType = React.useMemo1(() => {
    cardBrand->CardUtils.getCardType
  }, [cardBrand])
  let setUserError = message => {
    postFailedSubmitResponse(~errortype="validation_error", ~message)
  }
  let (cardProps, expiryProps, cvcProps, _zipProps) = CommonCardProps.useCardProps(
    ~logger,
    ~supportedCardBrands,
    ~cardType,
  )
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
    onExpiryKeyDown,
    expiryError,
    setExpiryError,
  } = expiryProps

  let {
    isCVCValid,
    setIsCVCValid,
    cvcNumber,
    setCvcNumber,
    changeCVCNumber,
    handleCVCBlur,
    cvcRef,
    onCvcKeyDown,
    cvcError,
    setCvcError,
  } = cvcProps

  let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
  let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
    ~cvcNumber,
    ~isCVCValid,
    ~isCvcValidValue,
  )
  let compressedLayoutStyleForCvcError =
    innerLayout === Compressed && cvcError->String.length > 0 ? "!border-l-0" : ""

  React.useEffect0(() => {
    messageParentWindow([("innerIframeMountedCallback", true->JSON.Encode.bool)])
    Console.log("sentmessage==>")
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->Utils.getDictFromJson
      if dict->Dict.get("innerIframeMounted")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")

        let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
        let config = metadata->Utils.getDictFromJson->Dict.get("config")
        let configDict = switch config {
        | Some(config) => config->getDictFromJson
        | None => Dict.make()
        }
        Console.log2("Getting The metadata==>", config)
        // let (default, defaultRules) = {
        //   default: DefaultTheme.default,
        //   defaultRules: DefaultTheme.defaultRules,
        // }
        Console.log2("ConfigDict000777===>", configDict)
        let config = CardTheme.itemToObjMapper(
          configDict,
          DefaultTheme.default,
          DefaultTheme.defaultRules,
          logger,
        )
        Console.log2("Config888999==>", config)
        // let optionsLocaleString = getWarningString(optionsDict, "locale", "", ~logger)
        // let optionsAppearance = CardTheme.getAppearance(
        //   "appearance",
        //   optionsDict,
        //   default,
        //   defaultRules,
        //   logger,
        // )
        let appearance = // optionsAppearance == CardTheme.defaultAppearance
        //   ? {
        //       Console.log("Inside default")
        config.appearance
        //   }
        // : {
        //     Console.log("Inside options")
        //     optionsAppearance
        //   }
        let localeString = config.locale
        // await CardTheme.getLocaleObject(
        //   optionsLocaleString == "" ?  : optionsLocaleString,
        // )
        // let constantString = await CardTheme.getConstantStringsObject()
        setConfig(prev => {
          ...prev,
          config: {
            appearance: config.appearance,
            locale: config.locale === "auto" ? Window.Navigator.language : config.locale,
            fonts: config.fonts,
            clientSecret: config.clientSecret,
            ephemeralKey: config.ephemeralKey,
            pmClientSecret: config.pmClientSecret,
            pmSessionId: config.pmSessionId,
            loader: config.loader,
          },
          themeObj: appearance.variables,
          // localeString,
          // constantString,
          // showLoader: config.loader == Auto || config.loader == Always,
        })
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  React.useEffect(() => {
    //Add an event listener listening for the message to do tokenize call
    let handle = (ev: Types.event) => {
      let json = ev.data->Identity.anyTypeToJson->getStringFromJson("")->safeParse
      let dict = json->getDictFromJson
      if dict->Dict.get("tokenizeCard")->Option.isSome {
        //DO ALL the validations of proper values
        let (month, year) = CardUtils.getExpiryDates(cardExpiry)

        let cardNetwork = [
          ("card_network", cardBrand != "" ? cardBrand->JSON.Encode.string : JSON.Encode.null),
        ]
        let defaultCardBody = PaymentManagementBody.saveCardBody(
          ~cardNumber,
          ~month,
          ~year,
          ~cardHolderName=None,
          ~cvcNumber,
          ~cardBrand=cardNetwork,
          // ~nickname=nickname.value,
        )

        let banContactBody = PaymentBody.bancontactBody()
        let cardBody = defaultCardBody

        let isCardDetailsValid =
          isCVCValid->Option.getOr(false) &&
          isCardValid->Option.getOr(false) &&
          isCardSupported->Option.getOr(false) &&
          isExpiryValid->Option.getOr(false)

        // let isNicknameValid = nickname.value === "" || nickname.isValid->Option.getOr(false)

        let validFormat = isCardDetailsValid
        if validFormat {
          Console.log("valid")
          //After Validation
          //Do Tokenize call on getting the message
          Console.log4("Tokenize the card using details==>", cardNumber, cvcNumber, cardExpiry)
          //Send the token reponse via post message
          let msg = [("tokenReceived", "abc"->JSON.Encode.string)]->Dict.fromArray
          ev.source->Window.sendPostMessage(msg)
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
          if cvcNumber === "" {
            setCvcError(_ => localeString.cvcNumberEmptyText)
            setUserError(localeString.enterFieldsText)
          }
          if !validFormat {
            setUserError(localeString.enterValidDetailsText)
          }
        }
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  }, [cardNumber, cardExpiry, cvcNumber])

  <div className="animate-slowShow">
    // <RenderIf condition={showFields || isBancontact}>
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
        // <RenderIf condition={!isBancontact}>
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
          className={innerLayout === Compressed && cardError->String.length > 0 ? "border-b-0" : ""}
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
        // </RenderIf>
        // <DynamicFields
        //   paymentMethod
        //   paymentMethodType
        //   setRequiredFieldsBody
        //   cardProps={Some(cardProps)}
        //   expiryProps={Some(expiryProps)}
        //   cvcProps={Some(cvcProps)}
        //   isBancontact
        //   isSaveDetailsWithClickToPay
        // />
        // <RenderIf condition={conditionsForShowingSaveCardCheckbox}>
        //   <div className="flex items-center justify-start">
        //     <SaveDetailsCheckbox
        //       isChecked=isSaveCardsChecked setIsChecked=setIsSaveCardsChecked
        //     />
        //   </div>
        // </RenderIf>
        // <RenderIf
        //   condition={(!options.hideCardNicknameField && isCustomerAcceptanceRequired) ||
        //     paymentType == PaymentMethodsManagement}>
        //   <NicknamePaymentInput />
        // </RenderIf>
      </div>
    </div>
    // </RenderIf>
  </div>
}

let default = make
