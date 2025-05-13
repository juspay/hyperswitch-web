type networkState = {
  isOnline: bool,
  effectiveType: string,
  downlink: float,
  rtt: float,
}

type connection = {
  effectiveType: string,
  downlink: float,
  rtt: float,
}

@val external navigatorOnLine: bool = "navigator.onLine"
@val @scope("navigator") external connection: Js.Nullable.t<connection> = "connection"

let defaultNetworkState = {
  isOnline: navigatorOnLine,
  effectiveType: "",
  downlink: 0.,
  rtt: 0.,
}

type networkStateFromHook = CALCULATING | Value(networkState)
let getNetworkState = () => {
  let conn = connection->Js.Nullable.toOption

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
    let updateNetState = () => {
      let conn = connection->Js.Nullable.toOption

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
