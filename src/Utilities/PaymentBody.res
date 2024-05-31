@val @scope("window")
external btoa: string => string = "btoa"

let billingDetailsTuple = (
  ~fullName,
  ~email,
  ~line1,
  ~line2,
  ~city,
  ~state,
  ~postalCode,
  ~country,
) => (
  "billing_details",
  [
    ("name", fullName->JSON.Encode.string),
    ("email", email->JSON.Encode.string),
    (
      "address",
      [
        ("line1", line1->JSON.Encode.string),
        ("line2", line2->JSON.Encode.string),
        ("city", city->JSON.Encode.string),
        ("state", state->JSON.Encode.string),
        ("zip", postalCode->JSON.Encode.string),
        ("country", country->JSON.Encode.string),
      ]->Utils.getJsonFromArrayOfJson,
    ),
  ]->Utils.getJsonFromArrayOfJson,
)

let cardPaymentBody = (
  ~cardNumber,
  ~month,
  ~year,
  ~cardHolderName,
  ~cvcNumber,
  ~cardBrand,
  ~nickname="",
  (),
) => {
  let cardBody = [
    ("card_number", cardNumber->CardUtils.clearSpaces->JSON.Encode.string),
    ("card_exp_month", month->JSON.Encode.string),
    ("card_exp_year", year->JSON.Encode.string),
    ("card_holder_name", cardHolderName->JSON.Encode.string),
    ("card_cvc", cvcNumber->JSON.Encode.string),
    ("card_issuer", ""->JSON.Encode.string),
  ]

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

let bancontactBody = () => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "bancontact_card"->JSON.Encode.string),
]

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

let achBankDebitBody = (
  ~email,
  ~bank: ACHTypes.data,
  ~cardHolderName,
  ~line1,
  ~line2,
  ~country,
  ~city,
  ~postalCode,
  ~state,
  ~paymentType,
) =>
  [
    ("payment_method", "bank_debit"->JSON.Encode.string),
    ("setup_future_usage", "off_session"->JSON.Encode.string),
    ("payment_method_type", "ach"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "bank_debit",
          [
            (
              "ach_bank_debit",
              [
                billingDetailsTuple(
                  ~fullName=cardHolderName,
                  ~email,
                  ~line1,
                  ~line2,
                  ~city,
                  ~state,
                  ~postalCode,
                  ~country,
                ),
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
  ]->Array.concat(mandateBody(paymentType->PaymentMethodsRecord.paymentTypeToStringMapper))

let sepaBankDebitBody = (
  ~fullName,
  ~email,
  ~data: ACHTypes.data,
  ~line1,
  ~line2,
  ~country,
  ~city,
  ~postalCode,
  ~state,
) => [
  ("payment_method", "bank_debit"->JSON.Encode.string),
  ("payment_method_type", "sepa"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_debit",
        [
          (
            "sepa_bank_debit",
            [
              billingDetailsTuple(
                ~fullName,
                ~email,
                ~line1,
                ~line2,
                ~city,
                ~state,
                ~postalCode,
                ~country,
              ),
              ("iban", data.iban->JSON.Encode.string),
              ("bank_account_holder_name", data.accountHolderName->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let bacsBankDebitBody = (
  ~email,
  ~accNum,
  ~sortCode,
  ~line1,
  ~line2,
  ~city,
  ~zip,
  ~state,
  ~country,
  ~bankAccountHolderName,
) => [
  ("payment_method", "bank_debit"->JSON.Encode.string),
  ("payment_method_type", "bacs"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_debit",
        [
          (
            "bacs_bank_debit",
            [
              billingDetailsTuple(
                ~fullName=bankAccountHolderName,
                ~email,
                ~line1,
                ~line2,
                ~city,
                ~state,
                ~postalCode=zip,
                ~country,
              ),
              ("bank_account_holder_name", bankAccountHolderName->JSON.Encode.string),
              ("sort_code", sortCode->JSON.Encode.string),
              ("account_number", accNum->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let becsBankDebitBody = (
  ~fullName,
  ~email,
  ~data: ACHTypes.data,
  ~line1,
  ~line2,
  ~country,
  ~city,
  ~postalCode,
  ~state,
) => [
  ("payment_method", "bank_debit"->JSON.Encode.string),
  ("payment_method_type", "becs"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_debit",
        [
          (
            "becs_bank_debit",
            [
              billingDetailsTuple(
                ~fullName,
                ~email,
                ~line1,
                ~line2,
                ~city,
                ~state,
                ~postalCode,
                ~country,
              ),
              ("bsb_number", data.sortCode->JSON.Encode.string),
              ("account_number", data.accountNumber->JSON.Encode.string),
              ("bank_account_holder_name", data.accountHolderName->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let klarnaRedirectionBody = (~fullName, ~email, ~country, ~connectors) => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "klarna"->JSON.Encode.string),
  ("payment_experience", "redirect_to_url"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  ("name", fullName->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [
          (
            "klarna_redirect",
            [
              ("billing_email", email->JSON.Encode.string),
              ("billing_country", country->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

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

let paypalRedirectionBody = (~connectors) => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "paypal"->JSON.Encode.string),
  ("payment_experience", "redirect_to_url"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("paypal_redirect", []->Utils.getJsonFromArrayOfJson)]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

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

let gpayBody = (~payObj: GooglePayType.paymentData, ~connectors: array<string>) => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "google_pay"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [
          (
            "google_pay",
            [
              ("type", payObj.paymentMethodData.\"type"->JSON.Encode.string),
              ("description", payObj.paymentMethodData.description->JSON.Encode.string),
              ("info", payObj.paymentMethodData.info->Utils.transformKeys(Utils.SnakeCase)),
              (
                "tokenization_data",
                payObj.paymentMethodData.tokenizationData->Utils.transformKeys(Utils.SnakeCase),
              ),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

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
    ->btoa
  dict->Dict.set("paymentData", paymentDataString->JSON.Encode.string)
  [
    ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
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

let applePayThirdPartySdkBody = (~connectors) => [
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "apple_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [
          ("apple_pay_third_party_sdk", Dict.make()->JSON.Encode.object),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let cryptoBody = (~currency) => [
  ("payment_method", "crypto"->JSON.Encode.string),
  ("payment_method_type", "crypto_currency"->JSON.Encode.string),
  ("payment_experience", "redirect_to_url"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      ("crypto", [("pay_currency", currency->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let afterpayRedirectionBody = (~fullName, ~email) => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "afterpay_clearpay"->JSON.Encode.string),
  ("payment_experience", "redirect_to_url"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [
          (
            "afterpay_clearpay_redirect",
            [
              ("billing_email", email->JSON.Encode.string),
              ("billing_name", fullName->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let giroPayBody = (~name, ~iban="", ()) => [
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

let achBankTransferBody = (~email, ~connectors) => [
  ("payment_method", "bank_transfer"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  ("payment_method_type", "ach"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_transfer",
        [
          (
            "ach_bank_transfer",
            [
              (
                "billing_details",
                [("email", email->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
              ),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]
let bacsBankTransferBody = (~email, ~name, ~connectors) => [
  ("payment_method", "bank_transfer"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  ("payment_method_type", "bacs"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_transfer",
        [
          (
            "bacs_bank_transfer",
            [
              (
                "billing_details",
                [
                  ("email", email->JSON.Encode.string),
                  ("name", name->JSON.Encode.string),
                ]->Utils.getJsonFromArrayOfJson,
              ),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]
let sepaBankTransferBody = (~email, ~name, ~country, ~connectors) => [
  ("payment_method", "bank_transfer"->JSON.Encode.string),
  ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
  ("payment_method_type", "sepa"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_transfer",
        [
          (
            "sepa_bank_transfer",
            [
              (
                "billing_details",
                [
                  ("email", email->JSON.Encode.string),
                  ("name", name->JSON.Encode.string),
                ]->Utils.getJsonFromArrayOfJson,
              ),
              ("country", country->JSON.Encode.string),
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
      (
        "bank_redirect",
        [
          (
            "przelewy24",
            [
              (
                "billing_details",
                [("email", email->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
              ),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let interacBody = (~email, ~country) => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "interac"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "interac",
            [
              ("email", email->JSON.Encode.string),
              ("country", country->JSON.Encode.string),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
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

let multibancoBody = (~email) => [
  ("payment_method", "bank_transfer"->JSON.Encode.string),
  ("payment_method_type", "multibanco"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_transfer",
        [
          (
            "multibanco_bank_transfer",
            [
              (
                "billing_details",
                [("email", email->JSON.Encode.string)]->Utils.getJsonFromArrayOfJson,
              ),
            ]->Utils.getJsonFromArrayOfJson,
          ),
        ]->Utils.getJsonFromArrayOfJson,
      ),
    ]->Utils.getJsonFromArrayOfJson,
  ),
]

let getPaymentMethodType = (paymentMethod, paymentMethodType) =>
  switch paymentMethod {
  | "bank_debit" => paymentMethodType->String.replace("_debit", "")
  | "bank_transfer" => paymentMethodType->String.replace("_transfer", "")
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
]

let appendPaymentMethodExperience = (paymentMethodType, isQrPaymentMethod) =>
  if isQrPaymentMethod {
    paymentMethodType ++ "_qr"
  } else if appendRedirectPaymentMethods->Array.includes(paymentMethodType) {
    paymentMethodType ++ "_redirect"
  } else {
    paymentMethodType
  }

let paymentExperiencePaymentMethods = ["affirm"]

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
              paymentMethodType->appendPaymentMethodExperience(isQrPaymentMethod),
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
  ~currency,
) =>
  switch paymentMethodType {
  | "afterpay_clearpay" => afterpayRedirectionBody(~fullName, ~email)
  | "crypto_currency" => cryptoBody(~currency)
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
  | "giropay" => giroPayBody(~name=fullName, ())
  | "trustly" => trustlyBody(~country)
  | "online_banking_poland" => polandOB(~bank)
  | "online_banking_czech_republic" => czechOB(~bank)
  | "online_banking_slovakia" => slovakiaOB(~bank)
  | "mb_way" => mbWayBody(~phoneNumber)
  | "interac" => interacBody(~email, ~country)
  | "przelewy24" => p24Body(~email)
  | "online_banking_fpx" => fpxOBBody(~bank)
  | "online_banking_thailand" => thailandOBBody(~bank)
  | "multibanco" => multibancoBody(~email)
  | "classic"
  | "evoucher" =>
    rewardBody(~paymentMethodType)
  | _ => dynamicPaymentBody(paymentMethod, paymentMethodType)
  }
