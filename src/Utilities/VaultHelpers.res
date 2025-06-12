open Utils

type vault = VeryGoodSecurity | Hyperswitch | None

let getVaultModeFromName = val => {
  switch val {
  | "vgs" => VeryGoodSecurity
  | "hyperswitch_payment_method" => Hyperswitch
  | _ => None
  }
}

let getVaultNameFromMode = val => {
  switch val {
  | VeryGoodSecurity => "vgs"
  | Hyperswitch => "hyperswitch_payment_method"
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

    let externalVaultId = vgsVaultDict->getString("external_vault_id", "")
    let env = vgsVaultDict->getString("env", "")
    (externalVaultId, env)
  | _ => ("", "")
  }
}

let getHyperswitchVaultDetails = (sessionObj: PaymentType.loadType) => {
  switch sessionObj {
  | Loaded(session) =>
    let dict = session->getDictFromJson
    let hyperswitchVaultDict =
      dict
      ->getDictFromDict("vault_details")
      ->getDictFromDict("hyperswitch_payment_method")

    let paymentMethodSessionId = hyperswitchVaultDict->getString("payment_method_session_id", "")
    let clientSecret = hyperswitchVaultDict->getString("client_secret", "")
    let publishableKey = hyperswitchVaultDict->getString("publishable_key", "")
    let profileId = hyperswitchVaultDict->getString("profile_id", "")
    (paymentMethodSessionId, clientSecret, publishableKey, profileId)
  | _ => ("", "", "", "")
  }
}
