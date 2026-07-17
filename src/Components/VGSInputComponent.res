open RecoilAtoms

// Container for a single VGS secure field.  VGS injects its own iframe into the
// `id` div; this wrapper provides the label + border/background/focus styling via
// the same theme classes (`Input` / `Input-Compressed` / `VGSField--focused`) that
// a native Hyperswitch <PaymentInputField /> uses, so the two look identical.
// `compact` + `height` are used by the saved-card (return user) cvc field so the
// secure field box matches the small native cvc input (≈ 1.8rem tall, no extra
// vertical padding) instead of the taller new-card field.
@react.component
let make = (~fieldName="", ~id="", ~isFocused=false, ~errorStr=?, ~compact=false, ~height="") => {
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
                // Compact (saved-card cvc): horizontal padding only + fixed height
                // so the box matches the native cvc input; otherwise the standard
                // all-around padding used by the new-card fields.
                padding: compact ? `0px ${themeObj.spacingUnit}` : themeObj.spacingUnit,
                width: "100%",
                height,
                boxSizing: "border-box",
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
