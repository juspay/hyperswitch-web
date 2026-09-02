open LoggerCommonHelpers

type apiEvent =
  | RetrievePaymentIntent
  | ConfirmCall
  | ConfirmPayoutCall
  | Sessions
  | PaymentMethodsList
  | CreateCustomerPaymentMethods
  | CompleteAuthorize
  | Authentication
  | PollStatus
  | TaxCalculation
  | SdkConfigs
  | ClientList
  | PaymentMethodsAuthLink
  | PaymentMethodsAuthExchange
  | PaymentMethodEligibility
  | PostSessionTokens

type lifecycleEvent =
  | PaymentAttempt
  | PaymentSuccess
  | PaymentFailed
  | RedirectingUser
  | RedirectingUserFailed
  | ThreeDsPopupRedirection
  | ThreeDsPopupRedirectionFailed
  | ThreeDsMethod
  | DdcFlow
  | DdcFlowFailed
  | DisplayQrCode
  | DisplayVoucher
  | DisplayBankTransfer
  | IsReadyStatusCheck
  | ConfirmPayment
  | ConfirmCardPayment
  | PaymentElementOptions
  | UpdateIntent
  | UpdateIntentFailed
  | UpdateSdk

let eventIdPrefix = "cpe_"

let lifecycleSeverity = event =>
  switch event {
  | PaymentFailed
  | RedirectingUserFailed
  | ThreeDsPopupRedirectionFailed
  | DdcFlowFailed
  | UpdateIntentFailed =>
    Error
  | _ => Info
  }

let logLifecycle = (~event: lifecycleEvent, ~paymentMethod="", ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Lifecycle,
    ~severity=lifecycleSeverity(event),
    ~event,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let observeApi = (
  ~event: apiEvent,
  ~paymentMethod="",
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) =>
  LoggerRuntime.observeEventAsync(
    ~category=Api,
    ~event,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure?,
    ~resultDetails?,
    ~call,
  )
