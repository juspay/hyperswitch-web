@val @scope("window")
external btoa: string => string = "btoa"
let cardPaymentBody = (~cardNumber, ~month, ~year, ~cardHolderName, ~cvcNumber, ~cardBrand) => [
  ("payment_method", "card"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "card",
        [
          ("card_number", cardNumber->CardUtils.clearSpaces->Js.Json.string),
          ("card_exp_month", month->Js.Json.string),
          ("card_exp_year", year->Js.Json.string),
          ("card_holder_name", cardHolderName->Js.Json.string),
          ("card_cvc", cvcNumber->Js.Json.string),
          ("card_issuer", ""->Js.Json.string),
        ]
        ->Js.Array2.concat(cardBrand)
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let bancontactBody = () => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "bancontact_card"->Js.Json.string),
]

let savedCardBody = (~paymentToken, ~customerId, ~cvcNumber) => [
  ("payment_method", "card"->Js.Json.string),
  ("payment_token", paymentToken->Js.Json.string),
  ("customer_id", customerId->Js.Json.string),
  ("card_cvc", cvcNumber->Js.Json.string),
]

let mandateBody = paymentType => {
  [
    (
      "mandate_data",
      [
        (
          "customer_acceptance",
          [
            ("acceptance_type", "online"->Js.Json.string),
            ("accepted_at", Js.Date.now()->Js.Date.fromFloat->Js.Date.toISOString->Js.Json.string),
            (
              "online",
              [("user_agent", BrowserSpec.navigator.userAgent->Js.Json.string)]
              ->Js.Dict.fromArray
              ->Js.Json.object_,
            ),
          ]
          ->Js.Dict.fromArray
          ->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
    ("setup_future_usage", "off_session"->Js.Json.string),
    ("payment_type", {paymentType === "" ? Js.Json.null : paymentType->Js.Json.string}),
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
  ~state,
  ~paymentType,
) =>
  [
    ("payment_method", "bank_debit"->Js.Json.string),
    ("setup_future_usage", "off_session"->Js.Json.string),
    ("payment_method_type", "ach"->Js.Json.string),
    (
      "payment_method_data",
      [
        (
          "bank_debit",
          [
            (
              "ach_bank_debit",
              [
                (
                  "billing_details",
                  [
                    ("name", cardHolderName->Js.Json.string),
                    ("email", email->Js.Json.string),
                    (
                      "address",
                      [
                        ("line1", line1->Js.Json.string),
                        ("line2", line2->Js.Json.string),
                        ("city", city->Js.Json.string),
                        ("state", state->Js.Json.string),
                        ("zip", postalCode->Js.Json.string),
                        ("country", country->Js.Json.string),
                      ]
                      ->Js.Dict.fromArray
                      ->Js.Json.object_,
                    ),
                  ]
                  ->Js.Dict.fromArray
                  ->Js.Json.object_,
                ),
                ("account_number", bank.accountNumber->Js.Json.string),
                ("bank_account_holder_name", bank.accountHolderName->Js.Json.string),
                ("routing_number", bank.routingNumber->Js.Json.string),
                ("bank_type", bank.accountType->Js.Json.string),
              ]
              ->Js.Dict.fromArray
              ->Js.Json.object_,
            ),
          ]
          ->Js.Dict.fromArray
          ->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
  ]->Js.Array2.concat(mandateBody(paymentType))

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
  ("payment_method", "bank_debit"->Js.Json.string),
  ("payment_method_type", "sepa"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_debit",
        [
          (
            "sepa_bank_debit",
            [
              (
                "billing_details",
                [
                  ("name", fullName->Js.Json.string),
                  ("email", email->Js.Json.string),
                  (
                    "address",
                    [
                      ("line1", line1->Js.Json.string),
                      ("line2", line2->Js.Json.string),
                      ("city", city->Js.Json.string),
                      ("state", state->Js.Json.string),
                      ("zip", postalCode->Js.Json.string),
                      ("country", country->Js.Json.string),
                    ]
                    ->Js.Dict.fromArray
                    ->Js.Json.object_,
                  ),
                ]
                ->Js.Dict.fromArray
                ->Js.Json.object_,
              ),
              ("iban", data.iban->Js.Json.string),
              ("bank_account_holder_name", data.accountHolderName->Js.Json.string),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
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
  ("payment_method", "bank_debit"->Js.Json.string),
  ("payment_method_type", "bacs"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_debit",
        [
          (
            "bacs_bank_debit",
            [
              (
                "billing_details",
                [
                  ("name", bankAccountHolderName->Js.Json.string),
                  ("email", email->Js.Json.string),
                  (
                    "address",
                    [
                      ("line1", line1->Js.Json.string),
                      ("line2", line2->Js.Json.string),
                      ("city", city->Js.Json.string),
                      ("zip", zip->Js.Json.string),
                      ("state", state->Js.Json.string),
                      ("country", country->Js.Json.string),
                    ]
                    ->Js.Dict.fromArray
                    ->Js.Json.object_,
                  ),
                ]
                ->Js.Dict.fromArray
                ->Js.Json.object_,
              ),
              ("bank_account_holder_name", bankAccountHolderName->Js.Json.string),
              ("sort_code", sortCode->Js.Json.string),
              ("account_number", accNum->Js.Json.string),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
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
  ("payment_method", "bank_debit"->Js.Json.string),
  ("payment_method_type", "becs"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_debit",
        [
          (
            "becs_bank_debit",
            [
              (
                "billing_details",
                [
                  ("name", fullName->Js.Json.string),
                  ("email", email->Js.Json.string),
                  (
                    "address",
                    [
                      ("line1", line1->Js.Json.string),
                      ("line2", line2->Js.Json.string),
                      ("city", city->Js.Json.string),
                      ("state", state->Js.Json.string),
                      ("zip", postalCode->Js.Json.string),
                      ("country", country->Js.Json.string),
                    ]
                    ->Js.Dict.fromArray
                    ->Js.Json.object_,
                  ),
                ]
                ->Js.Dict.fromArray
                ->Js.Json.object_,
              ),
              ("bsb_number", data.sortCode->Js.Json.string),
              ("account_number", data.accountNumber->Js.Json.string),
              ("bank_account_holder_name", data.accountHolderName->Js.Json.string),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let klarnaRedirectionBody = (~fullName, ~email, ~country, ~connectors) => [
  ("payment_method", "pay_later"->Js.Json.string),
  ("payment_method_type", "klarna"->Js.Json.string),
  ("payment_experience", "redirect_to_url"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  ("name", fullName->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [
          (
            "klarna_redirect",
            [("billing_email", email->Js.Json.string), ("billing_country", country->Js.Json.string)]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let klarnaSDKbody = (~token, ~connectors) => [
  ("payment_method", "pay_later"->Js.Json.string),
  ("payment_method_type", "klarna"->Js.Json.string),
  ("payment_experience", "invoke_sdk_client"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("klarna_sdk", [("token", token->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let paypalRedirectionBody = (~connectors) => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "paypal"->Js.Json.string),
  ("payment_experience", "redirect_to_url"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("paypal_redirect", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let paypalSdkBody = (~token, ~connectors) => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "paypal"->Js.Json.string),
  ("payment_experience", "invoke_sdk_client"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("paypal_sdk", [("token", token->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let gpayBody = (~payObj: GooglePayType.paymentData, ~connectors: array<string>) => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "google_pay"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [
          (
            "google_pay",
            [
              ("type", payObj.paymentMethodData.\"type"->Js.Json.string),
              ("description", payObj.paymentMethodData.description->Js.Json.string),
              ("info", payObj.paymentMethodData.info->Utils.transformKeys(Utils.SnakeCase)),
              (
                "tokenization_data",
                payObj.paymentMethodData.tokenizationData->Utils.transformKeys(Utils.SnakeCase),
              ),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let gpayRedirectBody = (~connectors: array<string>) => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "google_pay"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("google_pay_redirect", Js.Dict.empty()->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let gPayThirdPartySdkBody = (~connectors) => {
  [
    ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
    ("payment_method", "wallet"->Js.Json.string),
    ("payment_method_type", "google_pay"->Js.Json.string),
    (
      "payment_method_data",
      [
        (
          "wallet",
          [("google_pay_third_party_sdk", Js.Dict.empty()->Js.Json.object_)]
          ->Js.Dict.fromArray
          ->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
  ]
}

let applePayBody = (~token, ~connectors) => {
  let dict = token->Js.Json.decodeObject->Belt.Option.getWithDefault(Js.Dict.empty())
  let paymentDataString =
    dict
    ->Js.Dict.get("paymentData")
    ->Belt.Option.getWithDefault(Js.Dict.empty()->Js.Json.object_)
    ->Js.Json.stringify
    ->btoa
  dict->Js.Dict.set("paymentData", paymentDataString->Js.Json.string)
  [
    ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
    ("payment_method", "wallet"->Js.Json.string),
    ("payment_method_type", "apple_pay"->Js.Json.string),
    (
      "payment_method_data",
      [
        (
          "wallet",
          [("apple_pay", dict->Js.Json.object_->Utils.transformKeys(SnakeCase))]
          ->Js.Dict.fromArray
          ->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
  ]
}

let applePayRedirectBody = (~connectors) => {
  [
    ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
    ("payment_method", "wallet"->Js.Json.string),
    ("payment_method_type", "apple_pay"->Js.Json.string),
    (
      "payment_method_data",
      [
        (
          "wallet",
          [("apple_pay_redirect", Js.Dict.empty()->Js.Json.object_)]
          ->Js.Dict.fromArray
          ->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
  ]
}

let applePayThirdPartySdkBody = (~connectors) => {
  [
    ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
    ("payment_method", "wallet"->Js.Json.string),
    ("payment_method_type", "apple_pay"->Js.Json.string),
    (
      "payment_method_data",
      [
        (
          "wallet",
          [("apple_pay_third_party_sdk", Js.Dict.empty()->Js.Json.object_)]
          ->Js.Dict.fromArray
          ->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
  ]
}

let affirmBody = () => [
  ("payment_method", "pay_later"->Js.Json.string),
  ("payment_method_type", "affirm"->Js.Json.string),
  ("payment_experience", "redirect_to_url"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("affirm_redirect", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let cryptoBody = (~currency) => [
  ("payment_method", "crypto"->Js.Json.string),
  ("payment_method_type", "crypto_currency"->Js.Json.string),
  ("payment_experience", "redirect_to_url"->Js.Json.string),
  (
    "payment_method_data",
    [("crypto", [("pay_currency", currency->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_)]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let afterpayRedirectionBody = (~fullName, ~email) => [
  ("payment_method", "pay_later"->Js.Json.string),
  ("payment_method_type", "afterpay_clearpay"->Js.Json.string),
  ("payment_experience", "redirect_to_url"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [
          (
            "afterpay_clearpay_redirect",
            [("billing_email", email->Js.Json.string), ("billing_name", fullName->Js.Json.string)]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let giroPayBody = (~name, ~iban="", ()) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "giropay"->Js.Json.string),
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
                [("billing_name", name->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
              ),
              ("bank_account_iban", iban->Js.Json.string),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let sofortBody = (~country, ~name, ~email) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "sofort"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "sofort",
            [
              ("country", (country == "" ? "US" : country)->Js.Json.string),
              ("preferred_language", "en"->Js.Json.string),
              (
                "billing_details",
                [
                  ("billing_name", name->Js.Json.string),
                  ("email", (email == "" ? "test@gmail.com" : email)->Js.Json.string),
                ]
                ->Js.Dict.fromArray
                ->Js.Json.object_,
              ),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let iDealBody = (~name, ~bankName) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "ideal"->Js.Json.string),
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
                [("billing_name", name->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
              ),
              ("bank_name", (bankName == "" ? "american_express" : bankName)->Js.Json.string),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let epsBody = (~name, ~bankName) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "eps"->Js.Json.string),
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
                [("billing_name", name->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
              ),
              ("bank_name", (bankName === "" ? "american_express" : bankName)->Js.Json.string),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let achBankTransferBody = (~email, ~connectors) => [
  ("payment_method", "bank_transfer"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  ("payment_method_type", "ach"->Js.Json.string),
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
                [("email", email->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
              ),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let bacsBankTransferBody = (~email, ~name, ~connectors) => [
  ("payment_method", "bank_transfer"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  ("payment_method_type", "bacs"->Js.Json.string),
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
                [("email", email->Js.Json.string), ("name", name->Js.Json.string)]
                ->Js.Dict.fromArray
                ->Js.Json.object_,
              ),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let sepaBankTransferBody = (~email, ~name, ~country, ~connectors) => [
  ("payment_method", "bank_transfer"->Js.Json.string),
  ("connector", connectors->Utils.getArrofJsonString->Js.Json.array),
  ("payment_method_type", "sepa"->Js.Json.string),
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
                [("email", email->Js.Json.string), ("name", name->Js.Json.string)]
                ->Js.Dict.fromArray
                ->Js.Json.object_,
              ),
              ("country", country->Js.Json.string),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let blikBody = (~blikCode) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "blik"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [("blik", [("blik_code", blikCode->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let p24Body = (~email) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "przelewy24"->Js.Json.string),
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
                [("email", email->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
              ),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let interacBody = (~email, ~country) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "interac"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "interac",
            [("email", email->Js.Json.string), ("country", country->Js.Json.string)]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let mobilePayBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "mobile_pay"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("mobile_pay", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let aliPayRedirectBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "ali_pay"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("ali_pay_redirect", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let aliPayQrBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "ali_pay"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("ali_pay_qr", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let weChatPayRedirectBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "we_chat_pay"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("we_chat_pay_redirect", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let weChatPayQrBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "we_chat_pay"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("we_chat_pay_qr", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let trustlyBody = (~country) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "trustly"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [("trustly", [("country", country->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let finlandOB = () => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "online_banking_finland"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [("online_banking_finland", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let polandOB = (~bank) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "online_banking_poland"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_poland",
            [("issuer", bank->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let czechOB = (~bank) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "online_banking_czech_republic"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_czech_republic",
            [("issuer", bank->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let slovakiaOB = (~bank) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "online_banking_slovakia"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_slovakia",
            [("issuer", bank->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let walleyBody = () => [
  ("payment_method", "pay_later"->Js.Json.string),
  ("payment_method_type", "walley"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("walley_redirect", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let payBrightBody = () => [
  ("payment_method", "pay_later"->Js.Json.string),
  ("payment_method_type", "pay_bright"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("pay_bright_redirect", []->Js.Dict.fromArray->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let mbWayBody = (~phoneNumber) => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "mb_way"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [
          (
            "mb_way_redirect",
            [("telephone_number", phoneNumber->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let twintBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "twint"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("twint_redirect", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let vippsBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "vipps"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("vipps_redirect", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let danaBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "dana"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("dana_redirect", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let goPayBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "go_pay"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("go_pay_redirect", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let kakaoPayBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "kakao_pay"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("kakao_pay_redirect", Js.Dict.empty()->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let gcashBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "gcash"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("gcash_redirect", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let momoBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "momo"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("momo_redirect", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let touchNGoBody = () => [
  ("payment_method", "wallet"->Js.Json.string),
  ("payment_method_type", "touch_n_go"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("touch_n_go_redirect", Js.Dict.empty()->Js.Json.object_)]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let bizumBody = () => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "bizum"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [("bizum", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let rewardBody = (~paymentMethodType) => [
  ("payment_method", "reward"->Js.Json.string),
  ("payment_method_type", paymentMethodType->Js.Json.string),
  ("payment_method_data", "reward"->Js.Json.string),
]

let fpxOBBody = (~bank) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "online_banking_fpx"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_fpx",
            [("issuer", bank->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let thailandOBBody = (~bank) => [
  ("payment_method", "bank_redirect"->Js.Json.string),
  ("payment_method_type", "online_banking_thailand"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [
          (
            "online_banking_thailand",
            [("issuer", bank->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let almaBody = () => [
  ("payment_method", "pay_later"->Js.Json.string),
  ("payment_method_type", "alma"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("alma", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let atomeBody = () => [
  ("payment_method", "pay_later"->Js.Json.string),
  ("payment_method_type", "atome"->Js.Json.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("atome_redirect", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]
let multibancoBody = (~email) => [
  ("payment_method", "bank_transfer"->Js.Json.string),
  ("payment_method_type", "multibanco"->Js.Json.string),
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
                [("email", email->Js.Json.string)]->Js.Dict.fromArray->Js.Json.object_,
              ),
            ]
            ->Js.Dict.fromArray
            ->Js.Json.object_,
          ),
        ]
        ->Js.Dict.fromArray
        ->Js.Json.object_,
      ),
    ]
    ->Js.Dict.fromArray
    ->Js.Json.object_,
  ),
]

let cardRedirectBody = () => {
  [
    ("payment_method", "card_redirect"->Js.Json.string),
    ("payment_method_type", "card_redirect"->Js.Json.string),
    (
      "payment_method_data",
      [
        (
          "card_redirect",
          [("card_redirect", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
  ]
}

let openBankingUKBody = () => {
  [
    ("payment_method", "bank_redirect"->Js.Json.string),
    ("payment_method_type", "open_banking_uk"->Js.Json.string),
    (
      "payment_method_data",
      [
        (
          "bank_redirect",
          [("open_banking_uk", Js.Dict.empty()->Js.Json.object_)]
          ->Js.Dict.fromArray
          ->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
  ]
}

let pixTransferBody = () => {
  [
    ("payment_method", "bank_transfer"->Js.Json.string),
    ("payment_method_type", "pix"->Js.Json.string),
    (
      "payment_method_data",
      [
        (
          "bank_transfer",
          [("pix", Js.Dict.empty()->Js.Json.object_)]->Js.Dict.fromArray->Js.Json.object_,
        ),
      ]
      ->Js.Dict.fromArray
      ->Js.Json.object_,
    ),
  ]
}

let getPaymentBody = (
  ~paymentMethod,
  ~fullName,
  ~email,
  ~country,
  ~bank,
  ~blikCode,
  ~paymentExperience: PaymentMethodsRecord.paymentFlow=RedirectToURL,
  ~phoneNumber,
  ~currency,
) => {
  switch paymentMethod {
  | "affirm" => affirmBody()
  | "afterpay_clearpay" => afterpayRedirectionBody(~fullName, ~email)
  | "crypto_currency" => cryptoBody(~currency)
  | "sofort" => sofortBody(~country, ~name=fullName, ~email)
  | "ideal" => iDealBody(~name=fullName, ~bankName=bank)
  | "eps" => epsBody(~name=fullName, ~bankName=bank)
  | "blik" => blikBody(~blikCode)
  | "mobile_pay" => mobilePayBody()
  | "ali_pay" =>
    switch paymentExperience {
    | QrFlow => aliPayQrBody()
    | RedirectToURL
    | _ =>
      aliPayRedirectBody()
    }
  | "we_chat_pay" =>
    switch paymentExperience {
    | QrFlow => weChatPayQrBody()
    | RedirectToURL
    | _ =>
      weChatPayRedirectBody()
    }
  | "giropay" => giroPayBody(~name=fullName, ())
  | "trustly" => trustlyBody(~country)
  | "online_banking_finland" => finlandOB()
  | "online_banking_poland" => polandOB(~bank)
  | "online_banking_czech_republic" => czechOB(~bank)
  | "online_banking_slovakia" => slovakiaOB(~bank)
  | "walley" => walleyBody()
  | "pay_bright" => payBrightBody()
  | "mb_way" => mbWayBody(~phoneNumber)
  | "interac" => interacBody(~email, ~country)
  | "przelewy24" => p24Body(~email)
  | "twint" => twintBody()
  | "vipps" => vippsBody()
  | "dana" => danaBody()
  | "go_pay" => goPayBody()
  | "kakao_pay" => kakaoPayBody()
  | "gcash" => gcashBody()
  | "momo" => momoBody()
  | "touch_n_go" => touchNGoBody()
  | "bizum" => bizumBody()
  | "online_banking_fpx" => fpxOBBody(~bank)
  | "online_banking_thailand" => thailandOBBody(~bank)
  | "alma" => almaBody()
  | "atome" => atomeBody()
  | "multibanco" => multibancoBody(~email)
  | "classic" => rewardBody(~paymentMethodType=paymentMethod)
  | "card_redirect" => cardRedirectBody()
  | "open_banking_uk" => openBankingUKBody()
  | "evoucher" => rewardBody(~paymentMethodType=paymentMethod)
  | "pix_transfer" => pixTransferBody()
  | _ => []
  }
}
