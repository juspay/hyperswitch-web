/* CardFormPortProtocol — the MessageChannel Card Relay wire format. Two planes, one
   snapshot source:
   window plane (`windowPayload`), stringified postMessage: validity state, masked cardInfo,
   cardBrand and focusReady ONLY — it must NEVER carry rawCardNumber, rawCardExpiry or rawCvc.
   port plane (`portPayload`), one MessageChannel per field per portEpoch, end-pointed inside
   the hidden coordinator iframe: the FULL snapshot, raw SAD included, in a versioned frame.
   Both halves are produced here from one memo, so the coordinator never sees a raw/validity skew. */

open Utils

/* Bumped whenever frame shape changes. Gate test asserts the integer and the
   key name so a silent drift can't desync producer/consumer pairs. */
let protocolVersion = 1.0
let protocolVersionKey = "cardFormPortV"

/* fieldStateUpdate is the only frame kind carrying SAD; confirm never rides the port plane
   — it is a content-free window command settling on the masked `confirmResult`. */
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

/* `windowPayload` is the STATE ENTRIES object, not the outer envelope, so the existing
   bridge slots it into the legacy `cardStateUpdate` frame byte-identically. */
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
  // focusReady emit-on-true, same as the legacy group contract.
  let sharedEntries = snapshot.focusReady
    ? sharedEntries->Array.concat([("focusReady", true->JSON.Encode.bool)])
    : sharedEntries

  let windowEntries = sharedEntries

  /* port extension: the shared half PLUS raw SAD. Every raw key is an option — absent stays
     ABSENT (never a null placeholder), so a key-scan of either payload stays clean. */
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
  version: float,
  kind: string,
  payload: JSON.t,
}

let decodePortFrame = (json: JSON.t): option<portFrame> => {
  let dict = json->getDictFromJson
  switch dict->Dict.get(protocolVersionKey) {
  | Some(versionJson) => {
      let version = versionJson->getFloatFromJson(0.0)
      if version != protocolVersion {
        /* Warn (dev drift signal) but KEEP DECODING — frames derived from
           forward-compatible fields stay consumable. */
        Console.warn(
          `[CardFormPortProtocol] decoding frame with version ${version->Float.toString}; expected ${protocolVersion->Float.toString}`,
        )
      }
      {
        version,
        kind: dict->getString("kind", ""),
        payload: dict->getJsonObjectFromDict("payload"),
      }->Some
    }
  | None => None
  }
}
