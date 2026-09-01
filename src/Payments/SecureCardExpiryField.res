// Standalone card-expiry field — shared by BOTH surface families.
//
// Rendered inside the per-field iframe:
//   - vault:     `componentName=paymentMethodsSDK&fieldName=cardExpiry&surfaceFamily=vault`
//     (routed from PaymentMethodsSDK.res)
//   - payments:  `componentName=paymentMethodsSDK&fieldName=cardExpiry&surfaceFamily=payments`
//     (same `PaymentMethodsSDK.res` route — families share the shell since
//     P1 convergence)
//
// Expiry NEVER owns confirm on either surface: the parent group's confirm
// relay targets cardNumber (Flow A) or cardCvc (Flow B) only, so this
// component registers no confirm listener (`~onInitiateConfirm` defaults to
// None — the unit arg closes the optional-args chain) and simply emits
// `cardStateUpdate` upstream. All shared plumbing (form state, ready/change
// emits, focus/blur listener) lives in `CommonCardFieldHooks.useCardExpiryField`.
//
// (Consolidation note: the vault `SecureCardExpiryField.res` and payments
// `SecureCardExpiryV2Field.res` shells were byte-identical; merged into this
// single component during the v22 cleanup.)
open JotaiAtoms

@react.component
let make = () => {
  let loggerState = Jotai.useAtomValue(loggerAtom)

  let state = CommonCardFieldHooks.useCardExpiryField(
    ~logger=loggerState,
    ~dualPlane=true,
    (),
  )

  <CommonCardFieldHooks.RenderCardExpiry state />
}
