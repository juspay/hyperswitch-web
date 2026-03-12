@react.component
let make = () => {
  let selectedOption = Jotai.useAtomValue(JotaiAtoms.selectedOptionAtom)
  UtilityHooks.useHandlePostMessages(~complete=false, ~empty=false, ~paymentType=selectedOption)
  <PaymentShimmer />
}
