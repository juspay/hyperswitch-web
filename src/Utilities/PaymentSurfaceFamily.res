// Classifies which surface an iframe was mounted for, from its URL params.
//
// Every field/coordinator iframe mounts under one `componentName`
// (`"paymentMethodsSDK"` or `"cardFormCoordinator"`) plus two params carrying
// the routing signal:
//
//   `fieldName`     — the bare field name (`"cardNumber"|"cardExpiry"|
//                     "cardCvc"`). Absent for the bundled surface.
//   `surfaceFamily` — `"vault"` or `"payments"`. Loud-fail if missing/unknown.
//
// Legacy payments strings (`componentName=cardNumber|cardExpiry|cardCvc` under
// `hyper.widgets()`) route through the legacy catch-all in `App.res` and never
// enter this classifier.

// Closed union of the surface families. Consumers `switch` on this
// exhaustively; the `OtherFamily` branch is the loud-fail path (raises
// `InvalidSurfaceFamilyParams` upstream).
type surfaceFamily =
  | VaultFamily // `componentName=paymentMethodsSDK&surfaceFamily=vault`
  | PaymentsFamilyV2 // `componentName=paymentMethodsSDK&surfaceFamily=payments`
  | OtherFamily // Any other combination (missing surfaceFamily, unknown value, etc.)

// `surfaceFamily` is `None` when the URL param is missing and `Some("")` when
// present but empty; both are treated identically upstream (see
// `PaymentMethodsSDK`). Anything but the two valid pairs is the raise path.
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
