@react.component
let make = (~showInBlock=true) => {
  open PaymentElementShimmer
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let bottomElement =
    <Shimmer classname="opacity-50">
      <div
        className="w-full h-2 animate-pulse"
        style={ReactDOMStyle.make(~backgroundColor=themeObj.colorPrimary, ~opacity="10%", ())}
      />
    </Shimmer>
  if showInBlock {
    <Block bottomElement />
  } else {
    {bottomElement}
  }
}
