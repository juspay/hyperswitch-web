let billingDetailsTuple = (
  ~fullName,
  ~email,
  ~line1,
  ~line2,
  ~city,
  ~stateCode,
  ~postalCode,
  ~country,
) => {
  let (firstName, lastName) = fullName->Utils.getFirstAndLastNameFromFullName

  (
    "billing",
    [
      ("email", email->JSON.Encode.string),
      (
        "address",
        [
          ("first_name", firstName),
          ("last_name", lastName),
          ("line1", line1->JSON.Encode.string),
          ("line2", line2->JSON.Encode.string),
          ("city", city->JSON.Encode.string),
          ("state", stateCode->JSON.Encode.string),
          ("zip", postalCode->JSON.Encode.string),
          ("country", country->JSON.Encode.string),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  )
}

let cardPaymentBody = (
  ~cardNumber,
  ~month,
  ~year,
  ~cardHolderName=None,
  ~cvcNumber,
  ~cardBrand,
  ~nickname="",
) => {
  let cardBody = [
    ("card_number", cardNumber->CardValidations.clearSpaces->JSON.Encode.string),
    ("card_exp_month", month->JSON.Encode.string),
    ("card_exp_year", year->JSON.Encode.string),
    ("card_cvc", cvcNumber->JSON.Encode.string),
    ("card_issuer", ""->JSON.Encode.string),
  ]

  cardHolderName
  ->Option.map(name => cardBody->Array.push(("card_holder_name", name->JSON.Encode.string))->ignore)
  ->ignore

  if nickname != "" {
    cardBody->Array.push(("nick_name", nickname->JSON.Encode.string))->ignore
  }

  [
    ("payment_method", "card"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        ("card", cardBody->Array.concat(cardBrand)->Utils.getJsonFromArrayOfJson),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]
}

let bancontactBody = () => {
  let bancontactField =
    [("bancontact_card", []->Utils.getJsonFromArrayOfJson)]->Utils.getJsonFromArrayOfJson
  let bankRedirectField = [("bank_redirect", bancontactField)]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method", "bank_redirect"->JSON.Encode.string),
    ("payment_method_type", "bancontact_card"->JSON.Encode.string),
    ("payment_method_data", bankRedirectField),
  ]
}

let boletoBody = (~socialSecurityNumber) => [
  ("payment_method", "voucher"->JSON.Encode.string),
  ("payment_method_type", "boleto"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "voucher",
        [
          (
            "boleto",
            [
              ("social_security_number", socialSecurityNumber->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let customerAcceptanceBody =
  [
    ("acceptance_type", "online"->JSON.Encode.string),
    ("accepted_at", Date.now()->Js.Date.fromFloat->Date.toISOString->JSON.Encode.string),
    (
      "online",
      [
        ("user_agent", BrowserSpec.navigator.userAgent->JSON.Encode.string),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]->Utils.getJsonFromArrayOfJson

let savedCardBody = (
  ~paymentToken,
  ~customerId,
  ~cvcNumber,
  ~requiresCvv,
  ~isCustomerAcceptanceRequired,
) => {
  let savedCardBody = [
    ("payment_method", "card"->JSON.Encode.string),
    ("payment_token", paymentToken->JSON.Encode.string),
    ("customer_id", customerId->JSON.Encode.string),
  ]

  if requiresCvv {
    savedCardBody->Array.push(("card_cvc", cvcNumber->JSON.Encode.string))->ignore
  }

  if isCustomerAcceptanceRequired {
    savedCardBody->Array.push(("customer_acceptance", customerAcceptanceBody))->ignore
  }

  savedCardBody
}

let mastercardClickToPayBody = (~merchantTransactionId, ~correlationId, ~xSrcFlowId) => {
  let clickToPayServiceDetails =
    [
      ("merchant_transaction_id", merchantTransactionId->JSON.Encode.string),
      ("correlation_id", correlationId->JSON.Encode.string),
      ("x_src_flow_id", xSrcFlowId->JSON.Encode.string),
      ("provider", "mastercard"->JSON.Encode.string),
    ]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method", "card"->JSON.Encode.string),
    ("ctp_service_details", clickToPayServiceDetails),
  ]
}

let visaClickToPayBody = (~encryptedPayload, ~email) => {
  let encPayload =
    [
      ("encrypted_payload", encryptedPayload->JSON.Encode.string),
      ("provider", "visa"->JSON.Encode.string),
    ]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method", "card"->JSON.Encode.string),
    ("ctp_service_details", encPayload),
    ("payment_method_type", "debit"->JSON.Encode.string),
    ("email", email->JSON.Encode.string),
  ]
}

let visaClickToPayAuthenticationBody = (~encryptedPayload) => {
  let paymentMethodData =
    [
      ("encrypted_payload", encryptedPayload->JSON.Encode.string),
      ("provider", "visa"->JSON.Encode.string),
    ]->Utils.getJsonFromArrayOfJson

  let paymentMethodDetails =
    [
      ("payment_method_type", "ctp"->JSON.Encode.string),
      ("payment_method_data", paymentMethodData),
    ]->Utils.getJsonFromArrayOfJson

  [("payment_method_details", paymentMethodDetails)]
}

let savedPaymentMethodBody = (
  ~paymentToken,
  ~customerId,
  ~paymentMethod,
  ~paymentMethodType,
  ~isCustomerAcceptanceRequired,
) => {
  let savedPaymentMethodBody = [
    ("payment_method", paymentMethod->JSON.Encode.string),
    ("payment_token", paymentToken->JSON.Encode.string),
    ("customer_id", customerId->JSON.Encode.string),
    ("payment_method_type", paymentMethodType),
  ]

  if isCustomerAcceptanceRequired {
    savedPaymentMethodBody->Array.push(("customer_acceptance", customerAcceptanceBody))->ignore
  }

  savedPaymentMethodBody
}

let mandateBody = paymentType => [
  ("mandate_data", [("customer_acceptance", customerAcceptanceBody)]->Utils.getJsonFromArrayOfJson),
  ("customer_acceptance", customerAcceptanceBody),
  ("setup_future_usage", "off_session"->JSON.Encode.string),
  ("payment_type", {paymentType === "" ? JSON.Encode.null : paymentType->JSON.Encode.string}),
]

let paymentTypeBody = paymentType =>
  if paymentType != "" {
    [("payment_type", paymentType->JSON.Encode.string)]
  } else {
    []
  }

let confirmPayloadForSDKButton = (sdkHandleConfirmPayment: PaymentType.sdkHandleConfirmPayment) =>
  [
    (
      "confirmParams",
      [
        ("return_url", sdkHandleConfirmPayment.confirmParams.return_url->JSON.Encode.string),
        ("redirect", "always"->JSON.Encode.string), // *As in the case of SDK Button we are not returning the promise back so it will always redirect
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]->Utils.getJsonFromArrayOfJson

let bankDebitsCommonBody = paymentMethodType => {
  [
    ("payment_method", "bank_debit"->JSON.Encode.string),
    ("setup_future_usage", "off_session"->JSON.Encode.string),
    ("payment_method_type", paymentMethodType->JSON.Encode.string),
    ("customer_acceptance", customerAcceptanceBody),
  ]
}

let achBankDebitBody = (
  ~email,
  ~bank: ACHTypes.data,
  ~cardHolderName,
  ~line1,
  ~line2,
  ~country,
  ~city,
  ~postalCode,
  ~stateCode,
) =>
  bankDebitsCommonBody("ach")->Array.concat([
    (
      "payment_method_data",
      [
        billingDetailsTuple(
          ~fullName=cardHolderName,
          ~email,
          ~line1,
          ~line2,
          ~city,
          ~stateCode,
          ~postalCode,
          ~country,
        ),
        (
          "bank_debit",
          [
            (
              "ach_bank_debit",
              [
                ("account_number", bank.accountNumber->JSON.Encode.string),
                ("bank_account_holder_name", bank.accountHolderName->JSON.Encode.string),
                ("routing_number", bank.routingNumber->JSON.Encode.string),
                ("bank_type", bank.accountType->JSON.Encode.string),
              ]->Utils.getJsonFromArrayOfJson,
            ),
          ]->Utils.getJsonFromArrayOfJson,
        ),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ])

let bacsBankDebitBody = (
  ~email,
  ~accNum,
  ~sortCode,
  ~line1,
  ~line2,
  ~city,
  ~zip,
  ~stateCode,
  ~country,
  ~bankAccountHolderName,
) =>
  bankDebitsCommonBody("bacs")->Array.concat([
    (
      "payment_method_data",
      [
        billingDetailsTuple(
          ~fullName=bankAccountHolderName,
          ~email,
          ~line1,
          ~line2,
          ~city,
          ~stateCode,
          ~postalCode=zip,
          ~country,
        ),
        (
          "bank_debit",
          [
            (
              "bacs_bank_debit",
              [
                ("bank_account_holder_name", bankAccountHolderName->JSON.Encode.string),
                ("sort_code", sortCode->JSON.Encode.string),
                ("account_number", accNum->JSON.Encode.string),
              ]->Utils.getJsonFromArrayOfJson,
            ),
          ]->Utils.getJsonFromArrayOfJson,
        ),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ])

let becsBankDebitBody = (
  ~fullName,
  ~email,
  ~data: ACHTypes.data,
  ~line1,
  ~line2,
  ~country,
  ~city,
  ~postalCode,
  ~stateCode,
) =>
  bankDebitsCommonBody("becs")->Array.concat([
    (
      "payment_method_data",
      [
        billingDetailsTuple(
          ~fullName,
          ~email,
          ~line1,
          ~line2,
          ~city,
          ~stateCode,
          ~postalCode,
          ~country,
        ),
        (
          "bank_debit",
          [
            (
              "becs_bank_debit",
              [
                ("bsb_number", data.sortCode->JSON.Encode.string),
                ("account_number", data.accountNumber->JSON.Encode.string),
                ("bank_account_holder_name", data.accountHolderName->JSON.Encode.string),
              ]->Utils.getJsonFromArrayOfJson,
            ),
          ]->Utils.getJsonFromArrayOfJson,
        ),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ])

let klarnaSDKbody = (~token, ~connectors) => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "klarna"->JSON.Encode.string),
  ("payment_experience", "invoke_sdk_client"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [
          ("klarna_sdk", [("token", token->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let klarnaCheckoutBody = (~connectors) => {
  open Utils
  let checkoutBody = []->Utils.getJsonFromArrayOfJson
  let payLaterBody = [("klarna_checkout", checkoutBody)]->getJsonFromArrayOfJson
  let paymentMethodData = [("pay_later", payLaterBody)]->getJsonFromArrayOfJson
  [
    ("payment_method", "pay_later"->JSON.Encode.string),
    ("payment_method_type", "klarna"->JSON.Encode.string),
    ("payment_experience", "redirect_to_url"->JSON.Encode.string),
    ("connector", connectors->getArrofJsonString->JSON.Encode.array),
    ("payment_method_data", paymentMethodData),
  ]
}

let paypalSdkBody = (~token, ~connectors) => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "paypal"->JSON.Encode.string),
  ("payment_experience", "invoke_sdk_client"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [
          ("paypal_sdk", [("token", token->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let samsungPayBody = (~metadata) => {
  let paymentCredential = [("payment_credential", metadata)]->Utils.getJsonFromArrayOfJson
  let spayBody = [("samsung_pay", paymentCredential)]->Utils.getJsonFromArrayOfJson
  let paymentMethodData = [("wallet", spayBody)]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_type", "samsung_pay"->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]
}

let gpayBody = (~payObj: GooglePayType.paymentData, ~connectors: array<string>) => {
  open Utils
  let (paymentMethodTypeKey, paymentMethodSubtypeKey) = switch GlobalVars.sdkVersion {
  | V1 => ("payment_method", "payment_method_type")
  | V2 => ("payment_method_type", "payment_method_subtype")
  }

  let paymentMethodData = {
    let paymentMethodData = payObj.paymentMethodData

    [
      ("type", paymentMethodData.\"type"->JSON.Encode.string),
      ("description", paymentMethodData.description->JSON.Encode.string),
      ("info", paymentMethodData.info->transformKeys(SnakeCase)),
      ("tokenization_data", paymentMethodData.tokenizationData->transformKeys(SnakeCase)),
    ]->getJsonFromArrayOfJson
  }

  let walletData = [("google_pay", paymentMethodData)]->getJsonFromArrayOfJson

  let paymentMethodDataJson = [("wallet", walletData)]->getJsonFromArrayOfJson

  let baseBody = [
    (paymentMethodTypeKey, "wallet"->JSON.Encode.string),
    (paymentMethodSubtypeKey, "google_pay"->JSON.Encode.string),
    ("payment_method_data", paymentMethodDataJson),
  ]

  switch connectors->Array.length > 0 {
  | true => [...baseBody, ("connector", connectors->getArrofJsonString->JSON.Encode.array)]
  | false => baseBody
  }
}

let gpayRedirectBody = (~connectors: array<string>) => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "google_pay"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("google_pay_redirect", Dict.make()->JSON.Encode.object)]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let gPayThirdPartySdkBody = (~connectors) => [
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "google_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [
          ("google_pay_third_party_sdk", Dict.make()->JSON.Encode.object),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let applePayBody = (~token, ~connectors) => {
  let dict = token->JSON.Decode.object->Option.getOr(Dict.make())
  let paymentDataString =
    dict
    ->Dict.get("paymentData")
    ->Option.getOr(Dict.make()->JSON.Encode.object)
    ->JSON.stringify
    ->Window.btoa
  dict->Dict.set("paymentData", paymentDataString->JSON.Encode.string)

  let applePayBody = [
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_type", "apple_pay"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "wallet",
          [
            ("apple_pay", dict->JSON.Encode.object->Utils.transformKeys(SnakeCase)),
          ]->Utils.getJsonFromArrayOfJson,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]

  if connectors->Array.length > 0 {
    applePayBody
    ->Array.push(("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array))
    ->ignore
  }

  applePayBody
}

let applePayRedirectBody = (~connectors) => [
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "apple_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("apple_pay_redirect", Dict.make()->JSON.Encode.object)]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let applePayThirdPartySdkBody = (~connectors, ~token=?) => {
  let tokenJson = switch token {
  | Some(val) => [("token", val->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson
  | None => Dict.make()->JSON.Encode.object
  }

  [
    ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_type", "apple_pay"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        ("wallet", [("apple_pay_third_party_sdk", tokenJson)]->Utils.getJsonFromArrayOfJson),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]
}

let cryptoBody = () => [
  ("payment_method", "crypto"->JSON.Encode.string),
  ("payment_method_type", "crypto_currency"->JSON.Encode.string),
  ("payment_experience", "redirect_to_url"->JSON.Encode.string),
  (
    "payment_method_data",
    [("crypto", []->Utils.getJsonFromArrayOfJson)]->Utils.getJsonFromArrayOfJson,
  ),
]

let afterpayRedirectionBody = () => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "afterpay_clearpay"->JSON.Encode.string),
  ("payment_experience", "redirect_to_url"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [
          ("afterpay_clearpay_redirect", []->Utils.getJsonFromArrayOfJson),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let giroPayBody = (~name, ~iban="") => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "giropay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "giropay",
            [
              (
                "billing_details",
                [("billing_name", name->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
              ),
              ("bank_account_iban", iban->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let sofortBody = (~country, ~name, ~email) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "sofort"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "sofort",
            [
              ("country", (country == "" ? "US" : country)->JSON.Encode.string),
              ("preferred_language", "en"->JSON.Encode.string),
              (
                "billing_details",
                [
                  ("billing_name", name->JSON.Encode.string),
                  ("email", (email == "" ? "test@gmail.com" : email)->JSON.Encode.string),
                ]->Utils.getJsonFromArrayOfJson,
              ),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let iDealBody = (~name, ~bankName) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "ideal"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "ideal",
            [
              (
                "billing_details",
                [("billing_name", name->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
              ),
              ("bank_name", (bankName == "" ? "american_express" : bankName)->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let epsBody = (~name, ~bankName) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "eps"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "eps",
            [
              (
                "billing_details",
                [("billing_name", name->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
              ),
              ("bank_name", (bankName === "" ? "american_express" : bankName)->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let blikBody = (~blikCode) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "blik"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          ("blik", [("blik_code", blikCode->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let p24Body = (~email) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "przelewy24"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      ("billing", [("email", email->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson),
      (
        "bank_redirect",
        [("przelewy24", Dict.make()->JSON.Encode.object)]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let trustlyBody = (~country) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "trustly"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          ("trustly", [("country", country->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let polandOB = (~bank) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "online_banking_poland"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_poland",
            [("issuer", bank->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let czechOB = (~bank) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "online_banking_czech_republic"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_czech_republic",
            [("issuer", bank->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let slovakiaOB = (~bank) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "online_banking_slovakia"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_slovakia",
            [("issuer", bank->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let mbWayBody = (~phoneNumber) => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "mb_way"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [
          (
            "mb_way_redirect",
            [("telephone_number", phoneNumber->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let rewardBody = (~paymentMethodType) => [
  ("payment_method", "reward"->JSON.Encode.string),
  ("payment_method_type", paymentMethodType->JSON.Encode.string),
  ("payment_method_data", "reward"->JSON.Encode.string),
]

let fpxOBBody = (~bank) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "online_banking_fpx"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_fpx",
            [("issuer", bank->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]
let thailandOBBody = (~bank) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "online_banking_thailand"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_thailand",
            [("issuer", bank->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let pazeBody = (~completeResponse) => {
  open Utils
  let pazeCompleteResponse =
    [("complete_response", completeResponse->JSON.Encode.string)]->getJsonFromArrayOfJson

  let pazeWalletData = [("paze", pazeCompleteResponse)]->getJsonFromArrayOfJson

  let paymentMethodData = [("wallet", pazeWalletData)]->getJsonFromArrayOfJson

  [
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_type", "paze"->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]
}

let revolutPayBody = () => {
  let walletBody = [("revolut_pay", Dict.make()->JSON.Encode.object)]->Utils.getJsonFromArrayOfJson
  let paymentMethodData = [("wallet", walletBody)]->Utils.getJsonFromArrayOfJson

  [
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_type", "revolut_pay"->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]
}
let eftBody = () => {
  open Utils
  let eftProviderName = [("provider", "ozow"->JSON.Encode.string)]->getJsonFromArrayOfJson

  let eftBankRedirectData = [("eft", eftProviderName)]->getJsonFromArrayOfJson

  let paymentMethodData = [("bank_redirect", eftBankRedirectData)]->getJsonFromArrayOfJson

  [
    ("payment_method", "bank_redirect"->JSON.Encode.string),
    ("payment_method_type", "eft"->JSON.Encode.string),
    ("payment_method_data", paymentMethodData),
  ]
}

let getPaymentMethodType = (paymentMethod, paymentMethodType) =>
  switch paymentMethod {
  | "bank_debit" => paymentMethodType->String.replace("_debit", "")
  | "bank_transfer" =>
    if !(Constants.bankTransferList->Array.includes(paymentMethodType)) {
      paymentMethodType->String.replace("_transfer", "")
    } else {
      paymentMethodType
    }
  | _ => paymentMethodType
  }

let appendRedirectPaymentMethods = [
  "touch_n_go",
  "momo",
  "gcash",
  "kakao_pay",
  "go_pay",
  "dana",
  "vipps",
  "twint",
  "atome",
  "pay_bright",
  "walley",
  "affirm",
  "we_chat_pay",
  "ali_pay",
  "ali_pay_hk",
  "revolut_pay",
  "klarna",
  "paypal",
  "breadpay",
  "flexiti",
  "bluecode",
]

let appendBankeDebitMethods = ["sepa"]
let appendBankTransferMethods = ["ach", "bacs", "multibanco"]

let getPaymentMethodSuffix = (~paymentMethodType, ~paymentMethod, ~isQrPaymentMethod) => {
  if isQrPaymentMethod {
    Some("qr")
  } else if appendRedirectPaymentMethods->Array.includes(paymentMethodType) {
    Some("redirect")
  } else if (
    appendBankeDebitMethods->Array.includes(paymentMethodType) && paymentMethod == "bank_debit"
  ) {
    Some("bank_debit")
  } else if (
    appendBankTransferMethods->Array.includes(paymentMethodType) && paymentMethod == "bank_transfer"
  ) {
    Some("bank_transfer")
  } else {
    None
  }
}

let appendPaymentMethodExperience = (~paymentMethod, ~paymentMethodType, ~isQrPaymentMethod) =>
  switch getPaymentMethodSuffix(~paymentMethodType, ~paymentMethod, ~isQrPaymentMethod) {
  | Some(suffix) => `${paymentMethodType}_${suffix}`
  | None => paymentMethodType
  }

let paymentExperiencePaymentMethods = ["affirm", "paypal", "klarna"]

let appendPaymentExperience = (paymentBodyArr, paymentMethodType) =>
  if paymentExperiencePaymentMethods->Array.includes(paymentMethodType) {
    paymentBodyArr->Array.concat([("payment_experience", "redirect_to_url"->JSON.Encode.string)])
  } else {
    paymentBodyArr
  }

let dynamicPaymentBody = (paymentMethod, paymentMethodType, ~isQrPaymentMethod=false) => {
  let paymentMethodType = paymentMethod->getPaymentMethodType(paymentMethodType)
  [
    ("payment_method", paymentMethod->JSON.Encode.string),
    ("payment_method_type", paymentMethodType->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          paymentMethod,
          [
            (
              appendPaymentMethodExperience(~paymentMethod, ~paymentMethodType, ~isQrPaymentMethod),
              Dict.make()->JSON.Encode.object,
            ),
          ]->Utils.getJsonFromArrayOfJson,
        ),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]->appendPaymentExperience(paymentMethodType)
}

let getPaymentBody = (
  ~paymentMethod,
  ~paymentMethodType,
  ~fullName,
  ~email,
  ~country,
  ~bank,
  ~blikCode,
  ~paymentExperience: PaymentMethodsRecord.paymentFlow=RedirectToURL,
  ~phoneNumber,
) =>
  switch paymentMethodType {
  | "afterpay_clearpay" => afterpayRedirectionBody()
  | "crypto_currency" => cryptoBody()
  | "sofort" => sofortBody(~country, ~name=fullName, ~email)
  | "ideal" => iDealBody(~name=fullName, ~bankName=bank)
  | "eps" => epsBody(~name=fullName, ~bankName=bank)
  | "blik" => blikBody(~blikCode)
  | "ali_pay"
  | "ali_pay_hk" =>
    switch paymentExperience {
    | QrFlow => dynamicPaymentBody(paymentMethod, paymentMethodType, ~isQrPaymentMethod=true)
    | RedirectToURL
    | _ =>
      dynamicPaymentBody(paymentMethod, paymentMethodType)
    }
  | "we_chat_pay" =>
    switch paymentExperience {
    | QrFlow => dynamicPaymentBody(paymentMethod, paymentMethodType, ~isQrPaymentMethod=true)
    | RedirectToURL
    | _ =>
      dynamicPaymentBody(paymentMethod, paymentMethodType)
    }
  | "duit_now" =>
    switch paymentExperience {
    | QrFlow => dynamicPaymentBody(paymentMethod, paymentMethodType, ~isQrPaymentMethod=true)
    | RedirectToURL
    | _ =>
      dynamicPaymentBody(paymentMethod, paymentMethodType)
    }
  | "giropay" => giroPayBody(~name=fullName)
  | "trustly" => trustlyBody(~country)
  | "online_banking_poland" => polandOB(~bank)
  | "online_banking_czech_republic" => czechOB(~bank)
  | "online_banking_slovakia" => slovakiaOB(~bank)
  | "mb_way" => mbWayBody(~phoneNumber)
  | "przelewy24" => p24Body(~email)
  | "online_banking_fpx" => fpxOBBody(~bank)
  | "online_banking_thailand" => thailandOBBody(~bank)
  | "revolut_pay" => revolutPayBody()
  | "classic"
  | "evoucher" =>
    rewardBody(~paymentMethodType)
  | "eft" => eftBody()
  | _ => dynamicPaymentBody(paymentMethod, paymentMethodType)
  }
