let switchToInteg = false
let isLocal = false
let sdkDomainUrl = `${GlobalVars.sdkUrl}${GlobalVars.repoPublicPath}`

// ─── Endpoint refs ────────────────────────────────────────────────────────────
//
// Priority hierarchy (highest → lowest) for each call type:
//
//  Backend (non-confirm) API calls  — getApiEndPoint(~isConfirmCall=false)
//    1. customConfig.overrideCustomBackendEndpoint  (backendOverrideEndPoint)
//    2. customConfig.customEndpoint                 (apiEndPoint)
//    3. customBackendUrl  [legacy]                  (apiEndPoint)
//    4. Build-time ENV_BACKEND_URL                  (GlobalVars.backendEndPoint)
//    5. Test-mode fallback: https://beta.hyperswitch.io/api  (pk_snd_* on prod)
//
//  Confirm API calls  — getApiEndPoint(~isConfirmCall=true)
//    1. customConfig.overrideCustomConfirmEndpoint  (confirmOverrideEndPoint)
//    2. customConfig.customEndpoint                 (apiEndPoint)
//    3. customBackendUrl  [legacy]                  (apiEndPoint)
//    4. Build-time ENV_CONFIRM_URL                  (GlobalVars.confirmEndPoint)
//    5. Test-mode fallback: https://beta.hyperswitch.io/api  (pk_snd_* on prod)
//
//  SDK-config fetch  — getSdkConfigEndPoint()
//    1. customConfig.overrideCustomSDKConfigEndpoint  (sdkConfigEndPoint)
//    2. customConfig.customEndpoint                   (apiEndPoint)
//    3. customBackendUrl  [legacy]                    (apiEndPoint)
//    4. Build-time ENV_BACKEND_URL                    (GlobalVars.backendEndPoint)
//    5. Test-mode fallback: https://beta.hyperswitch.io/api  (pk_snd_* on prod)
//
//  Assets / S3 calls  — getAssetsEndPoint()
//    1. customConfig.overrideCustomAssetsEndpoint  (assetsEndPoint)
//    2. customConfig.customEndpoint                (apiEndPoint)
//    3. customBackendUrl  [legacy]                 (apiEndPoint)
//    4. Build-time SDK URL                         (GlobalVars.sdkUrl; empty on local)
//
//  Logging / beacon calls  — getLoggingEndPoint()
//    1. customConfig.overrideCustomLoggingEndpoint  (loggingOverrideEndPoint)
//    2. Build-time log endpoint                     (GlobalVars.logEndpoint)
//
//  Airborne calls  — (consumed directly by the airborne module)
//    1. customConfig.overrideCustomAirborneEndpoint  (airborneEndPoint)
//    2. Module-internal default
//
// Note: customConfig.customEndpoint always wins over the legacy customBackendUrl
// because customConfig is parsed and applied after customBackendUrl in Hyper.res
// init (both write to the same apiEndPoint ref — last write wins).
// ─────────────────────────────────────────────────────────────────────────────

// General backend endpoint override (set by customBackendUrl or customConfig.customEndpoint)
let apiEndPoint: ref<option<string>> = ref(None)

// Per-endpoint specific overrides (set by customConfig.override* fields)
let backendOverrideEndPoint: ref<option<string>> = ref(None)
let assetsEndPoint: ref<option<string>> = ref(None)
let sdkConfigEndPoint: ref<option<string>> = ref(None)
let confirmOverrideEndPoint: ref<option<string>> = ref(None)
let airborneEndPoint: ref<option<string>> = ref(None)
let loggingOverrideEndPoint: ref<option<string>> = ref(None)
let platformPublishableKey: ref<option<string>> = ref(None)

let setApiEndPoint = str => {
  apiEndPoint := Some(str)
}

let setBackendOverrideEndPoint = str => {
  backendOverrideEndPoint := Some(str)
}

let setAssetsEndPoint = str => {
  assetsEndPoint := Some(str)
}

let setSdkConfigEndPoint = str => {
  sdkConfigEndPoint := Some(str)
}

let setConfirmOverrideEndPoint = str => {
  confirmOverrideEndPoint := Some(str)
}

let setAirborneEndPoint = str => {
  airborneEndPoint := Some(str)
}

let setLoggingOverrideEndPoint = str => {
  loggingOverrideEndPoint := Some(str)
}

let setPlatformPublishableKey = key => {
  platformPublishableKey := Some(key)
}

let getPlatformPublishableKey = () => platformPublishableKey.contents

let getLoggingEndPoint = () =>
  switch loggingOverrideEndPoint.contents {
  | Some(str) => str
  | None => GlobalVars.logEndpoint
  }

let getAssetsEndPoint = () =>
  switch (assetsEndPoint.contents, apiEndPoint.contents) {
  | (Some(str), _) => str
  | (None, Some(str)) => str
  | (None, None) => GlobalVars.isLocal ? "" : GlobalVars.sdkUrl
  }

let getSdkConfigEndPoint = (~publishableKey="") => {
  let testMode = publishableKey->String.startsWith("pk_snd_")
  switch (sdkConfigEndPoint.contents, apiEndPoint.contents) {
  | (Some(str), _) => str
  | (None, Some(str)) => str
  | (None, None) =>
    GlobalVars.isProd && testMode ? "https://beta.hyperswitch.io/api" : GlobalVars.backendEndPoint
  }
}

let getApiEndPoint = (~publishableKey="", ~isConfirmCall=false) => {
  let testMode = publishableKey->String.startsWith("pk_snd_")
  let specificOverride = if isConfirmCall {
    confirmOverrideEndPoint.contents
  } else {
    backendOverrideEndPoint.contents
  }
  switch (specificOverride, apiEndPoint.contents) {
  | (Some(str), _) => str
  | (None, Some(str)) => str
  | (None, None) =>
    let backendEndPoint = isConfirmCall ? GlobalVars.confirmEndPoint : GlobalVars.backendEndPoint
    GlobalVars.isProd && testMode ? "https://beta.hyperswitch.io/api" : backendEndPoint
  }
}

// Canonical Hyperswitch-hosted backend by env, independent of any self-hosted
// ENV_BACKEND_URL. Mirrors the sdkUrl / backendEndPoint host family that the vault iframe
// is served from and calls (prod → checkout, sandbox / local → beta, integ → dev).
let hyperswitchVaultEndPoint = (~publishableKey="") => {
  let testMode = publishableKey->String.startsWith("pk_snd_")

  if GlobalVars.isProd && !testMode {
    "https://checkout.hyperswitch.io/api"
  } else if GlobalVars.isInteg {
    "https://dev.hyperswitch.io/api"
  } else {
    "https://beta.hyperswitch.io/api"
  }
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
    : hyperswitchVaultEndPoint(~publishableKey)

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
