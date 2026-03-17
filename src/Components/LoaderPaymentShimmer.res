@react.component
let make = () => {
  open RecoilAtoms
  let selectedOption = Recoil.useRecoilValueFromAtom(selectedOptionAtom)
  SubscriptionEventHooks.useFormStatus(~empty=true, ~complete=false)
  UtilityHooks.useHandlePostMessages(~complete=false, ~empty=true, ~paymentType=selectedOption)
  <PaymentShimmer />
}
