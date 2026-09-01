// Standalone card-number field for the VaultSDK surface.
//
// Rendered inside the per-field iframe (URL: `componentName=paymentMethodsSDK&fieldName=cardNumber&surfaceFamily=vault`).
// All shared plumbing (form state, ready/change emits, focus/blur listener) lives
// in `CommonCardFieldHooks.useCardNumberField`.
//
// MessageChannel Card Relay: PURE EMITTER — the hidden `cardFormCoordinator`
// iframe owns the confirm; this shell never runs the tokenisation POST itself.
open Utils
open JotaiAtoms

@react.component
let make = () => {
  let loggerState = Jotai.useAtomValue(loggerAtom)

  let state = CommonCardFieldHooks.useCardNumberField(
    ~logger=loggerState,
    ~onInitiateConfirm=_ => (),
    ~dualPlane=true,
    (),
  )

  <CommonCardFieldHooks.RenderCardNumber state />
}
