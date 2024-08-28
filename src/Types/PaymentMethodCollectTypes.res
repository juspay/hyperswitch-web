type paymentMethod =
  | Card
  | BankTransfer
  | Wallet

type card = Credit | Debit
type bankTransfer = ACH | Bacs | Sepa
type wallet = Paypal | Pix | Venmo
type cardExpDate =
  | CardExpMonth
  | CardExpYear

type paymentMethodDataField =
  // Cards
  | CardNumber
  | CardExpDate(cardExpDate)
  | CardHolderName
  // Card meta
  | CardBrand
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

type userFullNameForAddress =
  | FirstName
  | LastName

type addressField =
  | Email
  | FullName(userFullNameForAddress)
  | CountryCode
  | PhoneNumber
  | PhoneCountryCode
  | AddressLine1
  | AddressLine2
  | AddressCity
  | AddressState
  | AddressPincode
  | AddressCountry

type requiredFieldsForAddress = {
  pmdMap: string,
  displayName: string,
  fieldType: addressField,
  value: option<string>,
}

type requiredFieldsForPaymentMethodData = {
  pmdMap: string,
  displayName: string,
  fieldType: paymentMethodDataField,
  value: option<string>,
}

type requiredFieldInfo =
  | BillingAddress(requiredFieldsForAddress)
  | PayoutMethodData(requiredFieldsForPaymentMethodData)

type requiredFieldType =
  | BillingAddress(addressField)
  | PayoutMethodData(paymentMethodDataField)

type requiredFields = {
  address: option<array<requiredFieldsForAddress>>,
  payoutMethodData: option<array<requiredFieldsForPaymentMethodData>>,
}

type paymentMethodType =
  | Card((card, requiredFields))
  | BankTransfer((bankTransfer, requiredFields))
  | Wallet((wallet, requiredFields))

type paymentMethodData = (paymentMethod, paymentMethodType, array<(requiredFieldInfo, string)>)

type formLayout = Journey | Tabs

type journeyViews =
  | SelectPM
  | SelectPMType(paymentMethod)
  | AddressForm(paymentMethod, paymentMethodType, array<requiredFieldsForAddress>)
  | PMDForm(paymentMethod, paymentMethodType, array<requiredFieldsForPaymentMethodData>)
  | FinalizeView(paymentMethod, paymentMethodType, paymentMethodData)

type tabViews =
  | DetailsForm(paymentMethod, paymentMethodType)
  | FinalizeView(paymentMethod, paymentMethodType, paymentMethodData)

type views = Journey(journeyViews) | Tabs(tabViews)

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
  formLayout: formLayout,
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

let decodeFormLayout = (dict, defaultFormLayout): formLayout =>
  switch dict->Dict.get("formLayout") {
  | Some(formLayout) =>
    switch formLayout->JSON.Decode.string {
    | Some("journey") => Journey
    | Some("tabs") => Tabs
    | _ => defaultFormLayout
    }
  | None => defaultFormLayout
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

let decodeFieldType = (key: string): option<requiredFieldType> => {
  switch key {
  // Card details
  | "payout_method_data.card.card_number" => Some(PayoutMethodData(CardNumber))
  | "payout_method_data.card.expiry_month" => Some(PayoutMethodData(CardExpDate(CardExpMonth)))
  | "payout_method_data.card.expiry_year" => Some(PayoutMethodData(CardExpDate(CardExpYear)))
  | "payout_method_data.card.card_holder_name" => Some(PayoutMethodData(CardHolderName))

  // SEPA
  | "payout_method_data.bank.iban" => Some(PayoutMethodData(SepaIban))
  | "payout_method_data.bank.bic" => Some(PayoutMethodData(SepaBic))

  // Billing address
  | "billing.address.first_name" => Some(BillingAddress(FullName(FirstName)))
  | "billing.address.last_name" => Some(BillingAddress(FullName(LastName)))
  | "billing.address.line1" => Some(BillingAddress(AddressLine1))
  | "billing.address.line2" => Some(BillingAddress(AddressLine2))
  | "billing.address.city" => Some(BillingAddress(AddressCity))
  | "billing.address.zip" => Some(BillingAddress(AddressPincode))
  | "billing.address.state" => Some(BillingAddress(AddressState))
  | "billing.address.country" => Some(BillingAddress(AddressCountry))
  | "billing.phone.country_code" => Some(BillingAddress(PhoneCountryCode))
  | "billing.phone.number" => Some(BillingAddress(PhoneNumber))

  | _ => None
  }
}

let decodeRequiredFields = (json: JSON.t): option<requiredFields> =>
  json
  ->JSON.Decode.object
  ->Option.map(obj => {
    let (addressFields, payoutMethodDataFields) =
      obj
      ->Js.Dict.entries
      ->Array.reduce(([], []), ((addressFields, payoutMethodDataFields), (key, value)) => {
        switch JSON.Decode.object(value) {
        | Some(fieldObj) => {
            let getString = key => fieldObj->Dict.get(key)->Option.flatMap(JSON.Decode.string)
            switch (getString("required_field"), getString("display_name"), getString("value")) {
            | (Some(pmdMap), Some(displayName), value) =>
              switch decodeFieldType(key) {
              | Some(BillingAddress(fieldType)) =>
                let addressField: requiredFieldsForAddress = {
                  pmdMap,
                  displayName,
                  fieldType,
                  value,
                }
                ([addressField, ...addressFields], payoutMethodDataFields)
              | Some(PayoutMethodData(fieldType)) =>
                let payoutMethodDataField = {
                  pmdMap,
                  displayName,
                  fieldType,
                  value,
                }
                (addressFields, [payoutMethodDataField, ...payoutMethodDataFields])
              | None => (addressFields, payoutMethodDataFields)
              }
            | _ => (addressFields, payoutMethodDataFields)
            }
          }
        | None => (addressFields, payoutMethodDataFields)
        }
      })

    {
      address: Some(addressFields),
      payoutMethodData: Some(payoutMethodDataFields),
    }
  })

let decodePaymentMethodType = (json: JSON.t): option<array<paymentMethodType>> =>
  json
  ->JSON.Decode.object
  ->Option.flatMap(obj => {
    let paymentMethod = obj->Dict.get("payment_method")->Option.flatMap(JSON.Decode.string)
    obj
    ->Dict.get("payment_method_types_info")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.map(pmtInfoArr =>
      Array.filterMap(
        pmtInfoArr,
        pmtInfo =>
          pmtInfo
          ->JSON.Decode.object
          ->Option.flatMap(
            obj => {
              let paymentMethodType =
                obj->Dict.get("payment_method_type")->Option.flatMap(JSON.Decode.string)
              let requiredFields =
                obj
                ->Dict.get("required_fields")
                ->Option.flatMap(decodeRequiredFields)
                ->Option.getOr({address: None, payoutMethodData: None})
              switch (paymentMethod, paymentMethodType) {
              | (Some("card"), Some(cardType)) =>
                cardType
                ->decodeCard
                ->Option.map(
                  card => {
                    Js.Console.log3("SETTIONG CARD", Card(card, requiredFields), obj)
                    Card(card, requiredFields)
                  },
                )
              | (Some("bank_transfer"), Some(transferType)) =>
                transferType
                ->decodeTransfer
                ->Option.map(transfer => BankTransfer(transfer, requiredFields))
              | (Some("wallet"), Some(walletType)) =>
                walletType
                ->decodeWallet
                ->Option.map(wallet => Wallet(wallet, requiredFields))
              | _ => None
              }
            },
          ),
      )
    )
  })

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
 *      "payment_method_types": [
          {
            "payment_method_type": "ach",
            "required_fields": {
              ""
            }
          },
          {
            "payment_method_type": "bacs"
          }
        ]
 *    },
 *    {
 *      "payment_method": "wallet",
 *      "payment_method_types": [
          {
            "payment_method_type": "paypal",
            "required_fields": {
              ""
            }
          },
          {
            "payment_method_type": "venmo"
          }
        ]
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
