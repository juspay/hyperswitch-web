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

let klarnaRedirectionBody = () => {
  let klarnaRedirectField =
    [("klarna_redirect", []->Utils.getJsonFromArrayOfJson)]->Utils.getJsonFromArrayOfJson
  let paymentMethodData = [("pay_later", klarnaRedirectField)]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method_type", "pay_later"->JSON.Encode.string),
    ("payment_method_subtype", "klarna"->JSON.Encode.string),
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
  | "klarna" =>
    switch paymentExperience {
    | RedirectToURL => klarnaRedirectionBody()
    | _ => dynamicPaymentBodyV2(paymentMethod, paymentMethodType)
    }
  | _ => dynamicPaymentBodyV2(paymentMethod, paymentMethodType)
  }
