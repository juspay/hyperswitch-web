let switchToInteg = false
let isLocal = false
let sdkDomainUrl = `${GlobalVars.sdkUrl}${GlobalVars.repoPublicPath}`

let apiEndPoint: ref<option<string>> = ref(None)

let setApiEndPoint = str => {
  apiEndPoint := Some(str)
}

let getApiEndPoint = (~publishableKey="", ~isConfirmCall=false, ()) => {
  let testMode = publishableKey->String.startsWith("pk_snd_")
  switch apiEndPoint.contents {
  | Some(str) => str
  | None =>
    let backendEndPoint = isConfirmCall ? GlobalVars.confirmEndPoint : GlobalVars.backendEndPoint
    GlobalVars.isProd && testMode ? "https://beta.hyperswitch.io/api" : backendEndPoint
  }
}

let addCustomPodHeader = (arr: array<(string, string)>, ~switchToCustomPod=?, ()) => {
  let customPod = switch switchToCustomPod {
  | Some(val) => val
  | None => false
  }
  if customPod {
    arr->Array.concat([("x-feature", "router-custom-dbd")])->Dict.fromArray
  } else {
    arr->Dict.fromArray
  }
}
