type confirmParams = {
  return_url: string,
  publishableKey: string,
}

type confirm = {
  doSubmit: bool,
  clientSecret: string,
  confirmParams: confirmParams,
}
open Utils
let defaultConfirm = {
  return_url: "",
  publishableKey: "",
}
let getConfirmParams = (dict, str) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      return_url: getString(json, "return_url", ""),
      publishableKey: getString(json, "publishableKey", ""),
    }
  })
  ->Belt.Option.getWithDefault(defaultConfirm)
}

let itemToObjMapper = dict => {
  {
    doSubmit: getBool(dict, "doSubmit", false),
    clientSecret: getString(dict, "clientSecret", ""),
    confirmParams: getConfirmParams(dict, "confirmParams"),
  }
}
