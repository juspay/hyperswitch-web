type apiLogType = Request | Response | NoResponse | Method | Err
type logType = DEBUG | INFO | ERROR | WARNING | SILENT
type logCategory = API | USER_ERROR | USER_EVENT | MERCHANT_EVENT

type eventName =
  | APP_RENDERED
  | PAYMENT_METHOD_CHANGED
  | PAYMENT_DATA_FILLED
  | PAYMENT_ATTEMPT
  | PAYMENT_SUCCESS
  | PAYMENT_FAILED
  | INPUT_FIELD_CHANGED
  | RETRIEVE_CALL_INIT
  | RETRIEVE_CALL
  | AUTHENTICATION_CALL_INIT
  | AUTHENTICATION_CALL
  | CONFIRM_CALL_INIT
  | CONFIRM_CALL
  | CONFIRM_PAYOUT_CALL_INIT
  | CONFIRM_PAYOUT_CALL
  | SESSIONS_CALL_INIT
  | SESSIONS_CALL
  | PAYMENT_METHODS_CALL_INIT
  | SAVED_PAYMENT_METHODS_CALL_INIT
  | PAYMENT_METHODS_CALL
  | SAVED_PAYMENT_METHODS_CALL
  | CUSTOMER_PAYMENT_METHODS_CALL_INIT
  | CUSTOMER_PAYMENT_METHODS_CALL
  | CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT
  | CREATE_CUSTOMER_PAYMENT_METHODS_CALL
  | TRUSTPAY_SCRIPT
  | PM_AUTH_CONNECTOR_SCRIPT
  | GOOGLE_PAY_SCRIPT
  | APPLE_PAY_FLOW
  | GOOGLE_PAY_FLOW
  | PAYPAL_FLOW
  | PAYPAL_SDK_FLOW
  | KLARNA_CHECKOUT_FLOW
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
  | POLL_STATUS_CALL
  | COMPLETE_AUTHORIZE_CALL_INIT
  | COMPLETE_AUTHORIZE_CALL
  | PLAID_SDK
  | PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT
  | PAYMENT_METHODS_AUTH_EXCHANGE_CALL
  | PAYMENT_METHODS_AUTH_LINK_CALL_INIT
  | PAYMENT_METHODS_AUTH_LINK_CALL
  | PAYMENT_MANAGEMENT_ELEMENTS_CALLED
  | DELETE_SAVED_PAYMENT_METHOD
  | DELETE_PAYMENT_METHODS_CALL_INIT
  | DELETE_PAYMENT_METHODS_CALL
  | EXTERNAL_TAX_CALCULATION
  | POST_SESSION_TOKENS_CALL
  | POST_SESSION_TOKENS_CALL_INIT
  | PAZE_SDK_FLOW
  | SAMSUNG_PAY_SCRIPT
  | SAMSUNG_PAY
  | CLICK_TO_PAY_SCRIPT
  | CLICK_TO_PAY_FLOW
  | PAYMENT_METHOD_TYPE_DETECTION_FAILED
  | NETWORK_STATE
  | THREE_DS_POPUP_REDIRECTION
  | S3_API
  | CARD_SCHEME_SELECTION
  | BLOCKED_BIN_CALL
  | APPLE_PAY_BRAINTREE_SCRIPT
  | BRAINTREE_CLIENT_SCRIPT
  | AUTHENTICATED_SESSION_INITIATED
  | ENABLED_AUTHN_METHODS_TOKEN_CALL
  | ELIGIBILITY_CHECK_CALL
  | AUTHENTICATION_SYNC_CALL
  | ONE_CLICK_HANDLER_CALLBACK

type maskableDetails = Email | CardDetails
type source = Loader | Elements(CardThemeType.mode) | Headless

type logFile = {
  timestamp: string,
  logType: logType,
  category: logCategory,
  source: string,
  version: string,
  value: string,
  // internalMetadata: string,
  sessionId: string,
  merchantId: string,
  paymentId: string,
  appId: string,
  platform: string,
  browserName: string,
  browserVersion: string,
  userAgent: string,
  eventName: eventName,
  latency: string,
  firstEvent: bool,
  paymentMethod: string,
  metadata: JSON.t,
  ephemeralKey: string,
}

type setlogApiValueType =
  | ArrayType(array<(string, JSON.t)>)
  | StringValue(string)

type setLogInfo = (
  ~value: string,
  // ~internalMetadata: string=?,
  ~eventName: eventName,
  ~timestamp: string=?,
  ~latency: float=?,
  ~logType: logType=?,
  ~logCategory: logCategory=?,
  ~paymentMethod: string=?,
) => unit

type loggerMake = {
  setLogInfo: setLogInfo,
  setLogError: setLogInfo,
  setLogApi: (
    ~value: setlogApiValueType,
    // ~internalMetadata: setlogApiValueType,
    ~eventName: eventName,
    ~timestamp: string=?,
    ~logType: logType=?,
    ~logCategory: logCategory=?,
    ~paymentMethod: string=?,
    ~apiLogType: apiLogType=?,
    ~isPaymentSession: bool=?,
  ) => unit,
  setLogInitiated: unit => unit,
  setConfirmPaymentValue: (~paymentType: string) => JSON.t,
  sendLogs: unit => unit,
  setSessionId: string => unit,
  setClientSecret: string => unit,
  setMerchantId: string => unit,
  setMetadata: JSON.t => unit,
  setSource: string => unit,
  setEphemeralKey: string => unit,
}
