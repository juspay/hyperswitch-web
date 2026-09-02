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
