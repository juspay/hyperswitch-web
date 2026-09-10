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
  | AliPay
  | Cashapp
  | Dana
  | Gcash
  | GoPay
  | KakaoPay
  | MbWay
  | MobilePay
  | Momo
  | Twint
  | Venmo
  | Vipps
  | WeChatPay
  | Dynamic(string)
  | Unspecified

type payLaterType =
  | Klarna
  | Affirm
  | AfterpayClearpay
  | Walley
  | Dynamic(string)
  | Unspecified

type bankRedirectType =
  | Trustly
  | Dynamic(string)
  | Unspecified

type bankDebitType = Unspecified

type bankTransferType = Unspecified

type openBankingType =
  | Plaid
  | Dynamic(string)
  | Unspecified

type cardRedirectType = Unspecified

type mobilePaymentType = Unspecified

type paymentMethod =
  | Card(cardType)
  | Wallet(walletType)
  | PayLater(payLaterType)
  | BankRedirect(bankRedirectType)
  | BankDebit(bankDebitType)
  | BankTransfer(bankTransferType)
  | OpenBanking(openBankingType)
  | CardRedirect(cardRedirectType)
  | MobilePayment(mobilePaymentType)
  | Crypto
  | Reward
  | Upi
  | Voucher
  | GiftCard
  | Dynamic(string)

let paymentMethodName = value =>
  switch value {
  | Card(_) => "CARD"
  | Wallet(_) => "WALLET"
  | PayLater(_) => "PAY_LATER"
  | BankRedirect(_) => "BANK_REDIRECT"
  | BankDebit(_) => "BANK_DEBIT"
  | BankTransfer(_) => "BANK_TRANSFER"
  | OpenBanking(_) => "OPEN_BANKING"
  | CardRedirect(_) => "CARD_REDIRECT"
  | MobilePayment(_) => "MOBILE_PAYMENT"
  | Crypto => "CRYPTO"
  | Reward => "REWARD"
  | Upi => "UPI"
  | Voucher => "VOUCHER"
  | GiftCard => "GIFT_CARD"
  | Dynamic(value) => value->LoggerCommonHelpers.screamingSnakeCase
  }

let paymentMethodTypeName = value =>
  switch value {
  | Card(Credit) => Some("CREDIT")
  | Card(Debit) => Some("DEBIT")
  | Wallet(GooglePay) => Some("GOOGLE_PAY")
  | Wallet(ApplePay) => Some("APPLE_PAY")
  | Wallet(SamsungPay) => Some("SAMSUNG_PAY")
  | Wallet(Paypal) => Some("PAYPAL")
  | Wallet(PaypalSdk) => Some("PAYPAL_SDK")
  | Wallet(Paze) => Some("PAZE")
  | Wallet(AliPay) => Some("ALI_PAY")
  | Wallet(Cashapp) => Some("CASHAPP")
  | Wallet(Dana) => Some("DANA")
  | Wallet(Gcash) => Some("GCASH")
  | Wallet(GoPay) => Some("GO_PAY")
  | Wallet(KakaoPay) => Some("KAKAO_PAY")
  | Wallet(MbWay) => Some("MB_WAY")
  | Wallet(MobilePay) => Some("MOBILE_PAY")
  | Wallet(Momo) => Some("MOMO")
  | Wallet(Twint) => Some("TWINT")
  | Wallet(Venmo) => Some("VENMO")
  | Wallet(Vipps) => Some("VIPPS")
  | Wallet(WeChatPay) => Some("WE_CHAT_PAY")
  | PayLater(Klarna) => Some("KLARNA")
  | PayLater(Affirm) => Some("AFFIRM")
  | PayLater(AfterpayClearpay) => Some("AFTERPAY_CLEARPAY")
  | PayLater(Walley) => Some("WALLEY")
  | BankRedirect(Trustly) => Some("TRUSTLY")
  | OpenBanking(Plaid) => Some("PLAID")
  | Card(Dynamic(value))
  | Wallet(Dynamic(value))
  | PayLater(Dynamic(value))
  | BankRedirect(Dynamic(value))
  | OpenBanking(Dynamic(value)) =>
    Some(value->LoggerCommonHelpers.screamingSnakeCase)
  | Dynamic(_)
  | Card(Unspecified)
  | Wallet(Unspecified)
  | PayLater(Unspecified)
  | BankRedirect(Unspecified)
  | BankDebit(Unspecified)
  | BankTransfer(Unspecified)
  | OpenBanking(Unspecified)
  | CardRedirect(Unspecified)
  | MobilePayment(Unspecified)
  | Crypto
  | Reward
  | Upi
  | Voucher
  | GiftCard =>
    None
  }

let paymentMethodFromString = value =>
  switch value->String.toLowerCase {
  | "card" => Some(Card(Unspecified))
  | "wallet" => Some(Wallet(Unspecified))
  | "pay_later" => Some(PayLater(Unspecified))
  | "bank_redirect" => Some(BankRedirect(Unspecified))
  | "bank_debit" => Some(BankDebit(Unspecified))
  | "bank_transfer" => Some(BankTransfer(Unspecified))
  | "open_banking" => Some(OpenBanking(Unspecified))
  | "card_redirect" => Some(CardRedirect(Unspecified))
  | "mobile_payment" => Some(MobilePayment(Unspecified))
  | "crypto" => Some(Crypto)
  | "reward" => Some(Reward)
  | "upi" => Some(Upi)
  | "voucher" => Some(Voucher)
  | "gift_card" => Some(GiftCard)
  | _ => None
  }

let paymentMethodTypeFromString = value =>
  switch value->String.toLowerCase {
  | "credit" => Some(Card(Credit))
  | "debit" => Some(Card(Debit))
  | "google_pay" => Some(Wallet(GooglePay))
  | "apple_pay" => Some(Wallet(ApplePay))
  | "samsung_pay" => Some(Wallet(SamsungPay))
  | "paypal" => Some(Wallet(Paypal))
  | "paypal_sdk" => Some(Wallet(PaypalSdk))
  | "paze" => Some(Wallet(Paze))
  | "ali_pay" => Some(Wallet(AliPay))
  | "cashapp" => Some(Wallet(Cashapp))
  | "dana" => Some(Wallet(Dana))
  | "gcash" => Some(Wallet(Gcash))
  | "go_pay" => Some(Wallet(GoPay))
  | "kakao_pay" => Some(Wallet(KakaoPay))
  | "mb_way" => Some(Wallet(MbWay))
  | "mobile_pay" => Some(Wallet(MobilePay))
  | "momo" => Some(Wallet(Momo))
  | "twint" => Some(Wallet(Twint))
  | "venmo" => Some(Wallet(Venmo))
  | "vipps" => Some(Wallet(Vipps))
  | "we_chat_pay" => Some(Wallet(WeChatPay))
  | "klarna" => Some(PayLater(Klarna))
  | "affirm" => Some(PayLater(Affirm))
  | "afterpay_clearpay" => Some(PayLater(AfterpayClearpay))
  | "walley" => Some(PayLater(Walley))
  | "trustly" => Some(BankRedirect(Trustly))
  | "plaid" => Some(OpenBanking(Plaid))
  | _ => None
  }

let fromBackendValue = value =>
  switch value->paymentMethodTypeFromString {
  | Some(resolved) => Some(resolved)
  | None =>
    switch value->paymentMethodFromString {
    | Some(resolved) => Some(resolved)
    | None => value->String.trim === "" ? None : Some(Dynamic(value))
    }
  }
