@react.component
let make = (~width, ~timeRemainingValue) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  <>
    <div className="w-40 h-1.5 bg-[#E5E7EB] rounded-full mb-2">
      <div
        className="h-full bg-[#2563EB] rounded-full transition-all duration-1000 ease-linear"
        style={
          width: `${width->Float.toString}%`,
        }
      />
    </div>
    <p className="text-sm">
      {React.string("Complete the payment within ")}
      <span className="font-semibold" style={color: themeObj.colorText}>
        {React.string(timeRemainingValue)}
      </span>
    </p>
  </>
}
