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
  let (value, internalMetadata) = switch apiLogType {
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
      ~internalMetadata=ArrayType(internalMetadata),
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
  ~internalMetadata="",
  ~eventName,
  ~paymentMethod,
  ~logType: HyperLoggerTypes.logType=INFO,
) => {
  switch optLogger {
  | Some(logger) =>
    logger.setLogInfo(~value, ~internalMetadata, ~eventName, ~paymentMethod, ~logType)
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
    ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
  ) => (),
  setLogApi: (
    ~value as _,
    ~internalMetadata as _,
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
    ~internalMetadata as _=?,
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

let eventNameFromString = (eventNameStr: string): HyperLoggerTypes.eventName => {
  switch eventNameStr {
  | "APP_RENDERED" => APP_RENDERED
  | "PAYMENT_METHOD_CHANGED" => PAYMENT_METHOD_CHANGED
  | "PAYMENT_DATA_FILLED" => PAYMENT_DATA_FILLED
  | "PAYMENT_ATTEMPT" => PAYMENT_ATTEMPT
  | "PAYMENT_SUCCESS" => PAYMENT_SUCCESS
  | "PAYMENT_FAILED" => PAYMENT_FAILED
  | "INPUT_FIELD_CHANGED" => INPUT_FIELD_CHANGED
  | "RETRIEVE_CALL_INIT" => RETRIEVE_CALL_INIT
  | "RETRIEVE_CALL" => RETRIEVE_CALL
  | "AUTHENTICATION_CALL_INIT" => AUTHENTICATION_CALL_INIT
  | "AUTHENTICATION_CALL" => AUTHENTICATION_CALL
  | "CONFIRM_CALL_INIT" => CONFIRM_CALL_INIT
  | "CONFIRM_CALL" => CONFIRM_CALL
  | "CONFIRM_PAYOUT_CALL_INIT" => CONFIRM_PAYOUT_CALL_INIT
  | "CONFIRM_PAYOUT_CALL" => CONFIRM_PAYOUT_CALL
  | "SESSIONS_CALL_INIT" => SESSIONS_CALL_INIT
  | "SESSIONS_CALL" => SESSIONS_CALL
  | "PAYMENT_METHODS_CALL_INIT" => PAYMENT_METHODS_CALL_INIT
  | "SAVED_PAYMENT_METHODS_CALL_INIT" => SAVED_PAYMENT_METHODS_CALL_INIT
  | "PAYMENT_METHODS_CALL" => PAYMENT_METHODS_CALL
  | "SAVED_PAYMENT_METHODS_CALL" => SAVED_PAYMENT_METHODS_CALL
  | "CUSTOMER_PAYMENT_METHODS_CALL_INIT" => CUSTOMER_PAYMENT_METHODS_CALL_INIT
  | "CUSTOMER_PAYMENT_METHODS_CALL" => CUSTOMER_PAYMENT_METHODS_CALL
  | "CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT" => CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT
  | "CREATE_CUSTOMER_PAYMENT_METHODS_CALL" => CREATE_CUSTOMER_PAYMENT_METHODS_CALL
  | "TRUSTPAY_SCRIPT" => TRUSTPAY_SCRIPT
  | "PM_AUTH_CONNECTOR_SCRIPT" => PM_AUTH_CONNECTOR_SCRIPT
  | "GOOGLE_PAY_SCRIPT" => GOOGLE_PAY_SCRIPT
  | "APPLE_PAY_FLOW" => APPLE_PAY_FLOW
  | "GOOGLE_PAY_FLOW" => GOOGLE_PAY_FLOW
  | "PAYPAL_FLOW" => PAYPAL_FLOW
  | "PAYPAL_SDK_FLOW" => PAYPAL_SDK_FLOW
  | "KLARNA_CHECKOUT_FLOW" => KLARNA_CHECKOUT_FLOW
  | "APP_INITIATED" => APP_INITIATED
  | "APP_REINITIATED" => APP_REINITIATED
  | "LOG_INITIATED" => LOG_INITIATED
  | "LOADER_CALLED" => LOADER_CALLED
  | "ORCA_ELEMENTS_CALLED" => ORCA_ELEMENTS_CALLED
  | "PAYMENT_OPTIONS_PROVIDED" => PAYMENT_OPTIONS_PROVIDED
  | "BLUR" => BLUR
  | "FOCUS" => FOCUS
  | "CLEAR" => CLEAR
  | "CONFIRM_PAYMENT" => CONFIRM_PAYMENT
  | "CONFIRM_CARD_PAYMENT" => CONFIRM_CARD_PAYMENT
  | "SDK_CRASH" => SDK_CRASH
  | "INVALID_PK" => INVALID_PK
  | "DEPRECATED_LOADSTRIPE" => DEPRECATED_LOADSTRIPE
  | "REQUIRED_PARAMETER" => REQUIRED_PARAMETER
  | "UNKNOWN_KEY" => UNKNOWN_KEY
  | "UNKNOWN_VALUE" => UNKNOWN_VALUE
  | "TYPE_BOOL_ERROR" => TYPE_BOOL_ERROR
  | "TYPE_INT_ERROR" => TYPE_INT_ERROR
  | "TYPE_STRING_ERROR" => TYPE_STRING_ERROR
  | "INVALID_FORMAT" => INVALID_FORMAT
  | "SDK_CONNECTOR_WARNING" => SDK_CONNECTOR_WARNING
  | "VALUE_OUT_OF_RANGE" => VALUE_OUT_OF_RANGE
  | "HTTP_NOT_ALLOWED" => HTTP_NOT_ALLOWED
  | "INTERNAL_API_DOWN" => INTERNAL_API_DOWN
  | "REDIRECTING_USER" => REDIRECTING_USER
  | "DISPLAY_BANK_TRANSFER_INFO_PAGE" => DISPLAY_BANK_TRANSFER_INFO_PAGE
  | "DISPLAY_QR_CODE_INFO_PAGE" => DISPLAY_QR_CODE_INFO_PAGE
  | "DISPLAY_VOUCHER" => DISPLAY_VOUCHER
  | "DISPLAY_THREE_DS_SDK" => DISPLAY_THREE_DS_SDK
  | "THREE_DS_METHOD" => THREE_DS_METHOD
  | "THREE_DS_METHOD_RESULT" => THREE_DS_METHOD_RESULT
  | "PAYMENT_METHODS_RESPONSE" => PAYMENT_METHODS_RESPONSE
  | "LOADER_CHANGED" => LOADER_CHANGED
  | "PAYMENT_SESSION_INITIATED" => PAYMENT_SESSION_INITIATED
  | "POLL_STATUS_CALL_INIT" => POLL_STATUS_CALL_INIT
  | "POLL_STATUS_CALL" => POLL_STATUS_CALL
  | "COMPLETE_AUTHORIZE_CALL_INIT" => COMPLETE_AUTHORIZE_CALL_INIT
  | "COMPLETE_AUTHORIZE_CALL" => COMPLETE_AUTHORIZE_CALL
  | "PLAID_SDK" => PLAID_SDK
  | "PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT" => PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT
  | "PAYMENT_METHODS_AUTH_EXCHANGE_CALL" => PAYMENT_METHODS_AUTH_EXCHANGE_CALL
  | "PAYMENT_METHODS_AUTH_LINK_CALL_INIT" => PAYMENT_METHODS_AUTH_LINK_CALL_INIT
  | "PAYMENT_METHODS_AUTH_LINK_CALL" => PAYMENT_METHODS_AUTH_LINK_CALL
  | "PAYMENT_MANAGEMENT_ELEMENTS_CALLED" => PAYMENT_MANAGEMENT_ELEMENTS_CALLED
  | "DELETE_SAVED_PAYMENT_METHOD" => DELETE_SAVED_PAYMENT_METHOD
  | "DELETE_PAYMENT_METHODS_CALL_INIT" => DELETE_PAYMENT_METHODS_CALL_INIT
  | "DELETE_PAYMENT_METHODS_CALL" => DELETE_PAYMENT_METHODS_CALL
  | "EXTERNAL_TAX_CALCULATION" => EXTERNAL_TAX_CALCULATION
  | "POST_SESSION_TOKENS_CALL" => POST_SESSION_TOKENS_CALL
  | "POST_SESSION_TOKENS_CALL_INIT" => POST_SESSION_TOKENS_CALL_INIT
  | "PAZE_SDK_FLOW" => PAZE_SDK_FLOW
  | "SAMSUNG_PAY_SCRIPT" => SAMSUNG_PAY_SCRIPT
  | "SAMSUNG_PAY" => SAMSUNG_PAY
  | "CLICK_TO_PAY_SCRIPT" => CLICK_TO_PAY_SCRIPT
  | "CLICK_TO_PAY_FLOW" => CLICK_TO_PAY_FLOW
  | "PAYMENT_METHOD_TYPE_DETECTION_FAILED" => PAYMENT_METHOD_TYPE_DETECTION_FAILED
  | "THREE_DS_POPUP_REDIRECTION" => THREE_DS_POPUP_REDIRECTION
  | _ => UNKNOWN_EVENT
  }
}
