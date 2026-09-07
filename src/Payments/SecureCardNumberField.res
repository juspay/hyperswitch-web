open JotaiAtoms

@react.component
let make = () => {
  let loggerState = Jotai.useAtomValue(loggerAtom)

  let state = CommonCardFieldHooks.useCardNumberField(
    ~logger=loggerState,
    ~dualPlane=true,
    (),
  )

  <CommonCardFieldHooks.RenderCardNumber state />
}
