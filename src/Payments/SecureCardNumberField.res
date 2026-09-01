/* Standalone card-number field for the VaultSDK surface; the shared plumbing lives in
   `CommonCardFieldHooks.useCardNumberField`.
   PURE EMITTER — the hidden `cardFormCoordinator` iframe owns the confirm and runs the
   tokenisation POST. */

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
