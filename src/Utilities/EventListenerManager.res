type sessionStorage
@val external sessionStorage: sessionStorage = "sessionStorage"

@send external setItem: (sessionStorage, string, 'a => unit) => unit = "setItem"

let eventListenerMap: Dict.t<Types.event => unit> = Dict.make()

let addSmartEventListener = (type_, handlerMethod: Types.event => unit, activity) => {
  switch eventListenerMap->Dict.get(activity) {
  | Some(value) => Window.removeEventListener(type_, value)
  | None => ()
  }
  eventListenerMap->Dict.set(activity, handlerMethod)
  Window.addEventListener(type_, handlerMethod)
}
