@react.component
let make = () => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  <div className="flex justify-center font-bold text-lg text-red-600">
    {React.string(localeString.errorOccurredText)}
  </div>
}
