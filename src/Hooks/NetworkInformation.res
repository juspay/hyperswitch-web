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

@val @scope("window")
external addEventListener: (string, unit => unit) => unit = "addEventListener"

@val @scope("window")
external removeEventListener: (string, unit => unit) => unit = "removeEventListener"

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

    addEventListener("load", updateNetState)
    addEventListener("online", updateNetState)
    addEventListener("offline", updateNetState)

    Some(
      () => {
        removeEventListener("load", updateNetState)
        removeEventListener("online", updateNetState)
        removeEventListener("offline", updateNetState)
      },
    )
  }, [])

  networkState
}
