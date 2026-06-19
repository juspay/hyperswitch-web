open RecoilAtoms

// Container for a single VGS secure field.  VGS injects its own iframe into the
// `id` div; this wrapper provides the label + border/background/focus styling via
// the same theme classes (`Input` / `Input-Compressed` / `VGSField--focused`) that
// a native Hyperswitch <PaymentInputField /> uses, so the two look identical.
@react.component
let make = (~fieldName="", ~id="", ~isFocused=false, ~errorStr=?) => {
  let {themeObj, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {innerLayout} = config.appearance

  let (focusClass, setFocusClass) = React.useState(_ => "")

  React.useEffect(() => {
    setFocusClass(_ => isFocused ? "VGSField--focused" : "")
    None
  }, [isFocused])

  let inputClassStyles = innerLayout === Spaced ? "Input" : "Input-Compressed"

  <div className="flex flex-col w-full" style={color: themeObj.colorText}>
    <RenderIf
      condition={fieldName->String.length > 0 &&
      config.appearance.labels == Above &&
      innerLayout === Spaced}>
      <div
        className="Label Label--empty"
        style={
          fontWeight: themeObj.fontWeightNormal,
          fontSize: themeObj.fontSizeLg,
          marginBottom: "5px",
          opacity: "0.6",
        }
        ariaHidden=true>
        {React.string(fieldName)}
      </div>
    </RenderIf>
    <div className="flex flex-row" style={direction: "ltr"}>
      <div className="relative w-full">
        <div className="flex flex-col w-full" style={color: themeObj.colorText}>
          <div className="flex flex-row">
            <div
              id
              style={
                background: themeObj.colorBackground,
                padding: themeObj.spacingUnit,
                width: "100%",
              }
              className={`${inputClassStyles} Input--empty focus:outline-none transition-shadow ease-out duration-200 ${focusClass}`}
            />
          </div>
          <ErrorComponent errorStr />
        </div>
      </div>
    </div>
  </div>
}
