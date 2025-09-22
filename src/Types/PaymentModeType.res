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
  | InstantTransfer
  | InstantTransferFinland
  | InstantTransferPoland
  | BacsTransfer
  | ACHBankDebit
  | SepaBankDebit
  | BacsBankDebit
  | BecsBankDebit
  | BanContactCard
  | GooglePay
  | ApplePay
  | RevolutPay
  | SamsungPay
  | Boleto
  | PayPal
  | EFT
  | Givex
  | Unknown

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
  | "sepa_bank_transfer" => SepaTransfer
  | "instant_bank_transfer" => InstantTransfer
  | "instant_bank_transfer_finland" => InstantTransferFinland
  | "instant_bank_transfer_poland" => InstantTransferPoland
  | "bacs_transfer" => BacsTransfer
  | "bancontact_card" => BanContactCard
  | "google_pay" => GooglePay
  | "apple_pay" => ApplePay
  | "revolut_pay" => RevolutPay
  | "samsung_pay" => SamsungPay
  | "boleto" => Boleto
  | "paypal" => PayPal
  | "eft" => EFT
  | "givex" => Givex
  | _ => Unknown
  }
}

let defaultOrder = [
  "card",
  "apple_pay",
  "google_pay",
  "paypal",
  "klarna",
  "samsung_pay",
  "affirm",
  "afterpay_clearpay",
  "ach_transfer",
  "sepa_bank_transfer",
  "instant_bank_transfer",
  "instant_bank_transfer_finland",
  "instant_bank_transfer_poland",
  "bacs_transfer",
  "ach_debit",
  "sepa_debit",
  "bacs_debit",
  "becs_debit",
  "sofort",
  "giropay",
  "ideal",
  "eps",
  "crypto",
  "bancontact_card",
  "boleto",
  "eft",
  "revolut_pay",
]
