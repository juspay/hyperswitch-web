@react.component
let make = () => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  <div className="w-full w-max-[750px] relative flex flex-row my-4 " ariaHidden=true>
    <div className="OrPayUsingLine relative top-[50%] h-[1px] bg-gray-400  w-full self-center" />
    <div
      className="OrPayUsingLabel relative min-w-fit px-5 text-sm text-gray-400 flex justify-center">
      {React.string(localeString.orPayUsing)}
    </div>
    <div className="OrPayUsingLine relative top-[50%] h-[1px] bg-gray-400 w-full self-center" />
  </div>
}
