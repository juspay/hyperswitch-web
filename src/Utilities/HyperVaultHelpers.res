open Utils

let getDetails = metadataDict => {
  let config = metadataDict->Dict.get("config")
  let pmSessionId = metadataDict->getString("pmSessionId", "")
  let pmClientSecret = metadataDict->getString("pmClientSecret", "")
  let vaultPublishableKey = metadataDict->getString("vaultPublishableKey", "")
  let vaultProfileId = metadataDict->getString("vaultProfileId", "")
  let endpoint = metadataDict->getString("endpoint", "")
  let customPodUri = metadataDict->getString("customPodUri", "")

  (config, pmSessionId, pmClientSecret, vaultPublishableKey, vaultProfileId, endpoint, customPodUri)
}
