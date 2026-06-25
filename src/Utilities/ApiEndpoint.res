let switchToInteg = false
let isLocal = false
let sdkDomainUrl = `${GlobalVars.sdkUrl}${GlobalVars.repoPublicPath}`

let apiEndPoint: ref<option<string>> = ref(None)

let setApiEndPoint = str => {
  apiEndPoint := Some(str)
}

let getApiEndPoint = (~publishableKey="", ~isConfirmCall=false) => {
  let testMode = publishableKey->String.startsWith("pk_snd_")
  switch apiEndPoint.contents {
  | Some(str) => str
  | None =>
    let backendEndPoint = isConfirmCall ? GlobalVars.confirmEndPoint : GlobalVars.backendEndPoint
    GlobalVars.isProd && testMode ? "https://beta.hyperswitch.io/api" : backendEndPoint
  }
}

// Canonical Hyperswitch-hosted backend by env, independent of any self-hosted
// ENV_BACKEND_URL. Mirrors the sdkUrl / backendEndPoint host family that the vault iframe
// is served from and calls (prod → checkout, sandbox / local → beta, integ → dev).
let hyperswitchVaultEndPoint = if GlobalVars.isProd {
  "https://checkout.hyperswitch.io/api"
} else if GlobalVars.isSandbox {
  "https://beta.hyperswitch.io/api"
} else {
  "https://dev.hyperswitch.io/api"
}

// Endpoint for vault operations: card tokenisation inside the nested iframe and the
// payment-method-session update / confirm calls (e.g.
// `${endpoint}/v1/payment-method-sessions/{id}/update-saved-payment-method`). A PCI
// merchant keeps the build endpoint (which may be a self-hosted ENV_BACKEND_URL); a
// non-PCI merchant routes to Hyperswitch's hosted backend so raw card data never reaches
// a self-hosted backend.
let getVaultEndPoint = (~publishableKey="") =>
  GlobalVars.isPciCompliant || GlobalVars.isLocal
    ? getApiEndPoint(~publishableKey)
    : hyperswitchVaultEndPoint

// Hyperswitch-hosted SDK origin by env (mirrors webpack getSdkUrl: prod → checkout,
// sandbox / local → beta, integ → dev).
let hyperswitchVaultSdkUrl = if GlobalVars.isProd {
  "https://checkout.hyperswitch.io"
} else if GlobalVars.isSandbox {
  "https://beta.hyperswitch.io"
} else {
  "https://dev.hyperswitch.io"
}

// Origin the inner vault iframe is served from. PCI merchants serve it from the build's
// own sdkDomainUrl; non-PCI merchants serve it from Hyperswitch so the card-collection
// iframe never loads from a self-hosted origin. repoPublicPath is preserved so the
// versioned asset path matches the deployed SDK.
let vaultSdkDomainUrl =
  GlobalVars.isPciCompliant || GlobalVars.isLocal
    ? sdkDomainUrl
    : `${hyperswitchVaultSdkUrl}${GlobalVars.repoPublicPath}`

let addCustomPodHeader = (arr: array<(string, string)>, ~customPodUri=?) => {
  switch customPodUri {
  | Some("")
  | None => ()
  | Some(customPodVal) => arr->Array.push(("x-feature", customPodVal))
  }
  arr->Dict.fromArray
}
