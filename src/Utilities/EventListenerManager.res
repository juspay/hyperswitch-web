type sessionStorage
@val external sessionStorage: sessionStorage = "sessionStorage"

@send external setItem: (sessionStorage, string, 'a => unit) => unit = "setItem"

let eventListenerMap: Js.Dict.t<Types.event => unit> = Js.Dict.empty()

let addSmartEventListener = (type_, handlerMethod: Types.event => unit, activity) => {
  switch eventListenerMap->Js.Dict.get(activity) {
  | Some(value) => Window.removeEventListener(type_, value)
  | None => ()
  }
  eventListenerMap->Js.Dict.set(activity, handlerMethod)
  Window.addEventListener(type_, handlerMethod)
}
