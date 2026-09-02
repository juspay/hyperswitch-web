open LoggerCommonHelpers

type apiEvent =
  | EnabledAuthnMethodsToken
  | EligibilityCheck
  | AuthenticationSync

type lifecycleEvent =
  | AuthenticatedSessionInitiated
  | ProviderInitialized
  | RecognitionTokenFetched
  | CardsFetched
  | AuthenticationCompleted
  | CheckoutSucceeded
  | CheckoutFailed
  | ProviderNotInitialized
  | CardEncryptionFailed
  | WindowReferenceMissing

type scriptEvent =
  | UiKitScriptLoaded
  | UiKitStylesheetLoaded
  | UiKitStylesheetError
  | ProviderScriptLoaded
  | ProviderScriptError

type checkoutCardSelection = Visa | Mastercard | Other | NotFound
type checkoutWithCardDetails = {
  rememberMe: bool,
  windowProvided: bool,
  cardSelection: checkoutCardSelection,
  totalCardsCount: int,
}
type emailProvidedDetails = {emailProvided: bool}

type merchantSyncEvent = InitAuthenticationSession

type merchantEvent =
  | InitClickToPaySession
  | GetActiveClickToPaySession
  | InitClickToPayDCTPSession
  | GetUserType
  | GetRecognizedCards
  | ValidateCustomerAuthentication
  | CheckoutWithCard(checkoutWithCardDetails)
  | SignOut
  | IsCustomerPresent(emailProvidedDetails)

type providerEvent<'a, 'b, 'c> =
  | VisaUctp('a)
  | VisaDirect('b)
  | MastercardDirect('c)

type visaUctpFunction = Initialize | GetCards | Checkout | UnbindAppInstance
type directFunction = Init | IdentityLookup
type functionEvent = providerEvent<visaUctpFunction, directFunction, directFunction>

type visaUctpResource = VsdkScript
type visaDirectResource = SrciAdapterScript
type mastercardDirectResource = SrcSdkScript
type resourceEvent = providerEvent<visaUctpResource, visaDirectResource, mastercardDirectResource>

let paymentMethod = "CLICK_TO_PAY"
let providerDimension = "ctp_provider"
let eventIdPrefix = "cte_"

let lifecycleSeverity = event =>
  switch event {
  | CheckoutFailed
  | ProviderNotInitialized
  | CardEncryptionFailed
  | WindowReferenceMissing =>
    Error
  | _ => Info
  }

let scriptSeverity = event =>
  switch event {
  | UiKitStylesheetError
  | ProviderScriptError =>
    Error
  | _ => Info
  }

let logLifecycle = (~event: lifecycleEvent, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Lifecycle,
    ~severity=lifecycleSeverity(event),
    ~event,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logScript = (~event: scriptEvent, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Resource,
    ~severity=scriptSeverity(event),
    ~event,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let observeApi = (
  ~event: apiEvent,
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
    ~providerDimension,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure?,
    ~resultDetails?,
    ~call,
  )

let observeMerchant = (
  ~event: merchantEvent,
  ~message=?,
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~call,
) =>
  LoggerRuntime.observeEventAsync(
    ~category=Merchant,
    ~event,
    ~providerDimension,
    ~paymentMethod,
    ~message?,
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure=LoggerCommonHelpers.errorResponseSummary,
    ~call,
  )

let observeMerchantSync = (~event: merchantSyncEvent, ~message=?, ~call) =>
  LoggerRuntime.observeEventSync(
    ~category=Merchant,
    ~event,
    ~providerDimension,
    ~paymentMethod,
    ~message?,
    ~eventIdPrefix,
    ~call,
  )

let observeFunction = (
  ~event: functionEvent,
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~call,
) =>
  LoggerRuntime.observeProviderAsync(
    ~category=Function,
    ~event,
    ~providerDimension,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~call,
  )

let observeResource = (
  ~event: resourceEvent,
  ~url,
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~onLoad,
  ~onError,
) =>
  LoggerRuntime.observeProviderResource(
    ~event,
    ~url,
    ~resource=ResourceLoader.Script,
    ~providerDimension,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~onLoad,
    ~onError,
  )
