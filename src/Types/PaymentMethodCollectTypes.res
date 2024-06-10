type paymentMethod =
  | Card
  | BankTransfer
  | Wallet

type card = Credit | Debit
type bankTransfer = ACH | Bacs | Sepa
type wallet = Paypal | Pix | Venmo
type paymentMethodType =
  | Card(card)
  | BankTransfer(bankTransfer)
  | Wallet(wallet)

type paymentMethodTypes = {
  card: array<card>,
  bankTransfer: array<bankTransfer>,
  wallet: array<wallet>,
}

type paymentMethodDataField =
  // Cards
  | CardNumber
  | CardExpDate
  | CardHolderName
  // Banks
  | ACHRoutingNumber
  | ACHAccountNumber
  | ACHBankName
  | ACHBankCity
  | BacsSortCode
  | BacsAccountNumber
  | BacsBankName
  | BacsBankCity
  | SepaIban
  | SepaBic
  | SepaBankName
  | SepaBankCity
  | SepaCountryCode
  // Wallets
  | PaypalMail
  | PaypalMobNumber
  | PixId
  | PixBankAccountNumber
  | PixBankName
  | VenmoMobNumber

type paymentMethodData = (paymentMethod, paymentMethodType, array<(paymentMethodDataField, string)>)

type paymentMethodCollectFlow = PayoutLinkInitiate | PayoutMethodCollect

type paymentMethodCollectOptions = {
  enabledPaymentMethods: array<paymentMethodType>,
  linkId: string,
  payoutId: string,
  customerId: string,
  theme: string,
  collectorName: string,
  logo: string,
  returnUrl: option<string>,
  amount: int,
  currency: string,
  flow: paymentMethodCollectFlow,
}

/** DECODERS */
let decodeAmount = (dict, defaultAmount) =>
  switch dict->Dict.get("amount") {
  | Some(amount) =>
    amount
    ->JSON.Decode.string
    ->Option.flatMap(amountStr => Belt.Int.fromString(amountStr))
    ->Option.getOr(defaultAmount)
  | None => defaultAmount
  }

let decodeFlow = (dict, defaultPaymentMethodCollectFlow) =>
  switch dict->Dict.get("flow") {
  | Some(flow) =>
    switch flow->JSON.Decode.string {
    | Some("PayoutLinkInitiate") => PayoutLinkInitiate
    | Some("PayoutMethodCollect") => PayoutMethodCollect
    | _ => defaultPaymentMethodCollectFlow
    }
  | None => defaultPaymentMethodCollectFlow
  }

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
  | "pix" => Some(Pix)
  | "venmo" => Some(Venmo)
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
            | (Some("wallet"), Some(walletType)) =>
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
