open RecoilAtoms

@react.component
let make = (~errorStr=None, ~cardError="", ~expiryError="", ~cvcError="") => {
  let {themeObj, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {innerLayout} = config.appearance

  let errorTextStyle: JsxDOM.style = {
    color: themeObj.colorDangerText,
    fontSize: themeObj.fontSizeSm,
    alignSelf: "start",
    textAlign: "left",
  }

  let isSpacedErrorShown = switch errorStr {
  | Some(val) => val->String.length > 0
  | None => false
  }

  let isCompressedErrorShown =
    innerLayout === Compressed && (cardError != "" || expiryError != "" || cvcError != "")

  switch innerLayout {
  | Spaced =>
    <RenderIf condition=isSpacedErrorShown>
      <LiveError
        text={errorStr->Belt.Option.getWithDefault("")}
        className="Error pt-1"
        style={errorTextStyle}
      />
    </RenderIf>
  | Compressed =>
    <RenderIf condition=isCompressedErrorShown>
      <LiveError text={"Invalid input"} className="Error pt-1" style={errorTextStyle} />
    </RenderIf>
  }
}
