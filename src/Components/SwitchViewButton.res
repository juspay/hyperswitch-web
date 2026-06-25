@react.component
let make = (~onActivate, ~icon, ~title, ~ariaLabel, ~dataTestId=?) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  <div
    className="Label flex flex-row gap-3 items-end cursor-pointer mt-4"
    style={
      fontSize: "14px",
      float: "left",
      fontWeight: themeObj.fontWeightNormal,
      width: "fit-content",
      color: themeObj.colorPrimary,
    }
    tabIndex=0
    role="button"
    ariaLabel
    onKeyDown={AccessibilityUtils.onActivateKeyDown(~onActivate)}
    dataTestId={dataTestId->Option.getOr("")}
    onClick={_ => onActivate()}>
    {icon}
    {React.string(title)}
  </div>
}
