@react.component
let make = () => {
  open Utils
  open RecoilAtoms
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let (isDisabled, setIsDisabled) = React.useState(() => false)
  let (showLoader, setShowLoader) = React.useState(() => false)

  let onClick = _ => {
    Console.log("Button clicked")
    setIsDisabled(_ => true)
    setShowLoader(_ => true)

    let metaData = [("isForceSync", true->JSON.Encode.bool)]->getJsonFromArrayOfJson
    let message = [
      ("fullscreen", true->JSON.Encode.bool),
      ("param", "pazeWallet"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
      ("metadata", metaData),
    ]

    messageParentWindow(message)
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
