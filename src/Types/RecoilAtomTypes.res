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

type redirectionFlags = {
  shouldUseTopRedirection: bool,
  shouldRemoveBeforeUnloadEvents: bool,
}

let decodeRedirectionFlags = (
  json: JSON.t,
  defaultRedirectionFlags: redirectionFlags,
): redirectionFlags => {
  json
  ->JSON.Decode.object
  ->Option.flatMap(obj => {
    let shouldUseTopRedirection =
      obj
      ->Dict.get("shouldUseTopRedirection")
      ->Option.flatMap(JSON.Decode.bool)
      ->Option.getOr(defaultRedirectionFlags.shouldUseTopRedirection)
    let shouldRemoveBeforeUnloadEvents =
      obj
      ->Dict.get("shouldRemoveBeforeUnloadEvents")
      ->Option.flatMap(JSON.Decode.bool)
      ->Option.getOr(defaultRedirectionFlags.shouldRemoveBeforeUnloadEvents)
    Some({
      shouldRemoveBeforeUnloadEvents,
      shouldUseTopRedirection,
    })
  })
  ->Option.getOr(defaultRedirectionFlags)
}
