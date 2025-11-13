module DoneButton = {
  @react.component
  let make = (~closeModal) => {
    open RecoilAtoms

    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)

    <button
      className="w-full p-3 rounded-lg font-medium"
      style={
        background: themeObj.colorPrimary,
        color: "#ffffff",
      }
      onClick={_ => {
        closeModal()->ignore
      }}>
      {React.string("Done")}
    </button>
  }
}

module TryAnotherAppButton = {
  @react.component
  let make = (~setCurrentScreen, ~setSelectedApp) => {
    open RecoilAtoms
    open UPITypes

    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)

    let handleBackToAppSelection = () => {
      setCurrentScreen(_ => AppSelection)
      setSelectedApp(_ => None)
    }

    <button
      className="w-full p-3 rounded-lg font-medium border"
      style={
        borderColor: themeObj.colorPrimary,
        color: themeObj.colorPrimary,
        backgroundColor: "transparent",
      }
      onClick={_ => handleBackToAppSelection()}>
      {React.string("Try Another App")}
    </button>
  }
}

module AppSelectionButton = {
  @react.component
  let make = (
    ~selectedApp,
    ~upiUrl,
    ~setCurrentScreen,
    ~setTimeRemaining,
    ~timer,
    ~defaultTimer,
  ) => {
    open RecoilAtoms
    open UPIHelpers
    open UPITypes

    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
    let logger = Recoil.useRecoilValueFromAtom(loggerAtom)

    let handleOpenApp = () => {
      switch selectedApp {
      | Some(app) => {
          let appSpecificUrl = constructAppSpecificUrl(app, upiUrl)
          logger.setLogInfo(
            ~value=`Opening UPI app: ${app.name} with URL: ${appSpecificUrl}`,
            ~eventName=PAYMENT_ATTEMPT,
          )
          UPIHelpers.openApp(appSpecificUrl)
          setCurrentScreen(_ => VerificationScreen)
          if timer > 0.0 {
            setTimeRemaining(_ => timer)
          } else {
            setTimeRemaining(_ => defaultTimer)
          }
        }
      | None => {
          logger.setLogInfo(
            ~value=`Opening UPI with default URL: ${upiUrl}`,
            ~eventName=PAYMENT_ATTEMPT,
          )
          UPIHelpers.openApp(upiUrl)

          setCurrentScreen(_ => VerificationScreen)
          setTimeRemaining(_ => defaultTimer)
        }
      }
    }

    <button
      className="w-full p-3 rounded-lg font-medium"
      style={
        background: themeObj.colorPrimary,
        color: "#ffffff",
      }
      onClick={_ => handleOpenApp()}>
      {React.string("Proceed to pay")}
    </button>
  }
}
