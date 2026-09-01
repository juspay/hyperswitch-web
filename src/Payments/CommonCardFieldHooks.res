// Shared plumbing for standalone per-field card inputs (Phase 1a vault fields;
// reused by Phase 2 PaymentsV2 fields). Each `use*Field` hook owns:
//   1. `useCardForm` mount (formatting, validity, brand detection),
//   2. `ready` emit once the parent's `iframeId` arrives,
//   3. a per-field doFocus/doBlur postMessage listener (the shared
//      `useCardForm` handler targets `cardRef`, which is unbound in
//      single-input iframes),
//   4. an `initiate-confirm` postMessage listener that packages the current
//      form state and hands it to the surface-specific injected handler,
//   5. `CardCollectorBridge.useEmitCardState` so `fieldHandle.on("change")`
//      sees a coherent snapshot.
//
// Surface divergence (vault tokenisation vs hosted-fields relay) is injected
// via `~onInitiateConfirm`, keeping this module atom-free. Renderers live
// under `Render.*` so per-field components stay one-liners.
open JotaiAtoms
open Utils

// Local DOM-event bindings — `CommonHooks.addEventListener` targets the
// opaque `Window.element` type which doesn't unify with `Dom.element` (the
// type of `React.ref` contents we hold). Inline externals sidestep the
// module-mismatch without a wider refactor.
@send external addDomEventListener: (Dom.element, string, Dom.event => unit) => unit = "addEventListener"
@send external removeDomEventListener: (Dom.element, string, Dom.event => unit) => unit = "removeEventListener"

// Per-field confirm-relay handler input. The LOCAL cardNumber/expiry/cvc
// fields reflect this iframe's own `useCardForm` state — for the cardNumber
// iframe (which OWNS confirm), only its `cardNumber` local is populated; the
// sibling values (cardExpiry, cvcNumber) come in via the outer group's
// `initiate-confirm` payload, which carries the latest cached per-field
// state the group aggregated from each field's `cardStateUpdate` stream.
// We prefer the external (group-supplied) values when present, falling back
// to the local state so single-iframe surfaces (e.g. saved-card CVC) still
// work unchanged.
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
  // Payments-surface saved-card flow (Flow B): the merchant supplies the
  // saved card's `payment_token` per selected card via
  // `cardForm.create("cardCvc", {savedCard: {token, brand}})`. The outer
  // group is the only place that knows it (the iframe only ever learns the
  // BRAND for length-validation), so it rides the confirm-relay payload —
  // same channel the aggregated sibling raw values use. Empty string when
  // the mounted field set isn't a saved-card recollect (Flow A).
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

// PR 4: per-field `formStatusChange` aggregated-status emission.
//
// The plan §4.3 group-event contract asks the outer group to surface FIVE
// form-status states per field — `complete | incomplete | invalid | focused |
// blurred`. The legacy subscription-event pipeline (`SubscriptionEventHooks.
// useEmitFormStatus` + `PaymentEventData.computeFormStatus`) only carries
// three (`empty | filling | complete`), and is also gated on the merchant
// opting into `subscriptionEvents` — neither suits the V2 group's ALWAYS-ON
// aggregation, nor does it surface invalid/focused/blurred. PR 4 therefore
// introduces a sibling emission keyed on a NEW postMessage event name
// (`formStatusChange`) that the outer group's per-field listener merges into
// its own `on("formStatusChange")` surface.
//
// Status mapping (locked to §4.3 + PR 4 spec):
//   - "empty" → incomplete  (no user input yet)
//   - "filling" → incomplete (some input, isValid not yet Some(true))
//   - "complete" → complete (isValid = Some(true) AND value non-empty)
//   - invalid → invalid (isValid = Some(false))
//   - focus/blur transitions surface as "focused" / "blurred" (one-shot)
// v22 (P2): the status canon moved to `CardFormShared`; aliased + opened
// below so the 5-state vocabulary above stays the documented FSM and the
// constructor matches in `computeFieldFormStatus` keep their bare spelling.
open CardFormShared

type fieldFormStatus = CardFormShared.fieldFormStatus

let fieldFormStatusToString = CardFormShared.fieldFormStatusToString

// Compute the aggregate (non-focus/blur) status from the live form state.
// Pure: reads current isValid + value and returns what the group's FSM would
// label this field as. Focus/blur are tracked separately via DOM listeners.
let computeFieldFormStatus = (~isValid: option<bool>, ~value: string): fieldFormStatus =>
  switch isValid {
  | Some(false) => Invalid
  | Some(true) => value === "" ? Incomplete : Complete
  | None => Incomplete
  }

// Emit `formStatusChange` upstream. `message` is the current error string
// (set when status=invalid; otherwise omitted). `cardBrand` is forwarded so
// the group's payload can carry brand context without a second request.
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
  | Some(m) if m !== "" => baseFields->Array.concat([("message", m->JSON.Encode.string)])
  | _ => baseFields
  }
  messageParentWindow(fields, ~targetOrigin=parentURL)
}

// All three fields share the same base machinery; only paymentType, the ref
// used for focus/blur, the elementType emitted on ready, and the confirm
// trigger name differ.
let useCardFieldBase = (
  ~logger: HyperLoggerTypes.loggerMake,
  ~paymentType: CardThemeType.mode,
  ~inputRef: CardThemeType.mode,
  // Optional: when absent, no confirm-listener is registered. Expiry passes
  // nothing (the card-number iframe owns confirm for new-card flow); number
  // and saved-card CVC always pass their vault-specific handler.
  ~onInitiateConfirm: option<confirmHandlerArgs => unit>,
  // Vault card-number confirm uses `"initiate-confirm"`; the saved-card CVC
  // relay uses `"initiate-confirm-cvc"` (see PaymentMethodsSessionGroup).
  ~confirmTriggerKey="initiate-confirm",
  ~cardBrandOverride="",
  // MessageChannel Card Relay (P0.3): when true, this field's FULL state
  // snapshot rides its MessageChannel port to the hidden coordinator (raw SAD
  // on the port plane only; the merchant-window plane gets the SPLIT payload
  // from CardFormPortProtocol.encodeFieldStateUpdate). The port side key is
  // derived from the iframe's own `groupId` URL param (embedded by the
  // mounting group). Bundled collectors never pass this flag — they stay
  // byte-frozen on the legacy path.
  ~dualPlane=false,
  (),
): cardFieldState => {
  let {localeString} = Jotai.useAtomValue(configAtom)
  let setShowPaymentMethodsScreen = Jotai.useSetAtom(showPaymentMethodsScreen)

  // Per-field iframes must opt into live cardBrand tracking the same way the
  // bundled collector does (CardsSDK.res). Without this,
  // `CardUtils.getCardBrandFromStates` (called inside `useCardForm`) reads the
  // frozen `cardScheme` Jotai atom — which nothing in a standalone per-field
  // iframe ever writes — and the brand icon never re-renders as the user
  // types. Setting the flag flips the derivation to the live React-state
  // `cardBrand`, which `useCardForm` updates on every keystroke. Each iframe
  // has its own Jotai store, so this write is scoped to this field's iframe.
  // Safe for the saved-card CVC flow: `cardBrandOverride` short-circuits the
  // derived brand before `getCardBrandFromStates` is consulted.
  React.useEffect0(() => {
    setShowPaymentMethodsScreen(_ => true)
    None
  })

  // MessageChannel Card Relay: the port key for this field. The mount-target
  // group's DOM contract carries `groupId` into the field iframe URL; the
  // group forwards port2 WITH the mount-config transfer, keyed
  // `${groupId}:${fieldName}` (see CardFormCoordinator.portKey).
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

  // Registry bump — the port is ingested by LoaderController on mount-config
  // arrival; this effect rewires when the registry gains the key.
  let (registryVersion, setRegistryVersion) = React.useState(() => 0)
  React.useEffect0(() => {
    let bump = () => setRegistryVersion(v => v + 1)
    SadPortRegistry.addChangeListener(bump)
    Some(() => SadPortRegistry.removeChangeListener(bump))
  })

  // Port-plane BRAND relay: the coordinator posts
  // `detectedCardBrand` frames (payload = brand string) onto cardNumber's
  // sibling cvc port. Saved-card override (`cardBrandOverride` arg) wins.
  let (portBrandOverride, setPortBrandOverride) = React.useState(_ => "")
  let effectiveCardBrandOverride = if cardBrandOverride !== "" {
    cardBrandOverride
  } else {
    portBrandOverride
  }

  let {cardProps, expiryProps, cvcProps, blurState: _} = CommonCardProps.useCardForm(
    ~logger,
    ~paymentType,
    // Standalone per-field iframes run their own eligibility probe — no outer
    // ParentCardComponent to answer the support/eligibility queries.
    ~runEligibility=false,
    ~logControlEvents=false,
    ~cardBrandOverride=effectiveCardBrandOverride,
  )

  let keys = Jotai.useAtomValue(keys)
  let {parentURL} = keys

  // Merchant-facing `fieldHandle.on("ready", cb)` — fire once the mount-config
  // has propagated (iframeId non-empty ⇒ parent finished handshake).
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

  // Per-field doFocus/doBlur — `useCardForm`'s shared handler only sets a
  // visual blur class on its own input and doesn't touch the DOM element in
  // this iframe. We need real DOM focus/blur so `fieldHandle.focus()` /
  // `fieldHandle.blur()` match merchant expectations.
  let focusTarget = switch inputRef {
  | CardThemeType.CardNumberElement => cardProps.cardRef
  | CardThemeType.CardExpiryElement => expiryProps.expiryRef
  | CardThemeType.CardCVCElement => cvcProps.cvcRef
  | _ => cardProps.cardRef
  }
  React.useEffect(() => {
    let handleFun = (ev: Window.event) => {
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
    handleMessage(handleFun, "")
  }, (focusTarget, parentURL))

  // SINGLE doFocus handler, DUAL-BOUND: the SAME focusRef fires for the
  // legacy window-posted `doFocus` (above) AND for the relay's port frame
  // `{cardFormPortV, kind: "doFocus"}` (below). Port detects the channel via
  // the registry key LoaderController absorbed from the mount-config
  // transfer; registryVersion braces us for the ingest race.
  React.useEffect(() => {
    if portKey !== "" {
      switch SadPortRegistry.getPort(~key=portKey) {
      | Some(port) =>
        MessageChannelBinding.onPortMessage(port, ev => {
          let data: JSON.t = ev.data->Identity.anyTypeToJson
          switch CardFormPortProtocol.decodePortFrame(data) {
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

  // Confirm relay. The merchant-page group's `confirm()` posts the trigger
  // name into this iframe; we package the live form state and hand it to the
  // `onInitiateConfirm` handler.
  // Keeping this a useEffect (not useCallback) lets a
  // `cardNumber` change re-register the listener with the latest closure —
  // same pattern the bundled collector uses via `useSubmitPaymentDataFromParent`.
  //
  // NEVER conditionally call a React hook — hoist the option
  // switch INSIDE the effect body so hook-order is stable across renders.
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

  // Emit state upstream — powers `fieldHandle.on("change", ...)` and the
  // confirm flow. We re-use the same shape as the bundled collector so
  // downstream listeners don't need to distinguish per-field vs bundled.
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
  // v20 Chunk 2 rework — keystroke-level focus-readiness, computed HERE in
  // the iframe (where the keystrokes land and the timing decision belongs),
  // not inferred by the group from `fieldStatus.complete` transitions.
  //   cardNumber → CardUtils.focusCardValid: brand-aware max length AND Luhn.
  //                This is the exact semantic the legacy bundled form uses at
  //                CommonCardProps.res:170 to advance card→expiry — one source
  //                of truth, no duplicated heuristics.
  //   cardExpiry → all 4 MMYY digits typed AND the validator is green.
  //   cardCvc    → brand-aware maxCVCLength reached AND the validator is green.
  //                 (Terminal field today — the group ignores the signal for
  //                 cvc→nothing, but emitting keeps the contract symmetric.)
  // The group only routes `doFocus` on the `false → true` edge of this flag.
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
    // Standalone per-field vault/payments iframes: each field's IFRAME is its
    // own trust domain (`?componentName=paymentMethodsSDK&...&surfaceFamily=…`
    // is loaded from the vault/sdk domain), so emitting the raw per-field value
    // upstream to the same-origin parent group is the established channel for
    // cross-iframe confirm aggregation (mirrors `ParentCardComponent`'s
    // bundled `? emitRawCardNumber=true` opt-in for the unified card form).
    // Expiry/CVC specifically MUST emit raw here so the outer group can
    // inject them into the cardNumber iframe's confirm payload — otherwise
    // the confirm body sees empty strings for fields the user filled in a
    // DIFFERENT iframe. Raw cardNumber MUST ride too: with `portKey` active
    // the window payload is stripped by `encodeFieldStateUpdate`, so the
    // ONLY delivery path to the coordinator is the port frame — dropping
    // the PAN here leaves `aggregatedCardNumber` permanently "" and every
    // confirm decays to "Card details incomplete or invalid".
    ~emitRawCardNumber=true,
    ~emitRawCardExpiry=true,
    ~emitRawCvc=true,
    // P0.3 `/port plane`: only fields mounted with a groupId in their URL
    // participate; empty → byte-frozen legacy path.
    ~portKey,
  )

  // ── PR 4: formStatusChange emission ─────────────────────────────────────
  // Watch the field's relevant isValid + value and re-emit the aggregated
  // status when either changes. We do NOT key on `complete`/`empty` directly
  // because those are derived from isValid+value — keying on the sources
  // means the status effect re-fires exactly once per validity transition.
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

  // Focus/blur transitions are one-shot (not status-latched) — we attach
  // native DOM listeners on the field's input ref so we don't fight
  // `useCardForm`'s shared focus/blur handler. These fire the *focused* and
  // *blurred* one-shot statuses which the outer group merges into its
  // per-field FSM (returning to complete/incomplete/invalid on next input).
  // Bound via local @send externals because the `Dom.element` reference held
  // by `focusTarget` does not unify with the `Window.element` type
  // `CommonHooks.addEventListener` expects (existing module mismatch).
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
  // Vault (Phase 1a) defaults to `"initiate-confirm"`; payments-V2 passes
  // `"initiate-payment-confirm"` so the parent group's doSubmit broadcast
  // triggers this field's confirm relay (Phase 2 PR 3 will wire the actual
  // `confirmPaymentWrapper` call inside the V2 handler).
  ~confirmTriggerKey="initiate-confirm",
  // MessageChannel Card Relay (P0.3): both shells flip this on — raw SAD
  // rides their per-field port; bundled users (`CardsSDK`, `RawCardCollector`)
  // keep the default FALSE so their legacy emission stays byte-frozen.
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
  // Symmetric with `useCardNumberField`; payments-V2 expiry does not own
  // confirm today, but keeping the trigger key overridable avoids a future
  // shape change if the group ever delegates confirm to expiry.
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

// Thin renderers — per-field JSX is parameterised by which sub-record of
// cardFieldState to bind, so the host components stay one-liners. ReScript
// allows one `@react.component` per module, hence each renderer lives in its
// own submodule (named `*Renderer`).
module RenderCardNumber = {
  @react.component
  let make = (~state: cardFieldState) => {
    let {themeObj} = Jotai.useAtomValue(configAtom)
    let numberPlaceholder = Jotai.useAtomValue(cardNumberPlaceholder)
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
    let expiryPlaceholder = Jotai.useAtomValue(cardExpiryPlaceholder)
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
    let cvcPlaceholder = Jotai.useAtomValue(cardCvcPlaceholder)
    let {isCVCValid, cvcNumber, changeCVCNumber, handleCVCBlur, cvcRef, cvcError, maxCVCLength, setIsCVCValid} = state.cvcProps
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
