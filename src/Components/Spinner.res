@react.component
let make = () => {
  let {themeObj} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  <div className="w-8 h-8 animate-spin" style={color: themeObj.colorTextSecondary}>
    <Icon size=32 name="loader" />
  </div>
}
