@react.component
let make = (~onClick, ~icon, ~title, ~ariaLabel) => {
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
    onKeyDown={event => {
      let key = JsxEvent.Keyboard.key(event)
      let keyCode = JsxEvent.Keyboard.keyCode(event)
      if key == "Enter" || keyCode == 13 {
        onClick(Obj.magic(event))
      }
    }}
    onClick={onClick}>
    {icon}
    {React.string(title)}
  </div>
}
