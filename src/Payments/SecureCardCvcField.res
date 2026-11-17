open JotaiAtoms

@react.component
let make = () => {
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let savedCardBrand = Jotai.useAtomValue(savedCardBrand)

  let state = CommonCardFieldHooks.useCardCvcField(
    ~logger=loggerState,
    ~cardBrandOverride=savedCardBrand,
    ~dualPlane=true,
    (),
  )

  <CommonCardFieldHooks.RenderCardCvc state />
}
