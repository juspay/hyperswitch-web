open Utils

type confirmPayload = {
  paymentMethodId: string,
  returnUrl: string,
  redirect: string,
  cvc: option<string>,
  cvcElementId: option<string>,
}

type confirmFlow =
  | TokenFlow
  | CardFlow(option<string>)
  | CvcWidgetFlow(string)
  | ApplePayFlow
  | GooglePayFlow

let getNonEmptyString = (dict, key) => dict->getOptionString(key)->getNonEmptyOption

let toNullableJson = value =>
  value->getNonEmptyOption->Option.mapOr(JSON.Encode.null, JSON.Encode.string)

let isExpiredCard = (savedMethod: PaymentType.customerMethods) =>
  switch (
    savedMethod.card.expiryMonth->Int.fromString,
    savedMethod.card.expiryYear->Int.fromString,
  ) {
  | (Some(month), Some(year)) if savedMethod.paymentMethod === "card" =>
    let year = year < 100 ? 2000 + year : year
    let currentDate = Date.make()
    let currentYear = currentDate->Date.getFullYear
    year < currentYear || (year === currentYear && month < currentDate->Date.getMonth + 1)
  | _ => false
  }

let getLastUsedToken = (savedMethods: array<PaymentType.customerMethods>) =>
  savedMethods
  ->Array.filter(savedMethod => savedMethod.lastUsedAt !== "")
  ->Array.toSorted((a, b) => compareLogic(a.lastUsedAt, b.lastUsedAt))
  ->Array.get(0)
  ->Option.map(savedMethod => savedMethod.paymentToken)

let savedMethodToJson = (savedMethod: PaymentType.customerMethods, ~lastUsedToken) => {
  let {card, bankRedirect, paymentMethod} = savedMethod
  let details = switch paymentMethod {
  | "card" =>
    [
      ("brand", card.scheme->toNullableJson),
      ("last4", Some(card.last4Digits)->toNullableJson),
      ("expiryMonth", Some(card.expiryMonth)->toNullableJson),
      ("expiryYear", Some(card.expiryYear)->toNullableJson),
    ]->getJsonFromArrayOfJson
  | "bank_redirect" =>
    [
      ("bankName", Some(bankRedirect.bankName)->toNullableJson),
      ("mask", Some(bankRedirect.mask)->toNullableJson),
    ]->getJsonFromArrayOfJson
  | _ => JSON.Encode.null
  }
  [
    ("id", savedMethod.paymentToken->JSON.Encode.string),
    ("paymentMethod", paymentMethod->JSON.Encode.string),
    ("paymentMethodType", savedMethod.paymentMethodType->toNullableJson),
    ("isDefault", savedMethod.defaultPaymentMethodSet->JSON.Encode.bool),
    ("isLastUsed", (lastUsedToken === Some(savedMethod.paymentToken))->JSON.Encode.bool),
    ("lastUsedAt", Some(savedMethod.lastUsedAt)->toNullableJson),
    ("requiresCvc", (paymentMethod === "card" && savedMethod.requiresCvv)->JSON.Encode.bool),
    ("isRecurringEnabled", savedMethod.recurringEnabled->JSON.Encode.bool),
    ("details", details),
  ]->getJsonFromArrayOfJson
}

let itemToConfirmPayloadMapper = payload => {
  let dict = payload->getDictFromJson
  let confirmParams = dict->ConfirmType.getConfirmParams("confirmParams")
  {
    paymentMethodId: dict->getString("paymentMethodId", ""),
    returnUrl: confirmParams.return_url,
    redirect: dict
    ->getNonEmptyString("redirect")
    ->Option.orElse(confirmParams.redirect)
    ->Option.getOr("if_required"),
    cvc: dict->getOptionString("cvc"),
    cvcElementId: dict->getNonEmptyString("cvcElementId"),
  }
}

let getIntentPayload = confirmPayload =>
  [
    (
      "confirmParams",
      [
        ("return_url", confirmPayload.returnUrl->JSON.Encode.string),
        ("redirect", confirmPayload.redirect->JSON.Encode.string),
      ]->getJsonFromArrayOfJson,
    ),
  ]->getJsonFromArrayOfJson

let isValidUrl = url =>
  try {
    URLModule.makeUrl(url)->ignore
    true
  } catch {
  | _ => false
  }

let isValidCvc = (cvc, savedMethod: PaymentType.customerMethods) =>
  switch savedMethod.card.scheme->getNonEmptyOption {
  | Some(brand) => CardUtils.checkCardCVC(cvc, brand->CardUtils.normalizeCardBrand)
  | None => %re("/^\d{3,4}$/")->RegExp.test(cvc)
  }

let getConfirmFlow = (
  savedMethod: PaymentType.customerMethods,
  confirmPayload,
  ~isApplePayReady,
  ~isGooglePayReady,
) =>
  switch savedMethod.paymentMethodType {
  | Some("apple_pay") if isApplePayReady => Ok(ApplePayFlow)
  | Some("google_pay") if isGooglePayReady => Ok(GooglePayFlow)
  | _ if savedMethod.paymentMethod !== "card" => Ok(TokenFlow)
  | _ if !savedMethod.requiresCvv => Ok(CardFlow(None))
  | _ =>
    switch (confirmPayload.cvc, confirmPayload.cvcElementId) {
    | (Some(cvc), _) if cvc->isValidCvc(savedMethod) => Ok(CardFlow(Some(cvc)))
    | (Some(_), _) => Error(("cvc_validation", "The provided CVC is invalid for this card."))
    | (None, Some(cvcElementId)) => Ok(CvcWidgetFlow(cvcElementId))
    | (None, None) =>
      Error((
        "cvc_required",
        "This card requires a CVC. Pass `cvc` or mount the CVC widget and pass `cvcElementId`.",
      ))
    }
  }

let getSavedMethodBody = (savedMethod: PaymentType.customerMethods, ~cvc=None) => {
  let {paymentToken, customerId, paymentMethod} = savedMethod
  let isCustomerAcceptanceRequired =
    paymentMethod !== "bank_redirect" && !savedMethod.recurringEnabled
  let paymentMethodType = savedMethod.paymentMethodType->getNonEmptyOption
  let body = if paymentMethod === "card" {
    PaymentBody.savedCardBody(
      ~paymentToken,
      ~customerId,
      ~cvcNumber=cvc->Option.getOr(""),
      ~requiresCvv=cvc->Option.isSome,
      ~isCustomerAcceptanceRequired,
    )
  } else {
    PaymentBody.savedPaymentMethodBody(
      ~paymentToken,
      ~customerId,
      ~paymentMethod,
      ~paymentMethodType=paymentMethodType->Option.mapOr(JSON.Encode.null, JSON.Encode.string),
      ~isCustomerAcceptanceRequired,
    )
  }
  body->Array.filter(((key, _)) =>
    switch key {
    | "customer_id" => customerId !== ""
    | "payment_method_type" => paymentMethodType->Option.isSome
    | _ => true
    }
  )
}

let addMandateBody = (body, ~paymentMethodList: PaymentMethodsRecord.paymentMethodList) => {
  let paymentType = paymentMethodList.payment_type->PaymentMethodsRecord.paymentTypeToStringMapper
  body->Array.concat(
    paymentMethodList.mandate_payment->Option.isSome
      ? PaymentBody.mandateBody(paymentType)
      : PaymentBody.paymentTypeBody(paymentType),
  )
}
