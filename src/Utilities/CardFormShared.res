/* shared canon for the CardForm surfaces; aliased (not `open`ed) by the group factories so
   their compiled modules keep these as named exports. */

open Utils

/* `focused` and `blurred` are ONE-SHOT transitions that never change the underlying
   validity track (complete/incomplete/invalid); the group never latches them. */
type fieldFormStatus =
  | Complete
  | Incomplete
  | Invalid
  | Focused
  | Blurred

let fieldFormStatusToString = (status: fieldFormStatus): string =>
  switch status {
  | Complete => "complete"
  | Incomplete => "incomplete"
  | Invalid => "invalid"
  | Focused => "focused"
  | Blurred => "blurred"
  }

let fieldFormStatusFromString = (str: string): option<fieldFormStatus> =>
  switch str {
  | "complete" => Some(Complete)
  | "incomplete" => Some(Incomplete)
  | "invalid" => Some(Invalid)
  | "focused" => Some(Focused)
  | "blurred" => Some(Blurred)
  | _ => None
  }

/* merchant vocabulary is the BARE field name; unknown strings fall through to "" and take
   the invalid-field-type rejection path. */
let mapFieldTypeToInternalFieldName = (fieldType: string): string =>
  switch fieldType {
  | "cardNumber"
  | "cardExpiry"
  | "cardCvc" => fieldType
  | _ => ""
  }

/* cardNumber → cardExpiry → cardCvc (terminal). This map only ROUTES the focus request —
   the iframe owns the timing decision. */
let nextFieldFor = (fieldType: string): option<string> =>
  switch fieldType {
  | "cardNumber" => Some("cardExpiry")
  | "cardExpiry" => Some("cardCvc")
  | _ => None
  }

/* per-field iframes emit a verbose `cardStateUpdate`; the merchant-facing `change` payload
   is the slim `{empty, complete, valid, error?, brand?, elementType}` shape keyed on
   `brand` (camelCase). `brand` is omitted when "", and `valid` picks the per-field flag. */
let reshapeCardStateUpdateToChangePayload = (
  ~fieldType: string,
  ~stateJson: JSON.t,
): JSON.t => {
  let stateDict = stateJson->getDictFromJson
  let fieldStatus = stateDict->getDictFromDict("fieldStatus")
  let empty = fieldStatus->getBool("empty", true)
  let complete = fieldStatus->getBool("complete", false)
  let valid = switch fieldType {
  | "cardNumber" => fieldStatus->getBool("isCardValid", false)
  | "cardExpiry" => fieldStatus->getBool("isExpiryValid", false)
  | "cardCvc" => fieldStatus->getBool("isCvcValid", false)
  | _ => false
  }
  let brand = stateDict->getString("cardBrand", "")
  let errorMessage = stateDict->getString("error", "")
  let changePayload = Dict.make()
  changePayload->Dict.set("empty", empty->JSON.Encode.bool)
  changePayload->Dict.set("complete", complete->JSON.Encode.bool)
  changePayload->Dict.set("valid", valid->JSON.Encode.bool)
  changePayload->Dict.set("elementType", fieldType->JSON.Encode.string)
  if brand !== "" {
    changePayload->Dict.set("brand", brand->JSON.Encode.string)
  }
  if errorMessage !== "" {
    changePayload->Dict.set("error", errorMessage->JSON.Encode.string)
  }
  changePayload->JSON.Encode.object
}
