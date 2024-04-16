@val @scope("window")
external btoa: string => string = "btoa"
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
      [("card", cardBody->Array.concat(cardBrand)->Dict.fromArray->JSON.Encode.object)]
      ->Dict.fromArray
      ->JSON.Encode.object,
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
            [("social_security_number", socialSecurityNumber->JSON.Encode.string)]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let customerAcceptanceBody =
  [
    ("acceptance_type", "online"->JSON.Encode.string),
    ("accepted_at", Date.now()->Js.Date.fromFloat->Date.toISOString->JSON.Encode.string),
    (
      "online",
      [("user_agent", BrowserSpec.navigator.userAgent->JSON.Encode.string)]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
  ->Dict.fromArray
  ->JSON.Encode.object

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
    ("customer_acceptance", customerAcceptanceBody),
  ]

  if requiresCvv {
    savedCardBody->Array.push(("card_cvc", cvcNumber->JSON.Encode.string))->ignore
  }

  if isCustomerAcceptanceRequired {
    savedCardBody->Array.push(("customer_acceptance", customerAcceptanceBody))->ignore
  }

  savedCardBody
}

let mandateBody = paymentType => {
  [
    (
      "mandate_data",
      [("customer_acceptance", customerAcceptanceBody)]->Dict.fromArray->JSON.Encode.object,
    ),
    ("customer_acceptance", customerAcceptanceBody),
    ("setup_future_usage", "off_session"->JSON.Encode.string),
    ("payment_type", {paymentType === "" ? JSON.Encode.null : paymentType->JSON.Encode.string}),
  ]
}

let paymentTypeBody = paymentType => {
  if paymentType != "" {
    [("payment_type", paymentType->JSON.Encode.string)]
  } else {
    []
  }
}

let confirmPayloadForSDKButton = (sdkHandleConfirmPayment: PaymentType.sdkHandleConfirmPayment) =>
  [
    ("redirect", "always"->JSON.Encode.string),
    (
      "confirmParams",
      [("return_url", sdkHandleConfirmPayment.confirmParams.return_url->JSON.Encode.string)]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
  ->Dict.fromArray
  ->JSON.Encode.object

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
                (
                  "billing_details",
                  [
                    ("name", cardHolderName->JSON.Encode.string),
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
                      ]
                      ->Dict.fromArray
                      ->JSON.Encode.object,
                    ),
                  ]
                  ->Dict.fromArray
                  ->JSON.Encode.object,
                ),
                ("account_number", bank.accountNumber->JSON.Encode.string),
                ("bank_account_holder_name", bank.accountHolderName->JSON.Encode.string),
                ("routing_number", bank.routingNumber->JSON.Encode.string),
                ("bank_type", bank.accountType->JSON.Encode.string),
              ]
              ->Dict.fromArray
              ->JSON.Encode.object,
            ),
          ]
          ->Dict.fromArray
          ->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
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
              (
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
                    ]
                    ->Dict.fromArray
                    ->JSON.Encode.object,
                  ),
                ]
                ->Dict.fromArray
                ->JSON.Encode.object,
              ),
              ("iban", data.iban->JSON.Encode.string),
              ("bank_account_holder_name", data.accountHolderName->JSON.Encode.string),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
              (
                "billing_details",
                [
                  ("name", bankAccountHolderName->JSON.Encode.string),
                  ("email", email->JSON.Encode.string),
                  (
                    "address",
                    [
                      ("line1", line1->JSON.Encode.string),
                      ("line2", line2->JSON.Encode.string),
                      ("city", city->JSON.Encode.string),
                      ("zip", zip->JSON.Encode.string),
                      ("state", state->JSON.Encode.string),
                      ("country", country->JSON.Encode.string),
                    ]
                    ->Dict.fromArray
                    ->JSON.Encode.object,
                  ),
                ]
                ->Dict.fromArray
                ->JSON.Encode.object,
              ),
              ("bank_account_holder_name", bankAccountHolderName->JSON.Encode.string),
              ("sort_code", sortCode->JSON.Encode.string),
              ("account_number", accNum->JSON.Encode.string),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
              (
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
                    ]
                    ->Dict.fromArray
                    ->JSON.Encode.object,
                  ),
                ]
                ->Dict.fromArray
                ->JSON.Encode.object,
              ),
              ("bsb_number", data.sortCode->JSON.Encode.string),
              ("account_number", data.accountNumber->JSON.Encode.string),
              ("bank_account_holder_name", data.accountHolderName->JSON.Encode.string),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
        [("klarna_sdk", [("token", token->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
        [("paypal_redirect", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
        [("paypal_sdk", [("token", token->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
        [("google_pay_redirect", Dict.make()->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let gPayThirdPartySdkBody = (~connectors) => {
  [
    ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_type", "google_pay"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "wallet",
          [("google_pay_third_party_sdk", Dict.make()->JSON.Encode.object)]
          ->Dict.fromArray
          ->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
}

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
          [("apple_pay", dict->JSON.Encode.object->Utils.transformKeys(SnakeCase))]
          ->Dict.fromArray
          ->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
}

let applePayRedirectBody = (~connectors) => {
  [
    ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_type", "apple_pay"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "wallet",
          [("apple_pay_redirect", Dict.make()->JSON.Encode.object)]
          ->Dict.fromArray
          ->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
}

let applePayThirdPartySdkBody = (~connectors) => {
  [
    ("connector", connectors->Utils.getArrofJsonString->JSON.Encode.array),
    ("payment_method", "wallet"->JSON.Encode.string),
    ("payment_method_type", "apple_pay"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "wallet",
          [("apple_pay_third_party_sdk", Dict.make()->JSON.Encode.object)]
          ->Dict.fromArray
          ->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
}

let affirmBody = () => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "affirm"->JSON.Encode.string),
  ("payment_experience", "redirect_to_url"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("affirm_redirect", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let cryptoBody = (~currency) => [
  ("payment_method", "crypto"->JSON.Encode.string),
  ("payment_method_type", "crypto_currency"->JSON.Encode.string),
  ("payment_experience", "redirect_to_url"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "crypto",
        [("pay_currency", currency->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                [("billing_name", name->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
              ),
              ("bank_account_iban", iban->JSON.Encode.string),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                ]
                ->Dict.fromArray
                ->JSON.Encode.object,
              ),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                [("billing_name", name->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
              ),
              ("bank_name", (bankName == "" ? "american_express" : bankName)->JSON.Encode.string),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                [("billing_name", name->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
              ),
              ("bank_name", (bankName === "" ? "american_express" : bankName)->JSON.Encode.string),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                [("email", email->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
              ),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                [("email", email->JSON.Encode.string), ("name", name->JSON.Encode.string)]
                ->Dict.fromArray
                ->JSON.Encode.object,
              ),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                [("email", email->JSON.Encode.string), ("name", name->JSON.Encode.string)]
                ->Dict.fromArray
                ->JSON.Encode.object,
              ),
              ("country", country->JSON.Encode.string),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
          (
            "blik",
            [("blik_code", blikCode->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                [("email", email->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
              ),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            [("email", email->JSON.Encode.string), ("country", country->JSON.Encode.string)]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let mobilePayBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "mobile_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("mobile_pay", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let aliPayRedirectBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "ali_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("ali_pay_redirect", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let aliPayQrBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "ali_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("ali_pay_qr", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let weChatPayRedirectBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "we_chat_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("we_chat_pay_redirect", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let weChatPayQrBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "we_chat_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("we_chat_pay_qr", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
          (
            "trustly",
            [("country", country->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let finlandOB = () => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "online_banking_finland"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [("online_banking_finland", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            [("issuer", bank->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            [("issuer", bank->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            [("issuer", bank->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let walleyBody = () => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "walley"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("walley_redirect", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let payBrightBody = () => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "pay_bright"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("pay_bright_redirect", []->Dict.fromArray->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            [("telephone_number", phoneNumber->JSON.Encode.string)]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let twintBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "twint"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("twint_redirect", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let vippsBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "vipps"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("vipps_redirect", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let danaBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "dana"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("dana_redirect", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let goPayBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "go_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("go_pay_redirect", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]
let kakaoPayBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "kakao_pay"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("kakao_pay_redirect", Dict.make()->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let gcashBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "gcash"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("gcash_redirect", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]
let momoBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "momo"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("momo_redirect", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let touchNGoBody = () => [
  ("payment_method", "wallet"->JSON.Encode.string),
  ("payment_method_type", "touch_n_go"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "wallet",
        [("touch_n_go_redirect", Dict.make()->JSON.Encode.object)]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let bizumBody = () => [
  ("payment_method", "bank_redirect"->JSON.Encode.string),
  ("payment_method_type", "bizum"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "bank_redirect",
        [("bizum", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            [("issuer", bank->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
            [("issuer", bank->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]
let almaBody = () => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "alma"->JSON.Encode.string),
  (
    "payment_method_data",
    [("pay_later", [("alma", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object)]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let atomeBody = () => [
  ("payment_method", "pay_later"->JSON.Encode.string),
  ("payment_method_type", "atome"->JSON.Encode.string),
  (
    "payment_method_data",
    [
      (
        "pay_later",
        [("atome_redirect", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
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
                [("email", email->JSON.Encode.string)]->Dict.fromArray->JSON.Encode.object,
              ),
            ]
            ->Dict.fromArray
            ->JSON.Encode.object,
          ),
        ]
        ->Dict.fromArray
        ->JSON.Encode.object,
      ),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  ),
]

let cardRedirectBody = () => {
  [
    ("payment_method", "card_redirect"->JSON.Encode.string),
    ("payment_method_type", "card_redirect"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "card_redirect",
          [("card_redirect", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
}

let openBankingUKBody = () => {
  [
    ("payment_method", "bank_redirect"->JSON.Encode.string),
    ("payment_method_type", "open_banking_uk"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "bank_redirect",
          [("open_banking_uk", Dict.make()->JSON.Encode.object)]
          ->Dict.fromArray
          ->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
}

let pixTransferBody = () => {
  [
    ("payment_method", "bank_transfer"->JSON.Encode.string),
    ("payment_method_type", "pix"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "bank_transfer",
          [("pix", Dict.make()->JSON.Encode.object)]->Dict.fromArray->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
    ),
  ]
}

let localBankTransferBody = () => {
  [
    ("payment_method", "bank_transfer"->JSON.Encode.string),
    ("payment_method_type", "local_bank_transfer"->JSON.Encode.string),
    (
      "payment_method_data",
      [
        (
          "bank_transfer",
          [("local_bank_transfer", Dict.make()->JSON.Encode.object)]
          ->Dict.fromArray
          ->JSON.Encode.object,
        ),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object,
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
  | "local_bank_transfer_transfer" => localBankTransferBody()
  | _ => []
  }
}
