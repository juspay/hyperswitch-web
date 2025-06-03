let useVGSFocus = (field: option<VGSTypes.field>, setFocus, setError) => {
  switch field {
  | Some(val) =>
    val.on("focus", _ => {
      setFocus(_ => Some(true))
      setError(_ => "")
    })
    val.on("blur", _ => setFocus(_ => Some(false)))
  | None => ()
  }
}
let getBoolValueFromOptionalDict = (dict, key) => {
  dict
  ->Option.getOr(Dict.make())
  ->Dict.get(key)
  ->Option.flatMap(JSON.Decode.bool)
  ->Option.getOr(true)
}

let getTokenizedData = data => {
  let dict = data->Utils.getDictFromJson
  let cardNumber =
    dict->Dict.get("card_number")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
  let cardExp = dict->Dict.get("card_exp")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
  let cardCvc = dict->Dict.get("card_cvc")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
  let (month, year) = CardUtils.splitExpiryDates(cardExp)
  (cardNumber, month, year, cardCvc)
}

let getErrorStr = (fieldname, ~empty=false, localeString: LocaleStringTypes.localeStrings) => {
  switch (fieldname, empty) {
  | ("card_number", true) => localeString.cardNumberEmptyText
  | ("card_exp", true) => localeString.cardExpiryDateEmptyText
  | ("card_cvc", true) => localeString.cvcNumberEmptyText
  | ("card_number", false) => localeString.enterValidCardNumberErrorText
  | ("card_exp", false) => localeString.inValidExpiryErrorText
  | ("card_cvc", false) => localeString.inCompleteCVCErrorText
  | _ => ""
  }
}

let setUserError = message => {
  Utils.postFailedSubmitResponse(~errortype="validation_error", ~message)
}

let vgsErrorHandler = (
  dict,
  fieldname,
  ~isSubmit=false,
  setError,
  localeString: LocaleStringTypes.localeStrings,
) => {
  let emptyErr = getErrorStr(fieldname, ~empty=true, localeString)
  let invalidErr = getErrorStr(fieldname, localeString)
  let dataDict = dict->Dict.get(fieldname)->Option.flatMap(JSON.Decode.object)
  let isFocused = dataDict->getBoolValueFromOptionalDict("isFocused")
  let isEmpty = dataDict->getBoolValueFromOptionalDict("isEmpty")
  let isValid = dataDict->getBoolValueFromOptionalDict("isValid")
  switch (isFocused, isEmpty, isValid, isSubmit) {
  | (false, true, _, true) => {
      setError(_ => emptyErr)
      setUserError(localeString.enterFieldsText)
    }
  | (false, false, false, _) => {
      setError(_ => invalidErr)
      setUserError(localeString.enterValidDetailsText)
    }
  | _ => ()
  }
}
