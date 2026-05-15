@react.component
let make = () => {
  open RecoilAtoms
  let selectedOption = Recoil.useRecoilValueFromAtom(selectedOptionAtom)
  let {redirectionInfo} = Recoil.useRecoilValueFromAtom(optionAtom)
  UtilityHooks.useHandlePostMessages(~complete=false, ~empty=false, ~paymentType=selectedOption)
  <RenderIf condition={redirectionInfo === PaymentType.ShowRedirectionInfo}>
    <PaymentShimmer />
  </RenderIf>
}
