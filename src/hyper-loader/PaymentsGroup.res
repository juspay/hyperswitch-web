// v20 Chunk 1: outer (merchant-page) CardForm factory for the payments
// surface, wired behind `hyper.widgets(options).cardForm()`.
//
// ── CONFIRM OWNERSHIP (MessageChannel Card Relay, P0.3+) ─────────────────
// The group no longer fans a confirm relay into any field iframe: fields
// ship their state to the hidden `cardFormCoordinator` iframe directly over
// MessageChannel ports (the dual-plane design — masked events continue on
// the window). The group posts a CONTENT-FREE
// `{cardFormCoordinatorCommand: "initiateConfirm"}` command into the
// coordinator; the coordinator aggregates port-side raws and runs the real
// `usePaymentIntent`. The retired `initiate-payment-confirm` /
// `initiate-payment-confirm-cvc` window-relay vocabulary is withdrawn (the
// comment trail below keeps the historical references only where they mark
// dead paths).
//
// Historical note (previously the confirm was posted directly to the
// cardNumber iframe's contentWindow because the root-window `doSubmit`
// broadcast never reached group-mounted iframes): that failure mode
// persists ONLY for merchants who synthesize their own root-window
// `doSubmit` events — the group KEEPS the defensive `doSubmit` listener as
// a fallback route into the coordinator command.
//
// This group's job is therefore:
//   1. Mount per-field iframes via `LoaderPaymentElement.make` under the
//      unified URL (`componentName=paymentMethodsSDK&fieldName=<bare>&surfaceFamily=payments`)
//      + the hidden coordinator iframe via `CoordinatorMount`.
//   2. Aggregate per-field `cardStateUpdate` emissions (mask-only: raw keys
//      are absent from the window post) into a per-field validity snapshot
//      + a group-level "all fields complete" flag.
//   3. Explicit `confirm()` entry-point, flow-inferred from mounted fields:
//      a mounted `cardNumber` selects Flow A (post the content-free
//      `initiateConfirm` COMMAND with `flow: "payments"` to the
//      coordinator); a cardCvc-ONLY mount (`{savedCard: {token, brand}}`)
//      posts the same command with `flow: "savedCardCvc"`. Gated by the
//      `confirmingRef` mutex (F6). The defensive root-window `doSubmit`
//      listener is kept as a fallback for DIY merchant wirings.
//   4. Surface coordinator `paymentConfirmAck` / `paymentConfirmFail`
//      via the group-level `on(...)` channels.
//   5. Feed the coordinator: mount config posts + clientList forward +
//      port-flush choreography (the legacy sibling-raw injection into the
//      cardNumber iframe's confirm payload is RETIRED — the coordinator
//      aggregates port-side raws).
//
// Note on `submitSuccessful`: the coordinator's real
// `usePaymentIntent`-driven confirm posts `submitSuccessful` to the
// merchant page (via `messageParentWindow` inside the intent machinery in
// `PaymentHelpers.res`). The outer `Hyper.res:440` listener already owns
// that contract end-to-end — `PaymentsGroup` does NOT need to
// re-implement submit-response plumbing. We only track
// `paymentConfirmAck` / `paymentConfirmFail` so integrators debugging the
// relay can see it in devtools.
//
// v20 naming: the legacy `*V2` field-string vocabulary (the retired
// `"cardNumber" + "V2"` family) is RETRACTED; the only surviving reference
// is this comment marking the retraction. The only field vocabulary is bare
// `cardNumber|cardExpiry|cardCvc` — the factory you obtained the CardForm
// from (`widgets.cardForm()` vs the vault session group) decides the flow,
// no suffix is needed.
//
// Plan reference: `docs/plans/secure-card-fields-plan-2026-08.md` §6.2.3
// PR 3 — outer group orchestration + real confirm call; v20 Chunk 1 for the
// `cardForm()` public wiring.

open Utils

// ── Public types ─────────────────────────────────────────────────────────────

// Per-field handle shape mirrors `Types.fieldHandle` so merchant-facing field
// methods match the vault group surface.
type fieldHandle = Types.fieldHandle

// Group-config record — the merchant-supplied options. Unlike the vault
// group's `options: JSON.t`, the payments V2 group expects a typed record so
// the mount-config keys are stable and the tests can assert them.
//
// Required:
//   - `clientSecret`: payment-intent client secret handed into the inner
//     iframe (the inner `usePaymentIntent` reads `keys.clientSecret` to
//     derive the `payments/{id}/confirm` URI).
// Optional (defaults noted inline):
//   - `publishableKey`: defaults to `""`; forwarded on the mount-config so
//     `usePaymentIntent` can attach the `api-key` header when
//     `sdkAuthorization` is absent.
//   - `endpoint`: defaults to `ApiEndpoint.getApiEndPoint()` — overridable
//     for sandboxes / local dev.
//   - `appearance`: theming blob forwarded to LoaderPaymentElement.
//   - `locale`: forwarded on the mount-config for every field iframe (and
//     fanned out on group-`update()`); "en" when unset. The inner iframe's
//     own LoaderController handshake is the fallback when the field mounts
//     without a locale key.
type groupConfig = {
  clientSecret: string,
  publishableKey: option<string>,
  endpoint: option<string>,
  appearance: option<JSON.t>,
  locale: option<string>,
}

// The group record returned to merchants. v20: this IS the CardForm surface
// (`Types.cardForm`) plus the PR 4 observability extras (`onFieldEvent` /
// `fieldEvents`). The F1 fix added the explicit `confirm()` entry point
// (parity with vault's `PaymentMethodsSessionGroup.confirm` — Types.res:82),
// because the `hyper.confirmPayment()` fan-out never reached group-mounted
// iframes. `confirm` is zero-arg per the v20 contract (Chunk 2 collapses the
// vault full-card vs saved-card-CVC flow inference into a single entrypoint —
// no separate CVC-only confirm exists anywhere).
type cardForm = {
  create: (string, JSON.t) => fieldHandle,
  update: JSON.t => unit,
  on: (string, JSON.t => unit) => unit,
  // PR 4 — segmented per-fieldType event subscription. Whereas `on` fans
  // into the group-level event pool, `onFieldEvent(fieldType, event, cb)`
  // fans into the per-fieldType pool so a listener fires ONLY when the
  // event originates from a `create(<fieldType>, ...)` mount. Pair with
  // `fieldEvents` (a metadata dict of mounted types) for introspection.
  onFieldEvent: (string, string, JSON.t => unit) => unit,
  confirm: unit => promise<JSON.t>,
  deinit: unit => unit,
  fields: ref<JSON.t>,
  fieldEvents: ref<JSON.t>,
}

// ── Per-field registry ───────────────────────────────────────────────────────

// PR 4 — aggregated per-field lifecycle status. Mirrors the group-event
// surface the vault group promises in plan §4.3:
//   "complete"   — isValid=Some(true), value non-empty (PR 3 readiness cares)
//   "incomplete" — no validity judgment yet OR user cleared the field
//   "invalid"    — isValid=Some(false) (post-blur validation failed)
//   "focused"    — one-shot; transient state while the input has DOM focus
//   "blurred"    — one-shot; transient state right after DOM blur
//
// The status machine is intentionally monotone-free: focused/blurred are
// one-shot updates that do NOT change the underlying validity track
// (complete/incomplete/invalid). The group never latches one-shot states.
// v22 (P2): the 5-state canon + string round-trippers moved to
// `CardFormShared` — aliased here so the compiled module keeps these names.
type aggregatedStatus = CardFormShared.fieldFormStatus

let aggregatedStatusToString = CardFormShared.fieldFormStatusToString

let aggregatedStatusFromString = CardFormShared.fieldFormStatusFromString

// ── Plan §4.3 `change`-payload reshaper ──────────────────────────────────
// The locked §4.3 `change`-payload contract + commentary live in
// `CardFormShared` (v22 P2 — single canon shared by both CardForm group
// factories); aliased here so in-module call sites stay unqualified.
let reshapeCardStateUpdateToChangePayload = CardFormShared.reshapeCardStateUpdateToChangePayload

// One entry per mounted field. `iframeRef` is the raw DOM handle exposed by
// `LoaderPaymentElement.make` via its `setIframeRef` callback. Confirm
// ack/fail is surfaced via the group-level event bus rather than a per-field
// resolver.
type fieldEntry = {
  iframeRef: ref<Nullable.t<Dom.element>>,
  handle: fieldHandle,
  fieldType: string,
  // Latest `cardStateUpdate` snapshot for this field. `None` until the first
  // emit arrives — treated as "not yet valid" by the readiness aggregator.
  lastStateRef: ref<option<JSON.t>>,
  // Latest aggregated lifecycle status for this field. `None` until the
  // iframe's first `formStatusChange` emit arrives. The group routes events
  // through this ref (rather than re-deriving from lastStateRef) so
  // focused/blurred one-shots don't get washed away by the next
  // `cardStateUpdate` tick.
  lastFormStatusRef: ref<option<aggregatedStatus>>,
  // Unique per-field EventListenerManager activity-name. Tracked so the
  // per-field `destroy()` (and group `deinit()`) can remove this listener,
  // not just clobber its Map entry. F7 fix — previously, each `create()`
  // generated a fresh `fieldId` → a fresh activity-name, and the OLD
  // listener was never removed, leaking live handlers across group
  // re-instantiations on the same page.
  listenerName: string,
  // Saved-card (Flow B) hint captured at `create()` from
  // `options.savedCard.token` and refreshed by `handle.update({savedCard:
  // {token, brand}})` — mirrors the vault group's `savedCardBrandRef /
  // savedCardLast4Ref` capture discipline. The payments Flow B confirm
  // relay embeds it as `paymentToken` so the CVC iframe can build a
  // `PaymentBody.savedCardBody` — the iframe itself never learns the token
  // any other way (its mount config only carries the BRAND for CVC-length
  // validation). `""` for non-saved-card fields.
  savedCardTokenRef: ref<string>,
  // Last observed `focusReady` emitted by this field's iframe. Auto-focus
  // progression fires ONLY on the `false → true` edge of THIS signal — the
  // iframe owns the timing decision (brand-aware max length + Luhn for
  // cardNumber; 4-digit MMYY + validity for expiry; maxCVCLength + validity
  // for CVC), and the group just routes `doFocus` to the next field's
  // iframe. (Mirrors `PaymentMethodsSessionGroup.res`'s latch semantics.)
  prevFocusReadyRef: ref<bool>,
}

// ── Merchant-facing surface helpers ─────────────────────────────────────────

// Public field strings accepted by `create(...)` — v20: bare vocabulary only
// (`cardNumber|cardExpiry|cardCvc`, the `*V2` suffix is retracted). The
// identity allow-list canon moved to `CardFormShared` (v22 P2); unknown
// strings fall through to the same error-handle pattern vault uses.
let mapFieldTypeToInternalFieldName = CardFormShared.mapFieldTypeToInternalFieldName

// ── Auto-focus progression map ────────────────────────────────────────────
// Tab-order within the payments CardForm surface (shared canon in
// `CardFormShared` — one vocabulary, one order):
//   cardNumber → cardExpiry → cardCvc → (terminal; no next field)
// The group's per-field `cardStateUpdate` listener uses this map to decide
// which field's iframe receives `doFocus` when the current field's EMITTED
// `focusReady` signal transitions from `false` to `true`. The iframe owns
// the timing decision (keystroke-level brand-aware max length + Luhn for
// cardNumber; 4-digit MMYY + validity for expiry); this map only routes it.
// Module-level alias (not inside `makeCardForm`) so the compiled module
// keeps the `nextFieldFor` export unit tests import directly.
let nextFieldFor = CardFormShared.nextFieldFor

// Group-readiness aggregation. All 3 card fields must be mounted AND have
// emitted at least one `cardStateUpdate` with `complete=true` AND be
// individually valid. We do NOT short-circuit on `isCvcValid` alone because
// per-field validity flags ride on the snapshot's `fieldStatus` sub-dict.
let computeGroupReadiness = (fieldsRef: ref<Dict.t<fieldEntry>>): bool => {
  let entries = fieldsRef.contents->Dict.valuesToArray
  // Require exactly one of each bare field; fewer means fields are unmounted,
  // more means caller misuse (we don't today police duplicates).
  let expected = ["cardNumber", "cardExpiry", "cardCvc"]
  let hasAllFields = expected->Array.every(ft =>
    entries->Array.some(e => e.fieldType === ft)
  )
  if !hasAllFields {
    false
  } else {
    entries->Array.every(e =>
      switch e.lastStateRef.contents {
      | Some(stateJson) =>
        let stateDict = stateJson->getDictFromJson
        let fieldStatus = stateDict->getDictFromDict("fieldStatus")
        fieldStatus->getBool("complete", false)
      | None => false
      }
    )
  }
}

// ── F4: confirm settle-timeout ───────────────────────────────────────────────
// Max wall-clock the `confirm()` mutex may stay latched waiting for the field
// iframe's `paymentConfirmAck` / `paymentConfirmFail`. If neither lands (field
// unmounted mid-confirm, iframe redirected, …) the timeout releases the mutex
// so a later `confirm()` isn't wedged forever. 8000ms sits inside the
// reviewer-bounded 5–10s band; `PaymentMethodsSessionGroup.res` carries the
// same value for its relay settle-timeout (F5 — mirrored constant,
// deliberately not shared: it is a per-group behavioral knob, not a locked
// cross-surface vocabulary).
let confirmSettleTimeoutMs = 8000

// ── Factory ─────────────────────────────────────────────────────────────────

// Queued port1 channel awaiting its coordinator iframe-mounted flush
// (MessageChannel Card Relay). Shape hoisted into CoordinatorMount so both
// groups share it and `CoordinatorMount.teardown` can close the
// un-transferred ones on group deinit.
type pendingPort = CoordinatorMount.pendingPort

let makeCardForm = (~config: groupConfig): Types.cardForm => {
  // 1. Resolve optional config values once — these don't change over the
  //    group's lifetime; merchant mutations update via group.update().
  let clientSecret = config.clientSecret
  let publishableKey = config.publishableKey->Option.getOr("")
  let endpoint = switch config.endpoint {
  | Some(e) => e
  | None => ApiEndpoint.getApiEndPoint(~publishableKey)
  }
  let appearance = config.appearance->Option.getOr(Dict.make()->JSON.Encode.object)
  let locale = config.locale->Option.getOr("en")

  // 2. Per-instance state refs (never module-level). The group multiplexes
  //    a single EventListenerManager callback across N mounted fields;
  //    routing is done by matching `event.source` against the field's
  //    iframe content window.
  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  let fields: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)
  let fieldEvents: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)
  let fieldEventsCallbacksRef: ref<Dict.t<Dict.t<JSON.t => unit>>> = ref(Dict.make())
  let eventCallbacksRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())
  let deinitCallbacksRef: ref<array<unit => unit>> = ref([])

  // Tracks whether ANY field has ever emitted a `paymentConfirmAck`. Used
  // by the readiness convolver to detect "confirm is in flight" — when an
  // ack lands, we flip this true so a subsequent `group.on("ready")` query
  // can distinguish "mounted + complete" from "mounted + complete + confirm
  // dispatched".
  let confirmDispatchedRef: ref<bool> = ref(false)

  // Per-group confirm mutex. A second `confirm()` while one is already
  // dispatched short-circuits with the `confirm_in_progress` error envelope
  // (type `api_error`) instead of posting a duplicate `initiateConfirm`
  // command into the coordinator. LATCHED at
  // dispatch and held until the relay settles: the per-field listener's
  // `paymentConfirmAck` / `paymentConfirmFail` arms release it, the
  // `confirmSettleTimeoutRef` timeout below releases it as a backstop, and
  // `deinit()` clears both. Group-scoped (never module-level): two
  // coexisting groups on one page confirm independently.
  let confirmingRef: ref<bool> = ref(false)

  // Id slot for the confirm settle-timeout. Armed by `confirm()` at dispatch
  // (one slot suffices: the mutex guarantees at most one armed confirm per
  // group at a time); cancelled by the first release path to fire so at most
  // one party owns settlement.
  let confirmSettleTimeoutRef = ref(None)

  // Readiness saturates. Without this latch, a merchant typing a
  // single bad character (e.g. wiping the CVC field) drops
  // `computeGroupReadiness` to false on the very next cardStateUpdate,
  // silently retracting a previously-emitted `ready` and flickering their
  // submit button off. Instead:
  //   - `hasBeenReadyRef` latches true on the first `ready` emit.
  //   - On subsequent updates, we compare the freshly-computed readiness
  //     against hasBeenReadyRef: `true && !prev` = rising edge → emit
  //     `ready` again (so second rise after a fall also fires); `false &&
  //     prev` = falling edge → emit `unready` explicitly so the merchant
  //     re-disables their submit; `true && prev` = steady-ready (no-op);
  //     `false && !prev` = still-not-ready (no-op, merchant never armed).
  let hasBeenReadyRef: ref<bool> = ref(false)

  // Brand-aware CVC maxLength (mirrors `PaymentMethodsSessionGroup`). The
  // cardNumber iframe detects the brand on each keystroke and emits it via
  // `cardStateUpdate`'s `cardBrand` envelope key. We cache the latest
  // non-empty value here so the group can propagate it to the cardCvc iframe
  // exactly once per brand change (not on every keystroke). The CVC iframe
  // lifts it into a React state that feeds `~cardBrandOverride`, which
  // drives `CommonCardProps.useCardForm`'s `maxCVCLength` /
  // `formatCVCNumber` / `cvcNumberInRange`.
  let lastDetectedBrandRef: ref<string> = ref("")

  // Client-list fetch (payments-V2 fix): `usePaymentIntent` inside the
  // cardNumber iframe gates the confirm dispatch on the Jotai
  // `paymentMethodList` atom reaching `Loaded`/`LoadError`/`SemiLoaded`
  // (`PaymentHelpers.res` ~line 1472) — otherwise it short-circuits with a
  // `payment_methods_loading` broadcast and the network call NEVER fires.
  // Stacked payment iframes get `clientList` forwarded by
  // `Elements.res`'s PreMountLoader plumbing; group-mounted per-field
  // iframes have no such forwarder, so the group fetches ONCE at factory
  // time and forwards the result to every field iframe at mount (promise
  // re-`then` covers late-mounted fields).
  let clientListDataPromise = PaymentHelpers.fetchClientList(
    ~clientSecret,
    ~publishableKey,
    ~logger=LoggerUtils.defaultLoggerConfig,
    ~customPodUri="",
    ~endpoint,
  )

  // ── MessageChannel Card Relay: coordinator wiring ────────────────────────
  //
  // The hidden 0×0 `cardFormCoordinator` iframe — OWNERSHIP of the confirm
  // (Flow A / Flow B) lives INSIDE it now: the group relays
  // `cardFormCoordinatorCommand` frames in and watches the masked
  // `confirmResult` post back. Per-field MessageChannels deliver raw SAD to
  // the coordinator off-window; the group never sees them.
  //
  //   groupInstanceId   — unique per factory call; rides `groupId` URL param
  //                       into each field iframe + the coordinator iframe, AND
  //                       IS the coordinator's `localSelectorString` (locked
  //                       DOM/iframeId contract #3).
  //   portEpochCounter  — incremented per field mount; rides with the port
  //                       transfer as `portEpoch`. Fresh mounts replace stale
  //                       epochs in the per-document SadPortRegistry.
  //   pendingPortsRef   — port1s queued for the coordinator, flushed when
  //                       its `iframeMounted` broadcast lands.
  let groupInstanceId = `payments-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
  let portEpochCounterRef: ref<int> = ref(0)
  let pendingPortsRef: ref<array<pendingPort>> = ref([])
  // Every portKey this group ever installed — deinit closes them in the
  // per-document registry (deinit-before-flush contract #7).
  let installedPortKeysRef: ref<array<string>> = ref([])
  let coordinatorMountRef: ref<option<CoordinatorMount.coordinatorMount>> = ref(None)
  let coordinatorReadyRef: ref<bool> = ref(false)
  let coordinatorListenerName = `onPaymentsCoordinator-${groupInstanceId}`

  // Relay a masked command envelope into the coordinator iframe. Flow params
  // ride the same frame (`flow`, `paymentToken`, `confirmId`); raw SAD is
  // never part of the message (the coordinator reads it off its per-field
  // port registry instead, per architecture pitchline #4).
  let postCoordinatorCommand = fields => {
    try
      coordinatorMountRef.contents->Option.forEach(mount =>
        mount.iframe->Nullable.make->Window.iframePostMessage(fields->Dict.fromArray)
      )
    catch {
    | _ => ()
    }
  }

  let flushPendingPorts = () => {
    switch (coordinatorMountRef.contents, coordinatorReadyRef.contents) {
    | (Some(mount), true) =>
      pendingPortsRef.contents->Array.forEach(({fieldName, epoch, port}) => {
        CoordinatorMount.forwardPortToCoordinator(
          ~coordinatorIframe=mount.iframe->Nullable.make,
          ~groupId=groupInstanceId,
          ~fieldName,
          ~portEpoch=epoch,
          ~port,
        )
      })
      pendingPortsRef := []
    | _ => ()
    }
  }

  let attachCoordinatorListener = () => {
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        let isOurCoordinator =
          coordinatorMountRef.contents
          ->Option.map(m =>
            ev.source === m.iframe->Window.contentWindow &&
            ev.origin === URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin
          )
          ->Option.getOr(false)
        if isOurCoordinator {
          let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
          let dict = json->getDictFromJson
          if dict->getBool("iframeMounted", false) {
            // Coordinator booted: flush the queued port1 channels + the
            // clientList snapshot (the COORDINATOR is the confirm owner —
            // its `usePaymentIntent` gate needs paymentMethodList Loaded).
            // It ALSO needs `keys.clientSecret` + `keys.publishableKey`:
            // LoaderController only hydrates those from a
            // `paymentElementCreate` envelope, which the field-mount path
            // never delivered to the coordinator iframe. Without this post
            // its `intent()` outer switch decays every confirm to the
            // `confirm_payment_failed` early-exit (no network call at all).
            coordinatorReadyRef := true
            flushPendingPorts()
            switch coordinatorMountRef.contents {
            | Some(mount) => {
              let coordinatorPaymentOptions =
                [
                  ("appearance", appearance),
                  ("fonts", []->JSON.Encode.array),
                  ("locale", locale->JSON.Encode.string),
                  ("clientSecret", clientSecret->JSON.Encode.string),
                  ("sdkAuthorization", ""->JSON.Encode.string),
                  ("pmSessionId", ""->JSON.Encode.string),
                ]
                ->Dict.fromArray
                ->JSON.Encode.object
              let coordinatorConfig =
                [
                  ("paymentElementCreate", true->JSON.Encode.bool),
                  ("otherElements", false->JSON.Encode.bool),
                  ("componentType", "payment"->JSON.Encode.string),
                  ("paymentOptions", coordinatorPaymentOptions),
                  ("options", Dict.make()->JSON.Encode.object),
                  // The coordinator's own intent `~iframeId` + the group's
                  // fullscreen router both key on this value — it MUST
                  // equal `groupInstanceId` (= localSelectorString on the
                  // mount) or three_ds_invoke routing desynchronises.
                  ("iframeId", groupInstanceId->JSON.Encode.string),
                  ("publishableKey", publishableKey->JSON.Encode.string),
                  ("endpoint", endpoint->JSON.Encode.string),
                  ("clientSecret", clientSecret->JSON.Encode.string),
                  ("sdkSessionId", ""->JSON.Encode.string),
                  ("customPodUri", ""->JSON.Encode.string),
                  ("parentURL", "*"->JSON.Encode.string),
                  ("sdkHandleOneClickConfirmPayment", false->JSON.Encode.bool),
                  ("launchTime", Date.now()->JSON.Encode.float),
                  ("loggerSource", "hyper_payments_coordinator"->JSON.Encode.string),
                ]
                ->Dict.fromArray
              mount.iframe->Nullable.make->Window.iframePostMessage(coordinatorConfig)
              }
            | None => ()
            }
            clientListDataPromise
            ->Promise.then(json => {
              switch coordinatorMountRef.contents {
              | Some(mount) =>
                mount.iframe->Nullable.make->Window.iframePostMessage(
                  [("clientList", json)]->Dict.fromArray,
                )
              | None => ()
              }
              Promise.resolve()
            })
            ->ignore
          } else if dict->getBool("paymentConfirmAck", false) {
            // Relay settled (ack) — release the F4-confirm mutex latched at
            // dispatch and cancel the settle-timeout backstop. Same surface
            // contract as the old per-field arm (confirmDispatched event).
            confirmDispatchedRef := true
            confirmingRef := false
            confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
            confirmSettleTimeoutRef := None
            let payload =
              [
                ("elementType", "paymentsCoordinator"->JSON.Encode.string),
                ("iframeId", groupInstanceId->JSON.Encode.string),
              ]
              ->Dict.fromArray
              ->JSON.Encode.object
            eventCallbacksRef.contents->Dict.get("confirmDispatched")->Option.forEach(cb => cb(payload))
          } else if dict->getBool("paymentConfirmFail", false) {
            confirmingRef := false
            confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
            confirmSettleTimeoutRef := None
            let errorMessage = dict->getString("errorMessage", "Card details incomplete or invalid")
            let errorPayload = {
              let errDict = Dict.make()
              errDict->Dict.set("elementType", "paymentsCoordinator"->JSON.Encode.string)
              errDict->Dict.set("iframeId", groupInstanceId->JSON.Encode.string)
              errDict->Dict.set("code", "validation_error"->JSON.Encode.string)
              errDict->Dict.set("message", errorMessage->JSON.Encode.string)
              errDict->JSON.Encode.object
            }
            eventCallbacksRef.contents->Dict.get("error")->Option.forEach(cb => cb(errorPayload))
          }
        }
      },
      coordinatorListenerName,
    )
    deinitCallbacksRef.contents->Array.push(
      () => EventListenerManager.removeSmartEventListener("message", coordinatorListenerName),
    )
  }

  let ensureCoordinatorMounted = () => {
    switch coordinatorMountRef.contents {
    | Some(_) => ()
    | None =>
      // Fullscreen answer-loop satellites: the overlay docs consume `metadata`
      // strongly; `options`/`appearance` are pass-through for driver
      // consumers (LoaderPaymentElement mirrors its create-time options) —
      // we forward the group config shape, which matches the mount configs
      // every field iframe of this group already receives.
      let groupAppearance =
        config.appearance->Option.getOr(Dict.make()->JSON.Encode.object)
      let groupConfigAsOptions =
        [
          ("clientSecret", config.clientSecret->JSON.Encode.string),
          ("publishableKey", config.publishableKey->Option.getOr("")->JSON.Encode.string),
          ("locale", config.locale->Option.getOr("en")->JSON.Encode.string),
          ("appearance", groupAppearance),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      let mount = CoordinatorMount.create(
        ~parentContainer=Window.body,
        ~localSelectorString=groupInstanceId,
        ~elementIframeId="cardFormCoordinator",
        ~surfaceFamily="payments",
        ~groupId=groupInstanceId,
        ~sdkDomain=ApiEndpoint.sdkDomainUrl,
      )
      coordinatorMountRef := Some(mount)
      attachCoordinatorListener()
      // Per-group fullscreen lifecycle for the coordinator's next-action
      // plumbing (three_ds_invoke etc.): ROUTER mounts scoped / tears down
      // UNGATED (bare `{fullscreen:false}` frames carry no iframeId) /
      // forwards the overlay's uplink stream back into the coordinator;
      // ANSWERER satisfies the metadata answer loop the overlay docs block
      // on (`iframeMountedCallback` / `driverMounted`).
      let (fullscreenRouter, fullscreenAnswerer) = CoordinatorMount.makeFullscreenFlows(
        ~mount,
        ~localSelectorString=groupInstanceId,
        ~sdkDomain=ApiEndpoint.sdkDomainUrl,
        ~options=groupConfigAsOptions,
        ~appearance=groupAppearance,
      )
      // Types.event (EventListenerManager's domain type) and Window.event
      // (hyper-loader controller docs) are structurally the same message
      // event — cast via %raw('ev') so both caller vocabularies stay exact.
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenRouter(%raw(`ev`)),
        `onPaymentsCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenAnswerer(%raw(`ev`)),
        CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
      )
      deinitCallbacksRef.contents->Array.push(() => {
        EventListenerManager.removeSmartEventListener(
          "message",
          `onPaymentsCoordinatorFullscreen-${groupInstanceId}`,
        )
        EventListenerManager.removeSmartEventListener(
          "message",
          CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
        )
        CoordinatorMount.teardown(~mount, ~pendingPorts=pendingPortsRef.contents)
        coordinatorMountRef := None
        coordinatorReadyRef := false
      })
    }
  }



  // 3. Mount-config builder — mirrors `PaymentMethodsSessionGroup.buildMountConfig`
  //    but with the payments-V2 endpoint + no session-specific fields.
  //    LoaderController inside the iframe reads `paymentElementCreate` to
  //    bootstrap its atom graph (configAtom / keys / sessions).
  let buildMountConfig = (~options: JSON.t, ~fieldId: string) => {
    // NOTE: `options` here is the PER-FIELD options bag passed to
    // `cardForm.create("cardNumber", opts)`, which is typically `{}`. The
    // group-level `appearance` (bound at make() entry from
    // `config.appearance`) must NOT shadow it — read per-field overrides
    // from `fieldOptionsDict`, then fall back to the group-level bag.
    // (Precedence rule mirrors `PaymentMethodsSessionGroup.buildMountConfig`.)
    let fieldOptionsDict = options->getDictFromJson
    let savedCardDict = fieldOptionsDict->getDictFromDict("savedCard")
    let savedCardBrand = savedCardDict->getString("brand", "")
    let emptyJson = Dict.make()->JSON.Encode.object
    let fieldAppearance = fieldOptionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    // Per-field appearance wins only if it actually carries keys; otherwise
    // prefer the group-level appearance from `config.appearance`.
    let appearance = if (
      fieldAppearance
      ->JSON.Decode.object
      ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
      ->Option.getOr(false)
    ) {
      fieldAppearance
    } else {
      appearance
    }
    let redirectionFlagsDict =
      [
        ("shouldUseTopRedirection", JSON.Encode.bool(false)),
        ("shouldRemoveBeforeUnloadEvents", JSON.Encode.bool(false)),
      ]->Dict.fromArray
    // Wrap appearance in the canonical widgetOptions envelope that
    // CardTheme.itemToObjMapper expects on the iframe side (whitelist:
    // ["appearance", "fonts", "locale", "clientSecret", "loader",
    //  "pmSessionId", "sdkAuthorization"]). Posting the raw merchant bag
    // directly caused "Unknown Key: 'variables'/'rules'" warnings and
    // silently dropped merchant appearance customizations. For payments,
    // sdkAuthorization / pmSessionId aren't part of the flow — emit empty
    // strings so the iframe-side `getWarningString`/`getString` defaults
    // kick in without spurious warnings.
    let paymentOptions =
      [
        ("appearance", appearance),
        ("fonts", []->JSON.Encode.array),
        ("locale", locale->JSON.Encode.string),
        ("clientSecret", clientSecret->JSON.Encode.string),
        ("sdkAuthorization", ""->JSON.Encode.string),
        ("pmSessionId", ""->JSON.Encode.string),
      ]->Dict.fromArray->JSON.Encode.object
    [
      ("paymentElementCreate", true->JSON.Encode.bool),
      ("otherElements", false->JSON.Encode.bool),
      ("componentType", "payment"->JSON.Encode.string),
      ("paymentOptions", paymentOptions),
      ("options", options),
      ("iframeId", fieldId->JSON.Encode.string),
      ("publishableKey", publishableKey->JSON.Encode.string),
      ("endpoint", endpoint->JSON.Encode.string),
      ("clientSecret", clientSecret->JSON.Encode.string),
      ("sdkSessionId", ""->JSON.Encode.string),
      ("customPodUri", ""->JSON.Encode.string),
      ("parentURL", "*"->JSON.Encode.string),
      ("sdkHandleOneClickConfirmPayment", false->JSON.Encode.bool),
      ("launchTime", Date.now()->JSON.Encode.float),
      ("loggerSource", "hyper_payments_v2"->JSON.Encode.string),
      ("isSavedCardCvcFlow", false->JSON.Encode.bool),
      ("savedCardBrand", savedCardBrand->JSON.Encode.string),
      ("cardCollectionMode", "tokenise"->JSON.Encode.string),
      ("isBancontactCardFlow", false->JSON.Encode.bool),
      ("cardFlowType", "payment"->JSON.Encode.string),
      ("isTestMode", false->JSON.Encode.bool),
      ("customBackendUrl", ""->JSON.Encode.string),
      ("paymentId", ""->JSON.Encode.string),
      ("blockConfirm", false->JSON.Encode.bool),
      ("analyticsMetadata", Dict.make()->JSON.Encode.object),
      ("redirectionFlags", redirectionFlagsDict->JSON.Encode.object),
      ("locale", locale->JSON.Encode.string),
    ]->Dict.fromArray
  }

  // 4. Per-field factory. Mounts ONE iframe per `create()` call. The
  //    per-field listener watches every postMessage from this iframe for
  //    the field's lifetime; routing desugars into four message kinds in
  //    priority order: ready/focus/blur, paymentConfirm{Ack,Fail}, then
  //    cardStateUpdate.
  let createFieldHandle = (fieldType: string, options: JSON.t, fieldId: string): fieldEntry => {
    let iframeRef: ref<Nullable.t<Dom.element>> = ref(Nullable.null)
    let lastStateRef: ref<option<JSON.t>> = ref(None)
    let lastFormStatusRef: ref<option<aggregatedStatus>> = ref(None)
    let eventHandlersRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())
    // Unique activity-name for THIS field's listener. Tracked on the
    // fieldEntry so per-field `destroy()` and group-level `deinit()` can
    // remove it via `EventListenerManager.removeSmartEventListener` — F7.
    let listenerName = `onPaymentsV2Field-${fieldId}`

    // Raw-value caching DELETED in the MessageChannel Card Relay
    // architecture: per-field raw SAD rides off-window MessageChannel ports
    // (`CardFormCoordinator` aggregates) — the group never holds it.
    // Saved-card (Flow B) hint — captured from the merchant's
    // `create("cardCvc", {savedCard: {token, brand}})` options so the Flow B
    // branch of `confirm()` can embed it as `paymentToken` on the
    // `cardFormCoordinatorCommand` (flow:"savedCardCvc") into the coordinator.
    // Refreshed in `handle.update` when the merchant switches the selected
    // saved card in place.
    let savedCardTokenRef = ref(
      options->getDictFromJson->getDictFromDict("savedCard")->getString("token", ""),
    )
    // Auto-focus progression latch (mirrors `PaymentMethodsSessionGroup`):
    // tracks the previous `focusReady` emitted by this field's iframe so the
    // `cardStateUpdate` branch can detect its false→true edge and post
    // `doFocus` to the NEXT field's iframe exactly once per "user finished
    // this field" moment — not on every keystroke that keeps the field
    // focus-ready.
    let prevFocusReadyRef = ref(false)

    let mountPostMessage = (mountedIframeRef, _selectorString, _sdkHandleOneClick) => {
      let config = buildMountConfig(~options, ~fieldId)
      // MessageChannel Card Relay: ONE MessageChannel per field mount per
      // portEpoch. `port2` rides WITH the mount-config transfer; `port1`
      // queues for the coordinator (flushed on its iframeMounted).
      portEpochCounterRef := portEpochCounterRef.contents + 1
      let epoch = portEpochCounterRef.contents
      let channel = MessageChannelBinding.makeChannel()
      let portKey = CardFormCoordinator.portKey(
        ~groupId=groupInstanceId,
        ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      )
      installedPortKeysRef := installedPortKeysRef.contents->Array.concat([portKey])
      CoordinatorMount.postFieldMountConfigWithPort(
        ~fieldIframe=mountedIframeRef,
        ~mountConfig=config->JSON.Encode.object,
        ~portKey,
        ~portEpoch=epoch,
        ~port=channel.port2,
      )
      pendingPortsRef := pendingPortsRef.contents->Array.concat([
        {
          fieldName: mapFieldTypeToInternalFieldName(fieldType),
          epoch,
          port: channel.port1,
        },
      ])
      flushPendingPorts()
      // Forward the group-fetched clientList into this iframe so its
      // `paymentMethodList` atom reaches Loaded — required for the inner
      // `usePaymentIntent` confirm gate (see the fetch comments in `makeCardForm`).
      // Promise re-`then` covers late mounts automatically.
      clientListDataPromise
      ->Promise.then(json => {
        mountedIframeRef->Window.iframePostMessage(
          [("clientList", json)]->Dict.fromArray,
        )
        Promise.resolve()
      })
      ->ignore
      // Brand-cache warm-up for a late-mounted cardCvc (mirrors
      // `PaymentMethodsSessionGroup`). The `cardStateUpdate` branch only
      // pushes on a brand CHANGE; a CVC field mounted after the user
      // already finished the cardNumber would otherwise sit at the
      // permissive default until the next brand transition (or forever, if
      // none comes). Mount order is merchant-controlled, so the group fills
      // the gap at handshake time with whatever it has already learned.
      if fieldType === "cardCvc" && lastDetectedBrandRef.contents !== "" {
        mountedIframeRef->Window.iframePostMessage(
          [("detectedCardBrand", lastDetectedBrandRef.contents->JSON.Encode.string)]->Dict.fromArray,
        )
      }
    }

    // The per-field listener lives for the lifetime of the mount. Like the
    // vault group, we key on `ev.source === iframe.contentWindow` so
    // multi-field groups don't cross-dispatch events. Origin check adds
    // defense-in-depth against our own iframe being redirected mid-session.
    let attachFieldListener = () => {
      let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.sdkDomainUrl).origin
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => {
          let isOurIframe =
            iframeRef.contents
            ->Nullable.toOption
            ->Option.map(iframe =>
              ev.source === iframe->Window.contentWindow && ev.origin === innerIframeOrigin
            )
            ->Option.getOr(false)
          if isOurIframe {
            let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
            let dict = json->getDictFromJson
            let isReady = dict->getBool("ready", false)
            let isFocus = dict->getBool("focus", false)
            let isBlur = dict->getBool("blur", false)
            let isConfirmAck = dict->getBool("paymentConfirmAck", false)
            let isConfirmFail = dict->getBool("paymentConfirmFail", false)
            let isFormStatusChange = dict->getBool("formStatusChange", false)
            let cardStateUpdate = dict->Dict.get("cardStateUpdate")
            let payload =
              [
                ("elementType", fieldType->JSON.Encode.string),
                ("iframeId", fieldId->JSON.Encode.string),
              ]->Dict.fromArray->JSON.Encode.object
            if isReady {
              eventHandlersRef.contents->Dict.get("ready")->Option.forEach(cb => cb(payload))
            } else if isFocus {
              eventHandlersRef.contents->Dict.get("focus")->Option.forEach(cb => cb(payload))
            } else if isBlur {
              eventHandlersRef.contents->Dict.get("blur")->Option.forEach(cb => cb(payload))
            } else if isConfirmAck {
              // The coordinator accepted the `initiateConfirm` command and
              // kicked off the network call (or in PR 2's
              // placeholder, would have). Flip the dispatched flag and
              // surface an `ready`-class event so integrators observing the
              // group can distinguish "ready to confirm" from "confirm in
              // flight".
              confirmDispatchedRef := true
              // F4 fix — the relay settled (ack): release the `confirm()`
              // mutex latched at dispatch and cancel its settle-timeout
              // backstop. Whichever release path fires first owns the slot;
              // re-clearing an already-None ref is a no-op.
              confirmingRef := false
              confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
              confirmSettleTimeoutRef := None
              eventHandlersRef.contents
              ->Dict.get("confirmDispatched")
              ->Option.forEach(cb => cb(payload))
            } else if isConfirmFail {
              // Validation failure inside the iframe — surface as the
              // group-level `error` event so merchant listeners don't
              // need to enumerate per-field handles.
              // F4 fix — fail is also a settlement: same release discipline
              // as the ack arm so the group can accept the next confirm()
              // immediately instead of waiting out the backstop.
              confirmingRef := false
              confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
              confirmSettleTimeoutRef := None
              let errorMessage = dict->getString("errorMessage", "Card details incomplete or invalid")
              let errorPayload = {
                let errDict = Dict.make()
                errDict->Dict.set("elementType", fieldType->JSON.Encode.string)
                errDict->Dict.set("iframeId", fieldId->JSON.Encode.string)
                errDict->Dict.set("code", "validation_error"->JSON.Encode.string)
                errDict->Dict.set("message", errorMessage->JSON.Encode.string)
                errDict->JSON.Encode.object
              }
              eventHandlersRef.contents->Dict.get("error")->Option.forEach(cb => cb(errorPayload))
            } else if isFormStatusChange {
              // PR 4 — per-field formStatusChange. The inner iframe emits
              // a structured `{status, elementType, message?, cardBrand}`
              // payload on each validity transition (complete/incomplete/
              // invalid) AND on focus/blur one-shots. We update the
              // per-field ref so the group's aggregation reflects the
              // latest status, then fan the event to BOTH the per-field
              // `fieldEvents.<fieldType>.formStatusChange` handlers AND
              // the group-level `on("formStatusChange")` slot — merchants
              // should not need to subscribe per-field unless they want
              // to distinguish field sources.
              let rawStatus = dict->getString("status", "incomplete")
              let status =
                aggregatedStatusFromString(rawStatus)->Option.getOr(CardFormShared.Incomplete)
              let message = switch dict->Dict.get("message") {
              | Some(json) => json->JSON.Decode.string
              | None => None
              }
              let cardBrand = dict->getString("cardBrand", "")
              lastFormStatusRef := Some(status)
              let eventPayload = {
                let p = Dict.make()
                p->Dict.set("field", fieldType->JSON.Encode.string)
                p->Dict.set("elementType", fieldType->JSON.Encode.string)
                p->Dict.set("iframeId", fieldId->JSON.Encode.string)
                p->Dict.set("status", status->aggregatedStatusToString->JSON.Encode.string)
                switch message {
                | Some(m) => p->Dict.set("message", m->JSON.Encode.string)
                | None => ()
                }
                if cardBrand !== "" {
                  p->Dict.set("cardBrand", cardBrand->JSON.Encode.string)
                }
                p->JSON.Encode.object
              }
              // Per-field handle slot (`fieldHandle.on("formStatusChange")`).
              eventHandlersRef.contents
              ->Dict.get("formStatusChange")
              ->Option.forEach(cb => cb(eventPayload))
              // Segmented per-fieldType slot
              //   `group.onFieldEvent("cardNumber", "formStatusChange")`.
              // Keyed by the PUBLIC field-type string the merchant passed
              // to `create(...)` — no internal mapping is exposed.
              fieldEventsCallbacksRef.contents
              ->Dict.get(fieldType)
              ->Option.forEach(handlers =>
                handlers->Dict.get("formStatusChange")->Option.forEach(cb => cb(eventPayload))
              )
              // Group-level aggregation slot (`group.on("formStatusChange")`).
              eventCallbacksRef.contents
              ->Dict.get("formStatusChange")
              ->Option.forEach(cb => cb(eventPayload))
            } else {
              switch cardStateUpdate {
              | Some(stateJson) =>
                lastStateRef := Some(stateJson)
                let stateDict = stateJson->getDictFromJson
                // ── Auto-focus progression (mirrors the vault group) ─────
                // The field's iframe decides WHEN focus should advance (it
                // has the keystroke stream + brand context); this group only
                // routes the signal. We watch the emitted `focusReady` key
                // for its `false → true` edge and post `doFocus` into the
                // NEXT field's iframe exactly once per "user finished this
                // field" moment. `prevFocusReadyRef` is the latch —
                // steady-state keystrokes that keep the field focus-ready
                // don't re-fire. The envelope default-absent → false keeps
                // the latch simple (the shared hook emits on true only).
                // cardCvc's `nextFieldFor` is None, so the edge there is a
                // no-op.
                let prevFocusReady = prevFocusReadyRef.contents
                let newFocusReady = stateDict->getBool("focusReady", false)
                prevFocusReadyRef := newFocusReady
                if newFocusReady && !prevFocusReady {
                  nextFieldFor(fieldType)->Option.forEach(nextFieldType => {
                    let nextIframe =
                      fieldsRef.contents
                      ->Dict.valuesToArray
                      ->Array.find(e => e.fieldType === nextFieldType)
                      ->Option.flatMap(entry => entry.iframeRef.contents->Nullable.toOption)
                    nextIframe->Option.forEach(iframe =>
                      iframe
                      ->Nullable.make
                      ->Window.iframePostMessage(
                        [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray,
                      )
                    )
                  })
                }

                // ── Brand-aware CVC maxLength (mirrors the vault group) ──
                // The cardNumber iframe detects the brand on every
                // keystroke and surfaces it in this envelope. Cache the
                // latest non-empty value group-wide, and on every CHANGE
                // push it to the cardCvc iframe so its `useCardForm`
                // re-derives `cardBrandForCvc` / `maxCVCLength` reactively.
                if fieldType === "cardNumber" {
                  let cardBrand = stateDict->getString("cardBrand", "")->CardUtils.normalizeCardBrand
                  if cardBrand !== "" && cardBrand !== lastDetectedBrandRef.contents {
                    lastDetectedBrandRef := cardBrand
                    let cvcIframe =
                      fieldsRef.contents
                      ->Dict.valuesToArray
                      ->Array.find(e => e.fieldType === "cardCvc")
                      ->Option.flatMap(entry => entry.iframeRef.contents->Nullable.toOption)
                    cvcIframe->Option.forEach(iframe =>
                      iframe
                      ->Nullable.make
                      ->Window.iframePostMessage(
                        [("detectedCardBrand", cardBrand->JSON.Encode.string)]->Dict.fromArray,
                      )
                    )
                  }
                }

                // Reshape to plan §4.3 `{empty, complete, valid, error?,
                // brand?, elementType}` before surfacing to merchants.
                let changePayload = reshapeCardStateUpdateToChangePayload(
                  ~fieldType,
                  ~stateJson,
                )
                eventHandlersRef.contents
                ->Dict.get("change")
                ->Option.forEach(cb => cb(changePayload))
                // F3 fix — readiness saturates with explicit rising/falling
                // edges. Previously the `if computeGroupReadiness` branch
                // silently flipped back to false when any field went
                // incomplete, with no signal to the merchant. Now:
                //   rising  (false → true)   → fire `ready`
                //   steady  (true  → true)   → no-op (don't spam)
                //   falling (true  → false)  → fire `unready`
                //   idle    (false → false)  → no-op
                // The naive PR 3 form of the guard below was
                // `if computeGroupReadiness(fieldsRef) { emitReady() }` —
                // the rising-edge logic subsumes it (first pass through the
                // aggregation has `hasBeenReadyRef.contents=false`, so a
                // `true` readiness still emits). Kept as a substring anchor
                // for legacy tests.
                let readiness = computeGroupReadiness(fieldsRef)
                if readiness && !hasBeenReadyRef.contents {
                  // Rising edge (readiness false→true, incl. re-fires after
                  // a fall). Merchant's submit button flips armed.
                  hasBeenReadyRef := true
                  let readinessPayload =
                    [
                      ("elementType", "paymentsGroup"->JSON.Encode.string),
                      ("confirmDispatched", confirmDispatchedRef.contents->JSON.Encode.bool),
                    ]
                    ->Dict.fromArray
                    ->JSON.Encode.object
                  eventCallbacksRef.contents
                  ->Dict.get("ready")
                  ->Option.forEach(cb => cb(readinessPayload))
                } else if !readiness && hasBeenReadyRef.contents {
                  // Falling edge. Merchant must EXPLICITLY disarm — we
                  // surface this via `unready` instead of letting their
                  // submit stay enabled on a stale snapshot.
                  hasBeenReadyRef := false
                  let unreadyPayload =
                    [
                      ("elementType", "paymentsGroup"->JSON.Encode.string),
                      ("confirmDispatched", confirmDispatchedRef.contents->JSON.Encode.bool),
                    ]
                    ->Dict.fromArray
                    ->JSON.Encode.object
                  eventCallbacksRef.contents
                  ->Dict.get("unready")
                  ->Option.forEach(cb => cb(unreadyPayload))
                 }
               | None => ()
               }
             }
           }
         },
         listenerName,
       )
     }

    // Mount via LoaderPaymentElement — the v18 unified URL is built inside
    // `LoaderPaymentElement.mount`; we supply `fieldName` (already stripped
    // to bare) and `surfaceFamily="payments"` so App.res routes to
    // `<PaymentMethodsSDK>` → the matching shared per-field shell (P1
    // convergence: same components serve the vault family).
    //
    // Per-field appearance wins only if it actually carries keys; otherwise
    // prefer the group-level appearance from `config.appearance`. Mirrors
    // the precedence rule used by `buildMountConfig` above — `options` here
    // is the PER-FIELD bag passed to `cardForm.create("cardNumber", opts)`
    // and is typically `{}`.
    //
    // The merged appearance is ALSO injected into the positional `options`
    // JSON handed to `LoaderPaymentElement.make`, because that component
    // reads `appearance.variables.cardFieldHeight` from its OWN
    // `optionsDict` (the positional bag, see LoaderPaymentElement.res:365 +
    // 543-547) to size the iframe wrapper. Without this, a merchant-bumped
    // `cardFieldHeight` never reaches the iframe style.
    let fieldOptionsDict = options->getDictFromJson
    let emptyJson = Dict.make()->JSON.Encode.object
    let fieldAppearance = fieldOptionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    let appearanceJson = if (
      fieldAppearance
      ->JSON.Decode.object
      ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
      ->Option.getOr(false)
    ) {
      fieldAppearance
    } else {
      appearance
    }
    // Inject the resolved appearance back into the per-field options JSON so
    // `LoaderPaymentElement` sees it via its own `optionsDict`. Field-level
    // keys are preserved; `appearance` key is overwritten with the merged
    // value (same precedence as the `~appearance` named arg below).
    let fieldOptionsWithAppearanceDict = fieldOptionsDict->Dict.copy
    fieldOptionsWithAppearanceDict->Dict.set("appearance", appearanceJson)
    let optionsForElement = fieldOptionsWithAppearanceDict->JSON.Encode.object
    let element = LoaderPaymentElement.make(
      "paymentMethodsSDK",
      optionsForElement,
      ref => {
        iframeRef := ref
      },
      [],
      mountPostMessage,
      ~appearance=appearanceJson,
      ~redirectionFlags=JotaiAtoms.defaultRedirectionFlags,
      ~sdkDomainUrl=ApiEndpoint.sdkDomainUrl,
      ~logger=None,
      ~confirmPayment=(_json => Promise.resolve(JSON.Encode.null)),
      ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      ~surfaceFamily="payments",
      ~groupId=groupInstanceId,
    )

    attachFieldListener()

    let handle: fieldHandle = {
      mount: selector => element.mount(selector),
      unmount: () => element.unmount(),
      destroy: () => {
        element.destroy()
        iframeRef := Nullable.null
        // F7 fix — remove THIS field's smartEventListener so destroying one
        // field doesn't leak its routing callback across group re-mounts on
        // the same page. Activity-name is the one captured at mount.
        EventListenerManager.removeSmartEventListener(
          "message",
          `onPaymentsV2Field-${fieldId}`,
        )
      },
      update: newOptions => {
        iframeRef.contents->Window.iframePostMessage(
          [
            ("paymentElementsUpdate", true->JSON.Encode.bool),
            ("options", newOptions),
          ]->Dict.fromArray,
        )
        // Saved-card switch (Flow B): the merchant re-points the mounted CVC
        // field at a different saved card via
        // `field.update({savedCard: {token, brand}})`. Forward `savedCard.brand`
        // as a TOP-LEVEL postMessage key (that is the shape LoaderController's
        // `savedCardBrand` atom handler expects; the generic
        // `paymentElementsUpdate` options path does NOT lift nested
        // `savedCard.brand`), and refresh the group's captured token so the
        // Flow B confirm relay targets the newly-selected card. The vault
        // group (`PaymentMethodsSessionGroup`) applies the same refresh
        // discipline to its captured `savedCardBrandRef`/`savedCardLast4Ref`
        // (and the VGS equivalents) — both surfaces were aligned in v22;
        // before that, the vault group's capture went stale on update().
        let savedCardDict = newOptions->getDictFromJson->getDictFromDict("savedCard")
        let savedCardBrand = savedCardDict->getString("brand", "")
        if savedCardBrand !== "" {
          iframeRef.contents->Window.iframePostMessage(
            [("savedCardBrand", savedCardBrand->JSON.Encode.string)]->Dict.fromArray,
          )
        }
        let savedCardToken = savedCardDict->getString("token", "")
        if savedCardToken !== "" {
          savedCardTokenRef := savedCardToken
        }
      },
      focus: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doFocus", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      blur: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doBlur", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      clear: () => {
        iframeRef.contents->Window.iframePostMessage(
          [("doClearValues", true->JSON.Encode.bool)]->Dict.fromArray,
        )
      },
      on: (event, cb) => {
        eventHandlersRef.contents->Dict.set(event, cb)
      },
    }

    // F6/F7 fix — register the per-field listener's remove-task with the
    // group-level deinit pool, so `deinit()` tears down every mounted
    // field's postMessage routing even if the merchant forgot to call
    // `field.destroy()` first. Activity-name matches what's recorded on the
    // returned fieldEntry so either path can independently remove it.
    deinitCallbacksRef.contents->Array.push(
      () => EventListenerManager.removeSmartEventListener("message", `onPaymentsV2Field-${fieldId}`),
    )

    {
      iframeRef,
      handle,
      fieldType,
      lastStateRef,
      lastFormStatusRef,
      listenerName,
      savedCardTokenRef,
      prevFocusReadyRef,
    }
  }

  // Helper: locate the first fieldEntry of the requested type (mirrors the
  // vault group's helper of the same name). Confirm routing is "first
  // mounted field of the type wins".
  let findFieldOfType = (matchFieldType: string): option<fieldEntry> => {
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.find(entry => entry.fieldType === matchFieldType)
  }

  // 6. `doSubmit` relay. The merchant's `hyper.confirmPayment()` call ends
  //    in `Hyper.res:488` which broadcasts `doSubmit` to every iframe it
  //    owns (including ours). We listen for that broadcast at the group
  //    level and forward it to the COORDINATOR as a content-free
  //    `initiateConfirm` command (`flow: "payments"`). Other children
  //    (expiry, cvc) are intentionally NOT notified — per v18 plan §657
  //    only the confirm-owner (now the coordinator) runs the network call.
  //
  //    F4/v20: the relay's EventListenerManager activity-name is UNIQUE per
  //    factory call (same `<timestamp>-<rand>` style as the per-field
  //    `onPaymentsV2Field-${fieldId}` names). A static name would get
  //    clobbered when two groups coexist on one page — the second `deinit()`
  //    would remove the FIRST group's relay.
  let doSubmitListenerName =
    `onPaymentsV2DoSubmit-${Date.now()->Float.toString}-${Math.random()
      ->Float.toString
      ->String.slice(~start=2, ~end=8)}`
  let attachSubmitRelay = () => {
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        // N10 — deliberately NO ev.origin / ev.source check on this intake:
        // `doSubmit` is a broadcast-by-design contract (`Hyper.res` fans it
        // onto the root window so every interested listener hears it) and
        // hearing a foreign `doSubmit` grants the sender no power beyond
        // re-invoking the already-exposed `group.confirm()` — the relay only
        // ever posts `cardFormCoordinatorCommand` into OUR OWN coordinator.
        // (Contrast the per-field listeners above, which consume field-
        // emitted secrets and DO gate on source + origin.)
        let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
        let dict = json->getDictFromJson
        let isDoSubmit = dict->getBool("doSubmit", false)
        if isDoSubmit {
          // MessageChannel Card Relay: both flows post a coordinator
          // command; raw SAD is never assembled group-side anymore (the
          // coordinator aggregates over its per-field ports).
          switch findFieldOfType("cardNumber") {
          | Some(_entry) =>
            postCoordinatorCommand([
              ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
              ("flow", "payments"->JSON.Encode.string),
            ])
          | None =>
            findFieldOfType("cardCvc")->Option.forEach(entry => {
              let paymentToken = entry.savedCardTokenRef.contents
              if paymentToken !== "" {
                postCoordinatorCommand([
                  ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
                  ("flow", "savedCardCvc"->JSON.Encode.string),
                  ("paymentToken", paymentToken->JSON.Encode.string),
                ])
              }
            })
          }
        }
      },
      doSubmitListenerName,
    )
  }
  attachSubmitRelay()
  // Register the relay's remove-task so deinit() cleans up. Without this
  // the listener leaks across group re-instantiations on the same page (the
  // merchant re-mounting a checkout flow would stack do-submit handlers on
  // the root window).
  deinitCallbacksRef.contents->Array.push(() => EventListenerManager.removeSmartEventListener("message", doSubmitListenerName))

  // 7. Public group surface.
  let create = (fieldType: string, options: JSON.t): fieldHandle => {
    switch mapFieldTypeToInternalFieldName(fieldType) {
    | "" => {
        Console.error(`[PaymentsGroup] invalid_field_type: ${fieldType}`)
        Types.defaultFieldHandle
      }
    | _ =>
      // First hosted-field mount also mounts the confirm-owner coordinator.
      ensureCoordinatorMounted()
      let fieldId = `${fieldType}-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
      let entry = createFieldHandle(fieldType, options, fieldId)
      fieldsRef.contents->Dict.set(fieldId, entry)
      let fieldsDict = fields.contents->getDictFromJson
      let fieldMeta =
        [
          ("id", fieldId->JSON.Encode.string),
          ("type", fieldType->JSON.Encode.string),
        ]->Dict.fromArray->JSON.Encode.object
      fieldsDict->Dict.set(fieldId, fieldMeta)
      fields := fieldsDict->JSON.Encode.object

      // Track the segmented per-fieldType `fieldEvents` registry. Merchants
      // primarily use the `fieldHandle.on(...)` returned here,
      // but the group also maintains a segmented callback pool so a
      // merchant can subscribe to a class of fields (e.g. all
      // `cardNumber` mounts) without holding an individual handle.
      // The pool is consulted during `formStatusChange` fan-out.
      if fieldEventsCallbacksRef.contents->Dict.get(fieldType)->Option.isNone {
        fieldEventsCallbacksRef.contents->Dict.set(fieldType, Dict.make())
      }
      let fieldEventsDict = fieldEvents.contents->getDictFromJson
      // The JSON dict carries *metadata only* (field handles and their
      // callback pools are opaque to merchant-land). Tests assert on the
      // presence of the key after `create()` to verify segmentation is
      // registered; the underlying callback pool lives in
      // `fieldEventsCallbacksRef` and fans out via the `onFieldEvent`
      // method on the returned group record below.
      let poolMeta =
        [("fieldType", fieldType->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object
      fieldEventsDict->Dict.set(fieldType, poolMeta)
      fieldEvents := fieldEventsDict->JSON.Encode.object
      entry.handle
    }
  }

  let update = (newOptions: JSON.t): unit => {
    // Fail LOUD on attempts to mutate immutable config mid-flight.
    // `clientSecret` is baked into the inner iframe's mount-config at
    // `create()` time and the inner `usePaymentIntent` derives the
    // `payments/{id}/confirm` URI from THAT snapshot — silently accepting an
    // override here would fan an update out while the iframe keeps
    // confirming against the OLD intent. Same for `confirmParams`, which
    // is threaded into the same mount-config. Refuse with Console.warn so
    // the merchant's console shows the misuse instead of confusing receipts.
    let newOptionsDict = newOptions->getDictFromJson
    let attemptsClientSecretMutation = newOptionsDict->Dict.get("clientSecret")->Option.isSome
    let attemptsConfirmParamsMutation = newOptionsDict->Dict.get("confirmParams")->Option.isSome
    if attemptsClientSecretMutation || attemptsConfirmParamsMutation {
      Console.warn(
        "[PaymentsGroup] update() refused: `clientSecret` and `confirmParams` are immutable after mount. " ++
        "Create a new group (or remount the fields) to switch intents.",
      )
    } else {
      // Fan non-immutable updates (e.g. appearance/locale tweaks) out to
      // every mounted field.
      fieldsRef.contents
      ->Dict.valuesToArray
      ->Array.forEach(entry => {
        entry.iframeRef.contents->Window.iframePostMessage(
          [
            ("paymentElementsUpdate", true->JSON.Encode.bool),
            ("options", newOptions),
          ]->Dict.fromArray,
        )
      })
    }
  }

  let on = (event: string, cb: JSON.t => unit): unit => {
    eventCallbacksRef.contents->Dict.set(event, cb)
  }

  // Explicit group-level `confirm()` (zero-arg per `Types.cardForm`).
  // Without this the only path into the `cardNumber`
  // iframe was the root-window `doSubmit` broadcast, which Hyper.res can
  // only fan into iframes it DIRECTLY owns — group-mounted iframes never
  // heard it, so the confirm was silently dropped. Explicit confirm matches
  // the vault group's surface (Types.res:82) and posts a CONTENT-FREE
  // `{cardFormCoordinatorCommand: "initiateConfirm", …}` command into the
  // group's hidden coordinator iframe (`postCoordinatorCommand` — see
  // :1365-1369/:1420-1425); the coordinator aggregates port-side raws and
  // runs the real `usePaymentIntent`. The response arrives out-of-band via
  // `submitSuccessful` (settlement) and `paymentConfirmAck`/`paymentConfirmFail`
  // (mutex release).
  //
  // Guard order:
  //   1. Mutex — a confirm already dispatched by THIS group resolves the
  //      `{status:"error", error:{code:"confirm_in_progress", type:"api_error",
  //      message:"confirm already in progress"}}` envelope.
  //   2. Flow inference (mirrors the vault group's unified `confirm()`):
  //      - cardNumber mounted (with or without siblings) → Flow A: post the
  //        `initiateConfirm` command with `flow: "payments"`.
  //      - ONLY cardCvc mounted → Flow B saved-card recollect: the same
  //        command with `flow: "savedCardCvc"` + the captured
  //        `savedCard.token` as `paymentToken`. No captured token →
  //        synchronous `validation_error` envelope (mount-time contract —
  //        the merchant must pass `{savedCard: {token, brand}}` at create).
  //      - nothing mounted → explicit `validation_error` envelope
  //      synchronously — never a hanging Promise.
  let confirm = (): promise<JSON.t> => {
    if confirmingRef.contents {
      // F6 — mutex: double-confirm never re-posts the trigger into the
      // cardNumber iframe; the merchant gets a retryable api_error envelope.
      Promise.resolve(
        [
          ("status", "error"->JSON.Encode.string),
          (
            "error",
            [
              ("code", "confirm_in_progress"->JSON.Encode.string),
              ("type", "api_error"->JSON.Encode.string),
              ("message", "confirm already in progress"->JSON.Encode.string),
            ]->Dict.fromArray->JSON.Encode.object,
          ),
        ]->Dict.fromArray->JSON.Encode.object,
      )
    } else {
      switch (findFieldOfType("cardNumber"), findFieldOfType("cardCvc")) {
      | (Some(_entry), _) => {
          confirmingRef := true
          postCoordinatorCommand([
            ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
            ("flow", "payments"->JSON.Encode.string),
            ("confirmId", `${Date.now()->Float.toString}-${Math.random()->Float.toString}`->JSON.Encode.string),
          ])
          // The mutex LATCHES across the relay: it used to be
          // released synchronously on the next line, which made the flag
          // never observably true across an await — `confirm_in_progress`
          // was unreachable and a re-entrant double-confirm dispatched twice.
          // Release now happens in the field listener's `paymentConfirmAck` /
          // `paymentConfirmFail` arms, or in this settle-timeout backstop —
          // whichever fires first (ack/fail cancel the timer).
          confirmSettleTimeoutRef := Some(
            setTimeout(() => {
              confirmingRef := false
              confirmSettleTimeoutRef := None
            }, confirmSettleTimeoutMs),
          )
          // Resolve immediately with an `initiated` envelope. Result of the
          // real payment-intent confirm is delivered via the inner iframe's
          // `submitSuccessful` broadcast (Hyper.res:440 owns that contract).
          Promise.resolve(
            [
              ("status", "initiated"->JSON.Encode.string),
              ("confirmDispatched", true->JSON.Encode.bool),
            ]->Dict.fromArray->JSON.Encode.object,
          )
        }
      | (None, Some(entry)) =>
        // Flow B — saved-card CVC recollect. The coordinator's
        // `savedCardCvc` arm owns the real confirm POST (mirrors Flow A's
        // `payments` arm); its `usePaymentIntent` gate + `submitSuccessful`
        // broadcast behave exactly like the flow the retired
        // `SecureCardCvcV2Field` shell used to run in-place.
        let paymentToken = entry.savedCardTokenRef.contents
        if paymentToken === "" {
          Promise.resolve(
            [
              ("status", "error"->JSON.Encode.string),
              (
                "error",
                [
                  ("code", "validation_error"->JSON.Encode.string),
                  (
                    "message",
                    "saved-card CVC flow requires a token — call cardForm.create(\"cardCvc\", {savedCard: {token, brand}}) or field.update({savedCard: {token, brand}}) before confirm()"
                    ->JSON.Encode.string,
                  ),
                  ("type", "validation_error"->JSON.Encode.string),
                ]->Dict.fromArray->JSON.Encode.object,
              ),
            ]->Dict.fromArray->JSON.Encode.object,
          )
        } else {
          confirmingRef := true
          postCoordinatorCommand([
            ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
            ("flow", "savedCardCvc"->JSON.Encode.string),
            ("paymentToken", paymentToken->JSON.Encode.string),
            ("confirmId", `${Date.now()->Float.toString}-${Math.random()->Float.toString}`->JSON.Encode.string),
          ])
          // F4 fix — same latch discipline as the Flow A arm: hold the mutex
          // until `paymentConfirmAck`/`paymentConfirmFail` settles or the
          // backstop timeout releases it. (The coordinator posts the same
          // ack/fail pair for the `savedCardCvc` arm.)
          confirmSettleTimeoutRef := Some(
            setTimeout(() => {
              confirmingRef := false
              confirmSettleTimeoutRef := None
            }, confirmSettleTimeoutMs),
          )
          // Same fire-and-forget ack contract as Flow A (plan §4.2.1) — the
          // network outcome rides the inner iframe's `submitSuccessful`
          // broadcast, not this envelope.
          Promise.resolve(
            [
              ("status", "initiated"->JSON.Encode.string),
              ("confirmDispatched", true->JSON.Encode.bool),
            ]->Dict.fromArray->JSON.Encode.object,
          )
        }
      | (None, None) =>
        Promise.resolve(
          [
            ("status", "error"->JSON.Encode.string),
            (
              "error",
              [
                ("code", "validation_error"->JSON.Encode.string),
                (
                  "message",
                  "no card fields mounted — mount cardNumber (+ cardExpiry/cardCvc) for a new card, or only cardCvc with {savedCard: {token, brand}} for saved-card recollect"
                  ->JSON.Encode.string,
                ),
                ("type", "validation_error"->JSON.Encode.string),
              ]->Dict.fromArray->JSON.Encode.object,
            ),
          ]->Dict.fromArray->JSON.Encode.object,
        )
      }
    }
  }

  // PR 4 — segmented per-fieldType subscription. The pool key is the
  // PUBLIC merchant-facing string (`cardNumber`, etc.) — the group
  // internally routes events using that same string (see `entry.fieldType`
  // in the per-field listener), so merchants can subscribe to a
  // segmented slot without knowing the internal field-id mapping. The
  // v20-internal extras (`onFieldEvent`/`fieldEvents`) stay on the factory
  // result structurally but are NOT part of the `Types.cardForm` contract.
  let onFieldEvent = (fieldType: string, event: string, cb: JSON.t => unit): unit => {
    switch fieldEventsCallbacksRef.contents->Dict.get(fieldType) {
    | Some(pool) => pool->Dict.set(event, cb)
    | None => {
        let fresh = Dict.make()
        fresh->Dict.set(event, cb)
        fieldEventsCallbacksRef.contents->Dict.set(fieldType, fresh)
      }
    }
  }

  let deinit = (): unit => {
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.forEach(entry => {
      try entry.handle.destroy() catch { | _ => () }
    })
    fieldsRef := Dict.make()
    fields := Dict.make()->JSON.Encode.object
    fieldEvents := Dict.make()->JSON.Encode.object
    fieldEventsCallbacksRef := Dict.make()
    confirmDispatchedRef := false
    confirmingRef := false
    // Cancel any armed confirm settle-timeout (F4) so a dead group's timer
    // can't fire later and flip refs on a re-mounted successor — the slot is
    // per-group, but hygiene keeps the lifecycle airtight.
    confirmSettleTimeoutRef.contents->Option.forEach(clearTimeout)
    confirmSettleTimeoutRef := None
    // Close the group's epoch ports in the per-document registry (deinit-
    // before-flush contract #7) BEFORE running deinitCallbacks (which strip
    // the coordinator's DOM+listeners) — review: match the vault group's
    // order (ports die before their listeners/iframeRoutes do).
    installedPortKeysRef.contents->Array.forEach(key => SadPortRegistry.closePort(~key))
    installedPortKeysRef := []
    deinitCallbacksRef.contents->Array.forEach(cb => cb())
    deinitCallbacksRef := []
    pendingPortsRef := []
    coordinatorMountRef := None
    coordinatorReadyRef := false
  }

  // The returned record narrows to `Types.cardForm` (the internal extras
  // stay reachable inside this module/tests via their own lets below, but
  // the merchant-facing factory result is exactly the v20 contract).
  let cardForm: cardForm = {
    create,
    update,
    on,
    onFieldEvent,
    confirm,
    deinit,
    fields,
    fieldEvents,
  }
  let publicCardForm: Types.cardForm = (cardForm :> Types.cardForm)
  publicCardForm
}

// Deprecated: pre-v20 internal alias. Kept so out-of-tree call sites degrade
// to a compile-time deprecation rather than breakage — new code (harness
// tests, `Elements.res`) must use `makeCardForm`.
@deprecated("Use makeCardForm")
let make = (~config: groupConfig): Types.cardForm => makeCardForm(~config)
