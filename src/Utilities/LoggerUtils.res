open IndexedDB
let logApi = (
  ~eventName,
  ~statusCode=0,
  ~data: JSON.t=Dict.make()->JSON.Encode.object,
  ~apiLogType: HyperLoggerTypes.apiLogType,
  ~url="",
  ~paymentMethod="",
  ~result: JSON.t=Dict.make()->JSON.Encode.object,
  ~optLogger: option<HyperLoggerTypes.loggerMake>,
  ~logType: HyperLoggerTypes.logType=INFO,
  ~logCategory: HyperLoggerTypes.logCategory=API,
  ~isPaymentSession: bool=false,
) => {
  let (value, _) = switch apiLogType {
  | Request => ([("url", url->JSON.Encode.string)], [])
  | Response => (
      [("url", url->JSON.Encode.string), ("statusCode", statusCode->JSON.Encode.int)],
      [("response", data)],
    )
  | NoResponse => (
      [("url", url->JSON.Encode.string), ("statusCode", 504->JSON.Encode.int), ("response", data)],
      [("response", data)],
    )
  | Err => (
      [
        ("url", url->JSON.Encode.string),
        ("statusCode", statusCode->JSON.Encode.int),
        ("response", data),
      ],
      [("response", data)],
    )
  | Method => ([("method", paymentMethod->JSON.Encode.string)], [("result", result)])
  }
  switch optLogger {
  | Some(logger) =>
    logger.setLogApi(
      ~eventName,
      ~value=ArrayType(value),
      // ~internalMetadata=ArrayType(internalMetadata),
      ~logType,
      ~logCategory,
      ~apiLogType,
      ~isPaymentSession,
    )
  | None => ()
  }
}

let logInputChangeInfo = (text, logger: HyperLoggerTypes.loggerMake) => {
  logger.setLogInfo(~value=text, ~eventName=INPUT_FIELD_CHANGED)
}

let handleLogging = (
  ~optLogger: option<HyperLoggerTypes.loggerMake>,
  ~value,
  // ~internalMetadata="",
  ~eventName,
  ~paymentMethod,
  ~logType: HyperLoggerTypes.logType=INFO,
) => {
  switch optLogger {
  | Some(logger) =>
    logger.setLogInfo(
      ~value,
      // ~internalMetadata,
      ~eventName,
      ~paymentMethod,
      ~logType,
    )
  | _ => ()
  }
}

let eventNameToStrMapper = (eventName: HyperLoggerTypes.eventName) => (eventName :> string)

let getPaymentId = clientSecret =>
  String.split(clientSecret, "_secret_")->Array.get(0)->Option.getOr("")

let convertToScreamingSnakeCase = text => {
  text->String.trim->String.replaceRegExp(%re("/ /g"), "_")->String.toUpperCase
}

let toSnakeCaseWithSeparator = (str, separator) => {
  str->Js.String2.unsafeReplaceBy0(%re("/[A-Z]/g"), (letter, _, _) =>
    `${separator}${letter->String.toLowerCase}`
  )
}

let defaultLoggerConfig: HyperLoggerTypes.loggerMake = {
  sendLogs: () => (),
  setClientSecret: _x => (),
  setEphemeralKey: _x => (),
  setConfirmPaymentValue: (~paymentType as _) => {Dict.make()->JSON.Encode.object},
  setLogError: (
    ~value as _,
    // ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
  ) => (),
  setLogApi: (
    ~value as _,
    // ~internalMetadata as _,
    ~eventName as _,
    ~timestamp as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
    ~apiLogType as _=?,
    ~isPaymentSession as _=?,
  ) => (),
  setLogInfo: (
    ~value as _,
    // ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
  ) => (),
  setLogInitiated: () => (),
  setMerchantId: _x => (),
  setSessionId: _x => (),
  setMetadata: _x => (),
  setSource: _x => (),
}

let saveLogsToIndexedDB = (logs: array<HyperLoggerTypes.logFile>) => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    request->OpenDBRequest.onsuccess(_ => {
      let db = OpenDBRequest.result(request)

      if logs->Array.length > 0 {
        let transaction = db->DB.transaction(["logs"], "readwrite")
        let store = transaction->Transaction.objectStore("logs")

        transaction->Transaction.oncomplete(
          _ => {
            db->DB.close
            resolve()
          },
        )

        transaction->Transaction.onerror(
          _ => {
            db->DB.close
            reject()
          },
        )

        logs->Array.forEach(
          log => {
            let _ = store->ObjectStore.put(log)
          },
        )
      } else {
        db->DB.close
        reject()
      }
    })

    request->OpenDBRequest.onerror(_ => {
      reject()
    })
  })
}

let retrieveLogsFromIndexedDB = () => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    request->OpenDBRequest.onsuccess(_ => {
      let db = OpenDBRequest.result(request)
      let transaction = db->DB.transaction(["logs"], "readonly")
      let store = transaction->Transaction.objectStore("logs")
      let getAllRequest = store->ObjectStore.getAll

      getAllRequest->Request.onsuccess(
        _ => {
          let result = Request.result(getAllRequest)
          db->DB.close
          resolve(result)
        },
      )

      getAllRequest->Request.onerror(
        _ => {
          db->DB.close
          reject([])
        },
      )
    })

    request->OpenDBRequest.onerror(_ => {
      reject([])
    })
  })
}

let clearLogsFromIndexedDB = () => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    request->OpenDBRequest.onsuccess(_ => {
      let db = OpenDBRequest.result(request)
      let transaction = db->DB.transaction(["logs"], "readwrite")
      let store = transaction->Transaction.objectStore("logs")
      let clearRequest = store->ObjectStore.clear

      clearRequest->Request.onsuccess(
        _ => {
          db->DB.close
          resolve()
        },
      )

      clearRequest->Request.onerror(
        _ => {
          db->DB.close
          reject()
        },
      )
    })

    request->OpenDBRequest.onerror(_ => {
      reject()
    })
  })
}

let apiEventInitMapper = (eventName: HyperLoggerTypes.eventName): option<
  HyperLoggerTypes.eventName,
> =>
  switch eventName {
  | CONFIRM_CALL => Some(CONFIRM_CALL_INIT)
  | PAYMENT_METHODS_CALL => Some(PAYMENT_METHODS_CALL_INIT)
  | SAVED_PAYMENT_METHODS_CALL => Some(SAVED_PAYMENT_METHODS_CALL_INIT)
  | CUSTOMER_PAYMENT_METHODS_CALL => Some(CUSTOMER_PAYMENT_METHODS_CALL_INIT)
  | CREATE_CUSTOMER_PAYMENT_METHODS_CALL => Some(CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT)
  | POLL_STATUS_CALL => Some(POLL_STATUS_CALL_INIT)
  | COMPLETE_AUTHORIZE_CALL => Some(COMPLETE_AUTHORIZE_CALL_INIT)
  | POST_SESSION_TOKENS_CALL => Some(POST_SESSION_TOKENS_CALL_INIT)
  | PAYMENT_METHODS_AUTH_EXCHANGE_CALL => Some(PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT)
  | PAYMENT_METHODS_AUTH_LINK_CALL => Some(PAYMENT_METHODS_AUTH_LINK_CALL_INIT)
  | DELETE_PAYMENT_METHODS_CALL => Some(DELETE_PAYMENT_METHODS_CALL_INIT)
  | SESSIONS_CALL => Some(SESSIONS_CALL_INIT)
  | RETRIEVE_CALL => Some(RETRIEVE_CALL_INIT)
  | AUTHENTICATION_CALL => Some(AUTHENTICATION_CALL_INIT)
  | CONFIRM_PAYOUT_CALL => Some(CONFIRM_PAYOUT_CALL_INIT)
  | ENABLED_AUTHN_METHODS_TOKEN_CALL => Some(ENABLED_AUTHN_METHODS_TOKEN_CALL)
  | ELIGIBILITY_CHECK_CALL => Some(ELIGIBILITY_CHECK_CALL)
  | AUTHENTICATION_SYNC_CALL => Some(AUTHENTICATION_SYNC_CALL)
  | APP_RENDERED
  | PAYMENT_METHOD_CHANGED
  | PAYMENT_DATA_FILLED
  | PAYMENT_ATTEMPT
  | PAYMENT_SUCCESS
  | PAYMENT_FAILED
  | INPUT_FIELD_CHANGED
  | RETRIEVE_CALL_INIT
  | AUTHENTICATION_CALL_INIT
  | CONFIRM_CALL_INIT
  | CONFIRM_PAYOUT_CALL_INIT
  | SESSIONS_CALL_INIT
  | PAYMENT_METHODS_CALL_INIT
  | SAVED_PAYMENT_METHODS_CALL_INIT
  | CUSTOMER_PAYMENT_METHODS_CALL_INIT
  | CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT
  | TRUSTPAY_SCRIPT
  | PM_AUTH_CONNECTOR_SCRIPT
  | GOOGLE_PAY_SCRIPT
  | APPLE_PAY_FLOW
  | GOOGLE_PAY_FLOW
  | PAYPAL_FLOW
  | PAYPAL_SDK_FLOW
  | KLARNA_CHECKOUT_FLOW
  | KLARNA_SDK_FLOW
  | APP_INITIATED
  | APP_REINITIATED
  | LOG_INITIATED
  | LOADER_CALLED
  | ORCA_ELEMENTS_CALLED
  | PAYMENT_OPTIONS_PROVIDED
  | BLUR
  | FOCUS
  | CLEAR
  | CONFIRM_PAYMENT
  | CONFIRM_CARD_PAYMENT
  | SDK_CRASH
  | INVALID_PK
  | DEPRECATED_LOADSTRIPE
  | REQUIRED_PARAMETER
  | TYPE_BOOL_ERROR
  | TYPE_INT_ERROR
  | TYPE_STRING_ERROR
  | INVALID_FORMAT
  | SDK_CONNECTOR_WARNING
  | VALUE_OUT_OF_RANGE
  | HTTP_NOT_ALLOWED
  | INTERNAL_API_DOWN
  | REDIRECTING_USER
  | DISPLAY_BANK_TRANSFER_INFO_PAGE
  | DISPLAY_QR_CODE_INFO_PAGE
  | DISPLAY_VOUCHER
  | DISPLAY_THREE_DS_SDK
  | THREE_DS_METHOD
  | THREE_DS_METHOD_RESULT
  | PAYMENT_METHODS_RESPONSE
  | LOADER_CHANGED
  | PAYMENT_SESSION_INITIATED
  | POLL_STATUS_CALL_INIT
  | COMPLETE_AUTHORIZE_CALL_INIT
  | PLAID_SDK
  | PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT
  | PAYMENT_METHODS_AUTH_LINK_CALL_INIT
  | PAYMENT_MANAGEMENT_ELEMENTS_CALLED
  | DELETE_SAVED_PAYMENT_METHOD
  | DELETE_PAYMENT_METHODS_CALL_INIT
  | EXTERNAL_TAX_CALCULATION
  | POST_SESSION_TOKENS_CALL_INIT
  | PAZE_SDK_FLOW
  | SAMSUNG_PAY_SCRIPT
  | SAMSUNG_PAY
  | CLICK_TO_PAY_SCRIPT
  | CLICK_TO_PAY_FLOW
  | PAYMENT_METHOD_TYPE_DETECTION_FAILED
  | THREE_DS_POPUP_REDIRECTION
  | NETWORK_STATE
  | CARD_SCHEME_SELECTION
  | S3_API
  | BLOCKED_BIN_CALL
  | PRELOAD_SDK_WITH_PARAMS
  | APPLE_PAY_BRAINTREE_SCRIPT
  | BRAINTREE_CLIENT_SCRIPT
  | AUTHENTICATED_SESSION_INITIATED =>
    None
  }
