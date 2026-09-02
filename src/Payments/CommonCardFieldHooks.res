open JotaiAtoms
open Utils

type cardFieldState = {
  localeString: LocaleStringTypes.localeStrings,
  cardProps: CardUtils.cardProps,
  expiryProps: CardUtils.expiryProps,
  cvcProps: CardUtils.cvcProps,
}

let useCardFieldBase = (
  ~paymentType: CardThemeType.mode,
  ~cardBrandOverride="",
  ~dualPlane=false,
  (),
): cardFieldState => {
  let {localeString} = Jotai.useAtomValue(configAtom)
  let setShowPaymentMethodsScreen = Jotai.useSetAtom(showPaymentMethodsScreen)

  React.useEffect0(() => {
    setShowPaymentMethodsScreen(_ => true)
    None
  })

  let groupIdFromUrl = CardUtils.getQueryParamsDictforKey(
    RescriptReactRouter.useUrl().search,
    "groupId",
  )
  let elementNameForPortKey = switch paymentType {
  | CardThemeType.CardNumberElement => "cardNumber"
  | CardThemeType.CardExpiryElement => "cardExpiry"
  | CardThemeType.CardCVCElement => "cardCvc"
  | _ => ""
  }
  let portKey = if dualPlane && groupIdFromUrl !== "" && elementNameForPortKey !== "" {
    CardFormCoordinator.portKey(~groupId=groupIdFromUrl, ~fieldName=elementNameForPortKey)
  } else {
    ""
  }
  let hasPortPlane = portKey !== ""

  let (registryVersion, setRegistryVersion) = React.useState(() => 0)
  React.useEffect(() => {
    let onRegistryChange = () => setRegistryVersion(v => v + 1)
    SadPortRegistry.addChangeListener(onRegistryChange)
    Some(() => SadPortRegistry.removeChangeListener(onRegistryChange))
  }, [])

  let (portBrandOverride, setPortBrandOverride) = React.useState(_ => "")
  let effectiveCardBrandOverride = if cardBrandOverride !== "" {
    cardBrandOverride
  } else {
    portBrandOverride
  }

  let {cardProps, expiryProps, cvcProps, blurState: _} = CommonCardProps.useCardForm(
    ~paymentType,
    ~runEligibility=false,
    ~logControlEvents=false,
    ~cardBrandOverride=effectiveCardBrandOverride,
  )

  let keys = Jotai.useAtomValue(keys)
  let {parentURL} = keys

  React.useEffect(() => {
    if keys.iframeId !== "" && keys.iframeId !== "no-element" {
      let elementType = switch paymentType {
      | CardThemeType.CardNumberElement => "cardNumber"
      | CardThemeType.CardExpiryElement => "cardExpiry"
      | CardThemeType.CardCVCElement => "cardCvc"
      | _ => "card"
      }
      SubscriptionEventHooks.emitReady(~iframeId=keys.iframeId, ~elementType)
    }
    None
  }, [keys.iframeId])

  let focusTarget = switch paymentType {
  | CardThemeType.CardNumberElement => cardProps.cardRef
  | CardThemeType.CardExpiryElement => expiryProps.expiryRef
  | CardThemeType.CardCVCElement => cvcProps.cvcRef
  | _ => cardProps.cardRef
  }
  React.useEffect(() => {
    let handleFocusEvent = (ev: Window.event) => {
      if ev.source === iframeParent && (parentURL === "*" || ev.origin === parentURL) {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        if dict->Dict.get("doFocus")->Option.isSome {
          CardUtils.focusRef(focusTarget)
        } else if dict->Dict.get("doBlur")->Option.isSome {
          CardUtils.blurRef(focusTarget)
        }
      }
    }
    handleMessage(handleFocusEvent, "")
  }, (focusTarget, parentURL))

  let clearFieldValue = () =>
    switch paymentType {
    | CardThemeType.CardExpiryElement => {
        expiryProps.setCardExpiry(_ => "")
        expiryProps.setIsExpiryValid(_ => None)
      }
    | CardThemeType.CardCVCElement => {
        cvcProps.setCvcNumber(_ => "")
        cvcProps.setIsCVCValid(_ => None)
      }
    | _ => ()
    }

  React.useEffect(() => {
    if portKey !== "" {
      switch SadPortRegistry.getPort(~key=portKey) {
      | Some(port) =>
        MessageChannelBinding.onPortMessage(port, ev => {
          let frameJson: JSON.t = ev.data->Identity.anyTypeToJson
          switch CardFormPortProtocol.decodePortFrame(frameJson) {
          | Some({kind, payload}) =>
            if kind === CardFormPortProtocol.kindDoFocus &&
              payload->JSON.Decode.bool->Option.getOr(false) {
              CardUtils.focusRef(focusTarget)
            } else if kind === CardFormPortProtocol.kindDetectedCardBrand {
              setPortBrandOverride(_ => payload->JSON.Decode.string->Option.getOr(""))
            } else if kind === CardFormPortProtocol.kindClearField {
              clearFieldValue()
            } else {
              Console.warn(`[CommonCardFieldHooks] dropped port frame on unknown kind "${kind}" (portKey "${portKey}")`)
            }
          | None =>
            Console.warn(`[CommonCardFieldHooks] dropped un-decodable port frame (portKey "${portKey}")`)
          }
        })
      | None => ()
      }
    }
    None
  }, (portKey, registryVersion, focusTarget))

  let (complete, empty) = switch paymentType {
  | CardThemeType.CardNumberElement => (
      cardProps.isCardValid->Option.getOr(false),
      cardProps.cardNumber === "",
    )
  | CardThemeType.CardExpiryElement => (
      expiryProps.isExpiryValid->Option.getOr(false),
      expiryProps.cardExpiry === "",
    )
  | CardThemeType.CardCVCElement => (
      cvcProps.isCVCValid->Option.getOr(false),
      cvcProps.cvcNumber === "",
    )
  | _ => (false, true)
  }
  let focusReady = switch paymentType {
  | CardThemeType.CardNumberElement =>
    CardUtils.focusCardValid(cardProps.cardNumber, cardProps.cardBrand)
  | CardThemeType.CardExpiryElement =>
    expiryProps.cardExpiry->CardValidations.clearSpaces->String.length == 4 &&
      expiryProps.isExpiryValid == Some(true)
  | CardThemeType.CardCVCElement =>
    cvcProps.cvcNumber->String.length == cvcProps.maxCVCLength &&
      cvcProps.isCVCValid == Some(true)
  | _ => false
  }
  let _ = CardCollectorBridge.useEmitCardState(
    ~cardNumber=cardProps.cardNumber,
    ~cardExpiry=expiryProps.cardExpiry,
    ~cvcNumber=cvcProps.cvcNumber,
    ~cardBrand=cardProps.cardBrand,
    ~complete,
    ~empty,
    ~isCardValid=cardProps.isCardValid,
    ~isExpiryValid=expiryProps.isExpiryValid,
    ~isCvcValid=cvcProps.isCVCValid,
    ~focusReady,
    ~emitRawCardNumber=hasPortPlane,
    ~emitRawCardExpiry=hasPortPlane,
    ~emitRawCvc=hasPortPlane,
    ~portKey,
  )

  {localeString, cardProps, expiryProps, cvcProps}
}

let useCardNumberField = (~dualPlane=false, ()): cardFieldState => {
  useCardFieldBase(~paymentType=CardThemeType.CardNumberElement, ~dualPlane, ())
}

let useCardExpiryField = (~dualPlane=false, ()): cardFieldState => {
  useCardFieldBase(~paymentType=CardThemeType.CardExpiryElement, ~dualPlane, ())
}

let useCardCvcField = (~cardBrandOverride="", ~dualPlane=false, ()): cardFieldState => {
  useCardFieldBase(~paymentType=CardThemeType.CardCVCElement, ~cardBrandOverride, ~dualPlane, ())
}

module RenderCardNumber = {
  @react.component
  let make = (~state: cardFieldState) => {
    let {themeObj} = Jotai.useAtomValue(configAtom)
    let numberPlaceholder =
      Jotai.useAtomValue(cardNumberPlaceholder)->Option.getOr("1234 1234 1234 1234")
    let {isCardValid, cardNumber, changeCardNumber, handleCardBlur, cardRef, cardError, maxCardLength, icon, setIsCardValid} = state.cardProps
    <div
      className="animate-slowShow flex flex-col"
      style={{gridGap: "0px", height: themeObj.inputFieldHeight}}>
      <PaymentInputField
        fieldName=state.localeString.cardNumberLabel
        isValid=isCardValid
        setIsValid=setIsCardValid
        value=cardNumber
        onChange=changeCardNumber
        onBlur=handleCardBlur
        errorString=cardError
        type_="tel"
        className="tracking-widest w-full"
        maxLength=maxCardLength
        height=themeObj.inputFieldHeight
        inputRef=cardRef
        placeholder=numberPlaceholder
        rightIcon=icon
        paymentType=CardThemeType.CardNumberElement
        id="card-number"
        autocomplete="cc-number"
        isLabelHidden=true
        isErrorHidden=true
      />
    </div>
  }
}

module RenderCardExpiry = {
  @react.component
  let make = (~state: cardFieldState) => {
    let {themeObj} = Jotai.useAtomValue(configAtom)
    let expiryPlaceholder =
      Jotai.useAtomValue(cardExpiryPlaceholder)->Option.getOr(state.localeString.expiryPlaceholder)
    let {isExpiryValid, cardExpiry, changeCardExpiry, handleExpiryBlur, expiryRef, expiryError, setIsExpiryValid} = state.expiryProps
    <div
      className="animate-slowShow flex flex-col"
      style={{gridGap: "0px", height: themeObj.inputFieldHeight}}>
      <PaymentInputField
        fieldName=state.localeString.validThruText
        isValid=isExpiryValid
        setIsValid=setIsExpiryValid
        value=cardExpiry
        onChange=changeCardExpiry
        onBlur=handleExpiryBlur
        errorString=expiryError
        type_="tel"
        className="tracking-widest w-full"
        maxLength=7
        height=themeObj.inputFieldHeight
        inputRef=expiryRef
        placeholder=expiryPlaceholder
        paymentType=CardThemeType.CardExpiryElement
        id="card-expiry"
        autocomplete="cc-exp"
        isLabelHidden=true
        isErrorHidden=true
      />
    </div>
  }
}

module RenderCardCvc = {
  @react.component
  let make = (~state: cardFieldState) => {
    let {themeObj} = Jotai.useAtomValue(configAtom)
    let {layout} = Jotai.useAtomValue(JotaiAtoms.optionAtom)
    let cvcPlaceholder = Jotai.useAtomValue(cardCvcPlaceholder)->Option.getOr("123")
    let {isCVCValid, cvcNumber, changeCVCNumber, handleCVCBlur, cvcRef, cvcError, maxCVCLength, setIsCVCValid} = state.cvcProps
    let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
    let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
      ~cvcNumber,
      ~isCVCValid,
      ~isCvcValidValue,
    )
    <div
      className="animate-slowShow flex flex-col"
      style={{gridGap: "0px", height: themeObj.inputFieldHeight}}>
      <PaymentInputField
        fieldName=state.localeString.cvcTextLabel
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
          ~cvcIcon=Jotai.useAtomValue(cvcIconOverride)->Option.getOr(
            CardUtils.getLayoutClass(layout).cvcIcon,
          ),
        )}
        type_="tel"
        className="tracking-widest w-full"
        maxLength=maxCVCLength
        height=themeObj.inputFieldHeight
        inputRef=cvcRef
        placeholder=cvcPlaceholder
        paymentType=CardThemeType.CardCVCElement
        id="card-cvc"
        autocomplete="cc-csc"
        isLabelHidden=true
        isErrorHidden=true
      />
    </div>
  }
}
