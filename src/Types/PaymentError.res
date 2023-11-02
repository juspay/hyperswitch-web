open Utils
type error = {
  type_: string,
  code: string,
  message: string,
}
type errorType = {error: error}
let defaultError = {
  type_: "server_error",
  code: "",
  message: "Something went wrong",
}
let getError = (dict, str) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      type_: getString(json, "type", ""),
      code: getString(json, "code", ""),
      message: getString(json, "message", ""),
    }
  })
  ->Belt.Option.getWithDefault(defaultError)
}
let itemToObjMapper = dict => {
  {error: getError(dict, "error")}
}
