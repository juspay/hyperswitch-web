module UPIQRCodeInfoElement = {
  @react.component
  let make = () => {
    open RecoilAtoms

    let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)

    <div className="flex flex-row items-start mt-3">
      <Icon name="qr_code" size=50 className="shrink-0" />
      <div className="flex flex-col ml-3 gap-3">
        <span className="text-base font-medium text-start" style={color: themeObj.colorText}>
          {React.string("Scan QR from your UPI app")}
        </span>
        <div
          className="w-full text-start opacity-60"
          style={
            color: themeObj.colorText,
            fontSize: themeObj.fontSizeLg,
            fontWeight: themeObj.fontWeightLight,
          }>
          {React.string(
            "Use any UPI app on your mobile phone like CRED, Phone Pe, Google Pay, BHIM etc",
          )}
        </div>
        <div className="flex flex-row items-center">
          <Icon name="multiple_apps" width=110 size=29 className="shrink-0" />
          <div
            className="w-full text-start ml-1 opacity-60"
            style={
              color: themeObj.colorText,
              fontSize: themeObj.fontSizeLg,
              fontWeight: themeObj.fontWeightLight,
            }>
            {React.string("& more")}
          </div>
        </div>
      </div>
    </div>
  }
}

@react.component
let make = (~upiUrl, ~timer, ~timeRemaining, ~defaultTimer) => {
  open RecoilAtoms

  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)

  let timerValueUsed = timer > 0.0 ? timer : defaultTimer

  let progressBarWidth = (timerValueUsed -. timeRemaining) /. timerValueUsed *. 100.0
  let timeRemainingValue = UPIHelpers.formatTime(timeRemaining)

  let addInnerHtml = htmlUi => {
    let element = Window.querySelector("#qr-code")
    switch element->Nullable.toOption {
    | Some(elem) => elem->Window.innerHTML(htmlUi)
    | None =>
      Console.warn(
        "INTEGRATION ERROR: Div does not seem to exist on which payment element is to mount/unmount",
      )
    }
  }

  React.useEffect(() => {
    switch UPIHelpers.generateQRCode(upiUrl) {
    | Some(qrSvg) => addInnerHtml(qrSvg)
    | None => {
        let fallbackUi = `<div>
          <p>
            Unable to generate QR code
          </p>
        </div>`
        addInnerHtml(fallbackUi)
      }
    }

    None
  }, [upiUrl])

  <div
    className="rounded-2xl border border-[#E5E7EB] bg-white p-8 text-center shadow-sm max-w-md mx-auto">
    <h2 className="text-lg font-semibold mb-1" style={color: themeObj.colorText}>
      {React.string("Pay with QR code")}
    </h2>
    <p className="text-sm mb-6" style={color: themeObj.colorTextSecondary}>
      {React.string("Scan & pay with any UPI app")}
    </p>
    <div className="flex justify-center mb-6">
      <div
        className="bg-[#FAFAFA] p-4 rounded-2xl shadow-sm border border-[#F1F1F1]" id="qr-code"
      />
    </div>
    <div className="flex flex-col items-center mb-6">
      <ProgressBar width=progressBarWidth timeRemainingValue />
    </div>
    <div className="border-t border-[#E5E7EB] pt-3 mt-4 flex text-xs text-gray-500">
      <Icon name="info_circle" className="shrink-0" />
      {React.string("You will be automatically redirected once the payment is done")}
    </div>
  </div>
}
