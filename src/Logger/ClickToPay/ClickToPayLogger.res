open LoggerCommonHelpers

type apiEvent =
  | EnabledAuthnMethodsToken
  | EligibilityCheck
  | AuthenticationSync

type cardsFetchedDetails = {visa: int, mastercard: int}
type checkoutFailureDetails = {stage: string, code: string}
type failureCodeDetails = {code: string}

type lifecycleEvent =
  | ProviderInitialized
  | RecognitionTokenFetched
  | CardsFetched(cardsFetchedDetails)
  | AuthenticationCompleted
  | AuthenticationPending(failureCodeDetails)
  | AuthenticationFailed(failureCodeDetails)
  | CheckoutSucceeded
  | CheckoutFailed(checkoutFailureDetails)
  | SessionInitFailed(failureCodeDetails)
  | ProviderInitFailed(failureCodeDetails)
  | SignOutFailed(failureCodeDetails)
  | CardsFetchFailed(failureCodeDetails)
  | GetUserTypeFailed(failureCodeDetails)
  | OtpValidationFailed(failureCodeDetails)
  | OtpResendFailed(failureCodeDetails)
  | ProviderNotInitialized
  | CardEncryptionFailed
  | WindowReferenceMissing

type scriptEvent =
  | UiKitScriptLoaded
  | UiKitStylesheetLoaded
  | UiKitScriptError
  | UiKitStylesheetError
  | ProviderScriptLoaded
  | ProviderScriptReused
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

type initSubject =
  | AuthenticatedSession(SdkLogger.outcome)
  | Provider(SdkLogger.outcome)

type fetchSubject =
  | RecognitionToken(SdkLogger.outcome)
  | Cards(SdkLogger.outcome)
  | UserType(SdkLogger.outcome)

type authenticateSubject = Customer(SdkLogger.outcome)

type checkoutSubject = Card(SdkLogger.outcome)

type encryptSubject = Card(SdkLogger.outcome)

type validateSubject =
  | WindowReference(SdkLogger.outcome)
  | Otp(SdkLogger.outcome)

type sessionSubject = Session(SdkLogger.outcome)

type otpSubject = Otp(SdkLogger.outcome)

type lifecycleAxes =
  | Init(initSubject)
  | Fetch(fetchSubject)
  | Authenticate(authenticateSubject)
  | Checkout(checkoutSubject)
  | Encrypt(encryptSubject)
  | Validate(validateSubject)
  | SignOut(sessionSubject)
  | Resend(otpSubject)

type scriptSubject =
  | UiKitScript(SdkLogger.outcome)
  | UiKitStylesheet(SdkLogger.outcome)
  | ProviderScript(SdkLogger.outcome)

type scriptAxes = Load(scriptSubject)

let lifecycleAxes = (event: lifecycleEvent): lifecycleAxes =>
  switch event {
  | ProviderInitialized => Init(Provider(Done))
  | ProviderNotInitialized => Init(Provider(Failed))
  | RecognitionTokenFetched => Fetch(RecognitionToken(Done))
  | CardsFetched(_) => Fetch(Cards(Done))
  | AuthenticationCompleted => Authenticate(Customer(Done))
  | AuthenticationPending(_) => Authenticate(Customer(Started))
  | AuthenticationFailed(_) => Authenticate(Customer(Failed))
  | CheckoutSucceeded => Checkout(Card(Done))
  | CheckoutFailed(_) => Checkout(Card(Failed))
  | SessionInitFailed(_) => Init(AuthenticatedSession(Failed))
  | ProviderInitFailed(_) => Init(Provider(Failed))
  | SignOutFailed(_) => SignOut(Session(Failed))
  | CardsFetchFailed(_) => Fetch(Cards(Failed))
  | GetUserTypeFailed(_) => Fetch(UserType(Failed))
  | OtpValidationFailed(_) => Validate(Otp(Failed))
  | OtpResendFailed(_) => Resend(Otp(Failed))
  | CardEncryptionFailed => Encrypt(Card(Failed))
  | WindowReferenceMissing => Validate(WindowReference(Failed))
  }

let scriptAxes = (event: scriptEvent): scriptAxes =>
  switch event {
  | UiKitScriptLoaded => Load(UiKitScript(Done))
  | UiKitScriptError => Load(UiKitScript(Failed))
  | UiKitStylesheetLoaded => Load(UiKitStylesheet(Done))
  | UiKitStylesheetError => Load(UiKitStylesheet(Failed))
  | ProviderScriptLoaded => Load(ProviderScript(Done))
  | ProviderScriptReused => Load(ProviderScript(Reused))
  | ProviderScriptError => Load(ProviderScript(Failed))
  }

let providerDimension = "ctp_provider"
let eventIdPrefix = "cte_"

let lifecycleSeverity = event =>
  switch event {
  | CheckoutFailed(_)
  | AuthenticationFailed(_)
  | SessionInitFailed(_)
  | ProviderInitFailed(_)
  | SignOutFailed(_)
  | CardsFetchFailed(_)
  | GetUserTypeFailed(_)
  | OtpValidationFailed(_)
  | OtpResendFailed(_)
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

let logLifecycle = (~event: lifecycleEvent, ~message=?, ~details=[], ~exn=?) => {
  let (eventName, taxonomyDetails) = event->lifecycleAxes->SdkLogger.axesEmission
  LoggerRuntime.logEvent(
    ~category=Lifecycle,
    ~severity=lifecycleSeverity(event),
    ~event,
    ~eventNameOverride=eventName,
    ~taxonomyDetails,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~exn?,
  )
}

let logScript = (~event: scriptEvent, ~message=?, ~details=[], ~exn=?) => {
  let (eventName, taxonomyDetails) = event->scriptAxes->SdkLogger.axesEmission
  LoggerRuntime.logEvent(
    ~category=Resource,
    ~severity=scriptSeverity(event),
    ~event,
    ~eventNameOverride=eventName,
    ~taxonomyDetails,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~exn?,
  )
}

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
