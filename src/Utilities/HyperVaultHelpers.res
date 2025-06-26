open Utils

type vaultMetadata = {
  config: JSON.t,
  pmSessionId: string,
  pmClientSecret: string,
  vaultPublishableKey: string,
  vaultProfileId: string,
  endpoint: string,
  customPodUri: string,
}

let extractVaultMetadata = metadataDict => {
  let getStr = key => metadataDict->getString(key, "")
  let config = metadataDict->Dict.get("config")->Option.getOr(Dict.make()->JSON.Encode.object)
  let pmSessionId = getStr("pmSessionId")
  let pmClientSecret = getStr("pmClientSecret")
  let vaultPublishableKey = getStr("vaultPublishableKey")
  let vaultProfileId = getStr("vaultProfileId")
  let endpoint = getStr("endpoint")
  let customPodUri = getStr("customPodUri")

  {config, pmSessionId, pmClientSecret, vaultPublishableKey, vaultProfileId, endpoint, customPodUri}
}
