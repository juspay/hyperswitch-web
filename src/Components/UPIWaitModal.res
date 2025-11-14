@react.component
let make = (~timeRemaining, ~timer, ~defaultTimer) => {
  open RecoilAtoms

  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)

  let timerValueUsed = timer > 0.0 ? timer : defaultTimer

  let progressBarWidth = (timerValueUsed -. timeRemaining) /. timerValueUsed *. 100.0
  let timeRemainingValue = UPIHelpers.formatTime(timeRemaining)

  <div className="w-full flex flex-col items-center justify-center h-full">
    <div
      className="w-full flex flex-col items-center justify-center h-full"
      style={
        borderBottom: `1px solid ${themeObj.borderColor}`,
      }>
      <Icon name="coin" size=80 className="shrink-0" />
      <p className="text-lg mb-6 mt-3" style={color: themeObj.colorTextSecondary}>
        {React.string("Payable amount request has been sent")}
      </p>
      <div className="flex flex-col items-center mb-6 mt-5">
        <ProgressBar width=progressBarWidth timeRemainingValue />
      </div>
    </div>
    <div className="w-full flex items-center justify-center rounded-lg bg-[#F5F7FA] mt-6 mb-6 py-3">
      <p className="text-base text-gray-500 text-center">
        {React.string("You will be automatically redirected once the payment is done")}
      </p>
    </div>
  </div>
}
