open Utils
open Identity
open PaymentHelpersTypes
open LoggerUtils
open URLModule

let getPaymentType = paymentMethodType =>
  switch paymentMethodType {
  | "apple_pay" => Applepay
  | "samsung_pay" => Samsungpay
  | "google_pay" => Gpay
  | "paze" => Paze
  | "debit"
  | "credit"
  | "" =>
    Card
  | _ => Other
  }

let closePaymentLoaderIfAny = () => messageParentWindow([("fullscreen", false->JSON.Encode.bool)])

let retrievePaymentIntent = (
  clientSecret,
  headers,
  ~optLogger,
  ~customPodUri,
  ~isForceSync=false,
) => {
  open Promise
  let paymentIntentID = clientSecret->Utils.getPaymentId
  let endpoint = ApiEndpoint.getApiEndPoint()
  let forceSync = isForceSync ? "&force_sync=true" : ""
  let uri = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}${forceSync}`

  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=RETRIEVE_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=RETRIEVE_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=RETRIEVE_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(e => {
    Console.error2("Unable to retrieve payment details because of ", e)
    JSON.Encode.null->resolve
  })
}

let threeDsAuth = (~clientSecret, ~optLogger, ~threeDsMethodComp, ~headers) => {
  let endpoint = ApiEndpoint.getApiEndPoint()
  let paymentIntentID = String.split(clientSecret, "_secret_")[0]->Option.getOr("")
  let url = `${endpoint}/payments/${paymentIntentID}/3ds/authentication`
  let broswerInfo = BrowserSpec.broswerInfo
  let body =
    [
      ("client_secret", clientSecret->JSON.Encode.string),
      ("device_channel", "BRW"->JSON.Encode.string),
      ("threeds_method_comp_ind", threeDsMethodComp->JSON.Encode.string),
    ]
    ->Array.concat(broswerInfo())
    ->getJsonFromArrayOfJson

  open Promise
  logApi(
    ~optLogger,
    ~url,
    ~apiLogType=Request,
    ~eventName=AUTHENTICATION_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(url, ~method=#POST, ~bodyStr=body->JSON.stringify, ~headers=headers->Dict.fromArray)
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=AUTHENTICATION_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        let dict = data->getDictFromJson
        let errorObj = PaymentError.itemToObjMapper(dict)
        closePaymentLoaderIfAny()
        postFailedSubmitResponse(~errortype=errorObj.error.type_, ~message=errorObj.error.message)
        JSON.Encode.null->resolve
      })
    } else {
      logApi(~optLogger, ~url, ~statusCode, ~apiLogType=Response, ~eventName=AUTHENTICATION_CALL)
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    Console.error2("Unable to call 3ds auth ", exceptionMessage)
    logApi(
      ~optLogger,
      ~url,
      ~eventName=AUTHENTICATION_CALL,
      ~apiLogType=NoResponse,
      ~data=exceptionMessage,
      ~logType=ERROR,
      ~logCategory=API,
    )
    reject(err)
  })
}

let rec pollRetrievePaymentIntent = (
  clientSecret,
  headers,
  ~optLogger,
  ~customPodUri,
  ~isForceSync=false,
) => {
  open Promise
  retrievePaymentIntent(clientSecret, headers, ~optLogger, ~customPodUri, ~isForceSync)
  ->then(json => {
    let dict = json->getDictFromJson
    let status = dict->getString("status", "")

    if status === "succeeded" || status === "failed" {
      resolve(json)
    } else {
      delay(2000)
      ->then(_val => {
        pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~customPodUri, ~isForceSync)
      })
      ->catch(_ => Promise.resolve(JSON.Encode.null))
    }
  })
  ->catch(e => {
    Console.error2("Unable to retrieve payment due to following error", e)
    pollRetrievePaymentIntent(clientSecret, headers, ~optLogger, ~customPodUri, ~isForceSync)
  })
}

let retrieveStatus = (~headers, ~customPodUri, pollID, logger) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let uri = `${endpoint}/poll/status/${pollID}`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=POLL_STATUS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=POLL_STATUS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=POLL_STATUS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(e => {
    Console.error2("Unable to Poll status details because of ", e)
    JSON.Encode.null->resolve
  })
}

let rec pollStatus = (~headers, ~customPodUri, ~pollId, ~interval, ~count, ~returnUrl, ~logger) => {
  open Promise
  retrieveStatus(~headers, ~customPodUri, pollId, logger)
  ->then(json => {
    let dict = json->getDictFromJson
    let status = dict->getString("status", "")
    Promise.make((resolve, _) => {
      if status === "completed" {
        resolve(json)
      } else if count === 0 {
        messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
        openUrl(returnUrl)
      } else {
        delay(interval)
        ->then(
          _ => {
            pollStatus(
              ~headers,
              ~customPodUri,
              ~pollId,
              ~interval,
              ~count=count - 1,
              ~returnUrl,
              ~logger,
            )->then(
              res => {
                resolve(res)
                Promise.resolve()
              },
            )
          },
        )
        ->catch(_ => Promise.resolve())
        ->ignore
      }
    })
  })
  ->catch(e => {
    Console.error2("Unable to retrieve payment due to following error", e)
    pollStatus(
      ~headers,
      ~customPodUri,
      ~pollId,
      ~interval,
      ~count=count - 1,
      ~returnUrl,
      ~logger,
    )->then(res => resolve(res))
  })
}

let rec intentCall = (
  ~fetchApi: (
    string,
    ~bodyStr: string=?,
    ~headers: Dict.t<string>=?,
    ~method: Fetch.method,
  ) => promise<Fetch.Response.t>,
  ~uri,
  ~headers,
  ~bodyStr,
  ~confirmParam: ConfirmType.confirmParams,
  ~clientSecret,
  ~optLogger,
  ~handleUserError,
  ~paymentType,
  ~iframeId,
  ~fetchMethod,
  ~setIsManualRetryEnabled,
  ~customPodUri,
  ~sdkHandleOneClickConfirmPayment,
  ~counter,
  ~isPaymentSession=false,
  ~isCallbackUsedVal=?,
  ~componentName="payment",
  ~redirectionFlags,
) => {
  open Promise
  let isConfirm = uri->String.includes("/confirm")

  let isCompleteAuthorize = uri->String.includes("/complete_authorize")
  let isPostSessionTokens = uri->String.includes("/post_session_tokens")
  let (eventName: HyperLoggerTypes.eventName, initEventName: HyperLoggerTypes.eventName) = switch (
    isConfirm,
    isCompleteAuthorize,
    isPostSessionTokens,
  ) {
  | (true, _, _) => (CONFIRM_CALL, CONFIRM_CALL_INIT)
  | (_, true, _) => (COMPLETE_AUTHORIZE_CALL, COMPLETE_AUTHORIZE_CALL_INIT)
  | (_, _, true) => (POST_SESSION_TOKENS_CALL, POST_SESSION_TOKENS_CALL_INIT)
  | _ => (RETRIEVE_CALL, RETRIEVE_CALL_INIT)
  }
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=initEventName,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  let handleOpenUrl = url => {
    if isPaymentSession {
      Utils.replaceRootHref(url, redirectionFlags)
    } else {
      openUrl(url)
    }
  }
  fetchApi(
    uri,
    ~method=fetchMethod,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~bodyStr,
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    let url = makeUrl(confirmParam.return_url)
    url.searchParams.set("payment_intent_client_secret", clientSecret)
    url.searchParams.set("status", "failed")
    url.searchParams.set("payment_id", clientSecret->Utils.getPaymentId)
    messageParentWindow([("confirmParams", confirmParam->anyTypeToJson)])

    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        Promise.make(
          (resolve, _) => {
            if isConfirm {
              let paymentMethod = switch paymentType {
              | Card => "CARD"
              | _ =>
                bodyStr
                ->safeParse
                ->getDictFromJson
                ->getString("payment_method_type", "")
              }
              handleLogging(
                ~optLogger,
                ~value=data->JSON.stringify,
                ~eventName=PAYMENT_FAILED,
                ~paymentMethod,
              )
            }
            logApi(
              ~optLogger,
              ~url=uri,
              ~data,
              ~statusCode,
              ~apiLogType=Err,
              ~eventName,
              ~logType=ERROR,
              ~logCategory=API,
              ~isPaymentSession,
            )

            let dict = data->getDictFromJson
            let errorObj = PaymentError.itemToObjMapper(dict)
            if !isPaymentSession {
              closePaymentLoaderIfAny()
              postFailedSubmitResponse(
                ~errortype=errorObj.error.type_,
                ~message=errorObj.error.message,
              )
            }
            if handleUserError {
              handleOpenUrl(url.href)
            } else {
              let failedSubmitResponse = getFailedSubmitResponse(
                ~errorType=errorObj.error.type_,
                ~message=errorObj.error.message,
              )
              resolve(failedSubmitResponse)
            }
          },
        )->then(resolve)
      })
      ->catch(err => {
        Promise.make(
          (resolve, _) => {
            let exceptionMessage = err->formatException
            logApi(
              ~optLogger,
              ~url=uri,
              ~statusCode,
              ~apiLogType=NoResponse,
              ~data=exceptionMessage,
              ~eventName,
              ~logType=ERROR,
              ~logCategory=API,
              ~isPaymentSession,
            )
            if counter >= 5 {
              if !isPaymentSession {
                closePaymentLoaderIfAny()
                postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
              }
              if handleUserError {
                handleOpenUrl(url.href)
              } else {
                let failedSubmitResponse = getFailedSubmitResponse(
                  ~errorType="server_error",
                  ~message="Something went wrong",
                )
                resolve(failedSubmitResponse)
              }
            } else {
              let paymentIntentID = clientSecret->Utils.getPaymentId
              let endpoint = ApiEndpoint.getApiEndPoint(
                ~publishableKey=confirmParam.publishableKey,
                ~isConfirmCall=isConfirm,
              )
              let retrieveUri = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}`
              intentCall(
                ~fetchApi,
                ~uri=retrieveUri,
                ~headers,
                ~bodyStr,
                ~confirmParam: ConfirmType.confirmParams,
                ~clientSecret,
                ~optLogger,
                ~handleUserError,
                ~paymentType,
                ~iframeId,
                ~fetchMethod=#GET,
                ~setIsManualRetryEnabled,
                ~customPodUri,
                ~sdkHandleOneClickConfirmPayment,
                ~counter=counter + 1,
                ~componentName,
                ~redirectionFlags,
              )
              ->then(
                res => {
                  resolve(res)
                  Promise.resolve()
                },
              )
              ->catch(_ => Promise.resolve())
              ->ignore
            }
          },
        )->then(resolve)
      })
    } else {
      res
      ->Fetch.Response.json
      ->then(data => {
        Promise.make(
          (resolve, _) => {
            logApi(
              ~optLogger,
              ~url=uri,
              ~statusCode,
              ~apiLogType=Response,
              ~eventName,
              ~isPaymentSession,
            )
            let val = `{
    "payment_id": "pay_U4BcHpNRIis7z29ixH55",
    "merchant_id": "merchant_1701168699",
    "status": "requires_customer_action",
    "amount": 6500,
    "net_amount": 6500,
    "shipping_cost": null,
    "amount_capturable": 6500,
    "amount_received": null,
    "connector": "checkout",
    "client_secret": "pay_U4BcHpNRIis7z29ixH55_secret_ig6rKZKyukorfQsEvplF",
    "created": "2025-04-28T17:54:09.335Z",
    "currency": "USD",
    "customer_id": "hyperswitch_sdk_demo_id",
    "customer": {
        "id": "hyperswitch_sdk_demo_id",
        "name": "John Doe",
        "email": "user@gmail.com",
        "phone": "999999999",
        "phone_country_code": "+65"
    },
    "description": "Hello this is description",
    "refunds": null,
    "disputes": null,
    "mandate_id": null,
    "mandate_data": null,
    "setup_future_usage": "on_session",
    "off_session": null,
    "capture_on": null,
    "capture_method": "automatic",
    "payment_method": "card",
    "payment_method_data": {
        "card": {
            "last4": "3340",
            "card_type": "DEBIT",
            "card_network": "Mastercard",
            "card_issuer": "MASTERCARD INTERNATIONAL",
            "card_issuing_country": "UNITED STATES",
            "card_isin": "530688",
            "card_extended_bin": null,
            "card_exp_month": "02",
            "card_exp_year": "2026",
            "card_holder_name": null,
            "payment_checks": null,
            "authentication_data": null
        },
        "billing": null
    },
    "payment_token": "token_UihP2BR32aKDGGD3DFxg",
    "shipping": {
        "address": {
            "city": "Banglore",
            "country": "US",
            "line1": "sdsdfsdf",
            "line2": "hsgdbhd",
            "line3": "alsksoe",
            "zip": "571201",
            "state": "California",
            "first_name": "John",
            "last_name": "Doe"
        },
        "phone": {
            "number": "123456789",
            "country_code": "+1"
        },
        "email": null
    },
    "billing": {
        "address": {
            "city": "San Fransico",
            "country": "US",
            "line1": "1467",
            "line2": "Harrison Street",
            "line3": "Harrison Street",
            "zip": "94122",
            "state": "California",
            "first_name": "joseph",
            "last_name": "Doe"
        },
        "phone": {
            "number": "8056594427",
            "country_code": "+91"
        },
        "email": null
    },
    "order_details": [
        {
            "brand": null,
            "amount": 6500,
            "category": null,
            "quantity": 1,
            "tax_rate": null,
            "product_id": null,
            "product_name": "Apple iphone 15",
            "product_type": null,
            "sub_category": null,
            "product_img_link": null,
            "product_tax_code": null,
            "total_tax_amount": null,
            "requires_shipping": null
        }
    ],
    "email": "user@gmail.com",
    "name": "John Doe",
    "phone": "999999999",
    "return_url": "https://hyperswitch-demo-store.netlify.app/?isTestingMode=true&publishableKey=pk_snd_23ff7c6d50e5424ba2e88415772380cd&secretKey=snd_iIwvrJvmQIaYsE8xzdfrbwEdxqmt3xUkiAG3yvyDS6Gsu3aL8bdjDpnMyXb7ANQL&profileId=pro_1PEZIEJyHhhZ3WJTVIVM&environment=Sandbox",
    "authentication_type": "three_ds",
    "statement_descriptor_name": null,
    "statement_descriptor_suffix": null,
    "next_action": {
        "type": "three_ds_invoke",
        "three_ds_data": {
            "three_ds_authentication_url": "https://app.hyperswitch.io/api/payments/pay_U4BcHpNRIis7z29ixH55/3ds/authentication",
            "three_ds_authorize_url": "https://app.hyperswitch.io/api/payments/pay_U4BcHpNRIis7z29ixH55/merchant_1701168699/authorize/checkout",
            "three_ds_method_details": {
                "three_ds_method_key": "threeDSMethodData",
                "three_ds_method_data_submission": true,
                "three_ds_method_data": "eyJ0aHJlZURTTWV0aG9kTm90aWZpY2F0aW9uVVJMIjoiaHR0cHM6Ly9leGFtcGxlLmNvbS8zZHMtbWV0aG9kLW5vdGlmaWNhdGlvbi11cmwiLCJ0aHJlZURTU2VydmVyVHJhbnNJRCI6IjZmNzQ1MzdkLTM1YzAtNGQyYi1iMDE1LTI3ZWE5NzNjYzcyNCJ9",
                "three_ds_method_url": "https://ndm-prev.3dss-non-prod.cloud.netcetera.com/acs/3ds-method"
            },
            "poll_config": {
                "poll_id": "external_authentication_pay_U4BcHpNRIis7z29ixH55",
                "delay_in_secs": 2,
                "frequency": 5
            },
            "message_version": "2.3.1",
            "directory_server_id": "A000000004"
        }
    },
    "cancellation_reason": null,
    "error_code": null,
    "error_message": null,
    "unified_code": null,
    "unified_message": null,
    "payment_experience": null,
    "payment_method_type": "debit",
    "connector_label": null,
    "business_country": null,
    "business_label": null,
    "business_sub_label": null,
    "allowed_payment_method_types": null,
    "ephemeral_key": null,
    "manual_retry_allowed": null,
    "connector_transaction_id": null,
    "frm_message": null,
    "metadata": {
        "udf1": "value1",
        "login_date": "2019-09-10T10:11:12Z",
        "new_customer": "true"
    },
    "connector_metadata": {
        "apple_pay": null,
        "airwallex": null,
        "noon": {
            "order_category": "applepay"
        },
        "braintree": null,
        "adyen": null
    },
    "feature_metadata": null,
    "reference_id": null,
    "payment_link": null,
    "profile_id": "pro_1PEZIEJyHhhZ3WJTVIVM",
    "surcharge_details": null,
    "attempt_count": 1,
    "merchant_decision": null,
    "merchant_connector_id": "mca_OSSNv3tVVO0dp6HbLgsw",
    "incremental_authorization_allowed": null,
    "authorization_count": null,
    "incremental_authorizations": null,
    "external_authentication_details": {
        "authentication_flow": null,
        "electronic_commerce_indicator": null,
        "status": "pending",
        "ds_transaction_id": "6f74537d-35c0-4d2b-b015-27ea973cc724",
        "version": "2.3.1",
        "error_code": null,
        "error_message": null
    },
    "external_3ds_authentication_attempted": true,
    "expires_on": "2025-04-28T18:09:09.335Z",
    "fingerprint": null,
    "browser_info": {
        "os_type": "macOS",
        "language": "en-GB",
        "time_zone": -330,
        "ip_address": "49.36.239.194",
        "os_version": "10.15.7",
        "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36",
        "color_depth": 24,
        "device_model": "Macintosh",
        "java_enabled": true,
        "screen_width": 1728,
        "accept_header": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
        "screen_height": 1117,
        "accept_language": "en-GB,en-US;q=0.9,en;q=0.8",
        "java_script_enabled": true
    },
    "payment_method_id": null,
    "payment_method_status": null,
    "updated": "2025-04-28T17:54:30.351Z",
    "split_payments": null,
    "frm_metadata": null,
    "extended_authorization_applied": null,
    "capture_before": null,
    "merchant_order_reference_id": null,
    "order_tax_amount": null,
    "connector_mandate_id": null,
    "card_discovery": "manual",
    "force_3ds_challenge": false,
    "force_3ds_challenge_trigger": false,
    "issuer_error_code": null,
    "issuer_error_message": null
}`->JSON.parseExn

            let intent = PaymentConfirmTypes.itemToObjMapper(val->getDictFromJson)
            let paymentMethod = switch paymentType {
            | Card => "CARD"
            | _ => intent.payment_method_type
            }

            let url = makeUrl(confirmParam.return_url)
            url.searchParams.set("payment_intent_client_secret", clientSecret)
            url.searchParams.set("payment_id", clientSecret->Utils.getPaymentId)
            url.searchParams.set("status", intent.status)
            // Console.log2("url===>", url)

            let handleProcessingStatus = (paymentType, sdkHandleOneClickConfirmPayment) => {
              // Console.log("here 119999")
              switch (paymentType, sdkHandleOneClickConfirmPayment) {
              | (Card, _)
              | (Gpay, false)
              | (Applepay, false)
              | (Paypal, false) =>
                // Console.log4(
                //   "here 1188777===>",
                //   paymentType,
                //   sdkHandleOneClickConfirmPayment,
                //   isPaymentSession,
                // )
                if !isPaymentSession {
                  // Console.log("here 456545651")
                  if isCallbackUsedVal->Option.getOr(false) {
                    handleOnCompleteDoThisMessage()
                  } else {
                    closePaymentLoaderIfAny()
                  }

                  postSubmitResponse(~jsonData=data, ~url=url.href)
                } else if confirmParam.redirect === Some("always") {
                  // Console.log("Here 22")
                  if isCallbackUsedVal->Option.getOr(false) {
                    handleOnCompleteDoThisMessage()
                  } else {
                    handleOpenUrl(url.href)
                  }
                } else {
                  // Console.log("Here 33")
                  resolve(data)
                }
              | _ =>
                if isCallbackUsedVal->Option.getOr(false) {
                  closePaymentLoaderIfAny()
                  handleOnCompleteDoThisMessage()
                } else {
                  handleOpenUrl(url.href)
                }
              }
            }

            if intent.status == "requires_customer_action" {
              if intent.nextAction.type_ == "redirect_to_url" {
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=intent.nextAction.redirectToUrl,
                  ~eventName=REDIRECTING_USER,
                  ~paymentMethod,
                )
                handleOpenUrl(intent.nextAction.redirectToUrl)
              } else if intent.nextAction.type_ == "display_bank_transfer_information" {
                let metadata = switch intent.nextAction.bank_transfer_steps_and_charges_details {
                | Some(obj) => obj->getDictFromJson
                | None => Dict.make()
                }
                let dict = deepCopyDict(metadata)
                dict->Dict.set("data", data)
                dict->Dict.set("url", url.href->JSON.Encode.string)
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=dict->JSON.Encode.object->JSON.stringify,
                  ~eventName=DISPLAY_BANK_TRANSFER_INFO_PAGE,
                  ~paymentMethod,
                )
                if !isPaymentSession {
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `${intent.payment_method_type}BankTransfer`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", dict->JSON.Encode.object),
                  ])
                }
                resolve(data)
              } else if intent.nextAction.type_ === "qr_code_information" {
                let qrData = intent.nextAction.image_data_url->Option.getOr("")
                let displayText = intent.nextAction.display_text->Option.getOr("")
                let borderColor = intent.nextAction.border_color->Option.getOr("")
                let expiryTime = intent.nextAction.display_to_timestamp->Option.getOr(0.0)
                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)
                let metaData =
                  [
                    ("qrData", qrData->JSON.Encode.string),
                    ("paymentIntentId", clientSecret->JSON.Encode.string),
                    ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                    ("headers", headerObj->JSON.Encode.object),
                    ("expiryTime", expiryTime->Float.toString->JSON.Encode.string),
                    ("url", url.href->JSON.Encode.string),
                    ("paymentMethod", paymentMethod->JSON.Encode.string),
                    ("display_text", displayText->JSON.Encode.string),
                    ("border_color", borderColor->JSON.Encode.string),
                  ]->getJsonFromArrayOfJson
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=metaData->JSON.stringify,
                  ~eventName=DISPLAY_QR_CODE_INFO_PAGE,
                  ~paymentMethod,
                )
                if !isPaymentSession {
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `qrData`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData),
                  ])
                }
                resolve(data)
              } else if intent.nextAction.type_ === "three_ds_invoke" {
                let threeDsData =
                  intent.nextAction.three_ds_data
                  ->Option.flatMap(JSON.Decode.object)
                  ->Option.getOr(Dict.make())
                let do3dsMethodCall =
                  threeDsData
                  ->Dict.get("three_ds_method_details")
                  ->Option.flatMap(JSON.Decode.object)
                  ->Option.flatMap(x => x->Dict.get("three_ds_method_data_submission"))
                  ->Option.getOr(Dict.make()->JSON.Encode.object)
                  ->JSON.Decode.bool
                  ->getBoolValue

                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)

                let metaData =
                  [
                    ("threeDSData", threeDsData->JSON.Encode.object),
                    ("paymentIntentId", clientSecret->JSON.Encode.string),
                    ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                    ("headers", headerObj->JSON.Encode.object),
                    ("url", url.href->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                  ]->Dict.fromArray

                handleLogging(
                  ~optLogger,
                  ~value=do3dsMethodCall ? "Y" : "N",
                  ~eventName=THREE_DS_METHOD,
                  ~paymentMethod,
                )

                if do3dsMethodCall {
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `3ds`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData->JSON.Encode.object),
                  ])
                } else {
                  metaData->Dict.set("3dsMethodComp", "U"->JSON.Encode.string)
                  messageParentWindow([
                    ("fullscreen", true->JSON.Encode.bool),
                    ("param", `3dsAuth`->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("metadata", metaData->JSON.Encode.object),
                  ])
                }
              } else if intent.nextAction.type_ === "invoke_hidden_iframe" {
                let iframeData =
                  intent.nextAction.iframe_data
                  ->Option.flatMap(JSON.Decode.object)
                  ->Option.getOr(Dict.make())

                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)
                let metaData =
                  [
                    ("iframeData", iframeData->JSON.Encode.object),
                    ("paymentIntentId", clientSecret->JSON.Encode.string),
                    ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                    ("headers", headerObj->JSON.Encode.object),
                    ("url", url.href->JSON.Encode.string),
                    ("iframeId", iframeId->JSON.Encode.string),
                    ("confirmParams", confirmParam->anyTypeToJson),
                  ]->Dict.fromArray

                messageParentWindow([
                  ("fullscreen", true->JSON.Encode.bool),
                  ("param", `redsys3ds`->JSON.Encode.string),
                  ("iframeId", iframeId->JSON.Encode.string),
                  ("metadata", metaData->JSON.Encode.object),
                ])
              } else if intent.nextAction.type_ === "display_voucher_information" {
                let voucherData = intent.nextAction.voucher_details->Option.getOr({
                  download_url: "",
                  reference: "",
                })
                let headerObj = Dict.make()
                mergeHeadersIntoDict(~dict=headerObj, ~headers)
                let metaData =
                  [
                    ("voucherUrl", voucherData.download_url->JSON.Encode.string),
                    ("reference", voucherData.reference->JSON.Encode.string),
                    ("returnUrl", url.href->JSON.Encode.string),
                    ("paymentMethod", paymentMethod->JSON.Encode.string),
                    ("payment_intent_data", data),
                  ]->Dict.fromArray
                handleLogging(
                  ~optLogger,
                  ~value="",
                  ~internalMetadata=metaData->JSON.Encode.object->JSON.stringify,
                  ~eventName=DISPLAY_VOUCHER,
                  ~paymentMethod,
                )
                messageParentWindow([
                  ("fullscreen", true->JSON.Encode.bool),
                  ("param", `voucherData`->JSON.Encode.string),
                  ("iframeId", iframeId->JSON.Encode.string),
                  ("metadata", metaData->JSON.Encode.object),
                ])
              } else if intent.nextAction.type_ == "third_party_sdk_session_token" {
                let session_token = switch intent.nextAction.session_token {
                | Some(token) => token->getDictFromJson
                | None => Dict.make()
                }
                let walletName = session_token->getString("wallet_name", "")

                let message = switch walletName {
                | "apple_pay" => [
                    ("applePayButtonClicked", true->JSON.Encode.bool),
                    ("applePayPresent", session_token->anyTypeToJson),
                    ("componentName", componentName->JSON.Encode.string),
                  ]
                | "google_pay" => [("googlePayThirdPartyFlow", session_token->anyTypeToJson)]
                | "open_banking" => {
                    let metaData = [
                      (
                        "linkToken",
                        session_token
                        ->getString("open_banking_session_token", "")
                        ->JSON.Encode.string,
                      ),
                      ("pmAuthConnectorArray", ["plaid"]->anyTypeToJson),
                      ("publishableKey", confirmParam.publishableKey->JSON.Encode.string),
                      ("clientSecret", clientSecret->JSON.Encode.string),
                      ("isForceSync", true->JSON.Encode.bool),
                    ]->getJsonFromArrayOfJson
                    [
                      ("fullscreen", true->JSON.Encode.bool),
                      ("param", "plaidSDK"->JSON.Encode.string),
                      ("iframeId", iframeId->JSON.Encode.string),
                      ("metadata", metaData),
                    ]
                  }
                | _ => []
                }

                if !isPaymentSession {
                  messageParentWindow(message)
                }
                resolve(data)
              } else if intent.nextAction.type_ === "invoke_sdk_client" {
                let nextActionData =
                  intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
                let response =
                  [
                    ("orderId", intent.connectorTransactionId->JSON.Encode.string),
                    ("nextActionData", nextActionData),
                  ]->getJsonFromArrayOfJson
                resolve(response)
              } else {
                if !isPaymentSession {
                  postFailedSubmitResponse(
                    ~errortype="confirm_payment_failed",
                    ~message="Payment failed. Try again!",
                  )
                }
                if uri->String.includes("force_sync=true") {
                  handleLogging(
                    ~optLogger,
                    ~value=intent.nextAction.type_,
                    ~internalMetadata=intent.nextAction.type_,
                    ~eventName=REDIRECTING_USER,
                    ~paymentMethod,
                    ~logType=ERROR,
                  )
                  handleOpenUrl(url.href)
                } else {
                  let failedSubmitResponse = getFailedSubmitResponse(
                    ~errorType="confirm_payment_failed",
                    ~message="Payment failed. Try again!",
                  )
                  resolve(failedSubmitResponse)
                }
              }
            } else if intent.status == "requires_payment_method" {
              if intent.nextAction.type_ === "invoke_sdk_client" {
                let nextActionData =
                  intent.nextAction.next_action_data->Option.getOr(JSON.Encode.null)
                let response =
                  [
                    ("orderId", intent.connectorTransactionId->JSON.Encode.string),
                    ("nextActionData", nextActionData),
                  ]->getJsonFromArrayOfJson
                resolve(response)
              }
            } else if intent.status == "processing" {
              if intent.nextAction.type_ == "third_party_sdk_session_token" {
                let session_token = switch intent.nextAction.session_token {
                | Some(token) => token->getDictFromJson
                | None => Dict.make()
                }
                let walletName = session_token->getString("wallet_name", "")
                let message = switch walletName {
                | "apple_pay" => [
                    ("applePayButtonClicked", true->JSON.Encode.bool),
                    ("applePayPresent", session_token->anyTypeToJson),
                  ]
                | "google_pay" => [("googlePayThirdPartyFlow", session_token->anyTypeToJson)]
                | _ => []
                }

                if !isPaymentSession {
                  messageParentWindow(message)
                }
              } else {
                handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
              }
              resolve(data)
            } else if intent.status != "" {
              // Console.log("here 11")
              if intent.status === "succeeded" {
                handleLogging(
                  ~optLogger,
                  ~value=intent.status,
                  ~eventName=PAYMENT_SUCCESS,
                  ~paymentMethod,
                )
              } else if intent.status === "failed" {
                handleLogging(
                  ~optLogger,
                  ~value=intent.status,
                  ~eventName=PAYMENT_FAILED,
                  ~paymentMethod,
                )
              }
              if intent.status === "failed" {
                setIsManualRetryEnabled(_ => intent.manualRetryAllowed)
              }
              handleProcessingStatus(paymentType, sdkHandleOneClickConfirmPayment)
            } else if !isPaymentSession {
              postFailedSubmitResponse(
                ~errortype="confirm_payment_failed",
                ~message="Payment failed. Try again!",
              )
            } else {
              let failedSubmitResponse = getFailedSubmitResponse(
                ~errorType="confirm_payment_failed",
                ~message="Payment failed. Try again!",
              )
              resolve(failedSubmitResponse)
            }
          },
        )->then(resolve)
      })
    }
  })
  ->catch(err => {
    Promise.make((resolve, _) => {
      try {
        let url = makeUrl(confirmParam.return_url)
        url.searchParams.set("payment_intent_client_secret", clientSecret)
        url.searchParams.set("payment_id", clientSecret->Utils.getPaymentId)
        url.searchParams.set("status", "failed")
        let exceptionMessage = err->formatException
        logApi(
          ~optLogger,
          ~url=uri,
          ~eventName,
          ~apiLogType=NoResponse,
          ~data=exceptionMessage,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        if counter >= 5 {
          if !isPaymentSession {
            closePaymentLoaderIfAny()
            postFailedSubmitResponse(~errortype="server_error", ~message="Something went wrong")
          }
          if handleUserError {
            handleOpenUrl(url.href)
          } else {
            let failedSubmitResponse = getFailedSubmitResponse(
              ~errorType="server_error",
              ~message="Something went wrong",
            )
            resolve(failedSubmitResponse)
          }
        } else {
          let paymentIntentID = clientSecret->Utils.getPaymentId
          let endpoint = ApiEndpoint.getApiEndPoint(
            ~publishableKey=confirmParam.publishableKey,
            ~isConfirmCall=isConfirm,
          )
          let retrieveUri = `${endpoint}/payments/${paymentIntentID}?client_secret=${clientSecret}`
          intentCall(
            ~fetchApi,
            ~uri=retrieveUri,
            ~headers,
            ~bodyStr,
            ~confirmParam: ConfirmType.confirmParams,
            ~clientSecret,
            ~optLogger,
            ~handleUserError,
            ~paymentType,
            ~iframeId,
            ~fetchMethod=#GET,
            ~setIsManualRetryEnabled,
            ~customPodUri,
            ~sdkHandleOneClickConfirmPayment,
            ~counter=counter + 1,
            ~isPaymentSession,
            ~componentName,
            ~redirectionFlags,
          )
          ->then(
            res => {
              resolve(res)
              Promise.resolve()
            },
          )
          ->catch(_ => Promise.resolve())
          ->ignore
        }
      } catch {
      | _ =>
        if !isPaymentSession {
          postFailedSubmitResponse(~errortype="error", ~message="Something went wrong")
        }
        let failedSubmitResponse = getFailedSubmitResponse(
          ~errorType="server_error",
          ~message="Something went wrong",
        )
        resolve(failedSubmitResponse)
      }
    })->then(resolve)
  })
}

let usePaymentSync = (optLogger: option<HyperLoggerTypes.loggerMake>, paymentType: payment) => {
  open RecoilAtoms
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCompleteCallbackUsed)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  (~handleUserError=false, ~confirmParam: ConfirmType.confirmParams, ~iframeId="") => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->Utils.getPaymentId
      let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let uri = `${endpoint}/payments/${paymentIntentID}?force_sync=true&client_secret=${clientSecret}`

      let paymentSync = () => {
        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr="",
          ~confirmParam: ConfirmType.confirmParams,
          ~clientSecret,
          ~optLogger,
          ~handleUserError,
          ~paymentType,
          ~iframeId,
          ~fetchMethod=#GET,
          ~setIsManualRetryEnabled,
          ~customPodUri,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~counter=0,
          ~isCallbackUsedVal,
          ~redirectionFlags,
        )->ignore
      }
      switch paymentMethodList {
      | Loaded(_) => paymentSync()
      | _ => ()
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="sync_payment_failed",
        ~message="Sync Payment Failed. Try Again!",
      )
    }
  }
}

let maskStr = str => str->Js.String2.replaceByRe(%re(`/\S/g`), "x")

let rec maskPayload = payloadJson => {
  switch payloadJson->JSON.Classify.classify {
  | Object(valueDict) =>
    valueDict
    ->Dict.toArray
    ->Array.map(entry => {
      let (key, value) = entry
      (key, maskPayload(value))
    })
    ->getJsonFromArrayOfJson

  | Array(arr) => arr->Array.map(maskPayload)->JSON.Encode.array
  | String(valueStr) => valueStr->maskStr->JSON.Encode.string
  | Number(float) => Float.toString(float)->maskStr->JSON.Encode.string
  | Bool(bool) => (bool ? "true" : "false")->JSON.Encode.string
  | Null => JSON.Encode.string("null")
  }
}

let useCompleteAuthorizeHandler = () => {
  open RecoilAtoms

  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(isCompleteCallbackUsed)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)

  (
    ~clientSecret: option<string>,
    ~bodyArr,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId,
    ~optLogger,
    ~handleUserError,
    ~paymentType,
    ~sdkHandleOneClickConfirmPayment,
    ~headers: option<array<(string, string)>>=?,
    ~paymentMode: option<string>=?,
  ) =>
    switch clientSecret {
    | Some(cs) =>
      let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey=confirmParam.publishableKey)
      let uri = `${endpoint}/payments/${cs->Utils.getPaymentId}/complete_authorize`

      let finalHeaders = switch headers {
      | Some(h) => h
      | None => [
          ("Content-Type", "application/json"),
          ("api-key", confirmParam.publishableKey),
          ("X-Client-Source", paymentMode->Option.getOr("")),
        ]
      }
      let bodyStr =
        [("client_secret", cs->JSON.Encode.string)]
        ->Array.concatMany([bodyArr, BrowserSpec.broswerInfo()])
        ->getJsonFromArrayOfJson
        ->JSON.stringify

      intentCall(
        ~fetchApi,
        ~uri,
        ~headers=finalHeaders,
        ~bodyStr,
        ~confirmParam,
        ~clientSecret=cs,
        ~optLogger,
        ~handleUserError,
        ~paymentType,
        ~iframeId,
        ~fetchMethod=#POST,
        ~setIsManualRetryEnabled,
        ~customPodUri,
        ~sdkHandleOneClickConfirmPayment,
        ~counter=0,
        ~isCallbackUsedVal,
        ~redirectionFlags,
      )->ignore
    | None =>
      postFailedSubmitResponse(
        ~errortype="complete_authorize_failed",
        ~message="Complete Authorize Failed. Try Again!",
      )
    }
}

let useCompleteAuthorize = (optLogger, paymentType) => {
  let completeAuthorizeHandler = useCompleteAuthorizeHandler()
  let keys = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)
  let url = RescriptReactRouter.useUrl()
  let mode =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")
    ->CardThemeType.getPaymentMode
    ->CardThemeType.getPaymentModeToStrMapper

  (~handleUserError=false, ~bodyArr, ~confirmParam, ~iframeId=keys.iframeId) =>
    switch paymentMethodList {
    | Loaded(_) =>
      completeAuthorizeHandler(
        ~clientSecret=keys.clientSecret,
        ~bodyArr,
        ~confirmParam,
        ~iframeId,
        ~optLogger,
        ~handleUserError,
        ~paymentType,
        ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
        ~paymentMode=mode,
      )
    | _ => ()
    }
}

let useRedsysCompleteAuthorize = optLogger => {
  let completeAuthorizeHandler = useCompleteAuthorizeHandler()
  (
    ~handleUserError=false,
    ~bodyArr,
    ~confirmParam,
    ~iframeId="redsys3ds",
    ~clientSecret,
    ~headers,
  ) =>
    completeAuthorizeHandler(
      ~clientSecret,
      ~bodyArr,
      ~confirmParam,
      ~iframeId,
      ~optLogger,
      ~handleUserError,
      ~paymentType=Card,
      ~sdkHandleOneClickConfirmPayment=false,
      ~headers,
    )
}

let usePaymentIntent = (optLogger, paymentType) => {
  open RecoilAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let paymentTypeFromUrl = componentName->CardThemeType.getPaymentMode
  let blockConfirm = Recoil.useRecoilValueFromAtom(isConfirmBlocked)
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let isCallbackUsedVal = Recoil.useRecoilValueFromAtom(RecoilAtoms.isCompleteCallbackUsed)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(redirectionFlagsAtom)

  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    ~intentCallback=_ => (),
    ~manualRetry=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->Utils.getPaymentId
      let headers = [
        ("Content-Type", "application/json"),
        ("api-key", confirmParam.publishableKey),
        ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
      ]
      let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]
      let manual_retry = manualRetry ? [("retry_action", "manual_retry"->JSON.Encode.string)] : []
      let body =
        [("client_secret", clientSecret->JSON.Encode.string)]->Array.concatMany([
          returnUrlArr,
          manual_retry,
        ])
      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let uri = `${endpoint}/payments/${paymentIntentID}/confirm`

      let callIntent = body => {
        let contentLength = body->String.length->Int.toString
        let maskedPayload =
          body->safeParseOpt->Option.getOr(JSON.Encode.null)->maskPayload->JSON.stringify
        let loggerPayload =
          [
            ("payload", maskedPayload->JSON.Encode.string),
            (
              "headers",
              headers
              ->Array.map(header => {
                let (key, value) = header
                (key, value->JSON.Encode.string)
              })
              ->getJsonFromArrayOfJson,
            ),
          ]
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        switch paymentType {
        | Card =>
          handleLogging(
            ~optLogger,
            ~internalMetadata=loggerPayload,
            ~value=contentLength,
            ~eventName=PAYMENT_ATTEMPT,
            ~paymentMethod="CARD",
          )
        | _ =>
          bodyArr->Array.forEach(((str, json)) => {
            if str === "payment_method_type" {
              handleLogging(
                ~optLogger,
                ~value=contentLength,
                ~internalMetadata=loggerPayload,
                ~eventName=PAYMENT_ATTEMPT,
                ~paymentMethod=json->getStringFromJson(""),
              )
            }
            ()
          })
        }
        if blockConfirm && GlobalVars.isInteg {
          Console.warn2("CONFIRM IS BLOCKED - Body", body)
          Console.warn2(
            "CONFIRM IS BLOCKED - Headers",
            headers->Dict.fromArray->Identity.anyTypeToJson->JSON.stringify,
          )
        } else {
          intentCall(
            ~fetchApi,
            ~uri,
            ~headers,
            ~bodyStr=body,
            ~confirmParam: ConfirmType.confirmParams,
            ~clientSecret,
            ~optLogger,
            ~handleUserError,
            ~paymentType,
            ~iframeId,
            ~fetchMethod=#POST,
            ~setIsManualRetryEnabled,
            ~customPodUri,
            ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
            ~counter=0,
            ~isCallbackUsedVal,
            ~componentName,
            ~redirectionFlags,
          )
          ->then(val => {
            intentCallback(val)
            resolve()
          })
          ->catch(_ => resolve())
          ->ignore
        }
      }

      let broswerInfo = BrowserSpec.broswerInfo
      let intentWithoutMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concatMany([
            bodyArr->Array.concat(broswerInfo()),
            mandatePaymentType->PaymentBody.paymentTypeBody,
          ])
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      let intentWithMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concat(
            bodyArr->Array.concatMany([PaymentBody.mandateBody(mandatePaymentType), broswerInfo()]),
          )
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      switch paymentMethodList {
      | LoadError(data)
      | Loaded(data) =>
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapper
        let mandatePaymentType =
          paymentList.payment_type->PaymentMethodsRecord.paymentTypeToStringMapper
        if paymentList.payment_methods->Array.length > 0 {
          switch paymentList.mandate_payment {
          | Some(_) =>
            switch paymentType {
            | Card
            | Gpay
            | Applepay
            | KlarnaRedirect
            | Paypal
            | BankDebits =>
              intentWithMandate(mandatePaymentType)
            | _ => intentWithoutMandate(mandatePaymentType)
            }
          | None => intentWithoutMandate(mandatePaymentType)
          }
        } else {
          postFailedSubmitResponse(
            ~errortype="payment_methods_empty",
            ~message="Payment Failed. Try again!",
          )
          Console.warn("Please enable atleast one Payment method.")
        }
      | SemiLoaded => intentWithoutMandate("")
      | _ =>
        postFailedSubmitResponse(
          ~errortype="payment_methods_loading",
          ~message="Please wait. Try again!",
        )
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="confirm_payment_failed",
        ~message="Payment failed. Try again!",
      )
    }
  }
}

let fetchSessions = (
  ~clientSecret,
  ~publishableKey,
  ~wallets=[],
  ~isDelayedSessionToken=false,
  ~optLogger,
  ~customPodUri,
  ~endpoint,
  ~isPaymentSession=false,
  ~merchantHostname=Window.Location.hostname,
) => {
  open Promise
  let headers = [
    ("Content-Type", "application/json"),
    ("api-key", publishableKey),
    ("X-Merchant-Domain", merchantHostname),
  ]
  let paymentIntentID = clientSecret->Utils.getPaymentId
  let body =
    [
      ("payment_id", paymentIntentID->JSON.Encode.string),
      ("client_secret", clientSecret->JSON.Encode.string),
      ("wallets", wallets->JSON.Encode.array),
      ("delayed_session_token", isDelayedSessionToken->JSON.Encode.bool),
    ]->getJsonFromArrayOfJson
  let uri = `${endpoint}/payments/session_tokens`
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=SESSIONS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=SESSIONS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=SESSIONS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        ~isPaymentSession,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=SESSIONS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      ~isPaymentSession,
    )
    JSON.Encode.null->resolve
  })
}

let confirmPayout = (~clientSecret, ~publishableKey, ~logger, ~customPodUri, ~uri, ~body) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=CONFIRM_PAYOUT_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  let body =
    body
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status

    resp
    ->Fetch.Response.json
    ->then(data => {
      if !(resp->Fetch.Response.ok) {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CONFIRM_PAYOUT_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
      } else {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~statusCode,
          ~apiLogType=Response,
          ~eventName=CONFIRM_PAYOUT_CALL,
          ~logType=INFO,
          ~logCategory=API,
        )
      }
      resolve(data)
    })
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CONFIRM_PAYOUT_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let createPaymentMethod = (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
  ~body,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  let uri = `${endpoint}/payment_methods`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  let body =
    body
    ->Array.concat([("client_secret", clientSecret->JSON.Encode.string)])
    ->getJsonFromArrayOfJson

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=body->JSON.stringify,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CREATE_CUSTOMER_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let fetchPaymentMethodList = (
  ~clientSecret,
  ~publishableKey,
  ~logger,
  ~customPodUri,
  ~endpoint,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  let uri = `${endpoint}/account/payment_methods?client_secret=${clientSecret}`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let fetchCustomerPaymentMethodList = (
  ~clientSecret,
  ~publishableKey,
  ~endpoint,
  ~optLogger,
  ~customPodUri,
  ~isPaymentSession=false,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]
  let uri = `${endpoint}/customers/payment_methods?client_secret=${clientSecret}`
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=CUSTOMER_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        ~isPaymentSession,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      ~isPaymentSession,
    )
    JSON.Encode.null->resolve
  })
}

let paymentIntentForPaymentSession = (
  ~body,
  ~paymentType,
  ~payload,
  ~publishableKey,
  ~clientSecret,
  ~logger,
  ~customPodUri,
  ~redirectionFlags,
) => {
  let confirmParams =
    payload
    ->getDictFromJson
    ->getDictFromDict("confirmParams")

  let redirect = confirmParams->getString("redirect", "if_required")

  let returnUrl = confirmParams->getString("return_url", "")

  let confirmParam: ConfirmType.confirmParams = {
    return_url: returnUrl,
    publishableKey,
    redirect,
  }

  let paymentIntentID = String.split(clientSecret, "_secret_")[0]->Option.getOr("")

  let endpoint = ApiEndpoint.getApiEndPoint(
    ~publishableKey=confirmParam.publishableKey,
    ~isConfirmCall=true,
  )
  let uri = `${endpoint}/payments/${paymentIntentID}/confirm`
  let headers = [("Content-Type", "application/json"), ("api-key", confirmParam.publishableKey)]

  let broswerInfo = BrowserSpec.broswerInfo()

  let returnUrlArr = [("return_url", confirmParam.return_url->JSON.Encode.string)]

  let bodyStr =
    body
    ->Array.concatMany([
      broswerInfo,
      [("client_secret", clientSecret->JSON.Encode.string)],
      returnUrlArr,
    ])
    ->getJsonFromArrayOfJson
    ->JSON.stringify

  intentCall(
    ~fetchApi,
    ~uri,
    ~headers,
    ~bodyStr,
    ~confirmParam: ConfirmType.confirmParams,
    ~clientSecret,
    ~optLogger=Some(logger),
    ~handleUserError=false,
    ~paymentType,
    ~iframeId="",
    ~fetchMethod=#POST,
    ~setIsManualRetryEnabled={_ => ()},
    ~customPodUri,
    ~sdkHandleOneClickConfirmPayment=false,
    ~counter=0,
    ~isPaymentSession=true,
    ~redirectionFlags,
  )
}

let callAuthLink = (
  ~publishableKey,
  ~clientSecret,
  ~paymentMethodType,
  ~pmAuthConnectorsArr,
  ~iframeId,
  ~optLogger,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let uri = `${endpoint}/payment_methods/auth/link`
  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]->Dict.fromArray

  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=[
      ("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string),
      ("payment_id", clientSecret->Option.getOr("")->Utils.getPaymentId->JSON.Encode.string),
      ("payment_method", "bank_debit"->JSON.Encode.string),
      ("payment_method_type", paymentMethodType->JSON.Encode.string),
    ]
    ->getJsonFromArrayOfJson
    ->JSON.stringify,
    ~headers,
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      res
      ->Fetch.Response.json
      ->then(data => {
        let metaData =
          [
            ("linkToken", data->getDictFromJson->getString("link_token", "")->JSON.Encode.string),
            ("pmAuthConnectorArray", pmAuthConnectorsArr->anyTypeToJson),
            ("publishableKey", publishableKey->JSON.Encode.string),
            ("clientSecret", clientSecret->Option.getOr("")->JSON.Encode.string),
            ("isForceSync", false->JSON.Encode.bool),
          ]->getJsonFromArrayOfJson

        messageParentWindow([
          ("fullscreen", true->JSON.Encode.bool),
          ("param", "plaidSDK"->JSON.Encode.string),
          ("iframeId", iframeId->JSON.Encode.string),
          ("metadata", metaData),
        ])
        logApi(
          ~optLogger,
          ~url=uri,
          ~statusCode,
          ~apiLogType=Response,
          ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL,
          ~logType=INFO,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    }
  })
  ->catch(e => {
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=PAYMENT_METHODS_AUTH_LINK_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data={e->formatException},
    )
    Console.error2("Unable to retrieve payment_methods auth/link because of ", e)
    JSON.Encode.null->resolve
  })
}

let callAuthExchange = (
  ~publicToken,
  ~clientSecret,
  ~paymentMethodType,
  ~publishableKey,
  ~setOptionValue: (PaymentType.options => PaymentType.options) => unit,
  ~optLogger,
) => {
  open Promise
  open PaymentType
  let endpoint = ApiEndpoint.getApiEndPoint()
  let logger = HyperLogger.make(~source=Elements(Payment))
  let uri = `${endpoint}/payment_methods/auth/exchange`
  let updatedBody = [
    ("client_secret", clientSecret->Option.getOr("")->JSON.Encode.string),
    ("payment_id", clientSecret->Option.getOr("")->Utils.getPaymentId->JSON.Encode.string),
    ("payment_method", "bank_debit"->JSON.Encode.string),
    ("payment_method_type", paymentMethodType->JSON.Encode.string),
    ("public_token", publicToken->JSON.Encode.string),
  ]

  let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]->Dict.fromArray

  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )

  fetchApi(
    uri,
    ~method=#POST,
    ~bodyStr=updatedBody->getJsonFromArrayOfJson->JSON.stringify,
    ~headers,
  )
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      fetchCustomerPaymentMethodList(
        ~clientSecret=clientSecret->Option.getOr(""),
        ~publishableKey,
        ~optLogger=Some(logger),
        ~customPodUri="",
        ~endpoint,
      )
      ->then(customerListResponse => {
        let customerListResponse =
          [("customerPaymentMethods", customerListResponse)]->Dict.fromArray
        setOptionValue(
          prev => {
            ...prev,
            customerPaymentMethods: customerListResponse->createCustomerObjArr(
              "customerPaymentMethods",
            ),
          },
        )
        JSON.Encode.null->resolve
      })
      ->catch(e => {
        Console.error2(
          "Unable to retrieve customer/payment_methods after auth/exchange because of ",
          e,
        )
        JSON.Encode.null->resolve
      })
    }
  })
  ->catch(e => {
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=PAYMENT_METHODS_AUTH_EXCHANGE_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data={e->formatException},
    )
    Console.error2("Unable to retrieve payment_methods auth/exchange because of ", e)
    JSON.Encode.null->resolve
  })
}

let fetchSavedPaymentMethodList = (
  ~ephemeralKey,
  ~endpoint,
  ~optLogger,
  ~customPodUri,
  ~isPaymentSession=false,
) => {
  open Promise
  let headers = [("Content-Type", "application/json"), ("api-key", ephemeralKey)]
  let uri = `${endpoint}/customers/payment_methods`
  logApi(
    ~optLogger,
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=SAVED_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession,
  )
  fetchApi(uri, ~method=#GET, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(res => {
    let statusCode = res->Fetch.Response.status
    if !(res->Fetch.Response.ok) {
      res
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger,
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
          ~isPaymentSession,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger,
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
        ~isPaymentSession,
      )
      res->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger,
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=CUSTOMER_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
      ~isPaymentSession,
    )
    JSON.Encode.null->resolve
  })
}

let deletePaymentMethod = (~ephemeralKey, ~paymentMethodId, ~logger, ~customPodUri) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Content-Type", "application/json"), ("api-key", ephemeralKey)]
  let uri = `${endpoint}/payment_methods/${paymentMethodId}`
  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=DELETE_PAYMENT_METHODS_CALL_INIT,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(uri, ~method=#DELETE, ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri))
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=DELETE_PAYMENT_METHODS_CALL,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=DELETE_PAYMENT_METHODS_CALL,
        ~logType=INFO,
        ~logCategory=API,
      )
      Fetch.Response.json(resp)
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=DELETE_PAYMENT_METHODS_CALL,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let calculateTax = (
  ~apiKey,
  ~paymentId,
  ~clientSecret,
  ~paymentMethodType,
  ~shippingAddress,
  ~logger,
  ~customPodUri,
  ~sessionId,
) => {
  open Promise
  let endpoint = ApiEndpoint.getApiEndPoint()
  let headers = [("Content-Type", "application/json"), ("api-key", apiKey)]
  let uri = `${endpoint}/payments/${paymentId}/calculate_tax`
  let body = [
    ("client_secret", clientSecret),
    ("shipping", shippingAddress),
    ("payment_method_type", paymentMethodType),
  ]
  sessionId->Option.mapOr((), id => body->Array.push(("session_id", id))->ignore)

  logApi(
    ~optLogger=Some(logger),
    ~url=uri,
    ~apiLogType=Request,
    ~eventName=EXTERNAL_TAX_CALCULATION,
    ~logType=INFO,
    ~logCategory=API,
  )
  fetchApi(
    uri,
    ~method=#POST,
    ~headers=headers->ApiEndpoint.addCustomPodHeader(~customPodUri),
    ~bodyStr=body->getJsonFromArrayOfJson->JSON.stringify,
  )
  ->then(resp => {
    let statusCode = resp->Fetch.Response.status
    if !(resp->Fetch.Response.ok) {
      resp
      ->Fetch.Response.json
      ->then(data => {
        logApi(
          ~optLogger=Some(logger),
          ~url=uri,
          ~data,
          ~statusCode,
          ~apiLogType=Err,
          ~eventName=EXTERNAL_TAX_CALCULATION,
          ~logType=ERROR,
          ~logCategory=API,
        )
        JSON.Encode.null->resolve
      })
    } else {
      logApi(
        ~optLogger=Some(logger),
        ~url=uri,
        ~statusCode,
        ~apiLogType=Response,
        ~eventName=EXTERNAL_TAX_CALCULATION,
        ~logType=INFO,
        ~logCategory=API,
      )
      resp->Fetch.Response.json
    }
  })
  ->catch(err => {
    let exceptionMessage = err->formatException
    logApi(
      ~optLogger=Some(logger),
      ~url=uri,
      ~apiLogType=NoResponse,
      ~eventName=EXTERNAL_TAX_CALCULATION,
      ~logType=ERROR,
      ~logCategory=API,
      ~data=exceptionMessage,
    )
    JSON.Encode.null->resolve
  })
}

let usePostSessionTokens = (
  optLogger,
  paymentType: payment,
  paymentMethod: PaymentMethodCollectTypes.paymentMethod,
) => {
  open RecoilAtoms
  open Promise
  let url = RescriptReactRouter.useUrl()
  let paymentTypeFromUrl =
    CardUtils.getQueryParamsDictforKey(url.search, "componentName")->CardThemeType.getPaymentMode
  let customPodUri = Recoil.useRecoilValueFromAtom(customPodUri)
  let paymentMethodList = Recoil.useRecoilValueFromAtom(paymentMethodList)
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let redirectionFlags = Recoil.useRecoilValueFromAtom(RecoilAtoms.redirectionFlagsAtom)

  let setIsManualRetryEnabled = Recoil.useSetRecoilState(isManualRetryEnabled)
  (
    ~handleUserError=false,
    ~bodyArr: array<(string, JSON.t)>,
    ~confirmParam: ConfirmType.confirmParams,
    ~iframeId=keys.iframeId,
    ~isThirdPartyFlow=false,
    ~intentCallback=_ => (),
    ~manualRetry as _=false,
  ) => {
    switch keys.clientSecret {
    | Some(clientSecret) =>
      let paymentIntentID = clientSecret->Utils.getPaymentId
      let headers = [
        ("Content-Type", "application/json"),
        ("api-key", confirmParam.publishableKey),
        ("X-Client-Source", paymentTypeFromUrl->CardThemeType.getPaymentModeToStrMapper),
      ]
      let body = [
        ("client_secret", clientSecret->JSON.Encode.string),
        ("payment_id", paymentIntentID->JSON.Encode.string),
        ("payment_method_type", (paymentType :> string)->JSON.Encode.string),
        ("payment_method", (paymentMethod :> string)->JSON.Encode.string),
      ]

      let endpoint = ApiEndpoint.getApiEndPoint(
        ~publishableKey=confirmParam.publishableKey,
        ~isConfirmCall=isThirdPartyFlow,
      )
      let uri = `${endpoint}/payments/${paymentIntentID}/post_session_tokens`

      let callIntent = body => {
        let contentLength = body->String.length->Int.toString
        let maskedPayload =
          body->safeParseOpt->Option.getOr(JSON.Encode.null)->maskPayload->JSON.stringify
        let loggerPayload =
          [
            ("payload", maskedPayload->JSON.Encode.string),
            (
              "headers",
              headers
              ->Array.map(header => {
                let (key, value) = header
                (key, value->JSON.Encode.string)
              })
              ->getJsonFromArrayOfJson,
            ),
          ]
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        switch paymentType {
        | Card =>
          handleLogging(
            ~optLogger,
            ~internalMetadata=loggerPayload,
            ~value=contentLength,
            ~eventName=PAYMENT_ATTEMPT,
            ~paymentMethod="CARD",
          )
        | _ =>
          bodyArr->Array.forEach(((str, json)) => {
            if str === "payment_method_type" {
              handleLogging(
                ~optLogger,
                ~value=contentLength,
                ~internalMetadata=loggerPayload,
                ~eventName=PAYMENT_ATTEMPT,
                ~paymentMethod=json->getStringFromJson(""),
              )
            }
            ()
          })
        }

        intentCall(
          ~fetchApi,
          ~uri,
          ~headers,
          ~bodyStr=body,
          ~confirmParam: ConfirmType.confirmParams,
          ~clientSecret,
          ~optLogger,
          ~handleUserError,
          ~paymentType,
          ~iframeId,
          ~fetchMethod=#POST,
          ~setIsManualRetryEnabled,
          ~customPodUri,
          ~sdkHandleOneClickConfirmPayment=keys.sdkHandleOneClickConfirmPayment,
          ~counter=0,
          ~redirectionFlags,
        )
        ->then(val => {
          intentCallback(val)
          resolve()
        })
        ->catch(_ => Promise.resolve())
        ->ignore
      }

      let broswerInfo = BrowserSpec.broswerInfo
      let intentWithoutMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concatMany([
            bodyArr->Array.concat(broswerInfo()),
            mandatePaymentType->PaymentBody.paymentTypeBody,
          ])
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      let intentWithMandate = mandatePaymentType => {
        let bodyStr =
          body
          ->Array.concat(
            bodyArr->Array.concatMany([PaymentBody.mandateBody(mandatePaymentType), broswerInfo()]),
          )
          ->getJsonFromArrayOfJson
          ->JSON.stringify
        callIntent(bodyStr)
      }

      switch paymentMethodList {
      | LoadError(data)
      | Loaded(data) =>
        let paymentList = data->getDictFromJson->PaymentMethodsRecord.itemToObjMapper
        let mandatePaymentType =
          paymentList.payment_type->PaymentMethodsRecord.paymentTypeToStringMapper
        if paymentList.payment_methods->Array.length > 0 {
          switch paymentList.mandate_payment {
          | Some(_) =>
            switch paymentType {
            | Card
            | Gpay
            | Applepay
            | KlarnaRedirect
            | Paypal
            | BankDebits =>
              intentWithMandate(mandatePaymentType)
            | _ => intentWithoutMandate(mandatePaymentType)
            }
          | None => intentWithoutMandate(mandatePaymentType)
          }
        } else {
          postFailedSubmitResponse(
            ~errortype="payment_methods_empty",
            ~message="Payment Failed. Try again!",
          )
          Console.warn("Please enable atleast one Payment method.")
        }
      | SemiLoaded => intentWithoutMandate("")
      | _ =>
        postFailedSubmitResponse(
          ~errortype="payment_methods_loading",
          ~message="Please wait. Try again!",
        )
      }
    | None =>
      postFailedSubmitResponse(
        ~errortype="post_session_tokens_failed",
        ~message="Post Session Tokens failed. Try again!",
      )
    }
  }
}
