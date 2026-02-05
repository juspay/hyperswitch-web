@react.component
let make = () => {
  open RecoilAtoms
  let selectedOption = Recoil.useRecoilValueFromAtom(selectedOptionAtom)
  UtilityHooks.useHandlePostMessages(~complete=false, ~empty=false, ~paymentType=selectedOption)
  <PaymentShimmer />
}
