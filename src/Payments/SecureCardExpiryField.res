/* Standalone card-expiry field, shared by both surface families.
   Expiry NEVER owns confirm: the group's relay targets cardNumber (Flow A) or cardCvc
   (Flow B), so this registers no confirm listener and just emits `cardStateUpdate`. */

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
