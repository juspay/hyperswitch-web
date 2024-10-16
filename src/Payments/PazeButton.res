@react.component
let make = (~token: SessionsType.token) => {
  open Utils
  open RecoilAtoms
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let (isDisabled, setIsDisabled) = React.useState(() => false)
  let (showLoader, setShowLoader) = React.useState(() => false)

  let onClick = _ => {
    setIsDisabled(_ => true)
    setShowLoader(_ => true)
    messageParentWindow([
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "pazeWallet"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      (
        "metadata",
        [
          ("clientId", token.clientId->JSON.Encode.string),
          ("clientName", token.clientName->JSON.Encode.string),
          ("clientProfileId", token.clientProfileId->JSON.Encode.string),
        ]->getJsonFromArrayOfJson,
      ),
    ])
  }

  <button
    disabled=false
    onClick
    className={`w-full flex flex-row justify-center items-center`}
    style={
      borderRadius: themeObj.buttonBorderRadius,
      backgroundColor: "#2B63FF",
      height: themeObj.buttonHeight,
      cursor: {isDisabled ? "not-allowed" : "pointer"},
      opacity: {isDisabled ? "0.6" : "1"},
      width: themeObj.buttonWidth,
      border: `${themeObj.buttonBorderWidth} solid ${themeObj.buttonBorderColor}`,
    }>
    {showLoader ? <Spinner /> : <Icon name="paze" size=55 />}
  </button>
}
