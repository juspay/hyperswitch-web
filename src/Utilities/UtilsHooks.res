open Utils

let useSubmitPaymentData = callback => {
  React.useEffect(() => {handleMessage(callback, "")}, [callback])
}

// Nested SDK components must only accept confirm/control messages from their
// direct host iframe. This keeps unrelated window messages from entering a
// payment submit path while retaining the existing callback API.
let useSubmitPaymentDataFromParent = (~parentOrigin="*", callback) => {
  let parentCallback = React.useCallback((ev: Window.event) => {
    if ev.source === iframeParent && (parentOrigin === "*" || ev.origin === parentOrigin) {
      callback(ev)
    }
  }, (callback, parentOrigin))
  useSubmitPaymentData(parentCallback)
}

let useWindowSize = () => {
  let (size, setSize) = React.useState(_ => (0, 0))
  React.useLayoutEffect1(() => {
    let updateSize = () => {
      setSize(_ => (Window.innerWidth, Window.innerHeight))
    }
    Window.addEventListener("resize", updateSize)
    updateSize()
    Some(_ => Window.removeEventListener("resize", updateSize))
  }, [])
  size
}
