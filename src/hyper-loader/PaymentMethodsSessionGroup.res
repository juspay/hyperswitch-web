// Factory behind `hyper.paymentMethodsSession(options)` — the VAULT CardForm
// group (mounts per-field iframes, relays confirms, owns the session state
// machine). Confirms are relay-only: the group posts a content-free
// `cardFormCoordinatorCommand` into its hidden `cardFormCoordinator` iframe;
// THE COORDINATOR iframe issues the vault POST itself
// (`CardFormCoordinator.res` vault arm) and the group settles on the
// coordinator's masked `confirmResult` envelope — no raw payload ever
// crosses the merchant window plane.
//
// Structure:
//   1. Decodes `options.sdkAuthorization` via `Utils.getSdkAuthorizationData`
//      (b64 "k=v,k=v" blob → `{publishableKey, pmSessionId, customerId, profileId}`).
//   2. Mode A (no `options.vault` passed): issues `fetchPaymentManagementList` from
//      this merchant-page context to discover `vault_details.vault_type` /
//      `vault_data`. Mirrors the established pattern in `Hyper.res`
//      (`fetchSessions`); the stored payload reaches the field iframes via the
//      standard `sessions` postMessage channel.
//   3. Mode B (`options.vault = {vault_type, vault_data}`): builds a synthetic
//      session JSON mirroring `fetchPaymentManagementList`'s shape, and runs it
//      through the same `VaultHelpers.buildVaultConfig` → decode pipeline so
//      downstream consumers see an identical structure either way. No fetch.
//   4. Per-instance state refs (never module-level): `sessionsDataRef`,
//      `vaultCredentialsRef`, `sessionStateRef: Active | Consumed | Deinitialized`,
//      `confirmingRef` (mutex backing `confirm_in_progress`), `expiresAtRef`,
//      `eventCallbacksRef` (group-level `on()` registry).
//   5. `expires_at` proactive handling: if the session is already expired at
//      creation time, the single `confirm()` entrypoint short-circuits with
//      `{status:"error", error:{code:"session_expired", ...}}`.
//
// Shared vocabulary (field-type allow-list, auto-focus progression, the §4.3
// `change`-payload reshaper) lives canonically in `CardFormShared.res` and is
// aliased below — parallel to `PaymentsGroup.res` (payments CardForm group).
//
// Plan reference: `docs/plans/secure-card-fields-plan-2026-08.md`.

open Utils

// Local aliases for `Types` fields we need (avoids `open Types` which would
// shadow the global `None` variant needed for optional labeled args like
// `~optLogger=None` / `~customPodUri=None` below).
// Queued port1 channel awaiting its coordinator iframe-mounted flush
// (MessageChannel Card Relay). Shape hoisted into CoordinatorMount (review
// nit — both groups share it) so `CoordinatorMount.teardown` can close the
// un-transferred ones on group deinit.
type pendingPort = CoordinatorMount.pendingPort

type paymentMethodsSessionGroup = Types.paymentMethodsSessionGroup
type fieldHandle = Types.fieldHandle
type cardForm = Types.cardForm

// ── Session state discriminant ───────────────────────────────────────────────
// Per-group lifecycle flag. `Active → Consumed` lands in the coordinator
// confirm-settlement arm on a `status == "success"` result (see the
// `coordinatorConfirmPendingRef` settle below); `→ Deinitialized` lands via
// `deinit()`. A Consumed session's single `confirm()` entrypoint refuses
// further confirms.
type sessionState =
  | Active
  | Consumed
  | Deinitialized

// ── Result-union mapper ──────────────────────────────────────────────────────
//
// Single source of truth for the unified `confirm()` result union: one
// entrypoint, Flow A vs Flow CVC-recollect inferred from mounted fields. The
// success union is locked by the plan — we do NOT change it here. The error
// envelope is
//     { status: "error", error: { code, message, type? } }
//
// `type` discriminator per plan §4.4:
//   - "validation_error" → merchant-fixable input problem
//   - "api_error"        → session / tokenization / network failure
//   - "card_error"       → field-specific card validation failure
//
// We keep the mapper pure (no refs, no I/O) and synchronous. Locale resolution
// is a labeled argument with defaults so the public `confirm()` API surface
// doesn't grow — the group passes its bootstrap `locale` string through.

// MessageChannel Card Relay: the §4.4 union vocabulary + builders MOVED to
// `CardFormCoordinator.res` (confirm owner; single source of truth). Aliases
// keep the group's VGS + guard code reading byte-stable.
type errorType = CardFormCoordinator.errorType

let defaultErrorMessage = CardFormCoordinator.defaultErrorMessage
let resolveErrorMessage = CardFormCoordinator.resolveErrorMessage

let makeErrorResult = (
  ~code: string,
  ~message: option<string>=?,
  ~locale: string="en",
  ~typeOverride: option<errorType>=?,
  (),
): JSON.t => {
  CardFormCoordinator.makeErrorResult(~code, ~message?, ~locale, ~typeOverride?, ())
}
// Convenience builders for the reserved codes we emit from this module.
let sessionExpiredResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="session_expired", ~locale, ())

let sessionConsumedResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="session_consumed", ~locale, ())

let confirmInFlightResult = (~locale: string="en", ()): JSON.t =>
  makeErrorResult(~code="confirm_in_progress", ~locale, ())

// The §4.4 payload record types + `buildConfirmResult` MOVED to
// `CardFormCoordinator.res` (MessageChannel Card Relay: single source of truth
// lives next to the confirm owner). Aliases keep the VGS branches and the
// masked-result settle reading byte-stable.
type flowASuccessPayload = CardFormCoordinator.flowASuccessPayload
type flowBSuccessPayload = CardFormCoordinator.flowBSuccessPayload
type failurePayload = CardFormCoordinator.failurePayload
type confirmOutcome = CardFormCoordinator.confirmOutcome

let buildConfirmResult = CardFormCoordinator.buildConfirmResult

// ── Synthetic session JSON construction (Mode B) ─────────────────────────────
// Mirrors `fetchPaymentManagementList`'s response shape so downstream helpers
// (`VaultHelpers.getVaultCredentialsFromSessions`, `LoaderController`'s `sessions`
// atom in Task 3) decode identically for either bootstrap path.
//
//   {
//     "payment_method_session_id": <pmSessionId>,
//     "customer_id": <customerId>,
//     "vault_details": { "vault_type": <vt>, "vault_data": <vd> },
//     "associated_payment_methods": [],
//     "expires_at": <expiresAt ISO-8601 str>
//   }
let buildSyntheticSession = (
  ~pmSessionId: string,
  ~customerId: string,
  ~vaultType: string,
  ~vaultData: JSON.t,
  ~expiresAt: string,
): JSON.t => {
  let vaultDetailsDict = Dict.make()
  vaultDetailsDict->Dict.set("vault_type", vaultType->JSON.Encode.string)
  vaultDetailsDict->Dict.set("vault_data", vaultData)
  let sessionDict = Dict.make()
  sessionDict->Dict.set("payment_method_session_id", pmSessionId->JSON.Encode.string)
  sessionDict->Dict.set("customer_id", customerId->JSON.Encode.string)
  sessionDict->Dict.set("vault_details", vaultDetailsDict->JSON.Encode.object)
  sessionDict->Dict.set("associated_payment_methods", []->JSON.Encode.array)
  sessionDict->Dict.set("expires_at", expiresAt->JSON.Encode.string)
  sessionDict->JSON.Encode.object
}

// ── expires_at helpers ───────────────────────────────────────────────────────
// Backend sends ISO-8601 (e.g. "2026-08-14T12:34:56.000Z"); `Date.fromString`
// wraps `new Date(str)` which parses ISO cleanly. Returns `0.0` when missing or
// unparseable — treated as "unknown" and NOT considered proactively expired.
// We only flag `session_expired` when we positively know `now >= expiresAt`.
let parseExpiresAtMs = (expiresAtStr: string): float => {
  if expiresAtStr->String.length == 0 {
    0.0
  } else {
    try {
      Date.fromString(expiresAtStr)->Date.getTime
    } catch {
    | _ => 0.0
    }
  }
}

let isExpired = (~expiresAtMs: float): bool =>
  expiresAtMs > 0.0 && Date.now() >= expiresAtMs

// ── Field registry shape ─────────────────────────────────────────────────────
// Each `create()` registers one of these — the iframe handle + the public
// fieldHandle record. `deinit()` walks the table and calls `handle.destroy()`.
//
// Confirm resolution ownership: the group posts a content-free
// `cardFormCoordinatorCommand` into the coordinator (see the vault arm in
// CardFormCoordinator) and settles on the coordinator's masked
// `confirmResult` envelope — no raw payload crosses the window plane. Confirm
// settlement rides `coordinatorConfirmPendingRef` (confirmId-keyed) alone —
// there is no window-relay resolver slot.
type fieldEntry = {
  iframeRef: ref<Nullable.t<Dom.element>>,
  handle: fieldHandle,
  fieldType: string,
  // Merchant-supplied `savedCard` options captured at `create()` — used by
  // the Flow B (saved-card CVC recollect) branch of the unified `confirm()`
  // to surface `{card: {brand, last4}}` on the success union.
  // Only populated for `cardCvc` fields; empty for cardNumber/cardExpiry.
  savedCardBrandRef: ref<string>,
  savedCardLast4Ref: ref<string>,
  // No group-side raw caches exist: the coordinator receives full snapshots
  // on the port plane and the window-plane `cardStateUpdate` carries the
  // SPLIT payload (no raw keys), so nothing could ever populate them.
  // Last observed `focusReady` emitted by this field's iframe. Auto-focus
  // progression fires ONLY on the `false → true` edge of THIS signal — the
  // iframe owns the timing decision (brand-aware max length + Luhn for
  // cardNumber; 4-digit MMYY + validity for expiry; maxCVCLength + validity
  // for CVC), and the group just routes `doFocus` to the next field's iframe.
  // Previous iteration keyed off `fieldStatus.complete`, which fires on
  // isXxxValid + non-empty WITHOUT brand-aware length+Luhn gating — caused
  // a Visa card to advance to expiry at 14 digits instead of 16. Reverted.
  prevFocusReadyRef: ref<bool>,
}

// ── Plan §4.3 `change`-payload reshaper ──────────────────────────────────
// The locked §4.3 `change`-payload contract + commentary live in
// `CardFormShared` (v22 P2 — single canon shared by both CardForm group
// factories); aliased here so the compiled module keeps the named export
// that `change-brand-payload.test.js` imports directly.
let reshapeCardStateUpdateToChangePayload = CardFormShared.reshapeCardStateUpdateToChangePayload

// ── Auto-focus progression map ────────────────────────────────────────────
// Tab-order within the v20 Secure Card Fields vault flow (shared canon in
// `CardFormShared`):
//   cardNumber → cardExpiry → cardCvc → (terminal; no next field)
// The group's per-field `cardStateUpdate` listener uses this map to decide
// which field's iframe receives `doFocus` when the current field's EMITTED
// `focusReady` signal transitions from `false` to `true`. The iframe owns
// the timing decision (keystroke-level brand-aware max length + Luhn for
// cardNumber; 4-digit MMYY + validity for expiry); this map only routes it.
// Module-level alias so the compiled module keeps the `nextFieldFor` export
// that coordinator-behavior tests import directly.
let nextFieldFor = CardFormShared.nextFieldFor

// ── Format-preserving alias → brand detector ─────────────────────────────
// VGS returns format-preserving aliases (e.g. `4111xxxxxxxx1111`) — the
// leading BIN prefix is the REAL card's prefix; the trailing digits are the
// masked middle. We sniff the leading 1/2/4 chars against the canonical
// issuer ranges. Match order matters: narrower / longer prefixes first so a
// 4-digit range can't shadow a 1-digit one. CardUtils' naive
// `startsWith("4")`-at-a-time approach risks false hits when a prefix shares
// a 1-char head; instead, we match the REAL leading digits per plan
// §5.1 Task 4c's spec.
//
// Lowercase strings match the plan's canonical union shape ("visa", "amex",
// etc.). Returns "" when nothing matches — plan instructs to mark unknown
// brands as "" for now; Phase 2 may adopt an aliased-BIN lookup.
//
// Module-level (not inside `make()`) so unit tests can exercise it directly
// without spinning up a full session-group. Phase 1b Task F hoisted it.
//
// DINERS CLUB NOTE (Task F regression): the IATA Diners range is a 3-char
// prefix series (300-305) *plus* two 2-char prefixes (36, 38). An earlier
// version of this function compared the 4-char `four` binding against the
// 3-char \"300\"..\"305\" literals — string-vs-string equality never held, so
// every 300-305 Diners alias silently resolved to \"\". Fixed by matching
// that branch against the first 3 chars (`three` binding below).
let detectBrandFromAlias = (alias: string): string => {
  let a = alias->String.trim
  let len = a->String.length
  if len == 0 {
    ""
  } else {
    let ch0 = a->String.charAt(0)
    let two = if len >= 2 {
      ch0 ++ a->String.charAt(1)
    } else {
      ch0
    }
    let three = if len >= 3 {
      a->String.substring(~start=0, ~end=3)
    } else {
      ""
    }
    let four = if len >= 4 {
      a->String.substring(~start=0, ~end=4)
    } else {
      ""
    }
    if ch0 == "4" {
      "visa"
    } else if ["51", "52", "53", "54", "55"]->Array.includes(two) {
      "mastercard"
    } else if two == "34" || two == "37" {
      "amex"
    } else if four == "6011" || two == "65" {
      "discover"
    } else if two == "35" {
      "jcb"
    } else if (
      ["300", "301", "302", "303", "304", "305"]->Array.includes(three) ||
      two == "36" ||
      two == "38"
    ) {
      "diners club"
    } else if two == "62" || two == "81" {
      "unionpay"
    } else {
      ""
    }
  }
}

// ── Confirm settle-timeout (F5) ──────────────────────────────────────────────
// Max wall-clock a single confirm relay may stay in flight before the group
// settles it itself. Backstop for "the field iframe never posted its
// resolution" (e.g. the merchant unmounted the field mid-confirm): without
// it the `confirm()` promise stays pending FOREVER. 8000ms sits inside the
// reviewer-bounded 5–10s band; `PaymentsGroup.res` carries the same value
// for its ack/fail settle-timeout (F4 — mirrored constant, deliberately not
// hauled into `CardFormShared`: it is a per-group behavioral knob, not a
// locked cross-surface vocabulary).
let confirmSettleTimeoutMs = 8000

// ── Factory ──────────────────────────────────────────────────────────────────

let make = (options: JSON.t): paymentMethodsSessionGroup => {
  let optionsDict = options->getDictFromJson

  // 1. sdkAuthorization decode → {publishableKey, pmSessionId, customerId, profileId}
  let sdkAuthorizationRaw = optionsDict->getString("sdkAuthorization", "")
  let sdkAuth = sdkAuthorizationRaw->getSdkAuthorizationData
  let publishableKey = sdkAuth.publishableKey->Option.getOr("")
  let pmSessionId = sdkAuth.pmSessionId->Option.getOr("")
  let customerId = sdkAuth.customerId->Option.getOr("")

  // 1a. Task 7 locale pull-through. Merchants pass `locale` on bootstrap
  //     (either the explicit string or "auto" for navigator). We resolve once
  //     here and stash it; all confirm-path error envelopes thread it through.
  //     Today we ship EN strings only — the labeled arg makes the signature
  //     stable so Phase 1b locales can land without breaking the public surface.
  let localeRaw = optionsDict->getString("locale", "auto")
  let locale = if localeRaw == "auto" { "en" } else { localeRaw }

  // 2. Per-instance state refs (never module-level).
  let sessionsDataRef: ref<JSON.t> = ref(JSON.Encode.null)
  let vaultCredentialsRef: ref<JSON.t> = ref(JSON.Encode.null)
  let sessionStateRef: ref<sessionState> = ref(Active)
  let confirmingRef: ref<bool> = ref(false)
  let expiresAtRef: ref<float> = ref(0.0)
  let eventCallbacksRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())

  // Phase 1b Task A — lazily-instantiated VGS broker. One per group,
  // memoized across all `create()` calls. Created on first VGS-branch use
  // (`create()` for a VGS field, or the unified `confirm()` on the VGS
  // confirm path).
  let vgsBrokerRef: ref<option<VGSVaultBroker.vgsBrokerHandle>> = ref(None)

  // Phase 1b Task C — VGS saved-card metadata. The Hyperswitch branch of
  // `create()` stores these on the fieldEntry record; VGS doesn't build a
  // fieldEntry, so we capture `options.savedCard.{brand, last4}` here when a
  // VGS cardCvc field is created. Read by the Flow B (saved-card recollect)
  // VGS branch of `confirm()` when building the Flow B success union (VGS's
  // card_cvc alias response doesn't echo back the card's identity — we
  // surface the merchant-supplied hints instead).
  let vgsSavedCardBrandRef: ref<string> = ref("")
  let vgsSavedCardLast4Ref: ref<string> = ref("")

  // v20 Chunk 2 follow-up — brand-aware CVC maxLength. The cardNumber iframe
  // detects the brand on each keystroke and emits it via `cardStateUpdate`'s
  // `cardBrand` envelope key. We cache the latest non-empty value here so the
  // group can propagate it to the cardCvc iframe exactly once per brand
  // change (not on every keystroke). The CVC iframe lifts it into a React
  // state that feeds `~cardBrandOverride`, which drives
  // `CommonCardProps.useCardForm`'s `maxCVCLength` / `formatCVCNumber` /
  // `cvcNumberInRange`. Only applies when the CVC iframe has no explicit
  // `savedCardBrand` (Flow B) — saved-card flows thread the brand via their
  // own mount-config path and are untouched by this propagation.
  let lastDetectedBrandRef: ref<string> = ref("")

  // Internal registry of fields created via `create`. The `fields` JSON blob
  // still exposes per-field metadata on the returned group; `fieldsRef` holds
  // the real records for `deinit()` teardown.
  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  let fields: ref<JSON.t> = ref(Dict.make()->JSON.Encode.object)

  // ── MessageChannel Card Relay: coordinator wiring ────────────────────────
  //
  // The hidden 0×0 `cardFormCoordinator` iframe owns the Hyperswitch-vault
  // confirm (Flow A / Flow B). The group posts masked
  // `cardFormCoordinatorCommand` commands in and watches the masked
  // `confirmResult` back; raw SAD rides off-window per-field ports.
  // `groupInstanceId` doubles as the coordinator's `localSelectorString`
  // (locked DOM/iframeId contract #3) and rides `groupId` URL params into
  // every field iframe + the coordinator iframe (locked contract #5).
  //
  // VGS-VAULT branches NEVER touch this block (locked: no coordinator for
  // VGS-only groups) — a VGS group's fields don't carry ports and the
  // registry never sees VGS portKeys.
  let groupInstanceId = `vault-${pmSessionId}-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
  let portEpochCounterRef: ref<int> = ref(0)
  let pendingPortsRef: ref<array<pendingPort>> = ref([])
  let installedPortKeysRef: ref<array<string>> = ref([])
  let coordinatorMountRef: ref<option<CoordinatorMount.coordinatorMount>> = ref(None)
  let coordinatorReadyRef: ref<bool> = ref(false)
  let coordinatorListenerName = `onVaultCoordinator-${groupInstanceId}`
  // Active confirm slot: `(confirmId, resolve)` exactly-one-at-a-time (the
  // `confirmingRef` mutex owns the singleton; cleared on settle).
  let coordinatorConfirmPendingRef: ref<option<(string, JSON.t => unit)>> = ref(None)

  // Forward the current `sessions` snapshot to the mounted coordinator —
  // the coordinator decodes vaultCredentials off it for the confirm POST.
  let syncCoordinatorSessions = () => {
    if sessionsDataRef.contents != JSON.Encode.null && coordinatorReadyRef.contents {
      coordinatorMountRef.contents->Option.forEach(mount =>
        mount.iframe->Nullable.make->Window.iframePostMessage(
          [("sessions", sessionsDataRef.contents)]->Dict.fromArray,
        )
      )
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
    let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.vaultSdkDomainUrl).origin
    EventListenerManager.addSmartEventListener(
      "message",
      (ev: Types.event) => {
        let isOurCoordinator =
          coordinatorMountRef.contents
          ->Option.map(m =>
            ev.source === m.iframe->Window.contentWindow && ev.origin === innerIframeOrigin
          )
          ->Option.getOr(false)
        if isOurCoordinator {
          let json = try ev.data->Identity.anyTypeToJson catch { | _ => JSON.Encode.null }
          let dict = json->getDictFromJson
          if dict->getBool("iframeMounted", false) {
            coordinatorReadyRef := true
            flushPendingPorts()
            syncCoordinatorSessions()
          } else {
            switch dict->Dict.get("confirmResult") {
            | Some(result) =>
              let confirmId = dict->getString("confirmId", "")
              switch coordinatorConfirmPendingRef.contents {
              | Some((pendingId, settle)) if pendingId == confirmId =>
                coordinatorConfirmPendingRef := None
                settle(result)
              | _ => ()
              }
            | None => ()
            }
          }
        }
      },
      coordinatorListenerName,
    )
  }

  let ensureCoordinatorMounted = () => {
    switch coordinatorMountRef.contents {
    | Some(_) => ()
    | None =>
      // Fullscreen answer-loop satellites: same shape as the payments group
      // (pass-through `options` anatomy mirrors the group's mount config;
      // appearance from the top-level merchant bag).
      let groupAppearance =
        optionsDict->Dict.get("appearance")->Option.getOr(Dict.make()->JSON.Encode.object)
      let groupConfigAsOptions =
        [
          ("sdkAuthorization", sdkAuthorizationRaw->JSON.Encode.string),
          ("publishableKey", publishableKey->JSON.Encode.string),
          ("appearance", groupAppearance),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object
      let mount = CoordinatorMount.create(
        ~parentContainer=Window.body,
        ~localSelectorString=groupInstanceId,
        ~elementIframeId="cardFormCoordinator",
        ~surfaceFamily="vault",
        ~groupId=groupInstanceId,
        ~sdkDomain=ApiEndpoint.vaultSdkDomainUrl,
      )
      coordinatorMountRef := Some(mount)
      attachCoordinatorListener()
      // Per-group fullscreen lifecycle (router + answerer — see PaymentsGroup
      // for the full rationale; grouped slot + ungated teardown + uplink).
      let (fullscreenRouter, fullscreenAnswerer) = CoordinatorMount.makeFullscreenFlows(
        ~mount,
        ~localSelectorString=groupInstanceId,
        ~sdkDomain=ApiEndpoint.vaultSdkDomainUrl,
        ~options=groupConfigAsOptions,
        ~appearance=groupAppearance,
      )
      // Types.event (EventListenerManager's domain) and Window.event are
      // structurally the same message event — cast keeps both sites exact.
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenRouter(%raw(`ev`)),
        `onVaultCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.addSmartEventListener(
        "message",
        (ev: Types.event) => fullscreenAnswerer(%raw(`ev`)),
        CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
      )
    }
  }

  // 3. Mode A vs Mode B bootstrap — synchronously kick off whichever path applies.
  let vaultOptionDict = optionsDict->Dict.get("vault")->Option.flatMap(JSON.Decode.object)

  switch vaultOptionDict {
  | Some(vaultDict) => {
      // Mode B — skip discovery fetch.
      let vaultType = vaultDict->getString("vault_type", "")
      let vaultData = vaultDict->Dict.get("vault_data")->Option.getOr(JSON.Encode.null)
      // Mode B callers may also pass `expires_at` on the top level if they
      // already hold the backend response; default "" → treated as unknown.
      let expiresAt = optionsDict->getString("expires_at", "")
      expiresAtRef := parseExpiresAtMs(expiresAt)

      let syntheticSession = buildSyntheticSession(
        ~pmSessionId,
        ~customerId,
        ~vaultType,
        ~vaultData,
        ~expiresAt,
      )
      sessionsDataRef := syntheticSession

      // Run through the canonical VaultHelpers decode path so both modes produce
      // identical typed outputs downstream.
      let vaultMode = vaultType->VaultHelpers.getVaultModeFromName
      let loadedSession: PaymentType.loadType = Loaded(syntheticSession)
      let vaultConfigJson = VaultHelpers.buildVaultConfig(loadedSession, vaultMode)
      vaultCredentialsRef := vaultConfigJson
    }
  | None => {
      // Mode A — discovery fetch. Issued from this merchant-page context,
      // matching `Hyper.res:776` (`fetchSessions`); the result will be posted
      // into the coordinator iframe via the standard `sessions` channel once
      // Task 3 mounts fields.
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)
      PaymentHelpersV2.fetchPaymentManagementList(
        ~pmSessionId,
        ~endpoint,
        ~optLogger=None,
        ~customPodUri="",
        ~sdkAuthorization=sdkAuthorizationRaw,
      )
      ->Promise.then(sessionJson => {
        sessionsDataRef := sessionJson
        let sessionDict = sessionJson->getDictFromJson
        let expiresAt = sessionDict->getString("expires_at", "")
        expiresAtRef := parseExpiresAtMs(expiresAt)

        let vaultType =
          sessionDict->getDictFromDict("vault_details")->getString("vault_type", "")
        let vaultMode = vaultType->VaultHelpers.getVaultModeFromName
        let loadedSession: PaymentType.loadType = Loaded(sessionJson)
        let vaultConfigJson = VaultHelpers.buildVaultConfig(loadedSession, vaultMode)
        vaultCredentialsRef := vaultConfigJson
        // Late-settle coverage: if the coordinator mounted before the Mode A
        // fetch resolved, push the session snapshot now (ready-flush handles
        // the common ordering; this is the slow-fetch twin).
        syncCoordinatorSessions()
        Promise.resolve()
      })
      ->Promise.catch(err => {
        Console.error2("[PaymentMethodsSessionGroup] session fetch failed", err)
        Promise.resolve()
      })
      ->ignore
    }
  }

  // 4. Field handle factory — Task 3 wires real iframe mounting. Each `create()`
  //    call spins up an iframe at the v18 unified URL
  //    `index.html?componentName=paymentMethodsSDK&fieldName=<bare>&surfaceFamily=vault`
  //    (so App.res routes to `PaymentMethodsSDK`), posts a ParentCardComponent-style
  //    `paymentElementCreate: true` config on `iframeMounted`, and forwards
  //    updates via `paymentElementsUpdate` (LoaderPaymentElement.update). Field
  //    actions ride the existing `doFocus|doBlur|doClearValues` postMessage
  //    protocol; state flows back as `cardStateUpdate` / `savedCardCvcStatus`,
  //    which we re-dispatch to user-registered `on(event, cb)` listeners.
  //
  // v18 naming (SUPERSEDES the v17 `vaultCardNumber` URL scheme): the iframe
  // sees the BARE field name ("cardNumber" / "cardExpiry" / "cardCvc") in the
  // `fieldName` URL param; `surfaceFamily=vault` carries the surface-family
  // signal. The v17 `mapFieldTypeToComponentName` rename is dead.
  // v22 (P2): the allow-list itself is now the shared `CardFormShared` canon
  // (identical to `PaymentsGroup`'s) — aliased, not duplicated.
  let mapFieldTypeToInternalFieldName = CardFormShared.mapFieldTypeToInternalFieldName

  // ── Phase 1b Task A: VGS provider detection + broker memoization ───────
  //
  // Returns "vgs" | "hyperswitch" | "unknown". Reads `vaultCredentialsRef`
  // (populated by bootstrap code in step 3 above) and sniffs VGS via the
  // `{vaultId, environment}` credential shape. Mode A bootstrap resolves
  // async — if `create()` runs before the fetch settles, vaultCredentialsRef
  // is still null and we return "unknown" (which `create()` treats as the
  // Hyperswitch default, matching Phase 1a behavior).
  let detectVaultType = (): string => {
    // Prefer explicit Mode B declaration (synchronous, deterministic).
    let declaredType =
      optionsDict
      ->Dict.get("vault")
      ->Option.flatMap(JSON.Decode.object)
      ->Option.map(d => d->getString("vault_type", ""))
      ->Option.getOr("")
    if declaredType->String.length > 0 {
      declaredType
    } else if VGSVaultBroker.isVGSProvider(vaultCredentialsRef.contents) {
      "vgs"
    } else if vaultCredentialsRef.contents !== JSON.Encode.null {
      // Credentials exist and aren't VGS — Hyperswitch family
      "hyperswitch"
    } else {
      // Mode A fetch not settled yet — default to Hyperswitch (Phase 1a
      // behavior). Task B/Task F may revisit this fallback if Mode A +
      // VGS becomes a supported path in practice.
      "hyperswitch"
    }
  }

  // Memoized broker factory — create ONCE per group and share across all
  // `create()` calls. Returns None for non-VGS providers.
  let getOrCreateVgsBroker = (): option<VGSVaultBroker.vgsBrokerHandle> => {
    switch vgsBrokerRef.contents {
    | Some(broker) => Some(broker)
    | None =>
      // Pull VGS-specific credentials from `vaultCredentialsRef` (Mode A) OR
      // from Mode B's declared `vault_data`.
      let vaultDataDict =
        optionsDict
        ->Dict.get("vault")
        ->Option.flatMap(JSON.Decode.object)
        ->Option.flatMap(d => d->Dict.get("vault_data"))
        ->Option.flatMap(JSON.Decode.object)
      let fromCredentials = vaultCredentialsRef.contents->getDictFromJson
      let vaultId = switch vaultDataDict {
      | Some(d) => d->getString("vault_id", "")
      | None => fromCredentials->getString("vaultId", "")
      }
      let environment = switch vaultDataDict {
      | Some(d) => d->getString("environment", "")
      | None => fromCredentials->getString("environment", "")
      }
      if vaultId->String.length == 0 || environment->String.length == 0 {
        // No usable VGS credentials — keep the broker unset so we don't
        // chase a half-configured path. `create()` will fall back to the
        // default error-handle behavior.
        None
      } else {
        let broker = VGSVaultBroker.make(~pmSessionId, ~vaultId, ~environment, ~eventCallbacksRef)
        vgsBrokerRef := Some(broker)
        Some(broker)
      }
    }
  }

  // `LoaderPaymentElement.make`'s `mountPostMessage` runs on `iframeMounted` and
  // is responsible for the initial config handshake. We synthesise a config
  // payload matching ParentCardComponent's (its keys are what LoaderController
  // actually reads); anything unused by the vault surface is filled with the
  // minimal well-formed value.
  let buildMountConfig = (~options: JSON.t, ~fieldId: string) => {
    // NOTE: `options` here is the PER-FIELD options bag passed to
    // `cardForm.create("cardNumber", opts)`, which is typically `{}`. The
    // merchant's top-level options (including `appearance`) live on the
    // outer `optionsDict` bound at `make()` entry (line 480). We must NOT
    // shadow it — read per-field overrides from `fieldOptionsDict`, then
    // fall back to the outer merchant bag for `appearance`.
    let fieldOptionsDict = options->getDictFromJson
    let savedCardDict = fieldOptionsDict->getDictFromDict("savedCard")
    let savedCardBrand = savedCardDict->getString("brand", "")
    let emptyJson = Dict.make()->JSON.Encode.object
    let fieldAppearance = fieldOptionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
    // Per-field appearance wins only if it actually carries keys; otherwise
    // prefer the merchant-supplied appearance from the top-level bag.
    let appearance = if (
      fieldAppearance
      ->JSON.Decode.object
      ->Option.map(d => d->Dict.keysToArray->Array.length > 0)
      ->Option.getOr(false)
    ) {
      fieldAppearance
    } else {
      optionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
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
    // silently dropped merchant appearance customizations.
    let paymentOptions =
      [
        ("appearance", appearance),
        ("fonts", []->JSON.Encode.array),
        ("locale", locale->JSON.Encode.string),
        ("sdkAuthorization", sdkAuthorizationRaw->JSON.Encode.string),
        ("pmSessionId", pmSessionId->JSON.Encode.string),
      ]->Dict.fromArray->JSON.Encode.object
    [
      ("paymentElementCreate", true->JSON.Encode.bool),
      ("otherElements", false->JSON.Encode.bool),
      ("componentType", "payment"->JSON.Encode.string),
      ("paymentOptions", paymentOptions),
      ("options", options),
      ("iframeId", fieldId->JSON.Encode.string),
      ("publishableKey", publishableKey->JSON.Encode.string),
      ("endpoint", ApiEndpoint.getVaultEndPoint(~publishableKey)->JSON.Encode.string),
      ("sdkSessionId", pmSessionId->JSON.Encode.string),
      ("customPodUri", ""->JSON.Encode.string),
      ("parentURL", "*"->JSON.Encode.string),
      ("sdkHandleOneClickConfirmPayment", false->JSON.Encode.bool),
      ("launchTime", Date.now()->JSON.Encode.float),
      ("loggerSource", "hyper_vault"->JSON.Encode.string),
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
    ]->Dict.fromArray
  }

  // Per-field callback registry — events named `fieldReady`, `fieldChange`,
  // `fieldFocus`, `fieldBlur`, `fieldError` plus the single-slot cardStateUpdate
  // pipeline are wired through `addSmartEventListener` elsewhere. Here we keep a
  // straightforward Dict keyed by event name.
  let createFieldHandle = (fieldType: string, options: JSON.t, fieldId: string): fieldEntry => {
    let iframeRef: ref<Nullable.t<Dom.element>> = ref(Nullable.null)
    // Round-2 NIT-2: the per-field settle-resolver slot was deleted with the
    // retired window-relay — no allocation here.

    // Merchant-registered event listeners.
    let eventHandlersRef: ref<Dict.t<JSON.t => unit>> = ref(Dict.make())

    // Capture the merchant-supplied `savedCard` hints so the Flow B branch
    // of `confirm()` can surface them on the success union without requiring
    // the field's postMessage payload to round-trip cardholder-sensitive
    // data back.
    let savedCardDict = options->getDictFromJson->getDictFromDict("savedCard")
    let savedCardBrandRef = ref(savedCardDict->getString("brand", ""))
    let savedCardLast4Ref = ref(savedCardDict->getString("last4", ""))

    // Per-field raw-value caches DELETED (review): nothing populates them —
    // the coordinator receives full snapshots on the port plane; the window
    // `cardStateUpdate` carries the SPLIT payload with raw keys absent.
    // v20 Chunk 2 rework — auto-focus progression. Tracks the previous
    // `focusReady` emitted by this field's iframe so the `cardStateUpdate`
    // branch can detect its false→true edge and post `doFocus` to the NEXT
    // field's iframe exactly once per "user finished this field" moment —
    // not on every keystroke that keeps the field focus-ready.
    let prevFocusReadyRef = ref(false)

    // The `mountPostMessage` LoaderPaymentElement invokes on `iframeMounted`:
    // we post the initial config into the fresh iframe, then follow with any
    // `sessions` snapshot we already hold. The iframe's LoaderController reads
    // this and hands off to the vault-host tree.
    let mountPostMessage = (mountedIframeRef, _selectorString, _sdkHandleOneClick) => {
      let config = buildMountConfig(~options, ~fieldId)
      // MessageChannel Card Relay: ONE channel per field mount per portEpoch.
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
        {fieldName: mapFieldTypeToInternalFieldName(fieldType), epoch, port: channel.port1},
      ])
      flushPendingPorts()
      // Mirror what ParentCardComponent.res:519-526 does: if we already hold
      // the session JWT, forward it so the inner LoaderController can populate
      // its `sessions` atom → `vaultCredentials` atom → field components.
      if sessionsDataRef.contents != JSON.Encode.null {
        mountedIframeRef->Window.iframePostMessage(
          [("sessions", sessionsDataRef.contents)]->Dict.fromArray,
        )
      }
      // Brand-cache warm-up for a late-mounted cardCvc. The `cardStateUpdate`
      // branch only pushes on a brand CHANGE; a CVC field mounted after the
      // user already finished the cardNumber would otherwise sit at the
      // permissive default until the next brand transition (or forever, if
      // none comes). Mount order is merchant-controlled, so the group fills
      // the gap at handshake time with whatever it has already learned.
      if fieldType === "cardCvc" && lastDetectedBrandRef.contents !== "" {
        mountedIframeRef->Window.iframePostMessage(
          [("detectedCardBrand", lastDetectedBrandRef.contents->JSON.Encode.string)]->Dict.fromArray,
        )
      }
    }

    // Wire merchant-facing event handlers. Match the message by its window
    // source (the per-field iframe's contentWindow) AND origin — top-level
    // `iframeId` is only present in `ready|focus|blur` payloads, not in
    // `cardStateUpdate`, so keying on source is the reliable cross-event
    // matcher. Origin check adds defense-in-depth against our own iframe
    // being redirected to a hostile origin mid-session (mirrors
    // ParentCardComponent.res:559-565).
    let attachFieldListener = () => {
      let innerIframeOrigin = URLModule.makeUrl(ApiEndpoint.vaultSdkDomainUrl).origin
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
            let isCardTokenEvent = dict->getBool("cardTokenEvent", false)
            let isCardTokenFail = dict->getBool("cardTokenFail", false)
            let isCvcTokenEvent = dict->getBool("savedCardCvcTokenEvent", false)
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
            } else if isCardTokenEvent || isCardTokenFail || isCvcTokenEvent {
              // Retired window-relay resolution (keys posted today by
              // HyperswitchVaultCardCollector / VGSVault / CardCVCElement —
              // none of which this group's fieldName URLs load): relay
              // resolve confirms land ONLY via the coordinator's masked
              // `confirmResult` envelope now. Arm kept as a no-op catch.
              ()
            } else {
              switch cardStateUpdate {
              | Some(stateJson) =>
                // `cardStateUpdate` rides the `change` channel. When it carries
                // an error we ALSO fire the merchant's `error` listener — Task 7
                // plans this once per state update (never double-fires with the
                // group-level `error` event which emits from the confirm path
                // only). The envelope includes `elementType`/`iframeId` so the
                // merchant knows which field flagged it.
                let stateDict = stateJson->getDictFromJson
                // The raw-SAD half of `cardStateUpdate` rides the port plane
                // straight to the coordinator (the raw caches that lived here
                // are deleted) — the SPLIT payload fed into this branch never
                // carries `rawCardNumber`/`rawCardExpiry`/`rawCvc`.

                // ── v20 Chunk 2 rework: auto-focus progression ─────────────
                // The field's iframe decides WHEN focus should advance (it has
                // the keystroke stream + brand context); this group only routes
                // the signal. We watch the emitted `focusReady` key for its
                // `false → true` edge and post `doFocus` into the NEXT field's
                // iframe exactly once per "user finished this field" moment.
                // `prevFocusReadyRef` is the latch — steady-state keystrokes
                // that keep the field focus-ready don't re-fire. The envelope
                // default-absent → false keeps the latch simple. cardCvc's
                // `nextFieldFor` is None, so the edge there is a no-op.
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

                // ── v20 Chunk 2 follow-up: brand-aware CVC maxLength ───────
                // The cardNumber iframe detects the brand on every keystroke
                // and surfaces it in this envelope. Cache the latest non-empty
                // value group-wide, and on every CHANGE push it to the cardCvc
                // iframe so its `useCardForm` re-derives `cardBrandForCvc` /
                // `maxCVCLength` reactively. Flow B (saved-card CVC) is
                // untouched — its `savedCardBrand` mount-config key feeds the
                // same `~cardBrandOverride` slot with higher priority.
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

                let errorMessage = stateDict->getString("error", "")
                // Reshape to plan §4.3 `{empty, complete, valid, error?,
                // brand?, elementType}` before surfacing to merchants.
                let changePayload = reshapeCardStateUpdateToChangePayload(
                  ~fieldType,
                  ~stateJson,
                )
                eventHandlersRef.contents
                ->Dict.get("change")
                ->Option.forEach(cb => cb(changePayload))
                if errorMessage->String.length > 0 {
                  let errorPayload = {
                    let errDict = Dict.make()
                    errDict->Dict.set("elementType", fieldType->JSON.Encode.string)
                    errDict->Dict.set("iframeId", fieldId->JSON.Encode.string)
                    errDict->Dict.set("message", errorMessage->JSON.Encode.string)
                    errDict->JSON.Encode.object
                  }
                  eventHandlersRef.contents
                  ->Dict.get("error")
                  ->Option.forEach(cb => cb(errorPayload))
                }
              | None => ()
              }
            }
          }
        },
        `onVaultField-${fieldId}`,
      )
    }

    // One `LoaderPaymentElement` per field. Uses the v18 unified URL
    // (`componentName=paymentMethodsSDK&fieldName=<bare>&surfaceFamily=vault`)
    // so `App.res` routes to `PaymentMethodsSDK`; per-field dispatch happens
    // inside `PaymentMethodsSDK` via the `fieldName` + `surfaceFamily` URL
    // params. Merchant-facing string (`cardNumber|cardExpiry|cardCvc`) is
    // already bare for vault (no V* suffix to strip).
    // Per-field appearance wins only if it actually carries keys; otherwise
    // prefer the merchant-supplied appearance from the top-level
    // (`optionsDict`) bag. Mirrors the precedence rule used by
    // `buildMountConfig` above — `options` here is the PER-FIELD bag passed
    // to `cardForm.create("cardNumber", opts)` and is typically `{}`.
    //
    // The merged appearance is ALSO injected into the positional `options`
    // JSON handed to `LoaderPaymentElement.make`, because that component
    // reads `appearance.variables.cardFieldHeight` from its OWN `optionsDict`
    // (the positional bag, see LoaderPaymentElement.res:365+543-547) to size
    // the iframe wrapper. Without this, a merchant-bumped `cardFieldHeight`
    // never reaches the iframe style.
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
      optionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
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
      ~sdkDomainUrl=ApiEndpoint.vaultSdkDomainUrl,
      ~logger=None,
      ~confirmPayment=(_json => Promise.resolve(JSON.Encode.null)),
      ~fieldName=mapFieldTypeToInternalFieldName(fieldType),
      ~surfaceFamily="vault",
      ~groupId=groupInstanceId,
    )

    attachFieldListener()

    let handle: fieldHandle = {
      mount: selector => {
        element.mount(selector)
      },
      unmount: () => {
        element.unmount()
      },
      destroy: () => {
        element.destroy()
        iframeRef := Nullable.null
        // Remove THIS field's smartEventListener so destroying one field
        // doesn't leak its routing callback across remount cycles on the
        // same page. `fieldId` is unique per `create()` (timestamp+rand), so
        // dead listeners would otherwise ACCUMULATE (never clobber). The
        // listener is registered by `attachFieldListener` under
        // `onVaultField-${fieldId}`; removal here is the single teardown
        // site and is idempotent — group-level `deinit()` reaches it via its
        // per-entry `handle.destroy()` walk, so both paths are covered
        // without a deinit-callback pool.
        EventListenerManager.removeSmartEventListener(
          "message",
          `onVaultField-${fieldId}`,
        )
      },
      update: newOptions => {
        // Post `paymentElementsUpdate` (mirrors LoaderPaymentElement.update)
        // through our own ref — the 4th-arg array stays empty by design.
        iframeRef.contents->Window.iframePostMessage(
          [
            ("paymentElementsUpdate", true->JSON.Encode.bool),
            ("options", newOptions),
          ]->Dict.fromArray,
        )
        // Forward `savedCard.brand` explicitly — the generic `updateOptions`
        // path in LoaderController expects it as a top-level key, not nested.
        let d = newOptions->getDictFromJson->getDictFromDict("savedCard")
        let brand = d->getString("brand", "")
        if brand->String.length > 0 {
          iframeRef.contents->Window.iframePostMessage(
            [("savedCardBrand", brand->JSON.Encode.string)]->Dict.fromArray,
          )
        }
        // Refresh the group-side captured savedCard hints (brand + last4) —
        // without this, `field.update({savedCard: {...}})` re-pointed the
        // iframe's brand-driven validation but the Flow B branch of
        // `confirm()` still built the success union from the values captured
        // at `create()` time. Per-key `!== ""` guards mirror the create
        // captures above: a partial update (brand only, or last4 only) never
        // blanks out the sibling hint. Mirrors the payments group's
        // `savedCardTokenRef` refresh discipline (Flows are symmetric).
        let last4 = d->getString("last4", "")
        if brand !== "" {
          savedCardBrandRef := brand
        }
        if last4 !== "" {
          savedCardLast4Ref := last4
        }
      },
      focus: () => {
        // LoaderPaymentElement's own focus() walks the (empty-by-design) 4th
        // arg array; we bypass it and post directly via the ref that
        // setIframeRef gave us. Matches ParentCardComponent's pattern.
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

    {
      iframeRef,
      handle,
      fieldType,
      savedCardBrandRef,
      savedCardLast4Ref,
      prevFocusReadyRef,
    }
  }

  let create = (fieldType: string, options: JSON.t): fieldHandle => {
    if sessionStateRef.contents != Active {
      // Guide §4.1: `create` itself doesn't return the union — callers observe
      // `session_consumed` on `confirm()`. But `mount()` on a dead session is
      // meaningless, so return a handle that no-ops on every call.
      Console.warn(
        `[PaymentMethodsSessionGroup] create("${fieldType}") called on consumed/deinitialized session`,
      )
      Types.defaultFieldHandle
    } else {
      switch mapFieldTypeToInternalFieldName(fieldType) {
      | "" => {
          // Guide §4.1: unknown field types live in the error-handle path, not
          // a synchronous throw — merchants add fields defensively and the
          // error surfaces on mount rather than at create().
          Console.error(
            `[PaymentMethodsSessionGroup] invalid_field_type: ${fieldType}`,
          )
          Types.defaultFieldHandle
        }
      | _ =>
        let vaultType = detectVaultType()
        switch vaultType {
        | "vgs" =>
          // Phase 1b Task B — VGS branch. Lazily create the broker (first
          // `create()` for VGS mounts the script-fetch machinery) and return
          // a real `fieldHandle` whose methods delegate to the broker:
          //   mount    → broker.mountField(fieldId, fieldType, selector, options)
          //   update   → broker.updateField(fieldId, options)
          //   unmount  → broker.unmountField(fieldId)
          //   focus / blur / clear → %raw method calls on the stored VGS
          //                          fieldHandle via the broker's fieldsRef.
          //   on(evt, cb) → registers in `eventCallbacksRef` keyed
          //                 `"<fieldId>::<event>"` so the broker's field
          //                 event dispatchers can find the listener.
          switch getOrCreateVgsBroker() {
          | Some(broker) => {
              let fieldId = `${fieldType}-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
              // Task C: capture savedCard hints so the Flow B branch of
              // `confirm()` can surface {card:{brand, last4}} on the Flow B
              // success union without a backend round-trip. Only relevant
              // for cardCvc fields; we're harmless if this fires for others.
              let savedCardDict = options->getDictFromJson->getDictFromDict("savedCard")
              let scBrand = savedCardDict->getString("brand", "")
              let scLast4 = savedCardDict->getString("last4", "")
              if fieldType === "cardCvc" && (scBrand->String.length > 0 || scLast4->String.length > 0) {
                vgsSavedCardBrandRef := scBrand
                vgsSavedCardLast4Ref := scLast4
              }
              // VGS still tracks the field in the group's `fields` JSON so
              // merchants can enumerate via group.fields.
              let fieldsDict = fields.contents->getDictFromJson
              let fieldMeta =
                [
                  ("id", fieldId->JSON.Encode.string),
                  ("type", fieldType->JSON.Encode.string),
                  ("provider", "vgs"->JSON.Encode.string),
                ]
                ->Dict.fromArray
                ->JSON.Encode.object
              fieldsDict->Dict.set(fieldId, fieldMeta)
              fields := fieldsDict->JSON.Encode.object

              // Track the most recently mounted selector on the handle so
              // later destroy()/unmount() flows can recover the DOM spot
              // without needing to round-trip through the broker's
              // (private) fieldsRef. Mirrors the `uniqueSelector` tracking
              // Hyper's LoaderPaymentElement does for Hyperswitch fields.
              let uniqueSelectorRef: ref<option<string>> = ref(None)

              // Group-appearance umbrella for the VGS path. Mirrors the
              // merge in `createFieldHandle` (Hyperswitch branch) exactly:
              // the per-field `appearance` from `cardForm.create(type, opts)`
              // wins only when it carries keys; otherwise fall back to the
              // group-level appearance from `paymentMethodsSession(options)`.
              // The broker reads `appearance.variables.cardFieldHeight` off
              // the options bag it receives — without this merge a
              // merchant-set GROUP appearance was silently dropped for VGS.
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
                optionsDict->Dict.get("appearance")->Option.getOr(emptyJson)
              }
              // Inject the resolved appearance back into the per-field
              // options JSON handed to the broker (other keys preserved).
              let fieldOptionsWithAppearanceDict = fieldOptionsDict->Dict.copy
              fieldOptionsWithAppearanceDict->Dict.set("appearance", appearanceJson)
              let optionsForBroker = fieldOptionsWithAppearanceDict->JSON.Encode.object

              // Helper: pull the VGS field's opaque handle (if mounted) so
              // %raw methods can target it. The broker fieldsRef is the
              // single source of truth; the handle slot is Option because
              // fields are created before they are mounted.
              let getFieldHandle = (): option<JSON.t> => {
                switch broker.fieldsRef.contents->Dict.get(fieldId) {
                | Some(entry) => entry.fieldHandle
                | None => None
                }
              }

              // The real VGS handle. All methods delegate to the broker; the
              // broker owns the VGS-side field lifecycle and we just plumb
              // through the public fieldHandle API surface.
              let handle: fieldHandle = {
                mount: selector => {
                  uniqueSelectorRef := Some(selector)
                  broker
                  .mountField(~fieldId, ~fieldType, ~selector, ~options=optionsForBroker)
                  ->Promise.catch(err => {
                    // Plan §4.4's error contract: mount failures surface via
                    // the confirm-path union, not via a sync throw. Log so
                    // integrators iterating in devtools can see the cause.
                    Console.error2(
                      `[PaymentMethodsSessionGroup] VGS mountField(${fieldType}, ${selector}) failed`,
                      err->Identity.anyTypeToJson,
                    )
                    Promise.resolve()
                  })
                  ->ignore
                },
                unmount: () => {
                  broker.unmountField(~fieldId)
                  uniqueSelectorRef := None
                },
                destroy: () => {
                  broker.unmountField(~fieldId)
                  uniqueSelectorRef := None
                },
                update: newOptions => {
                  broker.updateField(~fieldId, ~options=newOptions)
                  // Refresh the group-side captured savedCard hints — mirrors
                  // the Hyperswitch branch's savedCard*Ref refresh. Without
                  // this the Flow B success union kept the brand/last4 from
                  // `create()` even after the merchant switched saved cards
                  // via `field.update({savedCard: {...}})`. Per-key `!== ""`
                  // guards prevent a partial update blanking out the sibling
                  // hint (mirrors the create capture guards above).
                  let savedCardDict = newOptions->getDictFromJson->getDictFromDict("savedCard")
                  let scBrand = savedCardDict->getString("brand", "")
                  let scLast4 = savedCardDict->getString("last4", "")
                  if scBrand !== "" {
                    vgsSavedCardBrandRef := scBrand
                  }
                  if scLast4 !== "" {
                    vgsSavedCardLast4Ref := scLast4
                  }
                },
                focus: () => {
                  switch getFieldHandle() {
                  | Some(fh) =>
                    try {
                      %raw(`(function(field) { if (field && typeof field.focus === "function") field.focus(); })`)(fh)
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS focus(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS focus(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                blur: () => {
                  switch getFieldHandle() {
                  | Some(fh) =>
                    try {
                      %raw(`(function(field) { if (field && typeof field.blur === "function") field.blur(); })`)(fh)
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS blur(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS blur(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                clear: () => {
                  // VGSCollect 2.27 field handles expose `clear()` for an
                  // input reset; if a future version drops it the warn
                  // below fires so integrators can swap to `update()`.
                  switch getFieldHandle() {
                  | Some(fh) =>
                    try {
                      let cleared: bool = %raw(`(function(field) {
                        if (field && typeof field.clear === "function") { field.clear(); return true; }
                        return false;
                      })`)(fh)
                      if !cleared {
                        Console.warn(
                          `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) — field has no clear() method; use update({placeholder: ..., validations: ...}) instead`,
                        )
                      }
                    } catch {
                    | exn =>
                      Console.error2(
                        `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) threw`,
                        exn->Identity.anyTypeToJson,
                      )
                    }
                  | None =>
                    Console.warn(
                      `[PaymentMethodsSessionGroup] VGS clear(${fieldId}) — field not yet mounted`,
                    )
                  }
                },
                on: (event, cb) => {
                  // Register merchant listener in the group's shared
                  // eventCallbacksRef, keyed `"<fieldId>::<event>"` so the
                  // broker's per-field event dispatchers (VGSVaultBroker's
                  // `dispatchFieldEvent`) can find them by composite key.
                  // Must match `VGSVaultBroker.eventKey` exactly.
                  let key = `${fieldId}::${event}`
                  eventCallbacksRef.contents->Dict.set(key, cb)
                },
              }
              handle
            }
          | None => {
              // VGS declared but credentials missing. Surface a clear
              // console error and return the no-op handle.
              Console.error(
                `[PaymentMethodsSessionGroup] vault_type="vgs" declared but vault_data has no vault_id/environment — cannot mount`,
              )
              Types.defaultFieldHandle
            }
          }
        | "hyperswitch" =>
          // First hosted-field mount also creates the hidden confirm-owner
          // (MessageChannel Card Relay contract #2). Locked: VGS-only groups
          // never reach this branch — no coordinator gets resources it can't
          // exercise.
          ensureCoordinatorMounted()
          let fieldId = `${fieldType}-${Date.now()->Float.toString}-${Math.random()->Float.toString->String.slice(~start=2, ~end=8)}`
          let entry = createFieldHandle(fieldType, options, fieldId)
          fieldsRef.contents->Dict.set(fieldId, entry)
          // Mirror the existence of this field in the JSON blob the group
          // exposes, so callers can enumerate created fields.
          let fieldsDict = fields.contents->getDictFromJson
          let fieldMeta =
            [
              ("id", fieldId->JSON.Encode.string),
              ("type", fieldType->JSON.Encode.string),
            ]->Dict.fromArray->JSON.Encode.object
          fieldsDict->Dict.set(fieldId, fieldMeta)
          fields := fieldsDict->JSON.Encode.object
          entry.handle
        | other => {
            Console.error(
              `[PaymentMethodsSessionGroup] unsupported_provider: vault_type "${other}" not yet supported`,
            )
            Types.defaultFieldHandle
          }
        }
      }
    }
  }

  // Group-level update() is intentionally a no-op on the vault surface:
  // session options (sdkAuthorization, appearance) are fixed at
  // `paymentMethodsSession(...)` creation time.
  let update = (_options: JSON.t): unit => {
    Console.warn(
      "[PaymentMethodsSessionGroup] session options are fixed at creation; create a new session to change them",
    )
  }

  // 5. Group-level event registry.
  let on = (event: string, cb: JSON.t => unit): unit => {
    eventCallbacksRef.contents->Dict.set(event, cb)
  }

  // 6. Unified `confirm()` — Phase 1a Task 4 wires the real round-trips;
  //    v20 Chunk 2 collapses the old separate full-card / saved-card-CVC
  //    entrypoints into ONE flow-inferring `confirm()`.
  //
  //    Guard order (first match wins, per guide §4.4.1):
  //      1. sessionStateRef != Active                              → session_consumed
  //         (covers both Consumed and Deinitialized — both mean "done")
  //      2. confirmingRef == true                                  → confirm_in_progress
  //      3. expiresAt in the past                                  → session_expired
  //      4. mounted-field-set inference (see below)                → incomplete_field_set
  //      5. run confirm relay (postMessage → field → vault POST → postMessage back)
  //
  //    Flow inference (v20 contract, Types.res §CardForm):
  //      cardNumber (or any of cardNumber|cardExpiry) mounted → Flow A (full
  //        tokenization; the full set {cardNumber, cardExpiry, cardCvc} is
  //        expected — cardNumber alone is accepted as the minimal tokenize
  //        signal, matching the legacy behaviour this unifies).
  //      ONLY cardCvc mounted → Flow B (saved-card CVC recollect; the merchant
  //        passes `{savedCard: {brand, last4}}` at `create("cardCvc", opts)` —
  //        captured at field-create time into savedCard*Ref below).
  //      nothing mounted → reject with `incomplete_field_set`.
  //
  //    On success: sessionStateRef := Consumed. On failure: state stays Active
  //    so the merchant can retry. The `confirmingRef` mutex is always released
  //    when the relay settles (success or failure).

  // Helper: locate the first fieldEntry of the requested type. The group
  // permits multiple fields of the same type to be created; confirm is
  // single-shot, and our contract is "first mounted cardNumber (or cardCvc)
  // wins" — matching what the guide describes.
  let findFieldOfType = (matchFieldType: string): option<fieldEntry> => {
    fieldsRef.contents
    ->Dict.valuesToArray
    ->Array.find(entry => entry.fieldType === matchFieldType)
  }

  // Shared confirm-relay driver — RETIRED (the coordinator relays confirms
  // now; see `runCoordinatorRelay`). Historical note: it once posted
  // `triggerKey` (e.g. "initiate-confirm") into the field's iframe and
  // awaited the message the field posted back.
  //
  // NOTE on message-handler lifecycle (historical): the per-field
  // `attachFieldListener` at create() time watched every postMessage from
  // this iframe for the lifetime of the field; a dedicated per-field
  // resolver slot once woke one round-trip exactly once — that slot was
  // hard-deleted in round 2 (NIT-2): settlement is `coordinatorConfirmPendingRef`
  // (confirmId-keyed).
  //
  // Task 7: every failure path emits a single `error` group event with the
  // same envelope that resolves the promise. We centralize emission at the
  // `settle` callsite so we always fire exactly once per failure.
  let emitGroupError = (envelope: JSON.t): unit => {
    eventCallbacksRef.contents->Dict.get("error")->Option.forEach(cb => cb(envelope))
  }

  let settleResult = (resolve: JSON.t => unit, result: JSON.t): unit => {
    // Task 7 invariant: promise resolution AND `error` event fire exactly once
    // per failure. Success envelopes are not re-emitted as events (matches
    // the guide's §4.3 `error` event contract — only failures broadcast).
    let outcomeDict = result->getDictFromJson
    let isError = outcomeDict->getString("status", "") === "error"
    if isError {
      emitGroupError(result)
    }
    resolve(result)
  }

  // NOTE: format-preserving alias → brand detector is now at module scope
  // (see `detectBrandFromAlias` above `make()`); Task F hoisted it there so
  // unit tests can exercise the BIN-prefix table directly.

  // ── VGS confirm paths (task 4c / 4d) ─────────────────────────────────────
  //
  // The Hyperswitch branch routes via field-iframe postMessage
  // (`initiate-confirm` → `cardTokenEvent`). VGS path calls the broker's
  // `submitForm()` directly — same single `vault.submit("/post", ...)` for
  // both Flow A (full card, 4c) and Flow B (saved-card CVC recollect, 4d).
  // For 4c the response contains all 4 aliases (`card_number`,
  // `card_exp_month`, `card_exp_year`, `card_cvc`); for 4d only `card_cvc`
  // is populated because only the CVC field was mounted on the form.
  //
  // Guard order and mutex discipline exactly mirror the Hyperswitch paths:
  //   1) sessionStateRef check lives at the call site (shared)
  //   2) confirm-set already flipped `confirmingRef := true`; we ALWAYS reset
  //      it in both success and failure settles.
  //   3) We `sessionStateRef := Consumed` on success only — failures leave
  //      the session Active so the merchant can retry.
  //   4) `settleResult` emits the group-level `error` event on failure and
  //      resolves the promise exactly once in both branches.
  let confirmVgsFlowA = (): promise<JSON.t> => {
    switch getOrCreateVgsBroker() {
    | None =>
      // VGS provider was detected but we couldn't construct a broker (missing
      // credentials). Surface as a validation error — this is a merchant
      // configuration problem, not a tokenization problem.
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "validation_error",
            message: Some(
              "VGS vault declared but vault_data missing vault_id/environment — cannot confirm",
            ),
            locale,
            typeOverride: Some(ValidationError),
          }),
        ),
      )
    | Some(broker) =>
      // Check that at least one cardNumber field is mounted. "Mounted" =
      // broker's fieldsRef has an entry with a non-None fieldHandle. We
      // don't check isEmpty — VGSCollect will surface empty-field errors
      // through onError. Mirrors §5.1 Task 4c spec: "at least cardNumber
      // field mounted" is the required precondition.
      let cardNumberMounted =
        broker.fieldsRef.contents
        ->Dict.valuesToArray
        ->Array.some(entry => entry.fieldType === "cardNumber" && entry.fieldHandle->Option.isSome)
      if !cardNumberMounted {
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "validation_error",
              message: Some(
                "cardNumber field not mounted — call cardForm.create(\"cardNumber\", opts) then mount() before confirm()",
              ),
              locale,
              typeOverride: None,
            }),
          ),
        )
      } else {
        confirmingRef := true
        broker
        .submitForm()
        ->Promise.then(result => {
          let resultDict = result->getDictFromJson
          let status = resultDict->getString("status", "")
          if status == "error" {
            // Forward the error envelope from submitForm into the locked
            // guide §4.4 shape. All VGS-side failures are tokenization/api
            // problems → ApiError type; we honor the code surfaced by the
            // broker (usually "tokenization_failed" or "vgs_form_not_ready").
            confirmingRef := false
            let errDict = resultDict->getDictFromDict("error")
            let code = errDict->getString("code", "tokenization_failed")
            let message = errDict->getString("message", "")
            let envelope = buildConfirmResult(
              ~outcome=Failure({
                code,
                message: if message->String.length > 0 {
                  Some(message)
                } else {
                  None
                },
                locale,
                typeOverride: Some(ApiError),
              }),
            )
            // Task 7 invariant: fire the group-level `error` event alongside
            // promise resolution exactly once per failure. Success envelopes
            // don't re-emit (matches Hyperswitch relay discipline).
            emitGroupError(envelope)
            Promise.resolve(envelope)
          } else {
            // Success: mark session consumed, decode + emit Flow A union.
            // Failure to decode (e.g. alias absent) still consumes the
            // session — matches Hyperswitch semantics where a successful
            // postMessage round-trip implies the vault has already vaulted
            // the data.
            sessionStateRef := Consumed
            let cardNumberAlias = resultDict->getString("card_number", "")
            let expMonth = resultDict->getString("card_exp_month", "")
            let expYear = resultDict->getString("card_exp_year", "")
            // Brand derived from the BIN prefix retained in the
            // format-preserving alias. Empty when no range matches.
            let brand = detectBrandFromAlias(cardNumberAlias)
            let last4 =
              cardNumberAlias->String.length >= 4
                ? cardNumberAlias->String.sliceToEnd(~start=cardNumberAlias->String.length - 4)
                : ""
            let envelope = buildConfirmResult(
              ~outcome=FlowASuccess({
                token: cardNumberAlias,
                // Phase 1b: no backend session-confirm — the card_number
                // alias IS the merchant's VGS reference; paymentMethodId
                // stays None (serializes to JSON null) per §4c. Merchant
                // backend resolves it against their own VGS proxy.
                paymentMethodId: None,
                brand,
                last4,
                expiryMonth: expMonth,
                expiryYear: expYear,
              }),
            )
            confirmingRef := false
            Promise.resolve(envelope)
          }
        })
        ->Promise.catch(_exn => {
          // Defensive — broker.submitForm() never rejects; if it ever does
          // (refactor regression), the merchant still gets a sane envelope.
          confirmingRef := false
          let envelope = buildConfirmResult(
            ~outcome=Failure({
              code: "tokenization_failed",
              message: Some("VGS submitForm rejected unexpectedly"),
              locale,
              typeOverride: Some(ApiError),
            }),
          )
          emitGroupError(envelope)
          Promise.resolve(envelope)
        })
      }
    }
  }

  // VGS Flow B (saved-card CVC recollect): the v20 unified `confirm()` routes
  // here when the ONLY mounted field is a VGS `cardCvc`. Semantics are the
  // retired separate-CVC-entrypoint's, now reached purely by mounted-field
  // inference.
  let confirmVgsFlowB = (): promise<JSON.t> => {
    switch getOrCreateVgsBroker() {
    | None =>
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "validation_error",
            message: Some(
              "VGS vault declared but vault_data missing vault_id/environment — cannot confirm Flow B (saved-card CVC recollect)",
            ),
            locale,
            typeOverride: Some(ValidationError),
          }),
        ),
      )
    | Some(broker) =>
      let cardCvcMounted =
        broker.fieldsRef.contents
        ->Dict.valuesToArray
        ->Array.some(entry => entry.fieldType === "cardCvc" && entry.fieldHandle->Option.isSome)
      if !cardCvcMounted {
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "validation_error",
              message: Some(
                "cardCvc field not mounted — for saved-card recollect, call cardForm.create(\"cardCvc\", {savedCard: {brand, last4}}) then mount() before confirm()",
              ),
              locale,
              typeOverride: None,
            }),
          ),
        )
      } else {
        confirmingRef := true
        broker
        .submitForm()
        ->Promise.then(result => {
          let resultDict = result->getDictFromJson
          let status = resultDict->getString("status", "")
          if status == "error" {
            confirmingRef := false
            let errDict = resultDict->getDictFromDict("error")
            let code = errDict->getString("code", "tokenization_failed")
            let message = errDict->getString("message", "")
            let envelope = buildConfirmResult(
              ~outcome=Failure({
                code,
                message: if message->String.length > 0 {
                  Some(message)
                } else {
                  None
                },
                locale,
                typeOverride: Some(ApiError),
              }),
            )
            emitGroupError(envelope)
            Promise.resolve(envelope)
          } else {
            sessionStateRef := Consumed
            let cvcAlias = resultDict->getString("card_cvc", "")
            let brand = vgsSavedCardBrandRef.contents
            let last4 = vgsSavedCardLast4Ref.contents
            let envelope = buildConfirmResult(
              ~outcome=FlowBSuccess({cvcToken: cvcAlias, brand, last4}),
            )
            confirmingRef := false
            Promise.resolve(envelope)
          }
        })
        ->Promise.catch(_exn => {
          confirmingRef := false
          let envelope = buildConfirmResult(
            ~outcome=Failure({
              code: "tokenization_failed",
              message: Some("VGS submitForm rejected unexpectedly"),
              locale,
              typeOverride: Some(ApiError),
            }),
          )
          emitGroupError(envelope)
          Promise.resolve(envelope)
        })
      }
    }
  }

  // Relay a masked command envelope into the coordinator iframe. Settle is
  // centrally keyed on `confirmId` returned in the coordinator's
  // `confirmResult` broadcast; the group keeps an exactly-once sink + an 8s
  // hang backstop so a dropped frame resolves deterministically.
  let runCoordinatorRelay = (
    ~flow: string,
    ~savedCardBrand: string="",
    ~savedCardLast4: string="",
  ): promise<JSON.t> => {
    switch coordinatorMountRef.contents {
    | None =>
      Promise.resolve(
        buildConfirmResult(
          ~outcome=Failure({
            code: "tokenization_failed",
            message: Some(
              "cardFormCoordinator is not mounted — create + mount a hosted (non-VGS) card field before calling confirm()",
            ),
            locale,
            typeOverride: Some(ApiError),
          }),
        ),
      )
    | Some(mount) =>
      Promise.make((resolve, _reject) => {
        let confirmId = `${Date.now()->Float.toString}-${Math.random()->Float.toString}`
        let settledRef = ref(false)
        let settleTimeoutRef = ref(None)
        let settle = result => {
          if !settledRef.contents {
            settledRef := true
            settleTimeoutRef.contents->Option.forEach(clearTimeout)
            coordinatorConfirmPendingRef := None
            confirmingRef := false
            if result->getDictFromJson->getString("status", "") == "success" {
              sessionStateRef := Consumed
            }
            settleResult(resolve, result)
          }
        }
        coordinatorConfirmPendingRef := Some((confirmId, settle))
        settleTimeoutRef := Some(
          setTimeout(
            () =>
              settle(
                buildConfirmResult(
                  ~outcome=Failure({
                    code: "tokenization_failed",
                    message: Some(
                      "confirm relay timed out waiting for the coordinator — it may be degraded. Retry; the session is still active.",
                    ),
                    locale,
                    typeOverride: Some(ApiError),
                  }),
                ),
              ),
            confirmSettleTimeoutMs,
          ),
        )
        try
          mount.iframe->Nullable.make->Window.iframePostMessage(
            [
              ("cardFormCoordinatorCommand", "initiateConfirm"->JSON.Encode.string),
              ("flow", flow->JSON.Encode.string),
              ("confirmId", confirmId->JSON.Encode.string),
              ("savedCardBrand", savedCardBrand->JSON.Encode.string),
              ("savedCardLast4", savedCardLast4->JSON.Encode.string),
              ("locale", locale->JSON.Encode.string),
            ]->Dict.fromArray,
          )
        catch {
        | _ => ()
        }
      })
    }
  }


  // v20 unified `confirm()` — flow inferred from mounted fields at call time.
  //
  //   Flow A (full tokenization): any of cardNumber|cardExpiry mounted.
  //     Hyperswitch branch: the group posts
  //     `{cardFormCoordinatorCommand: "initiateConfirm", flow: "save", …}`
  //     to the coordinator (content-free; raw state rides the port plane).
  //     VGS branch: single `vault.submit` expects the card_number
  //     alias set. (The legacy behaviour this replaces accepted cardNumber
  //     alone as the minimal tokenize signal; that contract is preserved —
  //     omitting cardCvc is allowed, matching the pre-v20 `confirm()`.)
  //   Flow B (saved-card CVC recollect): ONLY cardCvc mounted. Hyperswitch
  //     branch: the same command with `flow: "update"`. VGS
  //     branch: single `vault.submit` sees only `card_cvc`.
  //   Flow inference failure (nothing mounted, or — VGS only — a partial
  //     card set without cardNumber): reject `incomplete_field_set`.
  let confirm = (): promise<JSON.t> =>
    if sessionStateRef.contents != Active {
      Promise.resolve(sessionConsumedResult(~locale, ()))
    } else if confirmingRef.contents {
      Promise.resolve(confirmInFlightResult(~locale, ()))
    } else if isExpired(~expiresAtMs=expiresAtRef.contents) {
      Promise.resolve(sessionExpiredResult(~locale, ()))
    } else {
      let incompleteFieldSet = () =>
        Promise.resolve(
          buildConfirmResult(
            ~outcome=Failure({
              code: "incomplete_field_set",
              // defaultErrorMessage supplies the locked message; an explicit
              // override keeps this locale-pinned to EN. Either path resolves
              // identically today.
              message: None,
              locale,
              typeOverride: Some(ValidationError),
            }),
          ),
        )
      if detectVaultType() == "vgs" {
        // v20 inference runs over the broker's mounted VGS fields.
        let (numberMounted, cvcMounted) = switch vgsBrokerRef.contents {
        | Some(broker) => {
            let entries = broker.fieldsRef.contents->Dict.valuesToArray
            (
              entries->Array.some(e => e.fieldType === "cardNumber" && e.fieldHandle->Option.isSome),
              entries->Array.some(e => e.fieldType === "cardCvc" && e.fieldHandle->Option.isSome),
            )
          }
        | None => (false, false)
        }
        if numberMounted {
          // Flow A — VGS direct-injection: single vault.submit("/post") on the
          // shared VGSCollect form. No backend session-confirm call.
          confirmVgsFlowA()
        } else if cvcMounted {
          // Flow B — VGS saved-card CVC recollect: same single vault.submit on
          // the shared form (only card_cvc was mounted, so only `card_cvc`
          // comes back).
          confirmVgsFlowB()
        } else {
          incompleteFieldSet()
        }
      } else {
        switch (findFieldOfType("cardNumber"), findFieldOfType("cardExpiry"), findFieldOfType("cardCvc")) {
        | (None, None, None) => incompleteFieldSet()
        | (Some(_field), _, _) =>
          // Flow A — full-card confirm. The command rides to the coordinator;
          // the union comes back masked over `confirmResult` (the coordinator
          // decodes the backend response + builds FlowASuccess itself).
          confirmingRef := true
          runCoordinatorRelay(~flow="save")
        | (None, Some(_), _) =>
          // cardExpiry w/o cardNumber can't tokenize on its own — reject.
          incompleteFieldSet()
        | (None, None, Some(field)) =>
          // Flow B — saved-card CVC recollect. `savedCard` hints come from
          // the entry's captured-at-create refs and ride the command payload
          // so the masked result can echo them back in the Flow B union.
          confirmingRef := true
          runCoordinatorRelay(
            ~flow="update",
            ~savedCardBrand=field.savedCardBrandRef.contents,
            ~savedCardLast4=field.savedCardLast4Ref.contents,
          )
        }
      }
    }

  // 7. deinit — tears down state; idempotent. Iterates the registered fields,
  //    removes each iframe from the DOM, releases per-field refs, and (for
  //    VGS-direct-injection) also tears down the VGS broker: unmount all
  //    field state and release the script-load marker so a subsequent
  //    pmSession re-loads cleanly.
  let deinit = (): unit => {
    if sessionStateRef.contents != Deinitialized {
      // Tear down Hyperswitch-vault field iframes.
      fieldsRef.contents
      ->Dict.valuesToArray
      ->Array.forEach(entry => {
        try {
          entry.handle.destroy()
        } catch {
        | _ => ()
        }
      })
      fieldsRef := Dict.make()

      // Tear down VGS broker if we ever created one. Task B will extend
      // this with `vgsField.unmount()` per live field; today `unmountAll`
      // just wipes the broker's field registry.
      vgsBrokerRef.contents->Option.forEach(broker => broker.unmountAll())
      vgsBrokerRef := None

      // Remove the VGS script entirely so a fresh pmSession rebuilds
      // cleanly (e.g. merchant hot-swap environment requires a fresh
      // VGSCollect.create() call). Removing the <script> tag also removes
      // the data-vgs-script-loaded marker, which is the real goal here:
      // the broker's script dedupe in Task A is one-shot per page.
      switch Window.querySelector(`script[data-vgs-script-loaded]`)->Nullable.toOption {
      | Some(script) =>
        try {
          script->Window.remove
        } catch {
        | _ => ()
        }
      | None => ()
      }

      fields := Dict.make()->JSON.Encode.object
      sessionStateRef := Deinitialized
      confirmingRef := false

      // MessageChannel Card Relay teardown (contract #7 — deinit-before-
      // flush port closure + confirm-owner iframe removal + listener cleanup).
      installedPortKeysRef.contents->Array.forEach(key => SadPortRegistry.closePort(~key))
      installedPortKeysRef := []
      coordinatorMountRef.contents->Option.forEach(
        mount => CoordinatorMount.teardown(~mount, ~pendingPorts=pendingPortsRef.contents),
      )
      pendingPortsRef := []
      coordinatorMountRef := None
      coordinatorReadyRef := false
      coordinatorConfirmPendingRef := None
      EventListenerManager.removeSmartEventListener("message", coordinatorListenerName)
      EventListenerManager.removeSmartEventListener(
        "message",
        `onVaultCoordinatorFullscreen-${groupInstanceId}`,
      )
      EventListenerManager.removeSmartEventListener(
        "message",
        CoordinatorMount.fullscreenAnswerListenerName(groupInstanceId),
      )
    }
  }

  let cardForm = (): cardForm => {
    create,
    on,
    confirm,
    deinit,
    update,
    fields,
  }

  {
    cardForm,
    update,
    on,
    deinit,
    fields,
  }
}
