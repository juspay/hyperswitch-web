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

let epsBody = (~name, ~bankName) => [
  ("payment_method_type", "bank_redirect"->JSON.Encode.string),
  ("payment_method_subtype", "eps"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "eps",
            [
              (
                "billing_details",
                [("billing_name", name->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
              ),
              ("bank_name", (bankName === "" ? "american_express" : bankName)->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let getPaymentBody = (
  ~paymentMethod,
  ~paymentMethodType,
  ~fullName,
  ~email,
  ~country,
  ~bank,
  ~blikCode,
  ~paymentExperience: PaymentMethodsRecord.paymentFlow=RedirectToURL,
  ~phoneNumber,
) =>
  switch paymentMethodType {
  | "eps" => epsBody(~name=fullName, ~bankName=bank)
  | _ => dynamicPaymentBodyV2(paymentMethod, paymentMethodType)
  }
