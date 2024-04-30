type paymentMethod =
  | Card
  | BankTransfer
  | Wallet

type card = Credit | Debit
type bankTransfer = ACH | Bacs | Sepa
type wallet = Paypal
type paymentMethodType =
  | Card(card)
  | BankTransfer(bankTransfer)
  | Wallet(wallet)

type paymentMethodTypes = {
  card: array<card>,
  bankTransfer: array<bankTransfer>,
  wallet: array<wallet>,
}

type achBankTransferDetails = {
  routingNumber: string,
  accountNumber: string,
  bankName: option<string>,
  city: option<string>,
}
type bacsBankTransferDetails = {
  sortCode: string,
  accountNumber: string,
  bankName: option<string>,
  city: option<string>,
}
type sepaBankTransferDetails = {
  iban: string,
  bic: string,
  bankName: option<string>,
  city: option<string>,
  countryCode: option<string>,
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
let decodeCard = (cardType: string): option<card> =>
  switch cardType {
  | "credit" => Some(Credit)
  | "debit" => Some(Debit)
  | _ => None
  }

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

let decodePaymentMethodType = (json: Js.Json.t): option<array<paymentMethodType>> => {
  switch Js.Json.decodeObject(json) {
  | Some(obj) => {
      let payment_method = obj->Dict.get("payment_method")->Option.flatMap(JSON.Decode.string)
      let payment_methods: array<paymentMethodType> = []
      let _ =
        obj
        ->Dict.get("payment_method_types")
        ->Option.flatMap(JSON.Decode.array)
        ->Option.flatMap(pmts => {
          let _ = pmts->Array.map(pmt => {
            let payment_method_type = pmt->JSON.Decode.string
            let _ = switch (payment_method, payment_method_type) {
            | (Some("card"), Some(cardType)) =>
              switch decodeCard(cardType) {
              | Some(card) => payment_methods->Array.push(Card(card))
              | None => ()
              }
            | (Some("bank_transfer"), Some(transferType)) =>
              switch decodeTransfer(transferType) {
              | Some(transfer) => payment_methods->Array.push(BankTransfer(transfer))
              | None => ()
              }
            | (Some("wallets"), Some(walletType)) =>
              switch decodeWallet(walletType) {
              | Some(wallet) => payment_methods->Array.push(Wallet(wallet))
              | None => ()
              }
            | _ => ()
            }
          })
          None
        })
      Some(payment_methods)
    }
  | None => None
  }
}

/**
 * Expected JSON format
 * [
 *    {
 *      "payment_method": "bank_transfer",
 *      "payment_method_types": ["ach", "bacs"]
 *    },
 *    {
 *      "payment_method": "wallet",
 *      "payment_method_types": ["paypal", "venmo"]
 *    },
 * ]
 *
 * Decoded format - array<paymentMethodType>
 */
let decodePaymentMethodTypeArray = (jsonArray: Js.Json.t): array<paymentMethodType> =>
  switch Js.Json.decodeArray(jsonArray) {
  | Some(items) =>
    items
    ->Belt.Array.keepMap(decodePaymentMethodType)
    ->Array.reduce([], (acc, pm) => acc->Array.concat(pm))
  | None => []
  }
