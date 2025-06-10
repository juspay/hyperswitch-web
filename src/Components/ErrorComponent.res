open RecoilAtoms

@react.component
let make = (~errorStr=None, ~cardError="", ~expiryError="", ~cvcError="") => {
  let {themeObj, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {innerLayout} = config.appearance

  switch (innerLayout, errorStr) {
  | (Spaced, Some(val)) =>
    <RenderIf condition={val->String.length > 0}>
      <div
        className="Error pt-1"
        style={
          color: themeObj.colorDangerText,
          fontSize: themeObj.fontSizeSm,
          alignSelf: "start",
          textAlign: "left",
        }>
        {React.string(val)}
      </div>
    </RenderIf>
  | (Compressed, _) =>
    <RenderIf
      condition={cardError->String.length > 0 ||
      expiryError->String.length > 0 ||
      cvcError->String.length > 0}>
      <div
        className="Error pt-1"
        style={
          color: themeObj.colorDangerText,
          fontSize: themeObj.fontSizeSm,
          alignSelf: "start",
          textAlign: "left",
        }>
        {React.string("Invalid input")}
      </div>
    </RenderIf>
  | _ => React.null
  }
}
