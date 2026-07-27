type field = {
  value: string,
  isValid: option<bool>,
  errorString: string,
  countryCode?: string,
}

type load = Loading | Loaded(JSON.t) | LoadError

type paymentToken = {
  paymentToken: string,
  customerId: string,
}

let defaultPaymentToken: paymentToken = {
  paymentToken: "",
  customerId: "",
}

type redirectionFlags = {
  shouldUseTopRedirection: bool,
  shouldRemoveBeforeUnloadEvents: bool,
}

let decodeRedirectionFlags = (json: JSON.t, default: redirectionFlags): redirectionFlags => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(obj => {
    let shouldUseTopRedirection =
      obj
      ->Dict.get("shouldUseTopRedirection")
      ->Option.flatMap(JSON.Decode.bool)
      ->Option.getOr(default.shouldUseTopRedirection)
    let shouldRemoveBeforeUnloadEvents =
      obj
      ->Dict.get("shouldRemoveBeforeUnloadEvents")
      ->Option.flatMap(JSON.Decode.bool)
      ->Option.getOr(default.shouldRemoveBeforeUnloadEvents)
    Some({
      shouldRemoveBeforeUnloadEvents,
      shouldUseTopRedirection,
    })
  })
  ->Option.getOr(default)
}

type trustPayScriptStatus = NotLoaded | Loading | Loaded | Failed
