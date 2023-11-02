@send external postMessage: (Window.window, Js.Json.t, string) => unit = "postMessage"

external eventToJson: ReactEvent.Mouse.t => Js.Json.t = "%identity"

module Loader = {
  @react.component
  let make = () => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    <div
      className=" w-8 h-8 animate-spin"
      style={ReactDOMStyle.make(~color=themeObj.colorTextSecondary, ())}>
      <Icon size=32 name="loader" />
    </div>
  }
}
@react.component
let make = () => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let (isDisabled, setIsDisabled) = React.useState(() => false)
  let (showLoader, setShowLoader) = React.useState(() => false)
  let complete = Recoil.useRecoilValueFromAtom(RecoilAtoms.fieldsComplete)

  let handleOnClick = _ev => {
    setIsDisabled(_ => true)
    setShowLoader(_ => true)
    Utils.handleOnConfirmPostMessage(~targetOrigin="*", ())
  }
  React.useEffect1(() => {
    setIsDisabled(_ => !complete)
    None
  }, [complete])

  <div className="flex flex-col gap-1 h-auto w-full">
    <button
      disabled=isDisabled
      onClick=handleOnClick
      className={`w-full flex flex-row justify-center items-center rounded-md`}
      style={ReactDOMStyle.make(
        ~backgroundColor=themeObj.colorBackground,
        ~height="48px",
        ~cursor={isDisabled ? "not-allowed" : "pointer"},
        ~opacity={isDisabled ? "0.6" : "1"},
        ~borderWidth="thin",
        ~borderColor=themeObj.colorPrimary,
        (),
      )}>
      <span id="button-text" style={ReactDOMStyle.make(~color=themeObj.colorPrimary, ())}>
        {if showLoader {
          <Loader />
        } else {
          {React.string(localeString.payNowButton)}
        }}
      </span>
    </button>
  </div>
}
