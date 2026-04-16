@react.component
let make = (~isSelected) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let borderColor = isSelected ? themeObj.colorPrimary : themeObj.borderColor

  <div
    style={
      border: `1.5px solid ${borderColor}`,
    }
    className="w-4 h-4 rounded-full shrink-0 flex items-center justify-center">
    <RenderIf condition=isSelected>
      <div
        style={
          backgroundColor: themeObj.colorPrimary,
        }
        className="w-2 h-2 rounded-full"
      />
    </RenderIf>
  </div>
}
