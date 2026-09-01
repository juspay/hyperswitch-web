// v22 (P2) — shared canon for the CardForm surfaces. These four bindings were
// copy-evolved across `PaymentsGroup.res`, `PaymentMethodsSessionGroup.res`,
// and `CommonCardFieldHooks.res`; they are now owned HERE:
//
//   1. `fieldFormStatus` — the per-field lifecycle status union (5 states),
//      previously declared identically as `fieldFormStatus` in
//      `CommonCardFieldHooks.res` and `aggregatedStatus` in `PaymentsGroup.res`.
//   2. `mapFieldTypeToInternalFieldName` — the bare-name allow-list identity
//      mapping, previously declared identically in both group factories.
//   3. `nextFieldFor` — the auto-focus progression map, previously declared
//      identically in both group factories.
//   4. `reshapeCardStateUpdateToChangePayload` — the locked merchant-facing
//      `change` payload reshaper, previously declared identically in both
//      group factories.
//
// Consumers ALIAS (`let nextFieldFor = CardFormShared.nextFieldFor`) rather
// than `open` so the compiled `.bs.js` of BOTH group factories keeps the
// named exports that tests import directly.
//
// Intentionally NOT unified here (consciously duplicated, bound to factory
// state): the detected-brand warm-up/echo blocks (`lastDetectedBrandRef`),
// the per-field message listeners (vault `attachReadyListener` vs payments
// `attachFieldListener` — different flag sets + origin constants), and the
// vault-only session helpers (`buildConfirmResult`, `detectBrandFromAlias`,
// `isExpired`/`parseExpiresAtMs`).
open Utils

// ── Per-field lifecycle status vocabulary (locked, plan §4.3) ─────────────
// Five states: `focused`/`blurred` are ONE-SHOT transitions that do not
// change the underlying validity track (complete/incomplete/invalid) — the
// group never latches them.
type fieldFormStatus =
  | Complete
  | Incomplete
  | Invalid
  | Focused
  | Blurred

let fieldFormStatusToString = (status: fieldFormStatus): string =>
  switch status {
  | Complete => "complete"
  | Incomplete => "incomplete"
  | Invalid => "invalid"
  | Focused => "focused"
  | Blurred => "blurred"
  }

let fieldFormStatusFromString = (str: string): option<fieldFormStatus> =>
  switch str {
  | "complete" => Some(Complete)
  | "incomplete" => Some(Incomplete)
  | "invalid" => Some(Invalid)
  | "focused" => Some(Focused)
  | "blurred" => Some(Blurred)
  | _ => None
  }

// ── Bare-name allow-list (identity mapping) ───────────────────────────────
// Both surfaces' merchant vocabulary is the BARE field name (v20); unknown
// strings fall through to "" and take the invalid-field-type rejection path
// (`create()` logs `invalid_field_type` + returns the no-op default handle).
let mapFieldTypeToInternalFieldName = (ft: string): string =>
  switch ft {
  | "cardNumber" => "cardNumber"
  | "cardExpiry" => "cardExpiry"
  | "cardCvc" => "cardCvc"
  | _ => ""
  }

// ── Auto-focus progression map (one vocabulary, one order) ────────────────
// cardNumber → cardExpiry → cardCvc → (terminal; no next field). This map
// only ROUTES the focus request — the iframe owns the timing decision
// (keystroke-level brand-aware max length + Luhn for cardNumber; 4-digit
// MMYY + validity for expiry).
let nextFieldFor = (fieldType: string): option<string> =>
  switch fieldType {
  | "cardNumber" => Some("cardExpiry")
  | "cardExpiry" => Some("cardCvc")
  | _ => None
  }

// ── Plan §4.3 `change`-payload reshaper (locked contract) ─────────────────
// Per-field iframes emit a verbose `cardStateUpdate` envelope (`{cardBrand,
// fieldStatus:{empty,complete,isCardValid,isExpiryValid,isCvcValid,...},
// cardInfo, ...}`) that the group caches for confirm-relay. Plan §4.3 locks
// the merchant-facing `change` payload to the slim `{empty, complete, valid,
// error?, brand?, elementType}` shape — keying on `brand` (camelCase), not
// `cardBrand`. Reshaping here keeps `CardCollectorBridge`'s emitter
// unchanged (still serves V1 + co-located surfaces) while giving v18-P2 /
// payments-surface merchants the locked contract. `brand` is omitted
// entirely when "", matching the plan's `brand?` optional. `valid` picks
// the per-field relevant validity flag (cardNumber → isCardValid, etc.).
let reshapeCardStateUpdateToChangePayload = (
  ~fieldType: string,
  ~stateJson: JSON.t,
): JSON.t => {
  let stateDict = stateJson->getDictFromJson
  let fieldStatus = stateDict->getDictFromDict("fieldStatus")
  let empty = fieldStatus->getBool("empty", true)
  let complete = fieldStatus->getBool("complete", false)
  let valid = switch fieldType {
  | "cardNumber" => fieldStatus->getBool("isCardValid", false)
  | "cardExpiry" => fieldStatus->getBool("isExpiryValid", false)
  | "cardCvc" => fieldStatus->getBool("isCvcValid", false)
  | _ => false
  }
  let brand = stateDict->getString("cardBrand", "")
  let errorMessage = stateDict->getString("error", "")
  let p = Dict.make()
  p->Dict.set("empty", empty->JSON.Encode.bool)
  p->Dict.set("complete", complete->JSON.Encode.bool)
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
