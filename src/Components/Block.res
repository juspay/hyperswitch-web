@react.component
let make = (~topElement=?, ~bottomElement=?, ~padding="p-5", ~className="") => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let topBlock = switch topElement {
  | Some(ele) => ele
  | None => React.null
  }
  let actionBlock = switch bottomElement {
  | Some(ele) => ele
  | None => React.null
  }
  let divider = switch (topElement, bottomElement) {
  | (Some(_), Some(_)) =>
    <div
      className={"BlockDivider"}
      style={ReactDOMStyle.make(
        ~marginTop=themeObj.spacingUnit,
        ~marginBottom=themeObj.spacingUnit,
        (),
      )}
    />
  | (_, _) => React.null
  }
  <div
    className={`Block flex flex-col ${padding} ${className}`}
    style={ReactDOMStyle.make(~lineHeight=themeObj.fontLineHeight, ())}>
    <div className="BlockTop"> {topBlock} </div>
    {divider}
    <div className="BlockAction"> {actionBlock} </div>
  </div>
}
