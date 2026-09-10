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
  | UiKitScriptError
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
  | GetUserType
  | GetRecognizedCards
  | ValidateCustomerAuthentication
  | CheckoutWithCard(checkoutWithCardDetails)
  | SignOut
  | IsCustomerPresent(emailProvidedDetails)

type providerEvent<'a, 'b, 'c, 'd> =
  | VisaUctp('a)
  | VisaDirect('b)
  | MastercardDirect('c)
  | MastercardUctp('d)

type visaUctpFunction = Initialize | GetCards | Checkout | UnbindAppInstance
type directFunction = Init | IdentityLookup
type mastercardUctpFunction = Init | GetCards | Authenticate | EncryptCard
type functionEvent = providerEvent<
  visaUctpFunction,
  directFunction,
  directFunction,
  mastercardUctpFunction,
>

type visaUctpResource = VsdkScript
type resourceEvent = providerEvent<visaUctpResource, unit, unit, unit>

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
  | UiKitScriptError
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
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logScript = (~event: scriptEvent, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Resource,
    ~severity=scriptSeverity(event),
    ~event,
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
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultDetails=?,
  ~call,
) =>
  LoggerRuntime.observeEventAsync(
    ~category=Merchant,
    ~event,
    ~providerDimension,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure=LoggerCommonHelpers.errorResponseSummary,
    ~resultDetails?,
    ~call,
  )

let observeMerchantSync = (~event: merchantSyncEvent, ~message=?, ~call) =>
  LoggerRuntime.observeEventSync(
    ~category=Merchant,
    ~event,
    ~providerDimension,
    ~message?,
    ~eventIdPrefix,
    ~call,
  )

let observeFunction = (
  ~event: functionEvent,
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultDetails=?,
  ~call,
) =>
  LoggerRuntime.observeProviderAsync(
    ~category=Function,
    ~event,
    ~providerDimension,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultDetails?,
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
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~onLoad,
    ~onError,
  )
