open ErrorUtils

type events =
  | FORM_STATUS
  | PAYMENT_METHOD_STATUS
  | CARD_INFO
  | PAYMENT_METHOD_INFO_BILLING_ADDRESS
  | UNKNOWN_EVENT

let validSubscriptionEvents = [
  "FORM_STATUS",
  "PAYMENT_METHOD_STATUS",
  "CARD_INFO",
  "PAYMENT_METHOD_INFO_BILLING_ADDRESS",
]

let eventToString = event => {
  switch event {
  | FORM_STATUS => "FORM_STATUS"
  | PAYMENT_METHOD_STATUS => "PAYMENT_METHOD_STATUS"
  | CARD_INFO => "CARD_INFO"
  | PAYMENT_METHOD_INFO_BILLING_ADDRESS => "PAYMENT_METHOD_INFO_BILLING_ADDRESS"
  | UNKNOWN_EVENT => "UNKNOWN_EVENT"
  }
}

let stringToEvent = (str, key) =>
  switch str {
  | "FORM_STATUS" => FORM_STATUS
  | "PAYMENT_METHOD_STATUS" => PAYMENT_METHOD_STATUS
  | "CARD_INFO" => CARD_INFO
  | "PAYMENT_METHOD_INFO_BILLING_ADDRESS" => PAYMENT_METHOD_INFO_BILLING_ADDRESS
  | _ => {
      str->unknownPropValueWarning(validSubscriptionEvents, key)
      UNKNOWN_EVENT
    }
  }

let getSubscriptionEvents = (dict, key) => {
  let context = `options.${key}`
  let subscriptionList =
    dict
    ->Dict.get(key)
    ->Option.flatMap(JSON.Decode.array)
    ->Option.getOr([])

  let mappedSubscriptionEvents =
    subscriptionList
    ->Array.map(item =>
      switch JSON.Decode.string(item) {
      | Some(str) => stringToEvent(str, context)
      | None => UNKNOWN_EVENT
      }
    )
    ->Array.filter(opt => opt != UNKNOWN_EVENT)

  if mappedSubscriptionEvents->Array.length === 0 {
    None
  } else {
    Some(mappedSubscriptionEvents)
  }
}

let shouldEmitEvent = (subscriptionEvents: option<array<events>>, event: events) => {
  switch subscriptionEvents {
  | None => true // No subscription list provided, emit all events (backward compatible)
  | Some(events) => events->Array.includes(event) // Only emit if event is in the subscription list
  }
}

type formStatusValue =
  | Empty
  | Filling
  | Complete

let formStatusValueToString = (status: formStatusValue): string => {
  switch status {
  | Empty => "EMPTY"
  | Filling => "FILLING"
  | Complete => "COMPLETE"
  }
}

type formStatus = {status: string} // "EMPTY" | "FILLING" | "COMPLETE"

type cardInfo = {
  bin: string,
  last4: string,
  brand: string,
  expiryMonth: string,
  expiryYear: string,
  formattedExpiry: string,
  isCardNumberComplete: bool,
  isCvcComplete: bool,
  isExpiryComplete: bool,
  isCardNumberValid: bool,
  isExpiryValid: bool,
  isCvcValid: bool,
  isSavedCard: bool,
}

type paymentMethodStatus = {
  paymentMethod: string,
  paymentMethodType: string,
  isSavedPaymentMethod: bool,
  isOneClickWallet: bool,
}

type billingAddress = {
  country: string,
  state: string,
  postalCode: string,
}

let createFormStatusPayload = (~status) => {
  let payloadDict = Dict.make()
  payloadDict->Dict.set("status", status->JSON.Encode.string)

  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", "FORM_STATUS"->JSON.Encode.string),
    ("payload", payloadDict->JSON.Encode.object),
  ]
}

let createCardInfoPayload = (
  ~bin,
  ~last4,
  ~brand,
  ~expiryMonth,
  ~expiryYear,
  ~formattedExpiry,
  ~isCardNumberComplete,
  ~isCvcComplete,
  ~isExpiryComplete,
  ~isCardNumberValid,
  ~isExpiryValid,
  ~isCvcValid,
  ~isSavedCard,
) => {
  let payloadDict = Dict.make()
  payloadDict->Dict.set("bin", bin->JSON.Encode.string)
  payloadDict->Dict.set("last4", last4->JSON.Encode.string)
  payloadDict->Dict.set("brand", brand->JSON.Encode.string)
  payloadDict->Dict.set("expiryMonth", expiryMonth->JSON.Encode.string)
  payloadDict->Dict.set("expiryYear", expiryYear->JSON.Encode.string)
  payloadDict->Dict.set("formattedExpiry", formattedExpiry->JSON.Encode.string)
  payloadDict->Dict.set("isCardNumberComplete", isCardNumberComplete->JSON.Encode.bool)
  payloadDict->Dict.set("isCvcComplete", isCvcComplete->JSON.Encode.bool)
  payloadDict->Dict.set("isExpiryComplete", isExpiryComplete->JSON.Encode.bool)
  payloadDict->Dict.set("isCardNumberValid", isCardNumberValid->JSON.Encode.bool)
  payloadDict->Dict.set("isExpiryValid", isExpiryValid->JSON.Encode.bool)
  payloadDict->Dict.set("isCvcValid", isCvcValid->JSON.Encode.bool)
  payloadDict->Dict.set("isSavedCard", isSavedCard->JSON.Encode.bool)

  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", "CARD_INFO"->JSON.Encode.string),
    ("payload", payloadDict->JSON.Encode.object),
  ]
}

let createPaymentMethodStatusPayload = (
  ~paymentMethod,
  ~paymentMethodType,
  ~isSavedPaymentMethod,
  ~isOneClickWallet=false,
) => {
  let payloadDict = Dict.make()
  payloadDict->Dict.set("paymentMethod", paymentMethod->JSON.Encode.string)
  payloadDict->Dict.set("paymentMethodType", paymentMethodType->JSON.Encode.string)
  payloadDict->Dict.set("isSavedPaymentMethod", isSavedPaymentMethod->JSON.Encode.bool)
  payloadDict->Dict.set("isOneClickWallet", isOneClickWallet->JSON.Encode.bool)

  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", "PAYMENT_METHOD_STATUS"->JSON.Encode.string),
    ("payload", payloadDict->JSON.Encode.object),
  ]
}

let createBillingAddressPayload = (~country, ~state, ~postalCode) => {
  let payloadDict = Dict.make()
  payloadDict->Dict.set("country", country->JSON.Encode.string)
  payloadDict->Dict.set("state", state->JSON.Encode.string)
  payloadDict->Dict.set("postalCode", postalCode->JSON.Encode.string)

  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", "PAYMENT_METHOD_INFO_BILLING_ADDRESS"->JSON.Encode.string),
    ("payload", payloadDict->JSON.Encode.object),
  ]
}
