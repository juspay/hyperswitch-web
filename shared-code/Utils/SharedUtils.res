let nbsp = "\u00A0"

let getPaymentId = clientSecret =>
  String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")

let getHeader = (~apiKey, ~appId=?, ~redirectUri=?, ~merchantHostname=?, ~clientSource=?) => {
  [
    ("api-key", apiKey),
    ("Content-Type", "application/json"),
    ...switch appId {
    | Some(appId) => [
        ("x-app-id", Js.String.replace(".hyperswitch://", "", appId->Option.getOr(""))),
      ]
    | None => []
    },
    ...switch redirectUri {
    | Some(redirectUri) => [("x-redirect-uri", redirectUri->Option.getOr(""))]
    | None => []
    },
    // For web
    ...switch merchantHostname {
    | Some(merchantHostname) => [("X-Merchant-Domain", merchantHostname)]
    | None => []
    },
    ...switch clientSource {
      | Some(clientSource) =>[("X-Client-Source", clientSource)]
      | None => []
    }
  ]
}
