let useVGSEvents = (
  cardField: option<VGSTypes.field>,
  expiryField: option<VGSTypes.field>,
  cvcField: option<VGSTypes.field>,
  setIsCardFocused,
  setIsExpiryFocused,
  setIsCVCFocused,
  setVgsCardError,
  setVgsExpiryError,
  setVgsCVCError,
) => {
  switch cardField {
  | Some(field) =>
    field.on("focus", _ => {
      setIsCardFocused(_ => Some(true))
      setVgsCardError(_ => "")
    })
    field.on("blur", _ => {
      setIsCardFocused(_ => Some(false))
    })
  | None => ()
  }
  switch expiryField {
  | Some(field) =>
    field.on("focus", _ => {
      setIsExpiryFocused(_ => Some(true))
      setVgsExpiryError(_ => "")
    })
    field.on("blur", _ => {
      setIsExpiryFocused(_ => Some(false))
    })
  | None => ()
  }
  switch cvcField {
  | Some(field) =>
    field.on("focus", _ => {
      setIsCVCFocused(_ => Some(true))
      setVgsCVCError(_ => "")
    })
    field.on("blur", _ => {
      setIsCVCFocused(_ => Some(false))
    })
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
