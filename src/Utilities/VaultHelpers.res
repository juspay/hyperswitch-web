open Utils

type vault = VeryGoodSecurity | Hyperswitch | None

type hyperVaultType = {vaultId: string, vaultEnv: string}

type vgsVaultType = {
  pmSessionId: string,
  pmClientSecret: string,
  vaultPublishableKey: string,
  vaultProfileId: string,
}

let getVaultModeFromName = val => {
  switch val {
  | "vgs" => VeryGoodSecurity
  | "hyperswitch_vault" => Hyperswitch
  | _ => None
  }
}

let getVaultNameFromMode = val => {
  switch val {
  | VeryGoodSecurity => "vgs"
  | Hyperswitch => "hyperswitch_vault"
  | _ => ""
  }
}

let getVaultName = (sessionObj: PaymentType.loadType) => {
  switch sessionObj {
  | Loaded(session) =>
    let dict = session->getDictFromJson
    let vaultDetailsDict = dict->getDictFromDict("vault_details")
    let keys = vaultDetailsDict->Dict.keysToArray
    keys->Array.get(0)->Option.getOr("")
  | _ => ""
  }
}

let getVGSVaultDetails = (sessionObj: PaymentType.loadType, vaultName: string) => {
  switch sessionObj {
  | Loaded(session) =>
    let dict = session->getDictFromJson
    let vgsVaultDict =
      dict
      ->getDictFromDict("vault_details")
      ->getDictFromDict(vaultName)

    let vaultId = vgsVaultDict->getString("external_vault_id", "")
    let vaultEnv = vgsVaultDict->getString("sdk_env", "")
    {vaultId, vaultEnv}
  | _ => {vaultId: "", vaultEnv: ""}
  }
}

let getHyperswitchVaultDetails = (sessionObj: PaymentType.loadType) => {
  switch sessionObj {
  | Loaded(session) =>
    let dict = session->getDictFromJson
    let hyperswitchVaultDict =
      dict
      ->getDictFromDict("vault_details")
      ->getDictFromDict("hyperswitch_vault")

    let pmSessionId = hyperswitchVaultDict->getString("payment_method_session_id", "")
    let pmClientSecret = hyperswitchVaultDict->getString("client_secret", "")
    let vaultPublishableKey = hyperswitchVaultDict->getString("publishable_key", "")
    let vaultProfileId = hyperswitchVaultDict->getString("profile_id", "")

    {pmSessionId, pmClientSecret, vaultPublishableKey, vaultProfileId}
  | _ => {pmSessionId: "", pmClientSecret: "", vaultPublishableKey: "", vaultProfileId: ""}
  }
}
