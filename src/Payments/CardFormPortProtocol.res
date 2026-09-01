// CardFormPortProtocol — the MessageChannel Card Relay wire format.
//
// TWO PLANES, ONE SNAPSHOT SOURCE:
//
//   * Window plane (`windowPayload`) — postMessage, stringified by the sender.
//     Carries validity state + masked cardInfo + cardBrand/focusReady only.
//     NEVER carries rawCardNumber / rawCardExpiry / rawCvc. This preserves
//     the merchant-facing change events byte-for-byte while taking SAD off
//     the merchant window.
//   * Port plane (`portPayload`) — MessageChannel per field per portEpoch,
//     end-pointed inside the hidden cardFormCoordinator iframe. Carries the
//     FULL snapshot, raw SAD included, wrapped in a versioned relay frame:
//     {"cardFormPortV": 1, "kind": "...", "payload": {...}}.
//
// The encoder is the ONLY place the two halves are produced from one field
// state — both sides of every emit come from one coherent React memo, so the
// coordinator can never observe a raw/validity skew.
open Utils

// Bumped whenever frame shape changes. Gate test asserts the integer and the
// key name so a silent drift can't desync producer/consumer pairs.
let protocolVersion = 1.0
let protocolVersionKey = "cardFormPortV"

// `kind` vocabulary for port frames. fieldStateUpdate is the only frame kind
// with SAD; confirm never rides the port plane — it is dispatched on the
// window plane as the content-free `cardFormCoordinatorCommand` and settles
// on the coordinator's masked `confirmResult` envelope.
let kindFieldStateUpdate = "fieldStateUpdate"
let kindDoFocus = "doFocus"
let kindDetectedCardBrand = "detectedCardBrand"

// The complete per-field snapshot as the collector bridge computes it today
// (CardCollectorBridge.useEmitCardState). Raw values are optional so the SAME
// record serves bundled collectors (None forever) and per-field collectors.
type fieldStateSnapshot = {
  cardBrand: string,
  fieldStatus: JSON.t,
  cardInfo: JSON.t,
  focusReady: bool,
  rawCardNumber: option<string>,
  rawCardExpiry: option<string>,
  rawCvc: option<string>,
}

// Both halves of one emit. `windowPayload` is an OBJECT ready to
// `JSON.stringify` into the legacy `[["cardStateUpdate", stateEntries]]` frame
// — i.e. it is the STATE ENTRIES object, not the outer envelope, so the
// existing bridge can slot it in byte-identically. `portPayload` is the FULL
// versioned relay frame ready for MessagePort.postMessage.
type dualPlanePayload = {
  windowPayload: JSON.t,
  portPayload: JSON.t,
}

let encodeFieldStateUpdate = (snapshot: fieldStateSnapshot): dualPlanePayload => {
  // Shared (window + port) entries: validation state, masked card info,
  // brand, focus-readiness. Byte-shape mirrors the legacy cardStateUpdate
  // envelope EXACTLY — merchant change-event consumers must not notice.
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

  // PORT extension: the shared half PLUS the raw SAD half — one coherent
  // tuple. Every raw key is ported via option — absent stays ABSENT (never
  // null-placeholder) so any defensive key-scan of either payload's shape
  // stays vacuously clean for bundled collectors.
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

// Generic versioned-frame builder for non-state port messages (confirm
// relay, focus commands, brand relay) so every port frame shares the
// {cardFormPortV, kind, payload} envelope.
let makePortFrame = (~kind: string, ~payload: JSON.t): JSON.t =>
  [
    (protocolVersionKey, protocolVersion->JSON.Encode.float),
    ("kind", kind->JSON.Encode.string),
    ("payload", payload),
  ]
  ->Dict.fromArray
  ->JSON.Encode.object

// Consumer-side frame helpers: tolerant decode of the envelope.
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
        // Warn (dev drift signal) but KEEP DECODING — frames derived from
        // forward-compatible fields stay consumable.
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
