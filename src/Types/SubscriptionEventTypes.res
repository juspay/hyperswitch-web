open ErrorUtils
open PaymentEventTypes

let validSubscriptionEvents = ["surchargeInfo"]

let stringToEvent = (str, key) =>
  switch str {
  | "surchargeInfo" => Surcharge
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
      | None => {
          item->JSON.stringify->unknownPropValueWarning(validSubscriptionEvents, context)
          UnknownEvent
        }
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

let createCvcStatusPayload = (~iframeId, ~isCvcEmpty, ~isCvcComplete) => {
  let event = PaymentEventData.buildCvcStatusEvent(~isCvcEmpty, ~isCvcComplete)
  let payload = PaymentEventData.cvcStatusEventToJson(event)
  [
    ("elementType", "cardCvc"->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
    ("eventName", CvcStatus->PaymentEventTypes.eventToString->JSON.Encode.string),
    ("payload", payload),
  ]
}

let createSurchargePayload = (
  ~surchargeDetails: option<EligibilityHelpers.eligibilitySurchargeDetails>,
) => {
  let event = switch surchargeDetails {
  | Some(details) =>
    PaymentEventData.buildSurchargeEvent(
      ~surcharge={
        \"type": details.surcharge.\"type",
        value: details.surcharge.value,
      },
      ~taxOnSurcharge=details.taxOnSurcharge,
      ~displaySurchargeAmount=details.displaySurchargeAmount,
      ~displayTaxOnSurchargeAmount=details.displayTaxOnSurchargeAmount,
      ~displayTotalSurchargeAmount=details.displayTotalSurchargeAmount,
    )
  | None => PaymentEventData.buildSurchargeEvent(~surcharge={\"type": "", value: 0.0})
  }
  let payload = PaymentEventData.surchargeEventToJson(event)
  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", "surchargeInfo"->JSON.Encode.string),
    ("payload", payload),
  ]
}
