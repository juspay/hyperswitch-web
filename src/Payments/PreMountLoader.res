let sendPromiseData = (promise, key) => {
  let executePromise = async () => {
    let response = try {
      await promise
    } catch {
    | _ => JSON.Encode.null
    }
    Utils.messageParentWindow([("response", response), ("data", key->JSON.Encode.string)])
  }
  executePromise()->ignore
}

let useMessageHandler = getMessageHandler => {
  React.useEffect(_ => {
    let messageHandler = getMessageHandler()

    let setupMessageListener = _ => {
      Window.addEventListener("message", messageHandler)
      Utils.messageParentWindow([("preMountLoaderIframeMountedCallback", true->JSON.Encode.bool)])
    }

    let cleanupMessageListener = _ => {
      Window.removeEventListener("message", messageHandler)
      Utils.messageParentWindow([("preMountLoaderIframeUnMount", true->JSON.Encode.bool)])
    }

    let handleCleanUpEventListener = (ev: Window.event) => {
      open Utils
      let dict = ev.data->safeParse->getDictFromJson
      if dict->Dict.get("cleanUpPreMountLoaderIframe")->Option.isSome {
        cleanupMessageListener()
      }
    }

    Window.addEventListener("message", handleCleanUpEventListener)

    setupMessageListener()

    Some(
      () => {
        cleanupMessageListener()
        Window.removeEventListener("message", handleCleanUpEventListener)
      },
    )
  }, [])
}

let getMessageHandlerV1Elements = (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~merchantHostname,
) => {
  let paymentMethodsPromise = PaymentHelpers.fetchPaymentMethodList(
    ~clientSecret,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
  )

  let customerPaymentMethodsPromise = PaymentHelpers.fetchCustomerPaymentMethodList(
    ~clientSecret,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
  )

  let sessionTokensPromise = Promise.make((res, _) =>
    res(
      {
        "payment_id": "pay_muGLM56ntrMM7qcNFyII",
        "client_secret": "pay_muGLM56ntrMM7qcNFyII_secret_rjp2f13MqQ0DmgFgaeh5",
        "session_token": [
          {
            "wallet_name": "paypal",
            "connector": "paypal",
            "session_token": "ASKAGh2WXgqfQ5TzjpZzLsfhVGlFbjq5VrV5IOX8KXDD2N_XqkGeYNDkWyr_UXnfhXpEkABdmP284b_2",
            "sdk_next_action": {
              "next_action": "post_session_tokens",
            },
            "client_token": null,
            "transaction_info": null,
          }->Identity.anyTypeToJson,
          {
            "wallet_name": "google_pay",
            "merchant_info": {
              "merchant_id": "mpptiscity1",
              "merchant_name": "mpptiscity1",
            },
            "shipping_address_required": false,
            "email_required": false,
            "shipping_address_parameters": {
              "phone_number_required": false,
            },
            "allowed_payment_methods": [
              {
                "type": "CARD",
                "parameters": {
                  "allowed_auth_methods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
                  "allowed_card_networks": [
                    "AMEX",
                    "DISCOVER",
                    "INTERAC",
                    "JCB",
                    "MASTERCARD",
                    "VISA",
                  ],
                  "billing_address_required": false,
                },
                "tokenization_specification": {
                  "type": "PAYMENT_GATEWAY",
                  "parameters": {
                    "gateway": "cybersource",
                    "gateway_merchant_id": "mpptiscity1",
                  },
                },
              },
            ],
            "transaction_info": {
              "country_code": "US",
              "currency_code": "USD",
              "total_price_status": "Final",
              "total_price": "29.99",
            },
            "delayed_session_token": false,
            "connector": "cybersource",
            "sdk_next_action": {
              "next_action": "confirm",
            },
            "secrets": null,
          }->Identity.anyTypeToJson,
          {
            "wallet_name": "apple_pay",
            "payment_request_data": {
              "country_code": "US",
              "currency_code": "USD",
              "total": {
                "label": "apple",
                "type": "final",
                "amount": "29.99",
              },
              "merchant_capabilities": ["supports3DS"],
              "supported_networks": ["visa", "masterCard", "amex", "discover"],
              "merchant_identifier": "merchant.com.noon.juspay",
            },
            "connector": "cybersource",
            "delayed_session_token": false,
            "sdk_next_action": {
              "next_action": "confirm",
            },
            "connector_reference_id": null,
            "connector_sdk_public_key": null,
            "connector_merchant_id": null,
          }->Identity.anyTypeToJson,
        ],
      }->Identity.anyTypeToJson,
    )
  )

  let blockedBinsPromise = PaymentHelpers.fetchBlockedBins(
    ~clientSecret,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
  )

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendPaymentMethodsResponse") {
      paymentMethodsPromise->sendPromiseData("payment_methods")
    } else if dict->isKeyPresentInDict("sendCustomerPaymentMethodsResponse") {
      customerPaymentMethodsPromise->sendPromiseData("customer_payment_methods")
    } else if dict->isKeyPresentInDict("sendSessionTokensResponse") {
      sessionTokensPromise->sendPromiseData("session_tokens")
    } else if dict->isKeyPresentInDict("sendBlockedBinsResponse") {
      blockedBinsPromise->sendPromiseData("blocked_bins")
    }
  }
}

let getMessageHandlerV2Elements = (
  ~clientSecret,
  ~paymentId,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~profileId,
) => {
  let paymentMethodsListPromise = PaymentHelpersV2.fetchPaymentMethodList(
    ~clientSecret,
    ~paymentId,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
    ~profileId,
  )

  let sessionTokensPromise = PaymentHelpersV2.fetchSessions(
    ~clientSecret,
    ~paymentId,
    ~profileId,
    ~publishableKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
  )

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendPaymentMethodsListV2Response") {
      paymentMethodsListPromise->sendPromiseData("payment_methods_list_v2")
    } else if dict->isKeyPresentInDict("sendSessionTokensResponse") {
      sessionTokensPromise->sendPromiseData("session_tokens")
    }
  }
}

let getMessageHandlerV1PMM = (~ephemeralKey, ~logger, ~customPodUri, ~endpoint) => {
  let savedPaymentMethodsPromise = PaymentHelpers.fetchSavedPaymentMethodList(
    ~ephemeralKey,
    ~logger,
    ~customPodUri,
    ~endpoint,
  )

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendSavedPaymentMethodsResponse") {
      savedPaymentMethodsPromise->sendPromiseData("saved_payment_methods")
    }
  }
}

let getMessageHandlerV2PMM = (
  ~pmSessionId,
  ~pmClientSecret,
  ~publishableKey,
  ~profileId,
  ~logger,
  ~customPodUri,
  ~endpoint,
) => {
  let listPromise = PaymentHelpersV2.fetchPaymentManagementList(
    ~pmSessionId,
    ~pmClientSecret,
    ~publishableKey,
    ~profileId,
    ~optLogger=Some(logger),
    ~customPodUri,
    ~endpoint,
  )

  ev => {
    open Utils
    let dict = ev.data->safeParse->getDictFromJson
    if dict->isKeyPresentInDict("sendPaymentManagementListResponse") {
      listPromise->sendPromiseData("payment_management_list")
    }
  }
}

module PreMountLoaderForElements = {
  @react.component
  let make = (
    ~logger,
    ~publishableKey,
    ~clientSecret,
    ~paymentId,
    ~endpoint,
    ~merchantHostname,
    ~customPodUri,
    ~profileId,
  ) => {
    useMessageHandler(() =>
      switch GlobalVars.sdkVersion {
      | V1 =>
        getMessageHandlerV1Elements(
          ~clientSecret,
          ~publishableKey,
          ~logger,
          ~customPodUri,
          ~endpoint,
          ~merchantHostname,
        )
      | V2 =>
        getMessageHandlerV2Elements(
          ~clientSecret,
          ~paymentId,
          ~publishableKey,
          ~logger,
          ~customPodUri,
          ~endpoint,
          ~profileId,
        )
      }
    )

    React.null
  }
}

module PreMountLoaderForPMMElements = {
  @react.component
  let make = (
    ~logger,
    ~endpoint,
    ~ephemeralKey,
    ~customPodUri,
    ~pmSessionId,
    ~pmClientSecret,
    ~publishableKey,
    ~profileId,
  ) => {
    useMessageHandler(() =>
      switch GlobalVars.sdkVersion {
      | V1 => getMessageHandlerV1PMM(~ephemeralKey, ~logger, ~customPodUri, ~endpoint)
      | V2 =>
        getMessageHandlerV2PMM(
          ~pmSessionId,
          ~pmClientSecret,
          ~publishableKey,
          ~profileId,
          ~logger,
          ~customPodUri,
          ~endpoint,
        )
      }
    )

    React.null
  }
}

@react.component
let make = (
  ~sessionId,
  ~publishableKey,
  ~profileId,
  ~clientSecret,
  ~endpoint,
  ~paymentId,
  ~ephemeralKey,
  ~pmSessionId,
  ~pmClientSecret,
  ~hyperComponentName: Types.hyperComponentName,
  ~merchantHostname,
  ~customPodUri,
) => {
  let logger = HyperLogger.make(
    ~sessionId,
    ~source=Loader,
    ~merchantId=publishableKey,
    ~clientSecret,
  )

  switch hyperComponentName {
  | Elements =>
    <PreMountLoaderForElements
      logger publishableKey clientSecret endpoint merchantHostname customPodUri profileId paymentId
    />
  | PaymentMethodsManagementElements =>
    <PreMountLoaderForPMMElements
      logger endpoint ephemeralKey customPodUri pmSessionId pmClientSecret publishableKey profileId
    />
  }
}
