open Utils

// Wire a mounted VGS field's focus/blur events to local React state so the
// container can render the focus ring and clear errors on focus — mirroring the
// behaviour of a native Hyperswitch input field.
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

// Extract the tokenised (aliased) card fields from the VGS submit response.
// card_exp comes back as "MM / YY" and is split into separate month/year.
let getTokenizedData = data => {
  let dict = data->getDictFromJson
  let cardNumber = dict->getString("card_number", "")
  let cardExp = dict->getString("card_exp", "")
  let cardCvc = dict->getString("card_cvc", "")
  let (month, year) = CardUtils.getExpiryDates(cardExp)
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

// True when VGS reports the field empty — or hasn't reported it yet (a field
// never touched before the first submit), which we treat as empty.  Used to pick
// the merchant-facing reject message on submit.
let isFieldEmpty = (dict, fieldname) =>
  dict
  ->Dict.get(fieldname)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.getOr(Dict.make())
  ->getBool("isEmpty", true)

// Derives the inline error string for a single VGS field from the form state.
// Pure: it only computes the error text — surfacing it and rejecting the
// merchant's confirm promise is the caller's job (see VGSVault).
//
// `isSubmit=true` (submit path) surfaces "required field" errors for empty
// fields and, crucially, treats a *missing* field entry (state VGS hasn't
// emitted yet — e.g. a field never touched before the first submit) as empty so
// the required error still shows.  On the live path (isSubmit=false) empty and
// not-yet-seen fields stay silent.
let vgsErrorHandler = (
  dict,
  fieldname,
  ~isSubmit=false,
  localeString: LocaleStringTypes.localeStrings,
) => {
  let emptyErr = getErrorStr(fieldname, ~empty=true, localeString)
  let invalidErr = getErrorStr(fieldname, localeString)
  let dataDict = dict->Dict.get(fieldname)->Option.flatMap(JSON.Decode.object)

  let getBoolFromDictOpt = (optDict, key, ~fallback) => {
    optDict->Option.getOr(Dict.make())->getBool(key, fallback)
  }

  // Fallbacks describe a field VGS hasn't reported yet: on submit that means an
  // untouched, empty field (show the error); on the live path it means "no state
  // yet" (stay silent).
  let isFocused = dataDict->getBoolFromDictOpt("isFocused", ~fallback=false)
  let isEmpty = dataDict->getBoolFromDictOpt("isEmpty", ~fallback=isSubmit)
  let isValid = dataDict->getBoolFromDictOpt("isValid", ~fallback=!isSubmit)

  switch (isFocused, isEmpty, isValid) {
  | (false, true, _) if isSubmit => emptyErr
  | (false, false, false) => invalidErr
  | _ => ""
  }
}
