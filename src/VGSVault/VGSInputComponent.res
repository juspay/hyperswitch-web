open RecoilAtoms

@react.component
let make = (~fieldName="", ~id="", ~isFocused=false, ~errorStr=?) => {
  let {themeObj, config} = Recoil.useRecoilValueFromAtom(configAtom)
  let {innerLayout} = config.appearance

  let (focusClass, setFocusClass) = React.useState(_ => "input-empty")

  React.useEffect(() => {
    setFocusClass(_ => isFocused ? "VGSField--focused" : "input-empty")
    None
  }, [isFocused])

  <div className="flex flex-col w-full" style={color: themeObj.colorText}>
    <RenderIf
      condition={fieldName->String.length > 0 &&
      config.appearance.labels == Above &&
      innerLayout === Spaced}>
      <label
        htmlFor=id
        className={`Label Label--empty`}
        style={
          fontWeight: themeObj.fontWeightNormal,
          fontSize: themeObj.fontSizeLg,
          marginBottom: "5px",
          opacity: "0.6",
        }>
        {React.string(fieldName)}
      </label>
    </RenderIf>
    <div className="flex flex-row " style={direction: "ltr"}>
      <div className={`relative w-full `}>
        <div className={` flex flex-col w-full`} style={color: themeObj.colorText}>
          <div className="flex flex-row " style={direction: ""}>
            <div
              id
              style={
                background: themeObj.colorBackground,
                padding: themeObj.spacingUnit,
                width: "100%",
                height: "50px",
              }
              className={`Input Input--empty focus:outline-none transition-shadow ease-out duration-200 border border-gray-300 focus:border-[#006DF9] rounded-md text-sm ${focusClass}`}
            />
          </div>
          <ErrorComponent errorStr />
        </div>
      </div>
    </div>
  </div>
}
