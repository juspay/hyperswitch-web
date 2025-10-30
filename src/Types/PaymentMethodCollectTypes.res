let emailValidationRegex = %re("/^[a-zA-Z0-9._%+-]*[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]*$/")

type paymentMethod =
  | Card
  | BankRedirect
  | BankTransfer
  | Wallet

type card = Credit | Debit
type bankRedirect = Interac
type bankTransfer = ACH | Bacs | Pix | Sepa
type wallet = Paypal | Venmo
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
  | PixKey
  | PixBankAccountNumber
  | PixBankName
  | VenmoMobNumber
  // Bank Redirects
  | InteracEmail

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
  | AddressCountry(array<string>)

type dynamicFieldForAddress = {
  pmdMap: string,
  displayName: string,
  fieldType: addressField,
  value: option<string>,
}

type dynamicFieldForPaymentMethodData = {
  pmdMap: string,
  displayName: string,
  fieldType: paymentMethodDataField,
  value: option<string>,
}

type dynamicFieldInfo =
  | BillingAddress(dynamicFieldForAddress)
  | PayoutMethodData(dynamicFieldForPaymentMethodData)

type dynamicFieldType =
  | BillingAddress(addressField)
  | PayoutMethodData(paymentMethodDataField)

type payoutDynamicFields = {
  address: option<array<dynamicFieldForAddress>>,
  payoutMethodData: array<dynamicFieldForPaymentMethodData>,
}

type paymentMethodTypeWithDynamicFields =
  | Card((card, payoutDynamicFields))
  | BankRedirect((bankRedirect, payoutDynamicFields))
  | BankTransfer((bankTransfer, payoutDynamicFields))
  | Wallet((wallet, payoutDynamicFields))

type paymentMethodType =
  | Card(card)
  | BankRedirect(bankRedirect)
  | BankTransfer(bankTransfer)
  | Wallet(wallet)

type paymentMethodData = (paymentMethodType, array<(dynamicFieldInfo, string)>)

type formLayout = Journey | Tabs

type journeyViews =
  | SelectPM
  | SelectPMType(paymentMethod)
  | AddressForm(array<dynamicFieldForAddress>)
  | PMDForm(paymentMethodType, array<dynamicFieldForPaymentMethodData>)
  | FinalizeView(paymentMethodData)

type tabViews =
  | DetailsForm
  | FinalizeView(paymentMethodData)

type views = Journey(journeyViews) | Tabs(tabViews)

type paymentMethodCollectFlow = PayoutLinkInitiate | PayoutMethodCollect

type paymentMethodCollectOptions = {
  enabledPaymentMethods: array<paymentMethodType>,
  enabledPaymentMethodsWithDynamicFields: array<paymentMethodTypeWithDynamicFields>,
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
  | "sepa_bank_transfer" => Some(Sepa)
  | "bacs" => Some(Bacs)
  | "pix" => Some(Pix)
  | _ => None
  }

let decodeWallet = (methodType: string): option<wallet> =>
  switch methodType {
  | "paypal" => Some(Paypal)
  | "venmo" => Some(Venmo)
  | _ => None
  }

let decodeBankRedirect = (methodType: string): option<bankRedirect> =>
  switch methodType {
  | "interac" => Some(Interac)
  | _ => None
  }

let getFieldOptions = dict => {
  switch dict
  ->Dict.get("field_type")
  ->Option.getOr(Dict.make()->JSON.Encode.object)
  ->JSON.Classify.classify {
  | Object(dict) =>
    dict
    ->Dict.get("user_address_country")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.flatMap(obj =>
      obj
      ->Dict.get("options")
      ->Option.flatMap(JSON.Decode.array)
      ->Option.map(options => {
        let countries = options->Array.filterMap(option => option->JSON.Decode.string)
        countries->Array.sort(
          (c1, c2) =>
            (c1->String.charCodeAt(0)->Float.toInt - c2->String.charCodeAt(0)->Float.toInt)
              ->Int.toFloat,
        )
        BillingAddress(AddressCountry(countries))
      })
    )
  | _ => None
  }
}

let decodeFieldType = (key: string, fieldType: option<dynamicFieldType>): option<
  dynamicFieldType,
> => {
  switch (key, fieldType) {
  // Card details
  | ("payout_method_data.card.card_number", _) => Some(PayoutMethodData(CardNumber))
  | ("payout_method_data.card.expiry_month", _) => Some(PayoutMethodData(CardExpDate(CardExpMonth)))
  | ("payout_method_data.card.expiry_year", _) => Some(PayoutMethodData(CardExpDate(CardExpYear)))
  | ("payout_method_data.card.card_holder_name", _) => Some(PayoutMethodData(CardHolderName))

  // SEPA
  | ("payout_method_data.bank.iban", _) => Some(PayoutMethodData(SepaIban))
  | ("payout_method_data.bank.bic", _) => Some(PayoutMethodData(SepaBic))

  // Billing address
  | ("billing.address.first_name", _) => Some(BillingAddress(FullName(FirstName)))
  | ("billing.address.last_name", _) => Some(BillingAddress(FullName(LastName)))
  | ("billing.address.line1", _) => Some(BillingAddress(AddressLine1))
  | ("billing.address.line2", _) => Some(BillingAddress(AddressLine2))
  | ("billing.address.city", _) => Some(BillingAddress(AddressCity))
  | ("billing.address.zip", _) => Some(BillingAddress(AddressPincode))
  | ("billing.address.state", _) => Some(BillingAddress(AddressState))
  | ("billing.address.country", Some(BillingAddress(AddressCountry(countries)))) =>
    Some(BillingAddress(AddressCountry(countries)))
  | ("billing.phone.country_code", _) => Some(BillingAddress(PhoneCountryCode))
  | ("billing.phone.number", _) => Some(BillingAddress(PhoneNumber))

  | _ => fieldType
  }
}

let customAddressOrder = [
  "billing.address.first_name",
  "billing.address.last_name",
  "billing.address.line1",
  "billing.address.line2",
  "billing.address.city",
  "billing.address.zip",
  "billing.address.state",
  "billing.address.country",
  "billing.phone.country_code",
  "billing.phone.number",
]

let customPmdOrder = [
  "payout_method_data.card.card_number",
  "payout_method_data.card.expiry_month",
  "payout_method_data.card.expiry_year",
  "payout_method_data.card.card_holder_name",
  "payout_method_data.bank.iban",
  "payout_method_data.bank.bic",
]

let createCustomOrderMap = (customOrder: array<string>): Map.t<string, int> => {
  customOrder->Array.reduceWithIndex(Map.make(), (map, item, index) => {
    map->Map.set(item, index)
    map
  })
}

let getCustomIndex = (key: string, customOrderMap, defaultIndex) => {
  switch customOrderMap->Map.get(key) {
  | Some(index) => index
  | None => defaultIndex
  }
}

let sortByCustomOrder = (arr: array<'a>, getKey: 'a => string, customOrder: array<string>) => {
  let customOrderMap = createCustomOrderMap(customOrder)
  let defaultIndex = customOrder->Array.length

  arr->Js.Array2.sortInPlaceWith((a, b) => {
    let indexA = getCustomIndex(getKey(a), customOrderMap, defaultIndex)
    let indexB = getCustomIndex(getKey(b), customOrderMap, defaultIndex)
    indexA - indexB
  })
}

let decodePayoutDynamicFields = (json: JSON.t, defaultDynamicPmdFields): payoutDynamicFields =>
  json
  ->JSON.Decode.object
  ->Option.mapOr(
    // Fallback for null/invalid JSON - always return valid defaults
    {
      address: None,
      payoutMethodData: defaultDynamicPmdFields,
    },
    obj => {
      let (address, pmd) =
        obj
        ->Js.Dict.entries
        ->Array.reduce(([], []), ((addressFields, payoutMethodDataFields), (key, value)) => {
          switch JSON.Decode.object(value) {
          | Some(fieldObj) => {
              let getString = key => fieldObj->Dict.get(key)->Option.flatMap(JSON.Decode.string)
              let fieldType = getFieldOptions(fieldObj)
              switch (getString("required_field"), getString("display_name"), getString("value")) {
              | (Some(pmdMap), Some(displayName), value) =>
                switch decodeFieldType(key, fieldType) {
                | Some(BillingAddress(fieldType)) =>
                  let addressField: dynamicFieldForAddress = {
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
        address: address->Array.length > 0
          ? Some(sortByCustomOrder(address, item => item.pmdMap, customAddressOrder))
          : None,
        payoutMethodData: pmd->Array.length > 0
          ? sortByCustomOrder(pmd, item => item.pmdMap, customPmdOrder)
          : defaultDynamicPmdFields,
      }
    },
  )

let decodePaymentMethodTypeWithRequiredFields = (
  json: JSON.t,
  defaultDynamicPmdFields: (~pmt: paymentMethodType=?) => array<dynamicFieldForPaymentMethodData>,
): option<(array<paymentMethodType>, array<paymentMethodTypeWithDynamicFields>)> =>
  json
  ->JSON.Decode.object
  ->Option.flatMap(obj => {
    let paymentMethod = obj->Dict.get("payment_method")->Option.flatMap(JSON.Decode.string)
    obj
    ->Dict.get("payment_method_types_info")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.map(pmtInfoArr =>
      pmtInfoArr
      ->Belt.Array.keepMap(
        pmtInfo =>
          pmtInfo
          ->JSON.Decode.object
          ->Option.flatMap(
            obj => {
              let paymentMethodType =
                obj->Dict.get("payment_method_type")->Option.flatMap(JSON.Decode.string)
              switch (paymentMethod, paymentMethodType) {
              | (Some("card"), Some(cardType)) =>
                cardType
                ->decodeCard
                ->Option.map(card => Card(card))
              | (Some("bank_redirect"), Some(bankRedirectType)) =>
                bankRedirectType
                ->decodeBankRedirect
                ->Option.map(bankRedirect => BankRedirect(bankRedirect))
              | (Some("bank_transfer"), Some(transferType)) =>
                transferType
                ->decodeTransfer
                ->Option.map(transfer => BankTransfer(transfer))
              | (Some("wallet"), Some(walletType)) =>
                walletType
                ->decodeWallet
                ->Option.map(wallet => Wallet(wallet))
              | _ => None
              }->Option.map(
                pmt => {
                  let payoutDynamicFields =
                    obj
                    ->Dict.get("required_fields")
                    ->Option.map(
                      json => json->decodePayoutDynamicFields(defaultDynamicPmdFields(~pmt)),
                    )
                    ->Option.getOr({
                      address: None,
                      payoutMethodData: defaultDynamicPmdFields(~pmt),
                    })
                  (pmt, payoutDynamicFields)
                },
              )
            },
          ),
      )
      ->Array.reduce(
        ([], []),
        ((pmta, pmtr), (pmt, payoutDynamicFields)) => {
          switch pmt {
          | Card(card) => {
              pmta->Array.push(Card(card))
              let pmtwr: paymentMethodTypeWithDynamicFields = Card(card, payoutDynamicFields)
              pmtr->Array.push(pmtwr)
              (pmta, pmtr)
            }
          | BankRedirect(bankRedirect) => {
              pmta->Array.push(BankRedirect(bankRedirect))
              pmtr->Array.push(BankRedirect(bankRedirect, payoutDynamicFields))
              (pmta, pmtr)
            }
          | BankTransfer(transfer) => {
              pmta->Array.push(BankTransfer(transfer))
              pmtr->Array.push(BankTransfer(transfer, payoutDynamicFields))
              (pmta, pmtr)
            }
          | Wallet(wallet) => {
              let pmt: paymentMethodType = Wallet(wallet)
              pmta->Array.push(pmt)
              pmtr->Array.push(Wallet(wallet, payoutDynamicFields))
              (pmta, pmtr)
            }
          }
        },
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
let decodePaymentMethodTypeArray = (
  jsonArray: JSON.t,
  defaultDynamicPmdFields: (~pmt: paymentMethodType=?) => array<dynamicFieldForPaymentMethodData>,
): (array<paymentMethodType>, array<paymentMethodTypeWithDynamicFields>) =>
  switch JSON.Decode.array(jsonArray) {
  | Some(items) =>
    items
    ->Belt.Array.keepMap(decodePaymentMethodTypeWithRequiredFields(_, defaultDynamicPmdFields))
    ->Array.reduce(([], []), ((acc, accr), (pm, pmr)) => (
      acc->Array.concat(pm),
      accr->Array.concat(pmr),
    ))
  | None => ([], [])
  }
