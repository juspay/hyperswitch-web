open Utils

let fetchPaymentManagementList = (
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~profileId,
  ~endpoint,
  ~optLogger,
  ~customPodUri,
) => {
  open Promise
  let headers = [
    ("x-profile-id", `${profileId}`),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}/list-payment-methods`

  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
      res
      ->Fetch.Response.json
      ->then(_ => {
        // JSON.Encode.null->resolve
        // JSON.Encode.null->resolve
        let val = `{
    "payment_methods_enabled": [
        {
            "payment_method_type": "card",
            "payment_method_subtype": "credit",
            "required_fields": [
                {
                    "required_field": "payment_method_data.card.card_number",
                    "display_name": "card_number",
                    "field_type": "user_card_number",
                    "value": null
                },
                {
                    "required_field": "payment_method_data.card.card_exp_year",
                    "display_name": "card_exp_year",
                    "field_type": "user_card_expiry_year",
                    "value": null
                },
                {
                    "required_field": "payment_method_data.card.card_cvc",
                    "display_name": "card_cvc",
                    "field_type": "user_card_cvc",
                    "value": null
                },
                {
                            "required_field": "payment_method_data.billing.address.last_name",
                            "display_name": "card_holder_name",
                            "field_type": "user_full_name",
                            "value": null
                        },
                {
                    "required_field": "payment_method_data.card.card_exp_month",
                    "display_name": "card_exp_month",
                    "field_type": "user_card_expiry_month",
                    "value": null
                },
                        {
                            "required_field": "payment_method_data.billing.address.state",
                            "display_name": "state",
                            "field_type": "user_address_state",
                            "value": null
                        },
                        {
                            "required_field": "payment_method_data.billing.address.city",
                            "display_name": "city",
                            "field_type": "user_address_city",
                            "value": null
                        },
                        {
                            "required_field": "payment_method_data.billing.address.country",
                            "display_name": "country",
                            "field_type": {
                                "user_address_country": {
                                    "options": [
                                        "ALL"
                                    ]
                                }
                            },
                            "value": null
                        }
            ]
        },
        {
            "payment_method_type": "card",
            "payment_method_subtype": "debit",
            "required_fields": []
        }
    ],
    "customer_payment_methods": [
        {
            "id": "12345_pm_0194abb4d9bc735292e1f5682da787ff",
            "customer_id": "12345_cus_0194abb4c1b277e3a6b45551089cfd9e",
            "payment_method_type": "card",
            "payment_method_subtype": "credit",
            "recurring_enabled": true,
            "payment_method_data": {
                "card": {
                    "issuer_country": null,
                    "last4_digits": "4242",
                    "expiry_month": "03",
                    "expiry_year": "2025",
                    "card_holder_name": "joseph Doe",
                    "card_fingerprint": null,
                    "nick_name": "hello123",
                    "card_network": null,
                    "card_isin": null,
                    "card_issuer": null,
                    "card_type": null,
                    "saved_to_locker": true
                }
            },
            "bank": null,
            "created": "2025-01-28T06:59:03.754Z",
            "requires_cvv": true,
            "last_used_at": "2025-01-28T06:59:03.754Z",
            "is_default": false,
            "billing": null
        },
        {
            "id": "12345_pm_0194abb4d9bc735292e1f5682da787hh",
            "customer_id": "12345_cus_0194abb4c1b277e3a6b45551089cfd9e",
            "payment_method_type": "card",
            "payment_method_subtype": "credit",
            "recurring_enabled": true,
            "payment_method_data": {
                "card": {
                    "issuer_country": null,
                    "last4_digits": "4242",
                    "expiry_month": "03",
                    "expiry_year": "2025",
                    "card_holder_name": "joseph Doe",
                    "card_fingerprint": null,
                    "nick_name": "hello123",
                    "card_network": "Visa",
                    "card_isin": null,
                    "card_issuer": null,
                    "card_type": null,
                    "saved_to_locker": true
                }
            },
            "bank": null,
            "created": "2025-01-28T06:59:03.754Z",
            "requires_cvv": true,
            "last_used_at": "2025-01-28T06:59:03.754Z",
            "is_default": false,
            "billing": null
        }
    ]
}`->JSON.parseExn
        val->resolve
      })
    } else {
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let deletePaymentMethodV2 = (
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~paymentMethodId,
  ~logger,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/payment_methods/${paymentMethodId}`
  fetchApi(uri, ~method=#DELETE, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
      resp
      ->Fetch.Response.json
      ->then(_ => {
        JSON.Encode.null->resolve
      })
    } else {
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let updatePaymentMethod = (
  ~bodyArr,
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~paymentMethodId,
  ~logger,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${paymentMethodId}/update-saved-payment-method`

  fetchApi(
    uri,
    ~method=#PUT,
    ~bodyStr=bodyArr->getJsonFromArrayOfJson->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
      resp
      ->Fetch.Response.json
      ->then(_ => {
        JSON.Encode.null->resolve
      })
    } else {
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}

let savePaymentMethod = (
  ~bodyArr,
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  // ~paymentMethodId,
  ~logger,
  ~customPodUri,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [
    ("Content-Type", "application/json"),
    ("Authorization", `publishable-key=${publishableKey},client-secret=${pmClientSecret}`),
  ]
  let uri = `${endpoint}/v2/payment-methods-session/${pmSessionId}/confirm`
  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=bodyArr->getJsonFromArrayOfJson->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status->Int.toString
    if statusCode->String.charAt(0) !== "2" {
      resp
      ->Fetch.Response.json
      ->then(_ => {
        JSON.Encode.null->resolve
      })
    } else {
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Error ", exceptionMessage)
    JSON.Encode.null->resolve
  })
}
