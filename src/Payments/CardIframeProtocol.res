open Utils

type fieldStatus = {
  complete: bool,
  empty: bool,
  isCvcEmpty: bool,
  isCvcComplete: bool,
  isCardValid: bool,
  isExpiryValid: bool,
  isCvcValid: bool,
  hasCardValidationStatus: bool,
  hasExpiryValidationStatus: bool,
  hasCvcValidationStatus: bool,
}

type state = {
  cardBrand: string,
  rawCardNumber: string,
  cardFieldsComplete: bool,
  cardFieldsEmpty: bool,
  isCvcEmpty: bool,
  isCvcComplete: bool,
  hasCardFieldStatus: bool,
  isCardValid: bool,
  isExpiryValid: bool,
  isCvcValid: bool,
  hasCardValidationStatus: bool,
  hasExpiryValidationStatus: bool,
  hasCvcValidationStatus: bool,
  cardInfo: option<PaymentEventData.cardInfo>,
}

type savedCardCvcState = {
  ready: bool,
  empty: bool,
  complete: bool,
  valid: bool,
  error: string,
}

type cardSnapshot = {
  cardBrand: string,
  rawCardNumber: option<string>,
  fieldStatus: fieldStatus,
  cardInfo: PaymentEventData.cardInfo,
}

type decodedCardUpdate =
  | CardSnapshot(cardSnapshot)
  | FieldStatusUpdate(fieldStatus)

let initialState: state = {
  cardBrand: "",
  rawCardNumber: "",
  cardFieldsComplete: false,
  cardFieldsEmpty: true,
  isCvcEmpty: true,
  isCvcComplete: false,
  hasCardFieldStatus: false,
  isCardValid: false,
  isExpiryValid: false,
  isCvcValid: false,
  hasCardValidationStatus: false,
  hasExpiryValidationStatus: false,
  hasCvcValidationStatus: false,
  cardInfo: None,
}

let initialSavedCardCvcState: savedCardCvcState = {
  ready: false,
  empty: true,
  complete: false,
  valid: false,
  error: "",
}

let jsonOptionString = (dict, key) => {
  let value = dict->getString(key, "")
  value === "" ? None : Some(value)
}

let decodeCardInfo = (json: JSON.t): PaymentEventData.cardInfo => {
  let dict = json->getDictFromJson
  {
    bin: jsonOptionString(dict, "bin"),
    last4: jsonOptionString(dict, "last4"),
    brand: jsonOptionString(dict, "brand"),
    expiryMonth: jsonOptionString(dict, "expiryMonth"),
    expiryYear: jsonOptionString(dict, "expiryYear"),
    formattedExpiry: jsonOptionString(dict, "formattedExpiry"),
    isCardNumberComplete: dict->getBool("isCardNumberComplete", false),
    isCvcComplete: dict->getBool("isCvcComplete", false),
    isExpiryComplete: dict->getBool("isExpiryComplete", false),
    isCardNumberValid: dict->getBool("isCardNumberValid", false),
    isExpiryValid: dict->getBool("isExpiryValid", false),
  }
}

let decodeFieldStatus = (status: Dict.t<JSON.t>): fieldStatus => {
  complete: status->getBool("complete", false),
  empty: status->getBool("empty", true),
  isCvcEmpty: status->getBool("isCvcEmpty", true),
  isCvcComplete: status->getBool("isCvcComplete", false),
  isCardValid: status->getBool("isCardValid", false),
  isExpiryValid: status->getBool("isExpiryValid", false),
  isCvcValid: status->getBool("isCvcValid", false),
  hasCardValidationStatus: status->getBool("hasCardValidationStatus", false),
  hasExpiryValidationStatus: status->getBool("hasExpiryValidationStatus", false),
  hasCvcValidationStatus: status->getBool("hasCvcValidationStatus", false),
}

let decodeStateUpdate = (~dict, ~allowRawCardNumber, ~allowFullCardState): option<
  decodedCardUpdate,
> => {
  if allowFullCardState && dict->Dict.get("cardStateUpdate")->Option.isSome {
    let update = dict->getJsonObjectFromDict("cardStateUpdate")->getDictFromJson
    let status = update->getJsonObjectFromDict("fieldStatus")->getDictFromJson
    let rawCardNumber = if allowRawCardNumber && update->Dict.get("rawCardNumber")->Option.isSome {
      Some(update->getString("rawCardNumber", ""))
    } else {
      None
    }
    Some(
      CardSnapshot({
        cardBrand: update->getString("cardBrand", ""),
        rawCardNumber,
        fieldStatus: status->decodeFieldStatus,
        cardInfo: update->getJsonObjectFromDict("cardInfo")->decodeCardInfo,
      }),
    )
  } else if allowFullCardState && dict->Dict.get("cardFieldStatus")->Option.isSome {
    let status = dict->getJsonObjectFromDict("cardFieldStatus")->getDictFromJson
    Some(FieldStatusUpdate(status->decodeFieldStatus))
  } else {
    None
  }
}

let decodeSavedCardCvcState = (dict): option<savedCardCvcState> =>
  if dict->Dict.get("savedCardCvcStatus")->Option.isSome {
    let status = dict->getJsonObjectFromDict("savedCardCvcStatus")->getDictFromJson
    Some({
      ready: true,
      empty: status->getBool("empty", true),
      complete: status->getBool("complete", false),
      valid: status->getBool("valid", false),
      error: status->getString("error", ""),
    })
  } else {
    None
  }

let applyStateUpdate = (state: state, update: decodedCardUpdate): state => {
  switch update {
  | CardSnapshot(update) => {
      cardBrand: update.cardBrand,
      rawCardNumber: update.rawCardNumber->Option.getOr(state.rawCardNumber),
      cardFieldsComplete: update.fieldStatus.complete,
      cardFieldsEmpty: update.fieldStatus.empty,
      isCvcEmpty: update.fieldStatus.isCvcEmpty,
      isCvcComplete: update.fieldStatus.isCvcComplete,
      isCardValid: update.fieldStatus.isCardValid,
      isExpiryValid: update.fieldStatus.isExpiryValid,
      isCvcValid: update.fieldStatus.isCvcValid,
      hasCardValidationStatus: update.fieldStatus.hasCardValidationStatus,
      hasExpiryValidationStatus: update.fieldStatus.hasExpiryValidationStatus,
      hasCvcValidationStatus: update.fieldStatus.hasCvcValidationStatus,
      hasCardFieldStatus: true,
      cardInfo: Some(update.cardInfo),
    }
  | FieldStatusUpdate(status) => {
      ...state,
      cardFieldsComplete: status.complete,
      cardFieldsEmpty: status.empty,
      isCvcEmpty: status.isCvcEmpty,
      isCvcComplete: status.isCvcComplete,
      isCardValid: status.isCardValid,
      isExpiryValid: status.isExpiryValid,
      isCvcValid: status.isCvcValid,
      hasCardValidationStatus: status.hasCardValidationStatus,
      hasExpiryValidationStatus: status.hasExpiryValidationStatus,
      hasCvcValidationStatus: status.hasCvcValidationStatus,
      hasCardFieldStatus: true,
    }
  }
}
