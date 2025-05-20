type networkState = {
  isOnline: bool,
  effectiveType: string,
  downlink: float,
  rtt: float,
}

let defaultNetworkState = {
  isOnline: Window.Navigator.navigatorOnLine,
  effectiveType: "",
  downlink: 0.,
  rtt: 0.,
}

type networkStateFromHook = CALCULATING | Value(networkState)

let getNetworkState = () => {
  open Window.Navigator
  let conn = connection->Nullable.toOption

  switch conn {
  | Some(conn) =>
    Value({
      isOnline: navigatorOnLine,
      effectiveType: conn.effectiveType,
      downlink: conn.downlink,
      rtt: conn.rtt,
    })
  | None => CALCULATING
  }
}

let useNetworkInformation = () => {
  let initialState = CALCULATING
  let (networkState, setNetworkState) = React.useState(_ => initialState)

  React.useEffect(() => {
    open Window.Navigator

    let updateNetState = () => {
      let conn = connection->Nullable.toOption

      switch conn {
      | Some(conn) =>
        setNetworkState(_ => Value({
          isOnline: navigatorOnLine,
          effectiveType: conn.effectiveType,
          downlink: conn.downlink,
          rtt: conn.rtt,
        }))
      | None => setNetworkState(_ => CALCULATING)
      }
    }

    Window.addEventListener("load", updateNetState)
    Window.addEventListener("online", updateNetState)
    Window.addEventListener("offline", updateNetState)

    Some(
      () => {
        Window.removeEventListener("load", updateNetState)
        Window.removeEventListener("online", updateNetState)
        Window.removeEventListener("offline", updateNetState)
      },
    )
  }, [])

  networkState
}
