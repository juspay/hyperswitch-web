open Utils

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

  baseBody->appendPaymentExperience(resolvedPaymentMethodType)
}
