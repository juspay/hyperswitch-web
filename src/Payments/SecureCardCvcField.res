open JotaiAtoms

@react.component
let make = () => {
  let savedCardBrand = Jotai.useAtomValue(savedCardBrand)

  let state = CommonCardFieldHooks.useCardCvcField(
    ~cardBrandOverride=savedCardBrand,
    ~dualPlane=true,
    (),
  )

  <CommonCardFieldHooks.RenderCardCvc state />
}
