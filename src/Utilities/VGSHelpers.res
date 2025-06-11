open Utils

let handleVGSField = (field: option<VGSTypes.field>, setFocus, setError) => {
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

let getTokenizedData = data => {
  let dict = data->getDictFromJson
  let cardNumber = dict->getString("card_number", "")
  let cardExp = dict->getString("card_exp", "")
  let cardCvc = dict->getString("card_cvc", "")
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

let submitUserError = message => {
  postFailedSubmitResponse(~errortype="validation_error", ~message)
}

let vgsErrorHandler = (
  dict,
  fieldname,
  ~isSubmit=false,
  localeString: LocaleStringTypes.localeStrings,
) => {
  let emptyErr = getErrorStr(fieldname, ~empty=true, localeString)
  let invalidErr = getErrorStr(fieldname, localeString)
  let dataDict = dict->Dict.get(fieldname)->Option.flatMap(JSON.Decode.object)

  let getBoolFromDictOpt = (optDict, key, ~fallback=true) => {
    optDict->Option.getOr(Dict.make())->getBool(key, fallback)
  }

  let isFocused = dataDict->getBoolFromDictOpt("isFocused")
  let isEmpty = dataDict->getBoolFromDictOpt("isEmpty")
  let isValid = dataDict->getBoolFromDictOpt("isValid")

  switch (isFocused, isEmpty, isValid, isSubmit) {
  | (false, true, _, true) => {
      submitUserError(localeString.enterFieldsText)
      emptyErr
    }
  | (false, false, false, _) => {
      submitUserError(localeString.enterValidDetailsText)
      invalidErr
    }
  | _ => ""
  }
}
