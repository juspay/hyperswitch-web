open ErrorUtils
open PaymentEventTypes

// `PaymentEventTypes.events` is the vocabulary shared with the other SDKs via the
// `hyperswitch-sdk-utils` submodule, so web-only events are added to this wrapper instead.
type subscriptionEvent =
  | Shared(PaymentEventTypes.events)
  | CardFieldStatus

let shouldEmitEvent = (
  ~eventType: subscriptionEvent,
  ~subscribedEvents: array<subscriptionEvent>,
): bool => subscribedEvents->Array.some(subscribed => subscribed == eventType)

let cardFieldStatusEventName = "cardFieldStatusInfo"

let validSubscriptionEvents = ["surchargeInfo", "appliedOffersInfo", cardFieldStatusEventName]

let stringToEvent = (str, key) =>
  switch str {
  | "surchargeInfo" => Shared(Surcharge)
  | "appliedOffersInfo" => Shared(Offers)
  | _ if str === cardFieldStatusEventName => CardFieldStatus
  | _ => {
      str->unknownPropValueWarning(validSubscriptionEvents, key)
      Shared(UnknownEvent)
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
          Shared(UnknownEvent)
        }
      }
    )
    ->Array.filter(opt => opt != Shared(UnknownEvent))

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

let createAppliedOffersPayload = (
  ~offerDetails: option<EligibilityHelpers.eligibilityOfferDetails>,
) => {
  let event = switch offerDetails {
  | Some(details) =>
    // Only a single auto-applied offer is expected in `eligible_offers`; emit
    // just that applied offer to the merchant (as a one-element array) rather
    // than the full eligible-offers/uplifted-quote-ids lists.
    let appliedOffers =
      details.eligibleOffers
      ->Array.get(0)
      ->Option.map(offer => [
        (
          {
            offerQuoteId: offer.offerQuoteId,
            offerAmount: offer.offerAmount,
            currency: offer.currency,
            code: offer.code,
            title: offer.title,
            description: offer.description,
          }: PaymentEventData.eligibleOffer
        ),
      ])
      ->Option.getOr([])
    PaymentEventData.buildOffersEvent(~offers=appliedOffers)
  | None => PaymentEventData.buildOffersEvent()
  }
  let payload = PaymentEventData.offersEventToJson(event)

  [
    ("elementType", "payment"->JSON.Encode.string),
    ("eventName", "appliedOffersInfo"->JSON.Encode.string),
    ("payload", payload),
  ]
}

let cardFieldStatusEventToJson = (
  ~status: CardFormShared.fieldFormStatus,
  ~message: option<string>,
  ~cardBrand: string,
): JSON.t => {
  let baseFields = [
    ("status", status->CardFormShared.fieldFormStatusToString->JSON.Encode.string),
  ]
  let withBrand = if cardBrand === "" {
    baseFields
  } else {
    baseFields->Array.concat([("cardBrand", cardBrand->JSON.Encode.string)])
  }
  let withMessage = switch message {
  | Some(errorMessage) if errorMessage !== "" =>
    withBrand->Array.concat([("message", errorMessage->JSON.Encode.string)])
  | _ => withBrand
  }
  withMessage->Dict.fromArray->JSON.Encode.object
}

let createCardFieldStatusPayload = (
  ~elementType: string,
  ~iframeId: string,
  ~status: CardFormShared.fieldFormStatus,
  ~message: option<string>,
  ~cardBrand: string,
) => [
  ("elementType", elementType->JSON.Encode.string),
  ("iframeId", iframeId->JSON.Encode.string),
  ("eventName", cardFieldStatusEventName->JSON.Encode.string),
  ("payload", cardFieldStatusEventToJson(~status, ~message, ~cardBrand)),
]
