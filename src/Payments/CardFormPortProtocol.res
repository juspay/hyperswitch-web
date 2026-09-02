open Utils

let protocolVersion = 1.0
let protocolVersionKey = "cardFormPortV"

let kindFieldStateUpdate = "fieldStateUpdate"
let kindDoFocus = "doFocus"
let kindDetectedCardBrand = "detectedCardBrand"

type fieldStateSnapshot = {
  cardBrand: string,
  fieldStatus: JSON.t,
  cardInfo: JSON.t,
  focusReady: bool,
  rawCardNumber: option<string>,
  rawCardExpiry: option<string>,
  rawCvc: option<string>,
}

type dualPlanePayload = {
  windowPayload: JSON.t,
  portPayload: JSON.t,
}

let encodeFieldStateUpdate = (snapshot: fieldStateSnapshot): dualPlanePayload => {
  let sharedEntries = [
    ("cardBrand", snapshot.cardBrand->JSON.Encode.string),
    ("fieldStatus", snapshot.fieldStatus),
    ("cardInfo", snapshot.cardInfo),
  ]
  let sharedEntries = snapshot.focusReady
    ? sharedEntries->Array.concat([("focusReady", true->JSON.Encode.bool)])
    : sharedEntries

  let windowEntries = sharedEntries

  let portEntries =
    sharedEntries->Array.concat(
      [
        snapshot.rawCardNumber->Option.map(v => ("rawCardNumber", v->JSON.Encode.string)),
        snapshot.rawCardExpiry->Option.map(v => ("rawCardExpiry", v->JSON.Encode.string)),
        snapshot.rawCvc->Option.map(v => ("rawCvc", v->JSON.Encode.string)),
      ]->Array.filterMap(entry => entry),
    )

  let portPayload =
    [
      (protocolVersionKey, protocolVersion->JSON.Encode.float),
      ("kind", kindFieldStateUpdate->JSON.Encode.string),
      ("payload", portEntries->Dict.fromArray->JSON.Encode.object),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object

  {
    windowPayload: windowEntries->Dict.fromArray->JSON.Encode.object,
    portPayload,
  }
}

let makePortFrame = (~kind: string, ~payload: JSON.t): JSON.t =>
  [
    (protocolVersionKey, protocolVersion->JSON.Encode.float),
    ("kind", kind->JSON.Encode.string),
    ("payload", payload),
  ]
  ->Dict.fromArray
  ->JSON.Encode.object

type portFrame = {
  kind: string,
  payload: JSON.t,
}

let decodePortFrame = (json: JSON.t): option<portFrame> => {
  let dict = json->getDictFromJson
  switch dict->Dict.get(protocolVersionKey) {
  | Some(versionJson) => {
      let version = versionJson->getFloatFromJson(0.0)
      if version != protocolVersion {
        Console.warn(
          `[CardFormPortProtocol] decoding frame with version ${version->Float.toString}; expected ${protocolVersion->Float.toString}`,
        )
      }
      {
        kind: dict->getString("kind", ""),
        payload: dict->getJsonObjectFromDict("payload"),
      }->Some
    }
  | None => None
  }
}
