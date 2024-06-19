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
  amount: string,
  currency: string,
  flow: paymentMethodCollectFlow,
  sessionExpiry: string,
}

// API TYPES
type payoutStatus =
  | Success
  | Failed
  | Cancelled
  | Initiated
  | Expired
  | Reversed
  | Pending
  | Ineligible
  | RequiresCreation
  | RequiresConfirmation
  | RequiresPayoutMethodData
  | RequiresFulfillment
  | RequiresVendorAccountCreation

type payoutSuccessResponse = {
  payoutId: string,
  merchantId: string,
  customerId: string,
  amount: float,
  currency: string,
  connector: option<string>,
  payoutType: string,
  status: payoutStatus,
  errorMessage: option<string>,
  errorCode: option<string>,
  connectorTransactionId: option<string>,
}

type payoutFailureResponse = {
  errorType: string,
  code: string,
  message: string,
  reason: option<string>,
}

type payoutConfirmResponse =
  | SuccessResponse(payoutSuccessResponse)
  | ErrorResponse(payoutFailureResponse)

type statusInfoField = {
  key: string,
  value: string,
}

type statusInfo = {
  status: payoutStatus,
  payoutId: string,
  message: string,
  code: option<string>,
  errorMessage: option<string>,
  reason: option<string>,
}

/** DECODERS */
let decodeAmount = (dict, defaultAmount) =>
  switch dict->Dict.get("amount") {
  | Some(amount) =>
    amount
    ->JSON.Decode.string
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

let decodePaymentMethodType = (json: JSON.t): option<array<paymentMethodType>> => {
  switch JSON.Decode.object(json) {
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

let decodePayoutConfirmResponse = (json: JSON.t): option<payoutConfirmResponse> => {
  switch json->JSON.Decode.object {
  | Some(obj) => {
      let status = switch obj->Dict.get("status")->Option.flatMap(JSON.Decode.string) {
      | Some("success") => Some(Success)
      | Some("failed") => Some(Failed)
      | Some("cancelled") => Some(Cancelled)
      | Some("initiated") => Some(Initiated)
      | Some("expired") => Some(Expired)
      | Some("reversed") => Some(Reversed)
      | Some("pending") => Some(Pending)
      | Some("ineligible") => Some(Ineligible)
      | Some("requires_creation") => Some(RequiresCreation)
      | Some("requires_confirmation") => Some(RequiresConfirmation)
      | Some("requires_payout_method_data") => Some(RequiresPayoutMethodData)
      | Some("requires_fulfillment") => Some(RequiresFulfillment)
      | Some("requires_vendor_account_creation") => Some(RequiresVendorAccountCreation)
      | _ => None
      }

      // If status is found in the response, try to decode PayoutCreateResponse, else try to decode ErrorResponse
      switch status {
      | None =>
        switch (
          obj->Dict.get("type")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("code")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("message")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("reason")->Option.flatMap(JSON.Decode.string),
        ) {
        | (Some(errorType), Some(code), Some(message), reason) => {
            let payoutFailureResponse = {
              errorType,
              code,
              message,
              reason,
            }
            Some(ErrorResponse(payoutFailureResponse))
          }
        | _ => None
        }
      | Some(status) =>
        switch (
          obj->Dict.get("payout_id")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("merchant_id")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("customer_id")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("amount")->Option.flatMap(JSON.Decode.float),
          obj->Dict.get("currency")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("payout_type")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("connector")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("error_message")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("error_code")->Option.flatMap(JSON.Decode.string),
          obj->Dict.get("connector_transaction_id")->Option.flatMap(JSON.Decode.string),
        ) {
        | (
            Some(payoutId),
            Some(merchantId),
            Some(customerId),
            Some(amount),
            Some(currency),
            Some(payoutType),
            connector,
            errorMessage,
            errorCode,
            connectorTransactionId,
          ) => {
            let payoutSuccessResponse = {
              payoutId,
              merchantId,
              customerId,
              amount,
              currency,
              payoutType,
              connector,
              errorMessage,
              errorCode,
              connectorTransactionId,
              status,
            }
            Some(SuccessResponse(payoutSuccessResponse))
          }
        | _ => None
        }
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
let decodePaymentMethodTypeArray = (jsonArray: JSON.t): array<paymentMethodType> =>
  switch JSON.Decode.array(jsonArray) {
  | Some(items) =>
    items
    ->Belt.Array.keepMap(decodePaymentMethodType)
    ->Array.reduce([], (acc, pm) => acc->Array.concat(pm))
  | None => []
  }
