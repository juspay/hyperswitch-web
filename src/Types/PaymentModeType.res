type payment =
  | Klarna
  | Card
  | Sofort
  | AfterPay
  | Affirm
  | GiroPay
  | Ideal
  | EPS
  | CryptoCurrency
  | ACHTransfer
  | SepaTransfer
  | BacsTransfer
  | ACHBankDebit
  | SepaBankDebit
  | BacsBankDebit
  | BecsBankDebit
  | BanContactCard
  | GooglePay
  | ApplePay
  | NONE

let paymentMode = str => {
  switch str {
  | "card" => Card
  | "klarna" => Klarna
  | "afterpay_clearpay" => AfterPay
  | "affirm" => Affirm
  | "sofort" => Sofort
  | "giropay" => GiroPay
  | "ideal" => Ideal
  | "eps" => EPS
  | "crypto_currency" => CryptoCurrency
  | "ach_debit" => ACHBankDebit
  | "sepa_debit" => SepaBankDebit
  | "bacs_debit" => BacsBankDebit
  | "becs_debit" => BecsBankDebit
  | "ach_transfer" => ACHTransfer
  | "sepa_transfer" => SepaTransfer
  | "bacs_transfer" => BacsTransfer
  | "bancontact_card" => BanContactCard
  | "google_pay" => GooglePay
  | "apple_pay" => ApplePay
  | _ => NONE
  }
}

let defaultOrder = [
  "card",
  "klarna",
  "affirm",
  "afterpay_clearpay",
  "ach_transfer",
  "sepa_transfer",
  "bacs_transfer",
  "ach_debit",
  "sepa_debit",
  "bacs_debit",
  "becs_debit",
  "sofort",
  "giropay",
  "ideal",
  "eps",
  "google_pay",
  "apple_pay",
  "paypal",
  "crypto",
  "bancontact_card",
]
