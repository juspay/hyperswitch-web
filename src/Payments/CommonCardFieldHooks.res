/* Shared plumbing for standalone per-field card inputs on the vault and payments
   surfaces. Surface divergence (vault tokenisation vs hosted-fields relay) is injected
   via `~onInitiateConfirm`, keeping this module atom-free. */

open JotaiAtoms
open Utils

/* `CommonHooks.addEventListener` targets `Window.element`, which does not unify with the
   `Dom.element` a `React.ref` holds — inline externals sidestep the mismatch. */
@send external addDomEventListener: (Dom.element, string, Dom.event => unit) => unit = "addEventListener"
@send external removeDomEventListener: (Dom.element, string, Dom.event => unit) => unit = "removeEventListener"

/* the cardNumber iframe owns confirm but holds only its OWN local value; the sibling
   values arrive on the group's `initiate-confirm` payload. External values win when
   present, so single-iframe surfaces (saved-card CVC) still work off the locals. */
type confirmHandlerArgs = {
  loggerState: HyperLoggerTypes.loggerMake,
  localeString: LocaleStringTypes.localeStrings,
  isCardValid: option<bool>,
  isExpiryValid: option<bool>,
  isCvcValid: option<bool>,
  cardNumber: string,
  cardExpiry: string,
  cvcNumber: string,
  cardBrand: string,
  /* Flow B saved-card `payment_token`: only the outer group knows it (the iframe learns the
     BRAND alone, for length validation), so it rides the confirm-relay payload. Empty when
     the mounted field set is not a saved-card recollect. */
  paymentToken: string,
  parentURL: string,
  iframeId: string,
}

type cardFieldState = {
  localeString: LocaleStringTypes.localeStrings,
  cardProps: CardUtils.cardProps,
  expiryProps: CardUtils.expiryProps,
  cvcProps: CardUtils.cvcProps,
}

/* per-field `formStatusChange` carries FIVE states (complete, incomplete, invalid, focused,
   blurred); the subscription-event pipeline carries only three, is merchant-opt-in, and
   never surfaces invalid/focused/blurred. The status canon lives in `CardFormShared`. */

open CardFormShared

type fieldFormStatus = CardFormShared.fieldFormStatus

let fieldFormStatusToString = CardFormShared.fieldFormStatusToString

let computeFieldFormStatus = (~isValid: option<bool>, ~value: string): fieldFormStatus =>
  switch isValid {
  | Some(false) => Invalid
  | Some(true) => value === "" ? Incomplete : Complete
  | None => Incomplete
  }

let emitFormStatusChange = (
  ~parentURL: string,
  ~iframeId: string,
  ~fieldName: string,
  ~status: fieldFormStatus,
  ~message: option<string>,
  ~cardBrand: string,
) => {
  let baseFields = [
    ("formStatusChange", true->JSON.Encode.bool),
    ("elementType", fieldName->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
    ("status", status->fieldFormStatusToString->JSON.Encode.string),
    ("cardBrand", cardBrand->JSON.Encode.string),
  ]
  let fields = switch message {
  | Some(errorMessage) if errorMessage !== "" =>
    baseFields->Array.concat([("message", errorMessage->JSON.Encode.string)])
  | _ => baseFields
  }
  messageParentWindow(fields, ~targetOrigin=parentURL)
}

let useCardFieldBase = (
  ~logger: HyperLoggerTypes.loggerMake,
  ~paymentType: CardThemeType.mode,
  ~inputRef: CardThemeType.mode,
  // absent → no confirm listener: expiry passes nothing, the card-number iframe owns confirm.
  ~onInitiateConfirm: option<confirmHandlerArgs => unit>,
  // vault card-number confirm uses "initiate-confirm"; saved-card CVC uses "initiate-confirm-cvc".
  ~confirmTriggerKey="initiate-confirm",
  ~cardBrandOverride="",
  /* when true this field's FULL snapshot rides its MessageChannel port to the hidden
     coordinator — raw SAD on the port plane ONLY; the window plane gets the SPLIT payload
     from `CardFormPortProtocol.encodeFieldStateUpdate`. Bundled collectors never set it. */
  ~dualPlane=false,
  (),
): cardFieldState => {
  let {localeString} = Jotai.useAtomValue(configAtom)
  let setShowPaymentMethodsScreen = Jotai.useSetAtom(showPaymentMethodsScreen)

  /* per-field iframes must opt into live cardBrand tracking the way CardsSDK does: without it
     `CardUtils.getCardBrandFromStates` reads the frozen `cardScheme` atom, which nothing in a
     standalone field iframe ever writes, so the brand icon never re-renders while typing.
     Scoped to this iframe's own Jotai store; a saved-card override short-circuits first. */
  React.useEffect0(() => {
    setShowPaymentMethodsScreen(_ => true)
    None
  })

  /* port key for this field: the group carries `groupId` into the iframe URL and forwards
     port2 WITH the mount-config transfer, keyed `${groupId}:${fieldName}`. */
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

  let (registryVersion, setRegistryVersion) = React.useState(() => 0)
  React.useEffect(() => {
    let onRegistryChange = () => setRegistryVersion(v => v + 1)
    SadPortRegistry.addChangeListener(onRegistryChange)
    Some(() => SadPortRegistry.removeChangeListener(onRegistryChange))
  }, [])

  /* port-plane brand relay: the coordinator posts `detectedCardBrand` frames onto the cvc
     sibling port. A saved-card `cardBrandOverride` still wins. */
  let (portBrandOverride, setPortBrandOverride) = React.useState(_ => "")
  let effectiveCardBrandOverride = if cardBrandOverride !== "" {
    cardBrandOverride
  } else {
    portBrandOverride
  }

  let {cardProps, expiryProps, cvcProps, blurState: _} = CommonCardProps.useCardForm(
    ~logger,
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

  /* `useCardForm`'s shared handler only sets a visual blur class; we need real DOM focus and
     blur so `fieldHandle.focus()` and `.blur()` match merchant expectations. */
  let focusTarget = switch inputRef {
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

  /* ONE focusRef, dual-bound: the same handler serves the window-posted `doFocus` and the
     port frame `{cardFormPortV, kind: "doFocus"}`; registryVersion covers the ingest race. */
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

  /* a useEffect (not useCallback) re-registers with the latest closure on cardNumber change.
     NEVER call the hook conditionally — the option switch stays INSIDE the effect body. */
  React.useEffect(() => {
    switch onInitiateConfirm {
    | Some(confirmHandler) => {
      let handleConfirmEvent = (ev: Window.event) => {
        if ev.source === iframeParent && (parentURL === "*" || ev.origin === parentURL) {
          let json = ev.data->safeParse
          let dict = json->getDictFromJson
          if dict->Dict.get(confirmTriggerKey)->Option.isSome {
            let externalCardNumber = dict->getString("cardNumber", "")
            let externalCardExpiry = dict->getString("cardExpiry", "")
            let externalCvcNumber = dict->getString("cvcNumber", "")
            let externalPaymentToken = dict->getString("paymentToken", "")
            confirmHandler({
              loggerState: logger,
              localeString,
              isCardValid: cardProps.isCardValid,
              isExpiryValid: expiryProps.isExpiryValid,
              isCvcValid: cvcProps.isCVCValid,
              cardNumber: externalCardNumber !== "" ? externalCardNumber : cardProps.cardNumber,
              cardExpiry: externalCardExpiry !== "" ? externalCardExpiry : expiryProps.cardExpiry,
              cvcNumber: externalCvcNumber !== "" ? externalCvcNumber : cvcProps.cvcNumber,
              cardBrand: cardProps.cardBrand,
              paymentToken: externalPaymentToken,
              parentURL,
              iframeId: keys.iframeId,
            })
          }
        }
      }
      handleMessage(handleConfirmEvent, "")
      }
    | None => None
    }
   }, (
      cardProps.isCardValid,
      cardProps.cardNumber,
      expiryProps.cardExpiry,
      cvcProps.cvcNumber,
      cardProps.cardBrand,
      parentURL,
    ))

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
  /* focus-readiness is computed HERE in the iframe, where the keystrokes land — NOT inferred
     by the group from `fieldStatus.complete`. cardNumber uses `CardUtils.focusCardValid`
     (brand-aware max length AND Luhn, the same call the bundled form makes); expiry needs all
     4 MMYY digits plus a green validator; cvc needs maxCVCLength plus a green validator.
     The group routes `doFocus` on the false→true edge of this flag only. */
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
    /* each field iframe is its own trust domain, and the raw value must reach the parent group
       so the confirm payload can be aggregated across iframes. Raw cardNumber MUST ride too:
       with `portKey` active `encodeFieldStateUpdate` strips the window payload, so the port
       frame is the ONLY delivery path to the coordinator — dropping the PAN here leaves
       `aggregatedCardNumber` permanently "" and every confirm fails as incomplete. */
    ~emitRawCardNumber=true,
    ~emitRawCardExpiry=true,
    ~emitRawCvc=true,
    ~portKey,
  )

  /* key on isValid and value rather than the derived complete/empty, so the status effect
     re-fires exactly once per validity transition. */
  let elementType = switch paymentType {
  | CardThemeType.CardNumberElement => "cardNumber"
  | CardThemeType.CardExpiryElement => "cardExpiry"
  | CardThemeType.CardCVCElement => "cardCvc"
  | _ => "card"
  }
  let (relevantIsValid, relevantValue, relevantError) = switch paymentType {
  | CardThemeType.CardNumberElement => (
      cardProps.isCardValid,
      cardProps.cardNumber,
      cardProps.cardError,
    )
  | CardThemeType.CardExpiryElement => (
      expiryProps.isExpiryValid,
      expiryProps.cardExpiry,
      expiryProps.expiryError,
    )
  | CardThemeType.CardCVCElement => (
      cvcProps.isCVCValid,
      cvcProps.cvcNumber,
      cvcProps.cvcError,
    )
  | _ => (None, "", "")
  }
  React.useEffect(() => {
    if keys.iframeId !== "" && keys.iframeId !== "no-element" {
      let status = computeFieldFormStatus(~isValid=relevantIsValid, ~value=relevantValue)
      let message = switch status {
      | Invalid => relevantError === "" ? None : Some(relevantError)
      | _ => None
      }
      emitFormStatusChange(
        ~parentURL,
        ~iframeId=keys.iframeId,
        ~fieldName=elementType,
        ~status,
        ~message,
        ~cardBrand=cardProps.cardBrand,
      )
    }
    None
  }, (relevantIsValid, relevantValue, relevantError, keys.iframeId, parentURL))

  /* focus and blur are one-shot, not status-latched; native DOM listeners avoid fighting
     `useCardForm`'s shared handler and take local @send externals for the type mismatch. */
  React.useEffect(() => {
    let currentInput = focusTarget.current->Nullable.toOption
    switch currentInput {
    | Some(input) => {
        let onFocus = _ =>
          emitFormStatusChange(
            ~parentURL,
            ~iframeId=keys.iframeId,
            ~fieldName=elementType,
            ~status=Focused,
            ~message=None,
            ~cardBrand=cardProps.cardBrand,
          )
        let onBlur = _ =>
          emitFormStatusChange(
            ~parentURL,
            ~iframeId=keys.iframeId,
            ~fieldName=elementType,
            ~status=Blurred,
            ~message=None,
            ~cardBrand=cardProps.cardBrand,
          )
        addDomEventListener(input, "focus", onFocus)
        addDomEventListener(input, "blur", onBlur)
        Some(
          () => {
            removeDomEventListener(input, "focus", onFocus)
            removeDomEventListener(input, "blur", onBlur)
          },
        )
      }
    | None => None
    }
  }, (focusTarget, keys.iframeId, parentURL, elementType, cardProps.cardBrand))

  {localeString, cardProps, expiryProps, cvcProps}
}

let useCardNumberField = (
  ~logger: HyperLoggerTypes.loggerMake,
  ~onInitiateConfirm: confirmHandlerArgs => unit,
  ~confirmTriggerKey="initiate-confirm",
  /* both shells flip this on — raw SAD rides their per-field port. Bundled users
     (CardsSDK, RawCardCollector) keep FALSE so their emission stays window-only. */
  ~dualPlane=false,
  (),
): cardFieldState => {
  useCardFieldBase(
    ~logger,
    ~paymentType=CardThemeType.CardNumberElement,
    ~inputRef=CardThemeType.CardNumberElement,
    ~onInitiateConfirm=Some(onInitiateConfirm),
    ~confirmTriggerKey,
    ~dualPlane,
    (),
  )
}

let useCardExpiryField = (
  ~logger: HyperLoggerTypes.loggerMake,
  ~onInitiateConfirm: option<confirmHandlerArgs => unit>=None,
  ~confirmTriggerKey="initiate-confirm",
  ~dualPlane=false,
  (),
): cardFieldState => {
  useCardFieldBase(
    ~logger,
    ~paymentType=CardThemeType.CardExpiryElement,
    ~inputRef=CardThemeType.CardExpiryElement,
    ~onInitiateConfirm,
    ~confirmTriggerKey,
    ~dualPlane,
    (),
  )
}

let useCardCvcField = (
  ~logger: HyperLoggerTypes.loggerMake,
  ~onInitiateConfirm: confirmHandlerArgs => unit,
  ~confirmTriggerKey="initiate-confirm-cvc",
  ~cardBrandOverride="",
  ~dualPlane=false,
  (),
): cardFieldState => {
  useCardFieldBase(
    ~logger,
    ~paymentType=CardThemeType.CardCVCElement,
    ~inputRef=CardThemeType.CardCVCElement,
    ~onInitiateConfirm=Some(onInitiateConfirm),
    ~confirmTriggerKey,
    ~cardBrandOverride,
    ~dualPlane,
    (),
  )
}

/* ReScript allows one `@react.component` per module, so each renderer lives in its own
   `*Renderer` submodule. */
module RenderCardNumber = {
  @react.component
  let make = (~state: cardFieldState) => {
    let {themeObj} = Jotai.useAtomValue(configAtom)
    let numberPlaceholder =
      Jotai.useAtomValue(cardNumberPlaceholder)->Option.getOr("1234 1234 1234 1234")
    let {isCardValid, cardNumber, changeCardNumber, handleCardBlur, cardRef, cardError, maxCardLength, icon, setIsCardValid} = state.cardProps
    <div
      className="animate-slowShow flex flex-col"
      style={{gridGap: "0px", height: themeObj.cardFieldHeight}}>
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
      style={{gridGap: "0px", height: themeObj.cardFieldHeight}}>
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
      style={{gridGap: "0px", height: themeObj.cardFieldHeight}}>
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
