type confirmParams = {
  return_url: string,
  publishableKey: string,
  redirect?: string,
}

type confirm = {
  doSubmit: bool,
  clientSecret: string,
  confirmParams: confirmParams,
  confirmTimestamp: float,
  readyTimestamp: float,
}
open Utils
let defaultConfirm = {
  return_url: "",
  publishableKey: "",
  redirect: "if_required",
}
let getConfirmParams = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      return_url: getString(json, "return_url", ""),
      publishableKey: getString(json, "publishableKey", ""),
      redirect: getString(json, "redirect", "if_required"),
    }
  })
  ->Option.getOr(defaultConfirm)
}

let itemToObjMapper = dict => {
  {
    doSubmit: getBool(dict, "doSubmit", false),
    clientSecret: getString(dict, "clientSecret", ""),
    confirmParams: getConfirmParams(dict, "confirmParams"),
    confirmTimestamp: getFloat(dict, "confirmTimestamp", 0.0),
    readyTimestamp: getFloat(dict, "readyTimestamp", 0.0),
  }
}
