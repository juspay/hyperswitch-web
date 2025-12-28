open Utils

let paymentExperiencePaymentMethodsV2 = []

let appendPaymentExperienceV2 = (paymentBodyArr, paymentMethodType) =>
  if paymentExperiencePaymentMethodsV2->Array.includes(paymentMethodType) {
    paymentBodyArr->Array.concat([("payment_experience", "redirect_to_url"->JSON.Encode.string)])
  } else {
    paymentBodyArr
  }

let dynamicPaymentBodyV2 = (paymentMethod, paymentMethodTypeInput, ~isQrPaymentMethod=false) => {
  open PaymentBody

  let resolvedPaymentMethodType = paymentMethod->getPaymentMethodType(paymentMethodTypeInput)

  let paymentMethodExperienceKey = appendPaymentMethodExperience(
    ~paymentMethod,
    ~paymentMethodType=resolvedPaymentMethodType,
    ~isQrPaymentMethod,
  )

  let paymentMethodBody =
    [(paymentMethodExperienceKey, Dict.make()->JSON.Encode.object)]->getJsonFromArrayOfJson

  let paymentMethodData = [(paymentMethod, paymentMethodBody)]->getJsonFromArrayOfJson

  let baseBody = [
    ("payment_method_type", paymentMethod->JSON.Encode.string),
    ("payment_method_subtype", resolvedPaymentMethodType->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]

  baseBody->appendPaymentExperienceV2(resolvedPaymentMethodType)
}

let epsBody = (~name, ~bankName) => {
  let billingDetails = [("billing_name", name->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson
  let bankDetail = (bankName === "" ? "american_express" : bankName)->JSON.Encode.string

  let epsDetails =
    [("billing_details", billingDetails), ("bank_name", bankDetail)]->Utils.getJsonFromArrayOfJson

  let bankRedirectBody = [("eps", epsDetails)]->Utils.getJsonFromArrayOfJson

  let paymentMethodData = [("bank_redirect", bankRedirectBody)]->Utils.getJsonFromArrayOfJson
  [
    ("payment_method_type", "bank_redirect"->JSON.Encode.string),
    ("payment_method_subtype", "eps"->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]
}

let getPaymentBody = (
  ~paymentMethod,
  ~paymentMethodType,
  ~fullName,
  ~email as _,
  ~country as _,
  ~bank,
  ~blikCode as _,
  ~paymentExperience as _: PaymentMethodsRecord.paymentFlow=RedirectToURL,
  ~phoneNumber as _,
) =>
  switch paymentMethodType {
  | "eps" => epsBody(~name=fullName, ~bankName=bank)
  | _ => dynamicPaymentBodyV2(paymentMethod, paymentMethodType)
  }

let createGiftCardBody = (~giftCardType, ~requiredFieldsBody) => {
  [
    ("payment_method_type", "gift_card"->JSON.Encode.string),
    ("payment_method_subtype", giftCardType->JSON.Encode.string),
  ]->mergeAndFlattenToTuples(requiredFieldsBody)
}

let createSplitPaymentBodyForGiftCards = (
  appliedGiftCards: array<GiftCardTypes.appliedGiftCard>,
) => {
  let splitPaymentMethodData = appliedGiftCards->Array.map(giftCard => {
    createGiftCardBody(
      ~giftCardType=giftCard.giftCardType,
      ~requiredFieldsBody=giftCard.requiredFieldsBody,
    )->getJsonFromArrayOfJson
  })

  [("split_payment_method_data", splitPaymentMethodData->JSON.Encode.array)]
}
