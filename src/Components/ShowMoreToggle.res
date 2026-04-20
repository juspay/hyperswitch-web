@react.component
let make = (~isCollapsed, ~setIsCollapsed) => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  <div
    className="Label flex flex-row gap-1 items-end cursor-pointer mt-3 text-sm font-medium float-left w-fit"
    style={
      color: themeObj.colorPrimary,
    }
    onClick={_ => setIsCollapsed(prev => !prev)}>
    {isCollapsed ? React.string(localeString.showMore) : React.string(localeString.showLess)}
    <div className="m-1">
      {isCollapsed ? <Icon name="arrow-down" size=10 /> : <Icon name="arrow-up" size=10 />}
    </div>
  </div>
}
