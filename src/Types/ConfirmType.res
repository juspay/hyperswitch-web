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
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      return_url: getString(json, "return_url", ""),
      publishableKey: getString(json, "publishableKey", ""),
    }
  })
  ->Option.getOr(defaultConfirm)
}

let itemToObjMapper = dict => {
  {
    doSubmit: getBool(dict, "doSubmit", false),
    clientSecret: getString(dict, "clientSecret", ""),
    confirmParams: getConfirmParams(dict, "confirmParams"),
  }
}
