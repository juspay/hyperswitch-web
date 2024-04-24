type paymentMethod =
  | Card
  | BankTransfer
  | Wallet

type bankTransfer = ACH | Bacs | Sepa
type wallet = Paypal
type paymentMethodType =
  | Card
  | BankTransfer(bankTransfer)
  | Wallet(wallet)

type achBankTransferDetails = {
  routing_number: string,
  account_number: string,
  bank_name: option<string>,
  city: option<string>,
}
type bacsBankTransferDetails = {
  sort_code: string,
  account_number: string,
  bank_name: option<string>,
  city: option<string>,
}
type sepaBankTransferDetails = {
  iban: string,
  bic: string,
  bank_name: option<string>,
  city: option<string>,
  country_code: option<string>,
}
type bankTransferDetails =
  | ACH(achBankTransferDetails)
  | Bacs(bacsBankTransferDetails)
  | Sepa(sepaBankTransferDetails)

type paypalWalletDetails = {email: string}
type walletDetails = Paypal(paypalWalletDetails)

type cardDetails = {
  cardNumber: string,
  expiryMonth: string,
  expiryYear: string,
}

type paymentMethodData =
  | Card(cardDetails)
  | BankTransfer(bankTransferDetails)
  | Wallet(walletDetails)

/** DECODERS */
let decodeTransfer = (value: string): option<bankTransfer> =>
  switch value {
  | "ach" => Some(ACH)
  | "sepa" => Some(Sepa)
  | "bacs" => Some(Bacs)
  | _ => None
  }

let decodeWallet = (methodType: string): option<wallet> =>
  switch methodType {
  | "paypal" => Some(Paypal)
  | _ => None
  }

let decodePaymentMethodType = (json: Js.Json.t): option<paymentMethodType> => {
  switch Js.Json.decodeObject(json) {
  | Some(obj) => {
      let payment_method = obj->Dict.get("payment_method")->Option.flatMap(JSON.Decode.string)
      let payment_method_type =
        obj->Dict.get("payment_method_type")->Option.flatMap(JSON.Decode.string)
      switch (payment_method, payment_method_type) {
      | (Some("card"), _) => Some(Card)
      | (Some("bank_transfer"), Some(transferType)) =>
        switch decodeTransfer(transferType) {
        | Some(transfer) => Some(BankTransfer(transfer))
        | None => None
        }
      | (Some("wallets"), Some(walletType)) =>
        switch decodeWallet(walletType) {
        | Some(wallet) => Some(Wallet(wallet))
        | None => None
        }
      | _ => None
      }
    }
  | None => None
  }
}

/**
 * Expected JSON format
 * [
 *    {
 *      "payment_method": "bank_transfer",
 *      "payment_method_type": "ach"
 *    },
 *    {
 *      "payment_method": "wallet",
 *      "payment_method_type": "paypal"
 *    },
 * ]
 *
 * Decoded format - array<paymentMethodType>
 */
let decodePaymentMethodTypeArray = (jsonArray: Js.Json.t): array<paymentMethodType> =>
  switch Js.Json.decodeArray(jsonArray) {
  | Some(items) => items->Belt.Array.keepMap(decodePaymentMethodType)
  | None => []
  }
