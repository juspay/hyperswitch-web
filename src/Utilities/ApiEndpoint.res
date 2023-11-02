let switchToInteg = false
let isLocal = false
let sdkDomainUrl = `${GlobalVars.sdkUrl}${GlobalVars.repoPublicPath}`

let apiEndPoint = ref(None)

let setApiEndPoint = str => {
  apiEndPoint := Some(str)
}

let getApiEndPoint = (~publishableKey="", ()) => {
  let testMode = publishableKey->Js.String2.startsWith("pk_snd_")
  switch apiEndPoint.contents {
  | Some(str) => str
  | None =>
    if GlobalVars.isProd {
      testMode ? "https://sandbox.hyperswitch.io" : {GlobalVars.backendEndPoint}
    } else {
      {GlobalVars.backendEndPoint}
    }
  }
}

let addCustomPodHeader = (arr: array<(string, string)>, ~switchToCustomPod=?, ()) => {
  let customPod = switch switchToCustomPod {
  | Some(val) => val
  | None => false
  }
  if customPod {
    arr->Js.Array2.concat([("x-feature", "router-custom-dbd")])->Js.Dict.fromArray
  } else {
    arr->Js.Dict.fromArray
  }
}
