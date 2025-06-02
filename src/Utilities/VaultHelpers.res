type vault = VGS | HS | NONE

let getVaultModeFromName = val => {
  switch val {
  | "vgs" => VGS
  | "hyperswitch_payment_method" => HS
  | _ => NONE
  }
}
let getVaultNameFromMode = val => {
  switch val {
  | VGS => "vgs"
  | HS => "hyperswitch_payment_method"
  | _ => ""
  }
}
let getVaultName = (sessionObj: PaymentType.loadType) => {
  switch sessionObj {
  | Loaded(ssn) =>
    ssn
    ->Utils.getDictFromJson
    ->Dict.get("vault_details")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.map(vaultDetailsDict => {
      let keys = vaultDetailsDict->Js.Dict.keys
      keys->Array.get(0)->Option.getOr("")
    })
    ->Option.getOr("")
  | _ => ""
  }
}

let getVGSVaultDetails = (sessionObj: PaymentType.loadType, vaultName: string) => {
  switch sessionObj {
  | Loaded(ssn) =>
    ssn
    ->Utils.getDictFromJson
    ->Dict.get("vault_details")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.flatMap(vaultDetailsDict => vaultDetailsDict->Dict.get(vaultName))
    ->Option.flatMap(JSON.Decode.object)
    ->Option.map(specificVaultDict => {
      let externalVaultId =
        specificVaultDict->Dict.get("external_vault_id")->Option.flatMap(JSON.Decode.string)
      let env = specificVaultDict->Dict.get("env")->Option.flatMap(JSON.Decode.string)
      (externalVaultId, env)
    })
    ->Option.getOr((None, None))
  | _ => (None, None)
  }
}

let getHyperswitchVaultDetails = (sessionObj: PaymentType.loadType) => {
  switch sessionObj {
  | Loaded(ssn) =>
    ssn
    ->Utils.getDictFromJson
    ->Dict.get("vault_details")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.flatMap(vaultDetailsDict => vaultDetailsDict->Dict.get("hyperswitch_payment_method"))
    ->Option.flatMap(JSON.Decode.object)
    ->Option.map(specificVaultDict => {
      let paymentMethodSessionId =
        specificVaultDict
        ->Dict.get("payment_method_session_id")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOr("")
      let clientSecret =
        specificVaultDict
        ->Dict.get("client_secret")
        ->Option.flatMap(JSON.Decode.string)
        ->Option.getOr("")
      (paymentMethodSessionId, clientSecret)
    })
    ->Option.getOr(("", ""))
  | _ => ("", "")
  }
}
