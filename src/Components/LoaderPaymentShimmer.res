@react.component
let make = () => {
  open JotaiAtoms
  let selectedOption = Jotai.useAtomValue(selectedOptionAtom)
  let {redirectionInfo} = Jotai.useAtomValue(optionAtom)
  UtilityHooks.useHandlePostMessages(~complete=false, ~empty=false, ~paymentType=selectedOption)
  SubscriptionEventHooks.useEmitFormStatus(~empty=false, ~complete=false)
  <RenderIf condition={redirectionInfo === PaymentType.ShowRedirectionInfo}>
    <PaymentShimmer />
  </RenderIf>
}
