// Phase 2 PR 1 — PaymentSurfaceFamily classifier (v18 unified URL-param form).
//
// v18 collapses the v17 per-surface `componentName` alphabet
// (`vaultCardNumber|vaultCardExpiry|vaultCardCvc|paymentMethodsSDK`) into ONE
// componentName — `"paymentMethodsSDK"` — plus two URL params that carry the
// routing signal:
//
//   `fieldName`     — the bare internal field name (`"cardNumber"|"cardExpiry"|
//                     "cardCvc"`). Absent for the bundled surface.
//   `surfaceFamily` — `"vault"` or `"payments"`. Which surface family the
//                     iframe was mounted for. Loud-fail if missing or unknown.
//
// v20 (Secure Card Fields): the merchant-facing `*V2` string vocabulary is
// RETRACTED. There is exactly ONE field vocabulary — bare
// `cardNumber | cardExpiry | cardCvc` — on both surfaces, so this module no
// longer carries any public↔internal name mapping: `fieldName` arrives
// pre-bared from both group factories (`PaymentsGroup` for
// `hyper.widgets(...).cardForm()`, `PaymentMethodsSessionGroup` for the vault
// session). The only remaining job here is classifying an iframe's surface
// family from `componentName` + `surfaceFamily` URL params.
//
// Plan reference: `docs/plans/secure-card-fields-plan-2026-08.md` §3.4
// (unified URL topology) and §6.2.5 (naming lock — the bare name flows
// end-to-end; no suffix exists anywhere).
//
// Scope: legacy payments strings (`"cardNumber"|"cardExpiry"|"cardCvc"` under
// `hyper.widgets()`) continue to route through the FROZEN legacy catch-all
// (`App.res:110+ → <Payment>`) and never enter this classifier.

// Closed union of the surface families known to the v18 URL scheme. Consumers
// `switch` on this exhaustively; the `OtherFamily` branch is the loud-fail
// path (raises `InvalidSurfaceFamilyParams` upstream).
type surfaceFamily =
  | VaultFamily // `componentName=paymentMethodsSDK&surfaceFamily=vault`
  | PaymentsFamilyV2 // `componentName=paymentMethodsSDK&surfaceFamily=payments`
  | OtherFamily // Any other combination (missing surfaceFamily, unknown value, etc.)

// Classifies an iframe's routing surface from the URL params
// `componentName` and `surfaceFamily`. `surfaceFamily` is passed as an
// `option<string>` — `None` when the URL param is missing, `Some("")` when
// it is present but empty (both are treated identically here as `None`
// upstream — see `PaymentMethodsSDK`).
//
// THREE valid states:
//   ("paymentMethodsSDK", Some("vault"))    → VaultFamily
//   ("paymentMethodsSDK", Some("payments")) → PaymentsFamilyV2
//   _                                       → OtherFamily (raise path)
//
// The legacy `componentName=cardNumber|cardExpiry|cardCvc` strings route
// through the FROZEN legacy catch-all in `App.res` and never reach this
// classifier — PaymentMethodsSDK only renders when `componentName=
// "paymentMethodsSDK"` (per App.res:96-99).
let classifyFromUrlParams = (~componentName: string, ~surfaceFamily: option<string>): surfaceFamily =>
  switch (componentName, surfaceFamily) {
  | ("paymentMethodsSDK", Some("vault")) => VaultFamily
  | ("paymentMethodsSDK", Some("payments")) => PaymentsFamilyV2
  | _ => OtherFamily
  }

// ── Coordinator admission (MessageChannel Card Relay) ──────────────────────
// `componentName=cardFormCoordinator` carries `surfaceFamily` the same way the
// per-field iframes do — the coordinator derives its family from the URL at
// mount and uses it to route confirm ownership (payments Flow A →
// `usePaymentIntent`; vault → `PaymentHelpersV2` save/update).
//
// `getPaymentMode` map COUNTER-decision: `CardThemeType.getPaymentMode(
// "cardFormCoordinator")` stays NONE. This is deliberate and matches the
// paymentMethodsSDK iframes (X-Client-Source ships as "none" from both);
// the LoaderController handshake and atom-graph population are
// componentName-agnostic, so no logger/mapper change is needed.
type coordinatorFamily =
  | VaultCoordinator // `componentName=cardFormCoordinator&surfaceFamily=vault`
  | PaymentsCoordinator // `componentName=cardFormCoordinator&surfaceFamily=payments`
  | OtherCoordinatorFamily // unknown/missing → loud-fail arm upstream

let classifyCoordinatorFromUrl = (~componentName: string, ~surfaceFamily: option<string>): coordinatorFamily =>
  switch (componentName, surfaceFamily) {
  | ("cardFormCoordinator", Some("vault")) => VaultCoordinator
  | ("cardFormCoordinator", Some("payments")) => PaymentsCoordinator
  | _ => OtherCoordinatorFamily
  }
