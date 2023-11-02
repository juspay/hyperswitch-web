@react.component
let make = (~className="pt-4") => {
  let {branding} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  <RenderIf condition={branding == Auto}>
    <div className={`text-xs text-center w-full flex justify-center ${className}`}>
      <Icon size=18 width=130 name="powerd-by-hyper" />
    </div>
  </RenderIf>
}
