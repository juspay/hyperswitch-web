type cardType =
  | Credit
  | Debit
  | Dynamic(string)
  | Unspecified

type walletType =
  | GooglePay
  | ApplePay
  | SamsungPay
  | Paypal
  | PaypalSdk
  | Paze
  | Venmo
  | Dynamic(string)
  | Unspecified

type payLaterType =
  | Klarna
  | Affirm
  | AfterpayClearpay
  | PayBright
  | Walley
  | Alma
  | Atome
  | Dynamic(string)
  | Unspecified

type openBankingType =
  | Plaid
  | Dynamic(string)
  | Unspecified

type simpleType =
  | Dynamic(string)
  | Unspecified

type paymentMethod =
  | Card(cardType)
  | Wallet(walletType)
  | PayLater(payLaterType)
  | OpenBanking(openBankingType)
  | BankRedirect(simpleType)
  | BankDebit(simpleType)
  | BankTransfer(simpleType)
  | CardRedirect(simpleType)
  | MobilePayment(simpleType)
  | Dynamic(string)

let name = value =>
  switch value {
  | Card(_) => "CARD"
  | Wallet(_) => "WALLET"
  | PayLater(_) => "PAY_LATER"
  | OpenBanking(_) => "OPEN_BANKING"
  | BankRedirect(_) => "BANK_REDIRECT"
  | BankDebit(_) => "BANK_DEBIT"
  | BankTransfer(_) => "BANK_TRANSFER"
  | CardRedirect(_) => "CARD_REDIRECT"
  | MobilePayment(_) => "MOBILE_PAYMENT"
  | Dynamic(value) => value->LoggerUtils.screamingSnakeCase
  }

let typeName = value =>
  switch value {
  | Card(Credit) => Some("CREDIT")
  | Card(Debit) => Some("DEBIT")
  | Wallet(GooglePay) => Some("GOOGLE_PAY")
  | Wallet(ApplePay) => Some("APPLE_PAY")
  | Wallet(SamsungPay) => Some("SAMSUNG_PAY")
  | Wallet(Paypal) => Some("PAYPAL")
  | Wallet(PaypalSdk) => Some("PAYPAL_SDK")
  | Wallet(Paze) => Some("PAZE")
  | Wallet(Venmo) => Some("VENMO")
  | PayLater(Klarna) => Some("KLARNA")
  | PayLater(Affirm) => Some("AFFIRM")
  | PayLater(AfterpayClearpay) => Some("AFTERPAY_CLEARPAY")
  | PayLater(PayBright) => Some("PAY_BRIGHT")
  | PayLater(Walley) => Some("WALLEY")
  | PayLater(Alma) => Some("ALMA")
  | PayLater(Atome) => Some("ATOME")
  | OpenBanking(Plaid) => Some("PLAID")
  | Card(Dynamic(value))
  | Wallet(Dynamic(value))
  | PayLater(Dynamic(value))
  | OpenBanking(Dynamic(value))
  | BankRedirect(Dynamic(value))
  | BankDebit(Dynamic(value))
  | BankTransfer(Dynamic(value))
  | CardRedirect(Dynamic(value))
  | MobilePayment(Dynamic(value)) =>
    Some(value->LoggerUtils.screamingSnakeCase)
  | Card(Unspecified)
  | Wallet(Unspecified)
  | PayLater(Unspecified)
  | OpenBanking(Unspecified)
  | BankRedirect(Unspecified)
  | BankDebit(Unspecified)
  | BankTransfer(Unspecified)
  | CardRedirect(Unspecified)
  | MobilePayment(Unspecified)
  | Dynamic(_) =>
    None
  }

let fromBackendValue = value =>
  switch value->String.toLowerCase->String.trim {
  | "" => None
  | "credit" => Some(Card(Credit))
  | "debit" => Some(Card(Debit))
  | "google_pay" => Some(Wallet(GooglePay))
  | "apple_pay" => Some(Wallet(ApplePay))
  | "samsung_pay" => Some(Wallet(SamsungPay))
  | "paypal" => Some(Wallet(Paypal))
  | "paypal_sdk" => Some(Wallet(PaypalSdk))
  | "paze" => Some(Wallet(Paze))
  | "venmo" => Some(Wallet(Venmo))
  | "klarna" => Some(PayLater(Klarna))
  | "affirm" => Some(PayLater(Affirm))
  | "afterpay_clearpay" => Some(PayLater(AfterpayClearpay))
  | "pay_bright" => Some(PayLater(PayBright))
  | "walley" => Some(PayLater(Walley))
  | "alma" => Some(PayLater(Alma))
  | "atome" => Some(PayLater(Atome))
  | "plaid" => Some(OpenBanking(Plaid))
  | "card" => Some(Card(Unspecified))
  | "wallet" => Some(Wallet(Unspecified))
  | "pay_later" => Some(PayLater(Unspecified))
  | "open_banking" => Some(OpenBanking(Unspecified))
  | "bank_redirect" => Some(BankRedirect(Unspecified))
  | "bank_debit" => Some(BankDebit(Unspecified))
  | "bank_transfer" => Some(BankTransfer(Unspecified))
  | "card_redirect" => Some(CardRedirect(Unspecified))
  | "mobile_payment" => Some(MobilePayment(Unspecified))
  | other => Some(Dynamic(other))
  }

let withType = (value, typeValue) =>
  switch (value, typeValue->String.toLowerCase->String.trim) {
  | (value, "") => value
  | (Card(Unspecified), "credit") => Card(Credit)
  | (Card(Unspecified), "debit") => Card(Debit)
  | (Card(Unspecified), other) => Card(Dynamic(other))
  | (Wallet(Unspecified), "google_pay") => Wallet(GooglePay)
  | (Wallet(Unspecified), "apple_pay") => Wallet(ApplePay)
  | (Wallet(Unspecified), "samsung_pay") => Wallet(SamsungPay)
  | (Wallet(Unspecified), "paypal") => Wallet(Paypal)
  | (Wallet(Unspecified), "paypal_sdk") => Wallet(PaypalSdk)
  | (Wallet(Unspecified), "paze") => Wallet(Paze)
  | (Wallet(Unspecified), "venmo") => Wallet(Venmo)
  | (Wallet(Unspecified), other) => Wallet(Dynamic(other))
  | (PayLater(Unspecified), "klarna") => PayLater(Klarna)
  | (PayLater(Unspecified), "affirm") => PayLater(Affirm)
  | (PayLater(Unspecified), "afterpay_clearpay") => PayLater(AfterpayClearpay)
  | (PayLater(Unspecified), "pay_bright") => PayLater(PayBright)
  | (PayLater(Unspecified), "walley") => PayLater(Walley)
  | (PayLater(Unspecified), "alma") => PayLater(Alma)
  | (PayLater(Unspecified), "atome") => PayLater(Atome)
  | (PayLater(Unspecified), other) => PayLater(Dynamic(other))
  | (OpenBanking(Unspecified), "plaid") => OpenBanking(Plaid)
  | (OpenBanking(Unspecified), other) => OpenBanking(Dynamic(other))
  | (BankRedirect(Unspecified), other) => BankRedirect(Dynamic(other))
  | (BankDebit(Unspecified), other) => BankDebit(Dynamic(other))
  | (BankTransfer(Unspecified), other) => BankTransfer(Dynamic(other))
  | (CardRedirect(Unspecified), other) => CardRedirect(Dynamic(other))
  | (MobilePayment(Unspecified), other) => MobilePayment(Dynamic(other))
  | (value, _) => value
  }

let fromBackendPair = (~method, ~methodType) =>
  switch method->fromBackendValue {
  | Some(value) => Some(value->withType(methodType))
  | None => methodType->fromBackendValue
  }

let qualifiedName = value =>
  switch value->typeName {
  | Some(typeName) => `${value->name}.${typeName}`
  | None => value->name
  }
