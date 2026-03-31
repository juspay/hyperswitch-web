@react.component
let make = (~isToggled, ~onToggle, ~label, ~disabled=false) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)

  let handleToggle = _ => {
    if !disabled {
      onToggle(!isToggled)
    }
  }

  let toggleTrackColor = isToggled ? themeObj.colorPrimary : themeObj.borderColor

  <div
    className={`flex items-center gap-2 w-full ${disabled
        ? "cursor-not-allowed"
        : "cursor-pointer"}`}
    tabIndex={disabled ? -1 : 0}
    role="switch"
    ariaChecked={isToggled ? #"true" : #"false"}
    ariaLabel=label
    ariaDisabled=disabled
    onClick=handleToggle
    onKeyDown={event => {
      if !disabled {
        let key = JsxEvent.Keyboard.key(event)
        let keyCode = JsxEvent.Keyboard.keyCode(event)
        if key == "Enter" || keyCode == 13 || key == " " || keyCode == 32 {
          event->JsxEvent.Keyboard.preventDefault
          onToggle(!isToggled)
        }
      }
    }}>
    <div
      style={
        backgroundColor: toggleTrackColor,
        width: "32px",
        height: "16px",
        borderRadius: "8px",
        padding: "2px",
        transition: "background-color 0.2s ease",
      }
      className="flex items-center flex-shrink-0">
      <div
        style={
          width: "12px",
          height: "12px",
          borderRadius: "50%",
          backgroundColor: themeObj.colorBackground,
          transform: isToggled ? "translateX(16px)" : "translateX(0px)",
          transition: "transform 0.2s ease",
          boxShadow: "0 1px 3px rgba(0, 0, 0, 0.1)",
        }
      />
    </div>
    <span
      style={
        color: themeObj.colorText,
        fontWeight: themeObj.fontWeightNormal,
      }
      className="opacity-50 text-xs select-none">
      {label->React.string}
    </span>
  </div>
}
