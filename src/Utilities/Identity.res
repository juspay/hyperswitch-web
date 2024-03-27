external anyTypeToJson: 'a => JSON.t = "%identity"
external unsafeToJsExn: exn => Exn.t = "%identity"
external jsonToNullableJson: JSON.t => Nullable.t<JSON.t> = "%identity"
