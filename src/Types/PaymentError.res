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
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      type_: getString(json, "type", ""),
      code: getString(json, "code", ""),
      message: getString(json, "message", ""),
    }
  })
  ->Option.getOr(defaultError)
}
let itemToObjMapper = dict => {
  {error: getError(dict, "error")}
}
