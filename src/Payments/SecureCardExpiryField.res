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
