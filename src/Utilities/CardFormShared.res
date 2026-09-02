open Utils

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

let mapFieldTypeToInternalFieldName = (fieldType: string): string =>
  switch fieldType {
  | "cardNumber"
  | "cardExpiry"
  | "cardCvc" => fieldType
  | _ => ""
  }

let nextFieldFor = (fieldType: string): option<string> =>
  switch fieldType {
  | "cardNumber" => Some("cardExpiry")
  | "cardExpiry" => Some("cardCvc")
  | _ => None
  }

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
