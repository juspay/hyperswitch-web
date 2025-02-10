module Loader = {
  @react.component
  let make = () => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    <div className=" w-8 h-8 animate-spin" style={color: themeObj.colorTextSecondary}>
      <Icon size=32 name="loader" />
    </div>
  }
}
@react.component
let make = (~onClickHandler=?, ~label=?) => {
  open RecoilAtoms

  let {themeObj} = configAtom->Recoil.useRecoilValueFromAtom
  let (showAddScreen, setShowAddScreen) = Recoil.useRecoilState(RecoilAtomsV2.showAddScreen)

  let (isAddNowButtonDisable, setIsAddNowButtonDisable) = React.useState(() => false)
  let (showLoader, setShowLoader) = React.useState(() => false)

  let buttonText = switch label {
  | Some(val) => val
  | None => "Add a new card"->React.string
  }

  let onClickHandlerFunc = _ => {
    switch onClickHandler {
    | Some(fn) => fn()
    | None => ()
    }
  }

  let handleOnClick = _ => {
    setIsAddNowButtonDisable(_ => true)
    setShowAddScreen(_ => true)
    setShowLoader(_ => true)
  }

  <div className="flex flex-col gap-1 h-auto w-full items-center">
    <button
      disabled=isAddNowButtonDisable
      onClick={onClickHandler->Option.isNone ? handleOnClick : onClickHandlerFunc}
      className={`w-full flex flex-row justify-center items-center`}
      style={
        borderRadius: themeObj.buttonBorderRadius,
        backgroundColor: themeObj.buttonBackgroundColor,
        height: themeObj.buttonHeight,
        cursor: {isAddNowButtonDisable ? "not-allowed" : "pointer"},
        opacity: {isAddNowButtonDisable ? "0.6" : "1"},
        width: themeObj.buttonWidth,
        border: `${themeObj.buttonBorderWidth} solid ${themeObj.buttonBorderColor}`,
      }>
      <span
        id="button-text"
        style={
          color: themeObj.buttonTextColor,
          fontSize: themeObj.buttonTextFontSize,
          fontWeight: themeObj.buttonTextFontWeight,
        }>
        {if showLoader {
          <Loader />
        } else {
          buttonText
        }}
      </span>
    </button>
  </div>
}
