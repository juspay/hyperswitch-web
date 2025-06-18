open Utils
open ResizeObserver

@react.component
let make = () => {
  let contentRef = React.useRef(Nullable.null)

  let observer = ResizeObserver.newResizerObserver(entries => {
    entries->Array.forEach(entry => {
      let newHeight = entry.contentRect.height
      Utils.messageParentWindow([("cardIframeContentHeight", newHeight->JSON.Encode.float)])
    })
  })

  switch contentRef.current->Nullable.toOption {
  | Some(r) => observer.observe(r)
  | None => ()
  }

  let (paymentMethodsList, setPaymentMethodsList) = Recoil.useRecoilState(
    RecoilAtomsV2.paymentMethodsListV2,
  )
  let (configAtom, setConfig) = Recoil.useRecoilState(RecoilAtoms.configAtom)
  let {config, themeObj, localeString} = configAtom
  let (keys, setKeys) = Recoil.useRecoilState(RecoilAtoms.keys)
  let (vaultPublishableKey, setVaultPublishableKey) = Recoil.useRecoilState(
    RecoilAtomsV2.vaultPublishableKey,
  )
  let (vaultProfileId, setVaultProfileId) = Recoil.useRecoilState(RecoilAtomsV2.vaultProfileId)
  let {innerLayout} = config.appearance
  let (logger, _initTimestamp) = React.useMemo0(() => {
    (HyperLogger.make(~source=Elements(PaymentMethodsManagement)), Date.now())
  })
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let (cardBrand, setCardBrand) = Recoil.useRecoilState(RecoilAtoms.cardBrand)
  let (receivedSupportedCardBrands, setReceivedSupportedCardBrands) = React.useState(() => None)

  let supportedCardBrands = React.useMemo2(() => {
    switch receivedSupportedCardBrands {
    | Some(brands) => Some(brands)
    | None => Some([])
    }
  }, (receivedSupportedCardBrands, paymentMethodListValue))

  let cardType = React.useMemo1(() => {
    cardBrand->CardUtils.getCardType
  }, [cardBrand])

  let setUserError = message => {
    Console.log2("sending user eeror post failes==>", message)
    postFailedSubmitResponseTop(~errortype="validation_error", ~message)
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
    let handle = (ev: Window.event) => {
      let handleAsync = async () => {
        let json = ev.data->safeParse
        let dict = json->Utils.getDictFromJson
        if dict->Dict.get("innerIframeMounted")->Option.isSome {
          let metadata = dict->getJsonObjectFromDict("metadata")
          let metadataDict = metadata->Utils.getDictFromJson

          setReceivedSupportedCardBrands(_ => Some(
            metadataDict->getStrArray("supportedCardBrands"),
          ))
          setPaymentMethodsList(_ => {
            metadataDict->UnifiedHelpersV2.createPaymentsObjArr("paymentList")
          })
          let config = metadataDict->Dict.get("config")
          let pmSessionId =
            metadataDict
            ->Dict.get("pmSessionId")
            ->Option.flatMap(JSON.Decode.string)
            ->Option.getOr("")
          let pmClientSecret =
            metadataDict
            ->Dict.get("pmClientSecret")
            ->Option.flatMap(JSON.Decode.string)
            ->Option.getOr("")
          let vaultPublishableKey =
            metadataDict
            ->Dict.get("vaultPublishableKey")
            ->Option.flatMap(JSON.Decode.string)
            ->Option.getOr("")
          let vaultProfileId =
            metadataDict
            ->Dict.get("vaultProfileId")
            ->Option.flatMap(JSON.Decode.string)
            ->Option.getOr("")
          setKeys(prev => {
            ...prev,
            pmSessionId,
            pmClientSecret,
          })
          setVaultPublishableKey(_ => vaultPublishableKey)
          setVaultProfileId(_ => vaultProfileId)
          let configValue = switch config {
          | Some(c) => c->getDictFromJson
          | None => Dict.make()
          }
          let config = CardTheme.itemToObjMapper(
            configValue,
            DefaultTheme.default,
            DefaultTheme.defaultRules,
            logger,
          )

          let appearance = config.appearance

          let localeString = config.locale
          let localeObject = await CardTheme.getLocaleObject(
            localeString == "" ? "auto" : localeString,
          )
          let constantString = await CardTheme.getConstantStringsObject()

          setConfig(_ => {
            // ...prev,
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
            localeString: localeObject,
            constantString,
            showLoader: config.loader == Auto || config.loader == Always,
          })
        }
      }
      handleAsync()->ignore
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  let handleSaveCard = async (ev: Types.event) => {
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "paymentloader"->JSON.Encode.string),
    ])
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
    )
    try {
      let res = await PaymentHelpersV2.savePaymentMethod(
        ~bodyArr=defaultCardBody,
        ~pmSessionId=keys.pmSessionId->Option.getOr(""),
        ~pmClientSecret=keys.pmClientSecret->Option.getOr(""),
        ~publishableKey=vaultPublishableKey,
        ~profileId=vaultProfileId,
      )

      let dict = res->getDictFromJson
      let paymentMethodId = dict->getString("id", "")

      if paymentMethodId != "" {
        let msg = [("tokenReceived", paymentMethodId->JSON.Encode.string)]->Dict.fromArray
        ev.source->Window.sendPostMessage(msg)
      } else {
        Console.error2("Payment Id Empty ", res->JSON.stringify)
      }
    } catch {
    | err =>
      let exceptionMessage = err->formatException->JSON.stringify
      Console.error2("Unable to Save Card ", exceptionMessage)
    }
    // messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
  }

  React.useEffect(() => {
    let handle = (ev: Types.event) => {
      let json = ev.data->Identity.anyTypeToJson->getStringFromJson("")->safeParse
      let dict = json->getDictFromJson
      if dict->Dict.get("tokenizeCard")->Option.isSome {
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
        )

        let cardBody = defaultCardBody

        let isCardDetailsValid =
          isCVCValid->Option.getOr(false) &&
          isCardValid->Option.getOr(false) &&
          isCardSupported->Option.getOr(false) &&
          isExpiryValid->Option.getOr(false)

        let validFormat = isCardDetailsValid
        if validFormat {
          handleSaveCard(ev)->ignore
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
  }, (cardNumber, cardExpiry, cvcNumber))

  <div className="animate-slowShow" ref={contentRef->ReactDOM.Ref.domRef}>
    <div
      className="flex flex-col mb-[4px] mr-[4px] ml-[4px]"
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
      </div>
    </div>
  </div>
}

let default = make
