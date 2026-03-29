@val @scope("document")
external addDocumentEventListener: (string, _ => unit) => unit = "addEventListener"

@val @scope("document")
external removeDocumentEventListener: (string, _ => unit) => unit = "removeEventListener"

@react.component
let make = () => {
  let errorMessage = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentFailedErrorMessage)
  let setErrorMessage = Recoil.useSetRecoilState(RecoilAtoms.paymentFailedErrorMessage)
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  React.useEffect(() => {
    if errorMessage->String.length > 0 {
      let handler = _event => {
        setErrorMessage(_ => "")
      }
      addDocumentEventListener("input", handler)
      addDocumentEventListener("click", handler)
      Some(
        () => {
          removeDocumentEventListener("input", handler)
          removeDocumentEventListener("click", handler)
        },
      )
    } else {
      None
    }
  }, [errorMessage])

  <RenderIf condition={errorMessage->String.length > 0}>
    <div style={paddingTop: "24px"}>
        <div
        style={
          display: "flex",
          flexDirection: "row",
          alignItems: "flex-start",
          gap: themeObj.spacingUnit,
          padding: themeObj.spacingTab,
          borderRadius: themeObj.borderRadius,
          backgroundColor: `${themeObj.colorDanger}15`,
          border: `1px solid ${themeObj.colorDanger}40`,
          width: "100%",
          boxSizing: "border-box",
          fontFamily: themeObj.fontFamily,
        }>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke={themeObj.colorDanger}
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          style={
            flexShrink: "0",
            marginTop: "1px",
          }>
          <circle cx="12" cy="12" r="10" />
          <line x1="12" y1="16" x2="12" y2="12" />
          <line x1="12" y1="8" x2="12.01" y2="8" />
        </svg>
        <span
          style={
            color: themeObj.colorDangerText,
            fontSize: themeObj.fontSizeLg,
            lineHeight: "20px",
          }>
          {React.string(errorMessage)}
        </span>
      </div>
    </div>
  </RenderIf>
}
