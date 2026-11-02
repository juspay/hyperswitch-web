// Components that are still loading report it to the nearest section; a section is loaded once
// it is mounted and nothing inside it is pending.
let context = React.createContext((_delta: int) => ())

let provider = React.Context.provider(context)

let ignorePending = (_delta: int) => ()

// Bounds the wait for wallets whose availability answer may never arrive.
let walletDecisionTimeoutMs = 3000

let usePendingWhile = (~timeoutMs=?, isPending) => {
  let report = React.useContext(context)
  let (hasTimedOut, setHasTimedOut) = React.useState(_ => false)
  let isStillPending = isPending && !hasTimedOut

  React.useLayoutEffect(() => {
    if isStillPending {
      report(1)
      Some(() => report(-1))
    } else {
      None
    }
  }, (isStillPending, report))

  React.useEffect(() => {
    switch (isPending, timeoutMs) {
    | (true, Some(ms)) =>
      let timeoutId = setTimeout(() => setHasTimedOut(_ => true), ms)
      Some(() => clearTimeout(timeoutId))
    | _ => None
    }
  }, (isPending, timeoutMs))
}

// Hidden content (e.g. an unselected form kept mounted) must not hold its section back.
module Ignored = {
  @react.component
  let make = (~isIgnored, ~children) => {
    let report = React.useContext(context)
    React.createElement(provider, {value: isIgnored ? ignorePending : report, children})
  }
}

module Pending = {
  @react.component
  let make = () => {
    usePendingWhile(true)
    React.null
  }
}

let useSection = (~isMounted) => {
  let (pendingCount, setPendingCount) = React.useState(_ => 0)
  let report = React.useCallback(delta => setPendingCount(count => count + delta), [])
  (report, isMounted && pendingCount == 0)
}
