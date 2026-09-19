open Window
type contentRect = {height: float}

type keys = {
  clientSecret: option<string>,
  sdkAuthorization: option<string>,
  paymentId: string,
  pmSessionId?: string,
  publishableKey: string,
  iframeId: string,
  parentURL: string,
  sdkHandleOneClickConfirmPayment: bool,
}

type debounce = {
  startDebounce: (unit => unit) => unit,
  cancelDebounce: unit => unit,
}

@val @scope("document") external querySelector: string => Nullable.t<element> = "querySelector"

type event = {\"type": string}
@val @scope("document") external createElement: string => element = "createElement"

@val @scope(("document", "body")) external appendChild: element => unit = "appendChild"

@send
external addEventListener: (element, string, event => unit) => unit = "addEventListener"

let useScript = (
  src: string,
  ~integrity="",
  ~crossorigin="",
  ~resourceEvent: SdkLogger.resourceEvent,
) => {
  let (status, setStatus) = React.useState(_ => src != "" ? "loading" : "idle")
  React.useEffect(() => {
    if src == "" {
      setStatus(_ => "idle")
      None
    } else {
      let cancelled = ref(false)
      let settle = value => cancelled.contents ? () : setStatus(_ => value)
      setStatus(_ => "loading")
      SdkLogger.observeResource(
        ~event=resourceEvent,
        ~url=src,
        ~attributes=[("crossorigin", crossorigin), ("integrity", integrity)]
        ->Array.filter(((_, value)) => value != "")
        ->Array.concat([("async", "true")]),
        ~matchQuery=true,
        ~abandoned=() => cancelled.contents,
        ~onLoad=() => settle("ready"),
        ~onError=_ => settle("error"),
      )
      Some(() => cancelled := true)
    }
  }, [src])
  status
}

let updateKeys = (dict, keyPair, setKeys) => {
  let (key, value) = keyPair
  let valueStr = value->Utils.getStringFromJson("")
  let valueBool = default => value->JSON.Decode.bool->Option.getOr(default)
  if dict->Utils.getDictIsSome(key) {
    switch key {
    | "iframeId" =>
      setKeys(prev => {
        ...prev,
        iframeId: dict->Utils.getString(key, valueStr),
      })
    | "publishableKey" =>
      setKeys(prev => {
        ...prev,
        publishableKey: dict->Utils.getString(key, valueStr),
      })
    | "paymentId" =>
      setKeys(prev => {
        ...prev,
        paymentId: dict->Utils.getString(key, valueStr),
      })
    | "parentURL" =>
      setKeys(prev => {
        ...prev,
        parentURL: dict->Utils.getString(key, valueStr),
      })
    | "sdkHandleOneClickConfirmPayment" =>
      setKeys(prev => {
        ...prev,
        sdkHandleOneClickConfirmPayment: dict->Utils.getBool(key, valueBool(true)),
      })
    | _ => ()
    }
  }
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

let defaultkeys = {
  clientSecret: None,
  sdkAuthorization: None,
  publishableKey: "",
  paymentId: "",
  iframeId: "",
  parentURL: "*",
  sdkHandleOneClickConfirmPayment: true,
}
