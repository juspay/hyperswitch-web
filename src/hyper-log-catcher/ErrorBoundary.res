type errorLevel = Top | RequestButton | PaymentMethod

let errorIcon = {
  <svg
    xmlns="http://www.w3.org/2000/svg" width="50" height="50" viewBox="0 0 512 512" id="dead-ghost">
    <path
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="16"
      d="M73.73 398.49C86.92 453.5 174.24 496 280 496M312 304H264a40 40 0 00-40 40v24a32 32 0 0032 32h0a32 32 0 0032-32v-4a12 12 0 0112-12h12"
    />
    <path
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="16"
      d="M120,352H108a12,12,0,0,0-12,12v4a32,32,0,0,1-64,0V344a40,40,0,0,1,40-40h48"
    />
    <path
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="8"
      d="M160,264h27.2q11.6,0,23.189,0c3.22,0,5.97-.155,8.887.877,3.47,1.226,4.593,4.619,9.168,3.25,4.705-1.408,6.016-5.086,11.556-4.127"
    />
    <line
      x1="240"
      x2="288"
      y1="128"
      y2="208"
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="8"
    />
    <path
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="8"
      d="M288,128c-2.072,3.453-3.863,7.874-6.512,10.853-3.167,3.563-10.091,5.347-9.376,11.508.38,3.278,2.813,6.644,1.294,9.574-1,1.924-3.305,2.7-4.969,4.086-6.256,5.221-1.762,16.789-7.45,22.623-8.539,8.759-16,15.234-28.222,14.63"
    />
    <line
      x1="120"
      x2="168"
      y1="128"
      y2="208"
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="8"
    />
    <path
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="8"
      d="M168,128c-2.142,3.57-4.093,8.789-7.386,11.311-4.942,3.783-11.6,2.606-12.25,11.195-.218,2.885.646,5.866-.189,8.635-1.884,6.246-10.446,7.178-15.029,11.82-3.055,3.094-4.084,7.6-4.984,11.852C126.194,192.122,124.9,199.849,120,208"
    />
    <path
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="16"
      d="M168,264h32a0,0,0,0,1,0,0v16a16,16,0,0,1-16,16h0a16,16,0,0,1-16-16V264A0,0,0,0,1,168,264Z"
    />
    <path
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="16"
      d="M72,304a652.669,652.669,0,0,0-3.127-67.367C66.478,213.265,72,191.111,72,168a152,152,0,0,1,304,0v70.071c0,17.689-2.939,37.871.849,54.981a158.13,158.13,0,0,1,2.545,57.075c-1.179,8.136-3,16.563-.638,24.438,6.368,21.233,27.016,20.563,44.877,19.524,21.843-1.272,43.7-5.16,64.317-12.589.03.83.05,1.66.05,2.5,0,43.21-45.44,80.71-112,99.38C347.28,491.44,314.63,496,280,496c-105.76,0-193.08-42.5-206.27-97.51"
    />
    <path
      fill="none"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="8"
      d="M342.153 74.512l-21.939 27.094M352.83 95.734l-30.147 39.31M102.509 437.932c12.07-13.545 24.072-26.889 36.9-39.716M117.17 454.577l26.994-27.829"
    />
  </svg>
}

module ErrorTextAndImage = {
  @react.component
  let make = (~divRef, ~level) => {
    let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let message = switch level {
    | Top => "We'll be back with you shortly :)"
    | _ => "Try another payment method :)"
    }

    <div
      ref={divRef->ReactDOM.Ref.domRef}
      style={
        color: themeObj.colorPrimary,
        backgroundColor: themeObj.colorBackground,
        borderRadius: themeObj.borderRadius,
        borderColor: themeObj.borderColor,
      }
      className="flex  items-center">
      <div className="flex flex-row  items-center m-6">
        <div style={marginLeft: "1rem"}> {errorIcon} </div>
        <div className="flex flex-col items-center justify-center" style={marginLeft: "3rem"}>
          <div> {"Oops, something went wrong!"->React.string} </div>
          <div className="text-sm"> {message->React.string} </div>
        </div>
      </div>
    </div>
  }
}

module ErrorCard = {
  @react.component
  let make = (
    ~error: Sentry.ErrorBoundary.fallbackArg,
    ~level,
    ~componentName,
    ~publishableKey,
  ) => {
    let beaconApiCall = data => {
      if data->Array.length > 0 {
        let logData = data->Array.map(HyperLogger.logFileToObj)->JSON.Encode.array->JSON.stringify
        Window.Navigator.sendBeacon(GlobalVars.logEndpoint, logData)
      }
    }

    React.useEffect0(() => {
      let loggingLevel = GlobalVars.loggingLevelStr
      let enableLogging = GlobalVars.enableLogging
      if enableLogging && ["DEBUG", "INFO", "WARN", "ERROR"]->Array.includes(loggingLevel) {
        let errorDict =
          error
          ->Identity.anyTypeToJson
          ->Utils.getDictFromJson

        errorDict->Dict.set("componentName", componentName->JSON.Encode.string)

        let errorLog: HyperLoggerTypes.logFile = {
          logType: ERROR,
          timestamp: Date.now()->Float.toString,
          sessionId: "",
          source: "orca-elements",
          version: GlobalVars.repoVersion,
          value: errorDict->JSON.Encode.object->JSON.stringify,
          // internalMetadata: "",
          category: USER_ERROR,
          paymentId: "",
          merchantId: publishableKey,
          browserName: Utils.arrayOfNameAndVersion->Array.get(0)->Option.getOr("Others"),
          browserVersion: Utils.arrayOfNameAndVersion->Array.get(1)->Option.getOr("0"),
          platform: Window.Navigator.platform,
          userAgent: Window.Navigator.userAgent,
          appId: "",
          eventName: SDK_CRASH,
          latency: "",
          paymentMethod: "",
          firstEvent: false,
          metadata: JSON.Encode.null,
          ephemeralKey: "",
        }
        beaconApiCall([errorLog])
      }
      None
    })

    let (divH, setDivH) = React.useState(_ => 0.0)
    let (keys, _setKeys) = Recoil.useRecoilState(RecoilAtoms.keys)
    let {iframeId} = keys
    let divRef = React.useRef(Nullable.null)

    let observer = ResizeObserver.newResizerObserver(entries => {
      entries
      ->Array.map(item => {
        setDivH(_ => item.contentRect.height)
      })
      ->ignore
    })

    switch divRef.current->Nullable.toOption {
    | Some(r) => observer.observe(r)
    | None => ()
    }

    React.useEffect(() => {
      switch level {
      | Top =>
        Utils.messageParentWindow([
          ("iframeHeight", (divH +. 1.0)->JSON.Encode.float),
          ("iframeId", iframeId->JSON.Encode.string),
        ])
      | _ => ()
      }
      None
    }, (divH, iframeId))

    switch level {
    | RequestButton => React.null
    | _ => <ErrorTextAndImage divRef level />
    }
  }
}

let defaultFallback = (e, level, componentName, publishableKey) => {
  <ErrorCard error=e level componentName publishableKey />
}
@react.component
let make = (
  ~children,
  ~renderFallback=defaultFallback,
  ~level=PaymentMethod,
  ~componentName,
  ~publishableKey="",
) => {
  <Sentry.ErrorBoundary fallback={e => renderFallback(e, level, componentName, publishableKey)}>
    children
  </Sentry.ErrorBoundary>
}
