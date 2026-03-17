open ErrorUtils
open PaymentEventTypes

let validSubscriptionEvents = [
  "PAYMENT_METHOD_INFO_CARD",
  "PAYMENT_METHOD_STATUS",
  "FORM_STATUS",
  "PAYMENT_METHOD_INFO_BILLING_ADDRESS",
]

let stringToEvent = (str, key) =>
  switch str {
  | "PAYMENT_METHOD_INFO_CARD" => PaymentMethodInfoCard
  | "PAYMENT_METHOD_STATUS" => PaymentMethodStatus
  | "FORM_STATUS" => FormStatus
  | "PAYMENT_METHOD_INFO_BILLING_ADDRESS" => PaymentMethodInfoBillingAddress
  | _ => {
      str->unknownPropValueWarning(validSubscriptionEvents, key)
      UnknownEvent
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
      | None => UnknownEvent
      }
    )
    ->Array.filter(opt => opt != UnknownEvent)

  if mappedSubscriptionEvents->Array.length === 0 {
    None
  } else {
    Some(mappedSubscriptionEvents)
  }
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
let createCardInfoPayload = (cardInfo: PaymentEventData.cardInfo) => {
  let payload = PaymentEventData.cardInfoToJson(cardInfo)
  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", PaymentMethodInfoCard->PaymentEventTypes.eventToString->JSON.Encode.string),
    ("payload", payload),
  ]
}

let createFormStatusPayload = (~status) => {
  let payload = PaymentEventData.formStatusEventToJson(~status)
  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", FormStatus->eventToString->JSON.Encode.string),
    ("payload", payload),
  ]
}

let createPaymentMethodStatusPayload = (
  ~paymentMethod,
  ~paymentMethodType,
  ~isSavedPaymentMethod,
  ~isOneClickWallet=false,
) => {
  let payload = PaymentEventData.paymentMethodStatusEventToJson(
    ~paymentMethod,
    ~paymentMethodType,
    ~isSavedPaymentMethod,
    ~isOneClickWallet,
  )

  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", PaymentMethodStatus->eventToString->JSON.Encode.string),
    ("payload", payload),
  ]
}

let createBillingAddressPayload = (~country, ~state, ~postalCode) => {
  let payload = PaymentEventData.paymentMethodInfoAddressToJson(~country, ~state, ~postalCode)

  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", PaymentMethodInfoBillingAddress->eventToString->JSON.Encode.string),
    ("payload", payload),
  ]
}
