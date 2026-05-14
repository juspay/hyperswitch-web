@react.component
let make = () => {
  open RecoilAtoms
  let selectedOption = Recoil.useRecoilValueFromAtom(selectedOptionAtom)
  let {layout, customMethodNames, redirectionInfo} = Recoil.useRecoilValueFromAtom(optionAtom)
  UtilityHooks.useHandlePostMessages(~complete=false, ~empty=false, ~paymentType=selectedOption)
  redirectionInfo === PaymentType.ShowRedirectInfo ? <PaymentShimmer /> : React.null
}
