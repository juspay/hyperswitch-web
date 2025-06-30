let dynamicPaymentBodyV2 = (paymentMethod, paymentMethodTypeInput, ~isQrPaymentMethod=false) => {
  let resolvedPaymentMethodType =
    paymentMethod->PaymentBody.getPaymentMethodType(paymentMethodTypeInput)

  let paymentMethodExperienceKey = PaymentBody.appendPaymentMethodExperience(
    ~paymentMethod,
    ~paymentMethodType=resolvedPaymentMethodType,
    ~isQrPaymentMethod,
  )

  let paymentMethodData =
    [
      (
        paymentMethod,
        [
          (paymentMethodExperienceKey, Dict.make()->JSON.Encode.object),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson

  let baseBody = [
    ("payment_method_type", paymentMethod->JSON.Encode.string),
    ("payment_method_subtype", resolvedPaymentMethodType->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]

  baseBody->PaymentBody.appendPaymentExperience(resolvedPaymentMethodType)
}
