// VGS Collect.js broker with real field mounting.
//
// Runs ON the merchant's page in the merchant's document. No Hyperswitch
// iframe — VGS Collect.js injects its own secure field iframes directly at the
// merchant's DOM spots via `form.field(selector, options)`.
//
// Owed pieces:
//   - `isVGSProvider` detection helper (decodes vault_credentials blob)
//   - single-shot `loadVGSScript` (loads `vgs-collect/v2.27.2` onto the
//     merchant's `document.head`, deduped via a `data-vgs-script-loaded`
//     marker), SRI-pinned — `integrity` + `crossorigin="anonymous"` from
//     `VGSConstants.vgsScriptIntegrity` so a compromised VGS CDN cannot
//     silently inject malicious JS into merchant pages (fail-closed: a hash
//     mismatch makes the browser refuse to execute the script)
//   - internal `createForm` factory (calls `window.VGSCollect.create(vaultId,
//     environment)` after the script loads; memoized in `formRef` with the
//     in-flight promise shared across concurrent `mountField()` callers)
//   - `ensureReady` — combinator over script load + form creation
//   - `mountField` — `form.field(selector, options)` places a VGS Collect
//     iframe at the merchant selector, then per-field
//     `field.on("change"|"focus"|"blur"|"ready", cb)` events fan out to
//     merchant-registered listeners in the group's eventCallbacksRef
//   - per-field bookkeeping in `fieldsRef` so `updateField` / `unmountField`
//     can locate the mounted field handle
//   - savedCard.brand CVC options branching (amex → 4-digit CVC, else 3)
//   - `unmountField` — removes the VGS field's iframe from the DOM
//   - `updateField` — forwards `field.update(...)` to a mounted VGS field
//
// Per-field "ready" is the canonical merchant-visible mount signal. Confirms
// ride `submitForm` (`vault.submit(...)`) — aliases resolve entirely in-page,
// no backend session-confirm call (relay-only; see plan §4.4).
//
// Plan reference: docs/plans/secure-card-fields-plan-2026-08.md §3.4.

open Utils

// ── Script-load state discriminant ────────────────────────────────────────
// Per-broker lifecycle; `Loading` is entered exactly once per page (the
// dedupe marker on the script element prevents double-append). Owned by the
// broker record, never module-level.
type scriptState =
  | Loading
  | Ready
  | Failed

// ── Per-field mount state ─────────────────────────────────────────────────
// Keyed by a per-mount `fieldId`. The opaque `fieldHandle` slot is what
// `form.field(selector, options)` returned — Task B needs it to invoke
// `field.update(...)`, `field.on(...)`, and (via %raw) `field.delete()` for
// the unmount path. Storing the handle as `JSON.t` (rather than a typed
// `VGSTypes.field`) lets us forward VGS-specific methods through `%raw`
// without lifting the Broker into the typed VGSTypes surface.
type fieldEntry = {
  fieldType: string,
  selector: string,
  options: JSON.t,
  fieldHandle: option<JSON.t>,
}

// ── Broker handle ─────────────────────────────────────────────────────────
// Returned to PaymentMethodsSessionGroup, which owns one broker per group
// instance. All refs are per-broker, never module-level. The group only
// needs `mountField` / `updateField` / `unmountField` / `submitForm` /
// `unmountAll`; `formRef`, `scriptStateRef`, `fieldsRef`, and `ensureReady`
// are exposed so the group can introspect broker state on its confirm paths
// and so Task C hardening doesn't reshape the record again.
type vgsBrokerHandle = {
  formRef: ref<option<JSON.t>>,
  scriptStateRef: ref<scriptState>,
  fieldsRef: ref<Dict.t<fieldEntry>>,
  ensureReady: unit => promise<unit>,
  submitForm: unit => promise<JSON.t>,
  mountField: (
    ~fieldId: string,
    ~fieldType: string,
    ~selector: string,
    ~options: JSON.t,
  ) => promise<unit>,
  updateField: (~fieldId: string, ~options: JSON.t) => unit,
  unmountField: (~fieldId: string) => unit,
  unmountAll: unit => unit,
}

// ── VGS provider detection ────────────────────────────────────────────────
// Decodes the `vault_credentials` JSON blob that `VaultHelpers.buildVaultConfig`
// produced and detects VGS by inspecting the credentials blob for the
// VGS-specific `vaultId` + `environment` keys (see
// `VaultHelpers.buildVGSVaultConfig` — those keys are the VGS-specific
// surface). An equally valid alternate is to re-walk the parent session via
// `VaultHelpers.getVaultCredentialsFromSessions` and match on the
// `VGS({vaultId, environment})` variant — we choose direct key sniffing so
// the broker doesn't need a second round-trip through the sessions JSON.
let isVGSProvider = (vaultCredentials: JSON.t): bool => {
  if vaultCredentials === JSON.Encode.null {
    false
  } else {
    let dict = vaultCredentials->getDictFromJson
    dict->Dict.get("vaultId")->Option.isSome && dict->Dict.get("environment")->Option.isSome
  }
}

// ── Script loader ─────────────────────────────────────────────────────────
// Marker-attribute dedupe pattern: one `<script data-vgs-script-loaded=…>`
// element carries the load state machine (loading → loaded | error) so
// concurrent mountField() calls collapse onto a single append. We pick a
// fresh `data-vgs-script-loaded` attribute (not the `data-status` marker the
// React hook path uses) so the React-driven VGS flow (inside the payments
// iframe) and this broker (on the merchant page) don't fight over a shared
// element.
let scriptMarkerAttribute = "data-vgs-script-loaded"
let scriptSelector = `script[${scriptMarkerAttribute}]`

// Module-level in-flight promise memoization. The VGS Collect.js `<script>`
// is a page-global resource; if three `mountField()` calls race each other
// (cardNumber / cardExpiry / cardCvc all mounting concurrently), they share
// the SAME underlying `loadVGSScript()` promise instead of each attaching
// their own `@set elementOnload` handler — which would race-overwrite each
// other and strand every caller but the last (`@set` replaces rather than
// chains). Reset to None on failure so merchants can retry by creating a
// fresh pmSession.
//
// DOM-validity guard: we treat the memoized promise as STALE when the
// marker's script element has been removed from `document.head` (e.g. the
// previous pmSession's `deinit()` cleaned it up). In that case we drop the
// promise so the next broker call re-appends a fresh <script>.
let inFlightScriptPromise: ref<option<Promise.t<unit>>> = ref(None)

let scriptElementStillPresent = (): bool =>
  Window.querySelector(scriptSelector)->Nullable.toOption->Option.isSome

// Internal: appends VGS Collect.js to merchant's document.head, resolving
// once loaded. Idempotent; concurrent callers collapse onto the same
// in-flight promise and script element.
let loadVGSScript = (): Promise.t<unit> => {
  // Drop a stale memoized promise if the script element was removed by a
  // previous pmSession's deinit(). We can't key on `scriptLoaded` here
  // because the broker may have been dropped and recreated, so we go
  // straight to the DOM.
  switch (inFlightScriptPromise.contents, scriptElementStillPresent()) {
  | (Some(_), false) => inFlightScriptPromise := None
  | _ => ()
  }
  switch inFlightScriptPromise.contents {
  | Some(p) => p
  | None =>
    let p = Promise.make((resolve, reject) => {
      switch Window.querySelector(scriptSelector)->Nullable.toOption {
      | Some(existing) =>
        switch existing->Window.getAttribute(scriptMarkerAttribute)->Nullable.toOption {
        | Some("loaded") => resolve()
        | Some("error") =>
          // Prior attempt errored; clean up the marker so a retry re-appends.
          existing->Window.remove
          inFlightScriptPromise := None
          reject(%raw(`new Error("vgs-collect previously failed to load")`))
        | _ =>
          // Mid-flight (another broker/page already attached handlers):
          // attach a resolvable listener via addEventListener so we don't
          // clobber their `@set elementOnload`. The listener removes
          // itself via `{once: true}` so the handler table stays clean.
          // `%raw` because `Window.addEventListener` is scoped @window and
          // doesn't accept an options record typed for `once`.
          %raw(`(function(el, onload, onerror) {
            el.addEventListener("load", onload, { once: true });
            el.addEventListener("error", onerror, { once: true });
          })`)(
            existing,
            () => {
              existing->Window.setAttribute(scriptMarkerAttribute, "loaded")
              resolve()
            },
            err => {
              existing->Window.setAttribute(scriptMarkerAttribute, "error")
              existing->Window.remove
              inFlightScriptPromise := None
              reject(err)
            },
          )
        }
      | None =>
        let script = Window.createElement("script")
        script->Window.elementSrc(VGSConstants.vgsScriptURL)
        // SRI (Subresource Integrity): pin the fetched VGS payload to the hash in
        // VGSConstants. `crossorigin="anonymous"` is required for SRI on a
        // cross-origin script; without it the browser skips the integrity check.
        // If VGS's CDN ever serves a payload that doesn't match this hash, the
        // browser refuses to execute the script — fail-closed. Mirrors the
        // CommonHooks.useScript pattern used by the iframe VGS flow.
        script->Window.setAttribute("integrity", VGSConstants.vgsScriptIntegrity)
        script->Window.setAttribute("crossorigin", "anonymous")
        script->Window.setAttribute("async", "true")
        script->Window.setAttribute(scriptMarkerAttribute, "loading")
        script->Window.elementOnload(() => {
          script->Window.setAttribute(scriptMarkerAttribute, "loaded")
          resolve()
        })
        script->Window.elementOnerror(err => {
          script->Window.setAttribute(scriptMarkerAttribute, "error")
          inFlightScriptPromise := None
          reject(err)
        })
        let _ = Window.head->Window.appendChildElement(script)
      }
    })
    inFlightScriptPromise := Some(p)
    p
  }
}

// ── Field options mapping ─────────────────────────────────────────────────
// Maps the public field-type string + the merchant's `options` JSON blob
// onto the matching VGSConstants option builder. Reuses the canonical
// `VGSConstants.cardNumberOptions` / `cardExpiryOptions` / `cardCvcOptions` /
// `savedCardCvcOptions` from `src/Utilities/VGSConstants.res` unchanged —
// those builders are pure functions returning plain records, which the
// ReScript compiler already lowers to JS objects the VGSCollect runtime
// can consume directly (no JSON.stringify required). We still run them
// through `Identity.anyTypeToJson` so the broker only ever hands `%raw`
// JS a `JSON.t` — keeps the binding monomorphic.
//
// Card-expiry placeholder comes from `options.placeholder` (merchant
// override) falling back to "MM / YY" — matches the React path which uses
// `localeString.expiryPlaceholder` (default EN is "MM / YY"). Brokers don't
// carry locale context, so merchants that want a localized placeholder pass
// it explicitly via `options.placeholder` (Task F may wire localeString).
//
// CVC validation branching (3-digit default vs 4-digit amex) is computed
// inside `VGSConstants.savedCardCvcValidations` (VGSConstants.res:47-59)
// — the broker just branches on the presence of `options.savedCard.brand`.
let computeVGSBaseOptions = (~fieldType: string, ~options: JSON.t): JSON.t => {
  let optionsDict = options->getDictFromJson
  switch fieldType {
  | "cardNumber" => VGSConstants.cardNumberOptions->Identity.anyTypeToJson
  | "cardExpiry" =>
    // Merchant may override the placeholder via options.placeholder; default
    // "MM / YY" matches the English locale default.
    let placeholder = optionsDict->getString("placeholder", "MM / YY")
    VGSConstants.cardExpiryOptions(placeholder)->Identity.anyTypeToJson
  | "cardCvc" =>
    let savedCardDict = optionsDict->getDictFromDict("savedCard")
    let savedCardBrand = savedCardDict->getString("brand", "")
    if savedCardBrand->String.length > 0 {
      // savedCard.brand present → amex & co. get their brand-specific
      // 3-vs-4 digit CVC validations; see VGSConstants.res:47-59.
      // Merchants supply the lowercase scheme string ("amex", "visa"), but
      // getobjFromCardPattern keys on the issuer display name
      // ("AmericanExpress", "Visa"). Normalize through the SAME helper the
      // React path (VGSVault.res) uses so the broker and iframe paths agree.
      let normalizedBrand = CardUtils.normalizeCardBrand(savedCardBrand)
      VGSConstants.savedCardCvcOptions(normalizedBrand)->Identity.anyTypeToJson
    } else {
      VGSConstants.cardCvcOptions->Identity.anyTypeToJson
    }
  | _ =>
    // Unknown field type — default to cardNumber options; the caller should
    // have already filtered this via mapFieldTypeToComponentName.
    VGSConstants.cardNumberOptions->Identity.anyTypeToJson
  }
}

// ── Merchant per-field option overlay ─────────────────────────────────────
// Curated allowlist of VGS Collect.js field-option keys a merchant may
// override per field via `cardForm.create(fieldType, {…})`. Semantics:
// per-field merchant values WIN over the VGSConstants defaults — the same
// "per-field wins over the umbrella" precedence rule the appearance merge
// uses on the Hyperswitch iframe path.
//
// Deliberately EXCLUDED (not merchant-overridable on this surface):
//   - "type" / "name": structural. `name` IS the VGS alias key the submit
//     response echoes back, and `VGSHelpers.getTokenizedData` reads exactly
//     "card_number" / "card_exp" / "card_cvc" from it — merchant renaming
//     would silently break tokenization mapping.
//   - "validations": merchant-supplied validations need a replace-vs-merge
//     decision at the plan level (replacing would silently drop "required"
//     and the saved-card brand-length regexes). Plan-doc follow-up.
//   - "serializers": rewrites the submitted alias value shape (e.g. strip
//     spaces); interacts with the "MM / YY" expiry split in
//     `VGSHelpers.getTokenizedData`. Plan-doc follow-up.
let merchantOverridableStringKeys = [
  "placeholder",
  "successColor",
  "errorColor",
  "ariaLabel",
  "autoComplete",
  "inputMode",
  "defaultValue",
]
let merchantOverridableBoolKeys = ["showCardIcon", "disabled", "readOnly", "hideValue"]

let applyMerchantOptionOverrides = (~basis: JSON.t, ~options: JSON.t): JSON.t => {
  let basisDict = basis->getDictFromJson
  let optionsDict = options->getDictFromJson
  // String keys — a non-empty merchant string wins.
  merchantOverridableStringKeys->Array.forEach(key => {
    switch optionsDict->getOptionString(key)->getNonEmptyOption {
    | Some(value) => basisDict->Dict.set(key, value->JSON.Encode.string)
    | None => ()
    }
  })
  // Boolean keys — a present merchant boolean wins.
  merchantOverridableBoolKeys->Array.forEach(key => {
    switch optionsDict->getOptionBool(key) {
    | Some(value) => basisDict->Dict.set(key, value->JSON.Encode.bool)
    | None => ()
    }
  })
  // yearLength — the one integer knob (2-digit vs 4-digit expiry year).
  // JSON numbers decode as float; VGS expects an int.
  switch optionsDict->Dict.get("yearLength")->Option.flatMap(JSON.Decode.float) {
  | Some(value) => basisDict->Dict.set("yearLength", value->Float.toInt->JSON.Encode.int)
  | None => ()
  }
  // css — keywise merge so merchant keys win over (rather than wholesale
  // replace) the default css. Basis css exists only for savedCardCvcOptions
  // today; for Flow A fields the merchant css IS the whole object.
  let merchantCss = optionsDict->getDictFromDict("css")
  if merchantCss->Dict.keysToArray->Array.length > 0 {
    let mergedCss = basisDict->getDictFromDict("css")
    merchantCss->Dict.toArray->Array.forEach(((key, value)) => mergedCss->Dict.set(key, value))
    basisDict->Dict.set("css", mergedCss->JSON.Encode.object)
  }
  basisDict->JSON.Encode.object
}

let computeFieldOptions = (~fieldType: string, ~options: JSON.t): JSON.t => {
  let basis = computeVGSBaseOptions(~fieldType, ~options)
  applyMerchantOptionOverrides(~basis, ~options)
}

// ── Update-path merchant-option filter (F7) ─────────────────────────────────
// `mountField` runs merchant opts through `applyMerchantOptionOverrides`,
// which enforces the §8.18 frozen-option exclusions (merchant may NEVER set
// `type` / `name` / `validations` / `serializers` on this surface).
// `updateField` must honor the SAME exclusions — previously it forwarded the
// merchant bag RAW into VGSCollect's `field.update(opts)`, bypassing them.
// Two sets therefore intersect here:
//   1. VGSCollect's `field.update` honors ONLY: validations, placeholder,
//      ariaLabel, options, css, hideValue, autoComplete, disabled, readOnly,
//      showCardIcon (anything else is dropped by VGS at best).
//   2. Our mount-time merchant allowlist (§8.18): placeholder, successColor,
//      errorColor, ariaLabel, autoComplete, inputMode, defaultValue,
//      showCardIcon, disabled, readOnly, hideValue, yearLength, css.
// INTERSECTION (forwarded): placeholder, ariaLabel, autoComplete, css,
// hideValue, disabled, readOnly, showCardIcon.
//   - `validations` / `options` sit on VGS's list but NOT ours (§8.18 freezes
//     `validations`; `options` was never merchant-exposed), so they stay out.
//   - Our mount-only keys (successColor, errorColor, inputMode, defaultValue,
//     yearLength) are post-create no-ops to VGS — filtered here rather than
//     forwarded silently.
// Pass-through is verbatim per key (no reshape): VGS owns the value domain.
let vgsFieldUpdateAllowedKeys = [
  "placeholder",
  "ariaLabel",
  "autoComplete",
  "css",
  "hideValue",
  "disabled",
  "readOnly",
  "showCardIcon",
]
let filterFieldUpdateOptions = (~options: JSON.t): JSON.t => {
  let optionsDict = options->getDictFromJson
  let filtered = Dict.make()
  vgsFieldUpdateAllowedKeys->Array.forEach(key => {
    switch optionsDict->Dict.get(key) {
    | Some(value) => filtered->Dict.set(key, value)
    | None => ()
    }
  })
  filtered->JSON.Encode.object
}

// ── Field-event payload (locked plan §4.3 shape) ───────────────────────────
// VGS Collect emits per-event state payloads shaped
//   {name, isEmpty, isValid, isFocused, error?, cardBrand?, cardType?, ...}
// We normalize into the locked plan §4.3 merchant-facing envelope — the SAME
// shape the Hyperswitch-field `change` channel emits via
// `CardFormShared.reshapeCardStateUpdateToChangePayload`:
//   {empty, complete, valid, error?, brand?, elementType}
//   - empty       ← state.isEmpty
//   - valid       ← state.isValid
//   - complete    ← computed (!empty && valid) — VGS state carries no
//                   `complete` key; this mirrors §4.3's status-table semantic
//                   ("complete = isValid AND value is non-empty").
//   - error?      ← present ONLY when the state carries a non-empty `error`
//   - brand?      ← present when detectable: VGS card-number change states
//                   may carry `cardBrand` (preferred) or `cardType`
//                   (fallback); forwarded unnormalized, parity with the
//                   canonical reshaper's raw `cardBrand` pass-through.
//   - elementType ← the public field-type string ("cardNumber" | ...).
// F6 fix — the pre-normalization envelope (`{fieldType, fieldId, isEmpty,
// isValid, error}`) was retired: listeners register on the field HANDLE, so
// `fieldId`/`fieldType` keys were redundant, and `isEmpty`/`isValid`/
// always-present-`error` deviated from the locked contract. This single
// builder serves ALL four merchant-visible field events on this surface
// (ready/change/focus/blur) so the envelope vocabulary stays uniform.
let buildFieldEventPayload = (
  ~fieldType: string,
  ~state: JSON.t,
): JSON.t => {
  let stateDict = state->getDictFromJson
  let empty = stateDict->getBool("isEmpty", true)
  let valid = stateDict->getBool("isValid", false)
  // VGS's `error` key is null when absent; only surface a string.
  let errorMessage = stateDict->getString("error", "")
  let brand = stateDict->getString("cardBrand", "")
  let brand = if brand === "" {
    stateDict->getString("cardType", "")
  } else {
    brand
  }
  let p = Dict.make()
  p->Dict.set("empty", empty->JSON.Encode.bool)
  p->Dict.set("complete", (!empty && valid)->JSON.Encode.bool)
  p->Dict.set("valid", valid->JSON.Encode.bool)
  p->Dict.set("elementType", fieldType->JSON.Encode.string)
  if brand !== "" {
    p->Dict.set("brand", brand->JSON.Encode.string)
  }
  if errorMessage !== "" {
    p->Dict.set("error", errorMessage->JSON.Encode.string)
  }
  p->JSON.Encode.object
}

// Look up and fire registered merchant listeners for `(fieldId, event)`.
// We key the map as a composite `"<fieldId>::<event>"` so distinct fields
// never clobber each other's listeners on the shared eventCallbacksRef.
let eventKey = (~fieldId: string, ~event: string): string => `${fieldId}::${event}`

let dispatchFieldEvent = (
  ~eventCallbacksRef: ref<Dict.t<JSON.t => unit>>,
  ~fieldId: string,
  ~event: string,
  ~payload: JSON.t,
): unit => {
  eventCallbacksRef.contents
  ->Dict.get(eventKey(~fieldId, ~event))
  ->Option.forEach(cb => cb(payload))
}

// ── Broker factory ────────────────────────────────────────────────────────
// One per pmSession. `eventCallbacksRef` is the group's `on()` registry —
// passed in so Task B/C's mount/submit paths can fan state out to merchant
// listeners without registering a second callback pool.
let make = (
  ~pmSessionId: string,
  ~vaultId: string,
  ~environment: string,
  ~eventCallbacksRef: ref<Dict.t<JSON.t => unit>>,
): vgsBrokerHandle => {
  let formRef: ref<option<JSON.t>> = ref(None)
  let scriptStateRef: ref<scriptState> = ref(Loading)
  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  // Memoizes the in-flight `window.VGSCollect.create(...)` promise so
  // concurrent `mountField()` calls from the same broker share ONE form
  // instance (not three — see comment inside `createForm` below). Per-broker
  // (not module-level) because a fresh pmSession gets a fresh broker and
  // needs its own form.
  let createFormInFlightRef: ref<option<promise<JSON.t>>> = ref(None)

  // ── Form creation (internal) ──────────────────────────────────────────
  // Calls `window.VGSCollect.create(vaultId, environment, onErrorCallback)`.
  // VGS's browser-global API is plain JS; we bind via %raw because there is
  // no typed surface yet — Task B may introduce one as the mount path
  // hardens.
  let createForm = (): promise<JSON.t> =>
    switch formRef.contents {
    | Some(form) => Promise.resolve(form)
    | None =>
      // Memoize the in-flight "create the VGSCollect form" promise inside
      // `createFormInFlightRef` so concurrent `mountField()` callers from
      // the same broker share one VGSCollect.create(...) call. Without this,
      // three parallel `pmSession.create(...).mount(...)` enqueue three
      // separate `window.VGSCollect.create(...)` invocations, each producing
      // its own form — and only the last formRef survives (the earlier ones
      // still own their iframes, leading to triple-mounted fields).
      switch createFormInFlightRef.contents {
      | Some(p) => p
      | None =>
        let p =
          loadVGSScript()
          ->Promise.then(_ => {
            let onError: JSON.t => unit = errJson => {
              // Form-level errors are logged for merchant debugging; the
              // confirm path surfaces failures as `error` envelopes via
              // `submitForm` (structured propagation lives there).
              Console.error2("[VGSVaultBroker] VGSCollect form-level error", errJson)
            }
            let form: JSON.t = %raw(`
              (function(vaultId, environment, onError) {
                if (typeof window.VGSCollect === "undefined") {
                  throw new Error("VGSCollect script failed to register window.VGSCollect");
                }
                return window.VGSCollect.create(vaultId, environment, onError);
              })
            `)(vaultId, environment, onError)
            formRef := Some(form)
            scriptStateRef := Ready
            Promise.resolve(form)
          })
          ->Promise.catch(err => {
            scriptStateRef := Failed
            createFormInFlightRef := None
            Promise.reject(err)
          })
        createFormInFlightRef := Some(p)
        p
      }
    }

  //Combined "script is loaded AND form is created" — Task B field mounts
  // always go through here first so they can assume both exist.
  let ensureReady = (): promise<unit> =>
    createForm()->Promise.then(_ => Promise.resolve())

  // ── Task C: real submitForm — single vault.submit("/post", …) ─────────
  //
  // Single network round-trip; never rejects — the group maps a resolved
  // "error" envelope into the guide §4.4 Failure union via
  // `buildConfirmResult`. Success envelope:
  //   {status:"success", card_number, card_exp_month, card_exp_year, card_cvc}
  // The card_exp_* keys come from reusing `VGSHelpers.getTokenizedData`
  // (VGS only emits a combined `card_exp` alias; we split it here so the
  // group's Flow A union can expose month/year as separate fields — task
  // 4c's success shape).
  //
  // Error envelope:
  //   {status:"error", error:{code, message, type:"api_error"}}
  // — matches the guide's §4.4 error shape (tokenization/network failure).
  // `vgs_form_not_ready` is a broker-preflight failure; downstream callers
  // treat it identically to `tokenization_failed` (both emit type=api_error
  // and leave the session Active so a retry can re-submit).
  let submitForm = (): promise<JSON.t> => {
    switch formRef.contents {
    | None =>
      let errorDict = Dict.make()
      errorDict->Dict.set("code", "vgs_form_not_ready"->JSON.Encode.string)
      errorDict->Dict.set("message", "VGS form not initialized"->JSON.Encode.string)
      let resultDict = Dict.make()
      resultDict->Dict.set("status", "error"->JSON.Encode.string)
      resultDict->Dict.set("error", errorDict->JSON.Encode.object)
      Promise.resolve(resultDict->JSON.Encode.object)
    | Some(form) =>
      Promise.make((resolve, _reject) => {
        let onSuccess: (int, JSON.t) => unit = (_status, data) => {
          let (cardNumber, expMonth, expYear, cardCvc) = VGSHelpers.getTokenizedData(data)
          let resultDict = Dict.make()
          resultDict->Dict.set("status", "success"->JSON.Encode.string)
          resultDict->Dict.set("card_number", cardNumber->JSON.Encode.string)
          resultDict->Dict.set("card_exp_month", expMonth->JSON.Encode.string)
          resultDict->Dict.set("card_exp_year", expYear->JSON.Encode.string)
          resultDict->Dict.set("card_cvc", cardCvc->JSON.Encode.string)
          resolve(resultDict->JSON.Encode.object)
        }
        let onError: (int, JSON.t) => unit = (_status, errors) => {
          // VGS's onError payload is a per-field errors map; we squash to a
          // single string because the group maps everything to
          // `tokenization_failed` regardless. Fall back to a generic message
          // if stringify throws (e.g. circular refs).
          let messageStr: string = {
            let jsonStr: string = %raw(`(function(e) { try { return JSON.stringify(e); } catch(_) { return "unknown"; } })`)(errors)
            if jsonStr->String.length > 0 {
              jsonStr
            } else {
              "VGS submit failed"
            }
          }
          let errorDict = Dict.make()
          errorDict->Dict.set("code", "tokenization_failed"->JSON.Encode.string)
          errorDict->Dict.set("message", messageStr->JSON.Encode.string)
          errorDict->Dict.set("type", "api_error"->JSON.Encode.string)
          let resultDict = Dict.make()
          resultDict->Dict.set("status", "error"->JSON.Encode.string)
          resultDict->Dict.set("error", errorDict->JSON.Encode.object)
          resolve(resultDict->JSON.Encode.object)
        }
        let emptyPayload = JSON.Encode.object(Dict.make())
        try {
          %raw(`(function(form, path, payload, onSuccess, onError) {
            form.submit(path, payload, onSuccess, onError);
          })`)(form, "/post", emptyPayload, onSuccess, onError)
        } catch {
        | exn =>
          // Synchronous throw out of form.submit() — e.g. browser extensions
          // blocking the call. Resolve the same error envelope shape so the
          // caller doesn't need two pathways.
          let messageStr: string = {
            let literal: string = %raw(`(function(e) { try { return (e && e.message) ? String(e.message) : String(e); } catch (_) { return "unknown"; } })`)(exn)
            if literal->String.length > 0 {
              literal
            } else {
              "unknown"
            }
          }
          let errorDict = Dict.make()
          errorDict->Dict.set("code", "tokenization_failed"->JSON.Encode.string)
          errorDict->Dict.set("message", messageStr->JSON.Encode.string)
          errorDict->Dict.set("type", "api_error"->JSON.Encode.string)
          let resultDict = Dict.make()
          resultDict->Dict.set("status", "error"->JSON.Encode.string)
          resultDict->Dict.set("error", errorDict->JSON.Encode.object)
          resolve(resultDict->JSON.Encode.object)
        }
      })
    }
  }

  // ── Task B: real field mounting via form.field(selector, options) ────
  //
  //  1. ensureReady() resolves the script load + form creation handshake.
  //  2. Compute VGS field options per field type (and savedCard.brand for
  //     CVC); see `computeFieldOptions` above.
  //  3. Call the VGSCollect form's `.field(selector, computedOptions)` to
  //     inject the secure iframe into the merchant's DOM. Returns a VGS
  //     field handle.
  //  4. Wire per-field `field.on("change"|"focus"|"blur"|"ready", cb)` to
  //     dispatch reshaped event payloads into `eventCallbacksRef` keyed by
  //     `(fieldId, event)` — the group registers merchant listeners under
  //     those keys via its `fieldHandle.on(event, cb)`.
  //  5. Store the field handle + mount metadata under `fieldId` so later
  //     `updateField` / `unmountField` calls can locate the mounted field.
  //
  // Errors reject the returned promise with a
  //   {code: "vgs_mount_failed" | "vgs_form_not_ready", message}
  // envelope. The caller (`PaymentMethodsSessionGroup`'s VGS branch) catches
  // and logs; merchants never see mount-time throws on the public API.
  let mountField = (
    ~fieldId: string,
    ~fieldType: string,
    ~selector: string,
    ~options: JSON.t,
  ): promise<unit> => {
    ensureReady()
    ->Promise.then(_ => {
      switch formRef.contents {
      | None =>
        // `ensureReady` resolved but formRef is empty — should be
        // unreachable; treat as a hard failure so the caller can log.
        let errDict = Dict.make()
        errDict->Dict.set("code", "vgs_form_not_ready"->JSON.Encode.string)
        errDict->Dict.set(
          "message",
          "VGS form not initialized after ensureReady()"->JSON.Encode.string,
        )
        Promise.reject(%raw(`(function(e) { var err = new Error(e.message); err.code = e.code; err.envelope = e; return err; })`)(errDict->JSON.Encode.object))
      | Some(form) =>
        let computedOptions = computeFieldOptions(~fieldType, ~options)

        // ── cardFieldHeight sizing (v20 polish) ───────────────────────────
        // VGS's injected iframe defaults to 150×300px (their stylesheet) and
        // ignores both the merchant's container height AND any css={} we pass
        // via field options (which only styles the INNER <input>). To give
        // merchants ONE knob that works for both VGS and Hyperswitch paths,
        // we:
        //   1. Set the MERCHANT CONTAINER's style to the requested height —
        //      since VGS appends its iframe INTO the merchant's div, the
        //      container becomes the sizing authority. We deliberately do
        //      NOT use !important here so merchant-owned CSS on their own
        //      div still wins (clearly documented contract).
        //   2. After form.field() injects the iframe, set width/height 100%
        //      !important ON THE INJECTED IFRAME so VGS's default 150×300px
        //      inline style is overridden and the iframe fills its (now-
        //      correctly-sized) container. MutationObserver watched the
        //      container so we catch async injection; we also do a sync
        //      first-pass in case VGS happens to be synchronous.
        // `cardFieldHeight` is read from `options.appearance.variables.
        // cardFieldHeight` (the same key merchants use for Hyperswitch iframes).
        // Default "48px" matches CardTheme.default.cardFieldHeight.
        let cardFieldHeight =
          options
          ->getDictFromJson
          ->getDictFromDict("appearance")
          ->getDictFromDict("variables")
          ->getString("cardFieldHeight", "48px")
          ->String.trim
        // Sanity filter: refuse clearly-malformed values. Anything non-empty
        // and not literally "null" passes through as CSS — the browser ignores
        // invalid CSS gracefully, but a stray `"null"` string would produce
        // a confusing no-op rather than a visible fallback.
        let cardFieldHeight = if cardFieldHeight == "" || cardFieldHeight == "null" {
          Console.warn2(
            `[VGSVaultBroker] appearance.variables.cardFieldHeight was empty/"null"; falling back to 48px`,
            options,
          )
          "48px"
        } else {
          cardFieldHeight
        }

        // Step 1: size the merchant's container div. We use `style.height`
        // (inline style, no !important) so merchant-supplied CSS rules with
        // higher specificity or !important still win — see comment block
        // above for the contract. We ALSO leave `style.display` alone —
        // merchants own layout; we only own the height default.
        try {
          %raw(`(function(sel, h) {
            var el = document.querySelector(sel);
            if (el && el.style && typeof el.style.setProperty === "function") {
              el.style.setProperty("height", h);
              el.style.setProperty("width", "100%");
            }
          })`)(selector, cardFieldHeight)
        } catch {
        | _ => ()
        }

        // Mount the VGS field. We bind via %raw because the returned field
        // handle shape varies between VGSCollect versions and we need both
        // the typed `on/update` surface AND the (untyped) `delete()` method
        // for unmount. Everything we do through `fieldHandle` flows through
        // the same opaque JSON.t — no type information is lost at runtime.
        let fieldHandle: JSON.t = try {
          %raw(`(function(form, sel, opts) { return form.field(sel, opts); })`)(
            form,
            selector,
            computedOptions,
          )
        } catch {
        | exn =>
          // Best-effort stringify of the upstream error. JS Error objects
          // don't carry a `.message` via the plain JSON.stringify path —
          // they need the `String(err)` route — so use that for the message.
          let upstreamMsg: string = {
            let literal: string = %raw(`(function(e) { try { return (e && e.message) ? String(e.message) : String(e); } catch (_) { return "unknown"; } })`)(exn)
            if literal->String.length > 0 {
              literal
            } else {
              "unknown"
            }
          }
          let errDict = Dict.make()
          errDict->Dict.set("code", "vgs_mount_failed"->JSON.Encode.string)
          errDict->Dict.set(
            "message",
            `form.field("${selector}") threw: ${upstreamMsg}`->JSON.Encode.string,
          )
          %raw(`(function(e) { var err = new Error(e.message); err.code = e.code; err.envelope = e; throw err; })`)(errDict->JSON.Encode.object)
        }

        // Step 2: force the injected VGS <iframe> to fill its container.
        // VGS's Collect.js appends the iframe as the FIRST <iframe> child of
        // the merchant's selector div. Its inline style is set by VGS's own
        // sheet (150px × 300px default), so we must use !important to win.
        // We ONLY target width/height/display — anything else (border, etc.)
        // stays under VGS's control.
        //
        // Injection timing: `form.field(...)` returns synchronously, but the
        // iframe's insertion into the merchant DOM may be async depending on
        // VGSCollect internals. We do BOTH:
        //   (a) an immediate first-pass style write (handles the common
        //       sync-injection case VGSCollect exhibits today), and
        //   (b) a MutationObserver watching the container for childList
        //       additions, so even if VGS defers injection by a microtask
        //       we catch it on the first DOM append.
        // The observer disconnects itself after the first successful
        // styling OR after 5s — whichever comes first — so we never leak
        // an observer on a failed mount.
        try {
          %raw(`(function(sel) {
            var container = document.querySelector(sel);
            if (!container) return;
            function styleIframe() {
              var iframe = container.querySelector("iframe");
              if (iframe && iframe.style) {
                iframe.style.setProperty("width", "100%", "important");
                iframe.style.setProperty("height", "100%", "important");
                iframe.style.setProperty("display", "block", "important");
                return true;
              }
              return false;
            }
            // First-pass: may hit sync injection.
            if (styleIframe()) return;
            // Async fallback: watch for the iframe append, then style it.
            var observer = new MutationObserver(function() {
              if (styleIframe()) observer.disconnect();
            });
            observer.observe(container, { childList: true, subtree: false });
            setTimeout(function() { observer.disconnect(); }, 5000);
          })`)(selector)
        } catch {
        | _ => ()
        }

        // Bookkeeping: store the handle + mount metadata. This replaces any
        // prior entry under the same fieldId (remount flow).
        fieldsRef.contents->Dict.set(fieldId, {fieldType, selector, options, fieldHandle: Some(fieldHandle)})

        // Wire per-field event dispatchers. VGS emits a state-shaped JSON
        // per event; we reshape into the locked §4.3 merchant-facing
        // envelope (`buildFieldEventPayload`) before invoking merchant
        // listeners. Registration errors here log-and-continue —
        // the field is already mounted; one missing listener shouldn't
        // poison the rest of the wire-up.
        let wireEvent = (event: string): unit => {
          try {
            let cb: JSON.t => unit = state => {
              let payload = buildFieldEventPayload(~fieldType, ~state)
              dispatchFieldEvent(~eventCallbacksRef, ~fieldId, ~event, ~payload)
            }
            %raw(`(function(field, ev, cb) { field.on(ev, cb); })`)(fieldHandle, event, cb)
          } catch {
          | exn =>
            Console.error2(
              `[VGSVaultBroker] failed to wire field.on("${event}") for fieldId=${fieldId}`,
              exn->Identity.anyTypeToJson,
            )
          }
        }
        wireEvent("change")
        wireEvent("focus")
        wireEvent("blur")
        wireEvent("ready")

        Promise.resolve()
      }
    })
    ->Promise.catch(err => {
      Console.error2(
        `[VGSVaultBroker] mountField(${fieldType}, ${selector}) failed`,
        err->Identity.anyTypeToJson,
      )
      Promise.reject(err)
    })
  }

  // Forward a VGS `field.update(opts)` call to the mounted field. Used by
  // the group's `fieldHandle.update(options)` to let merchants flip
  // allowlisted knobs (placeholder / ariaLabel / css / disabled / ...) mid-
  // flight — never the §8.18-frozen structural keys. Silent no-op when the
  // fieldId is unknown or the field hasn't mounted yet.
  let updateField = (~fieldId: string, ~options: JSON.t): unit => {
    switch fieldsRef.contents->Dict.get(fieldId) {
    | Some({fieldHandle: Some(fh)}) =>
      try {
        // F7 fix — route merchant opts through the §8.18 ⇄ VGS-update
        // intersection (`filterFieldUpdateOptions` above) instead of the raw
        // bag: a raw `type`/`name`/`validations`/`serializers` key would
        // reach VGSCollect unfiltered, bypassing the exclusions the mount
        // path enforces via `applyMerchantOptionOverrides`.
        let filteredOptions = filterFieldUpdateOptions(~options)
        %raw(`(function(field, opts) { if (typeof field.update === "function") { field.update(opts); } })`)(fh, filteredOptions)
      } catch {
      | exn =>
        Console.error2(
          `[VGSVaultBroker] updateField(${fieldId}) threw`,
          exn->Identity.anyTypeToJson,
        )
      }
    | _ => ()
    }
  }

  // Remove the mounted VGS field's iframe from the DOM. We prefer the VGS
  // `field.delete()` API (clean internal teardown); if it's absent we fall
  // back to manually clearing the parent container's innerHTML (which the
  // iframe removal contract from VGSCollect 2.27 supports). Also drops the
  // entry from `fieldsRef` so a future `mountField(fieldId, ...)` re-mount
  // starts from a clean slate.
  let unmountField = (~fieldId: string): unit => {
    switch fieldsRef.contents->Dict.get(fieldId) {
    | Some({fieldHandle: Some(fh), selector}) =>
      try {
        let deleted: bool = %raw(`(function(field) {
          if (field && typeof field.delete === "function") {
            try { field.delete(); return true; } catch (e) { return false; }
          }
          return false;
        })`)(fh)
        if !deleted {
          // Fallback: clear the container's innerHTML. This kills the VGS
          // iframe without needing a typed binding to `field.delete()`.
          let _ = %raw(`(function(sel) {
            var el = document.querySelector(sel);
            if (el) { el.innerHTML = ""; return true; }
            return false;
          })`)(selector)
        }
      } catch {
      | exn =>
        Console.error2(
          `[VGSVaultBroker] unmountField(${fieldId}) threw`,
          exn->Identity.anyTypeToJson,
        )
      }
      fieldsRef.contents->Dict.set(fieldId, {
        fieldType: "",
        selector: "",
        options: JSON.Encode.null,
        fieldHandle: None,
      })
    | _ => ()
    }
  }

  // Called by the host group's `deinit()`. Unmounts every live field and
  // clears the field registry so the broker is reusable for a future
  // pmSession on the same page.
  let unmountAll = (): unit => {
    fieldsRef.contents
    ->Dict.keysToArray
    ->Array.forEach(fieldId => {
      // Best-effort per-field teardown — one bad unmount must not poison the rest.
      unmountField(~fieldId)
    })
    fieldsRef := Dict.make()
  }

  {formRef, scriptStateRef, fieldsRef, ensureReady, submitForm, mountField, updateField, unmountField, unmountAll}
}
