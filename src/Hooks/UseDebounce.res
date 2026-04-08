type debounce = {
  startDebounce: (unit => unit) => unit,
  cancelDebounce: unit => unit,
}

let useDebounce = (~delayMs) => {
  let timerRef = React.useRef(None)

  let cancelDebounce = React.useCallback(() => {
    timerRef.current->Option.forEach(clearTimeout)
    timerRef.current = None
  }, [])

  let startDebounce = React.useCallback(callback => {
    timerRef.current->Option.forEach(clearTimeout)
    let timerId = setTimeout(() => {
      timerRef.current = None
      callback()
    }, delayMs)
    timerRef.current = Some(timerId)
  }, [delayMs])

  // Cleanup on unmount
  React.useEffect0(() => {
    Some(
      () => {
        timerRef.current->Option.forEach(clearTimeout)
      },
    )
  })

  {
    startDebounce,
    cancelDebounce,
  }
}
