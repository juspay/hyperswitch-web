open LoggerCommonHelpers

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

type sessionValidationError = InvalidClientSecret | MissingAuthenticationId
type authenticationSessionValidation = Valid | Invalid(sessionValidationError)
type providerErrorSummary = {reason: option<string>, messagePresent: bool}
type directProviderReadiness =
  | Ready
  | LoadStatusMissing
  | ScriptUnavailable
  | InitializationFailed
  | AdapterUnavailable
type checkoutWindowSource = Provided | Created
type customerPresenceDegradationReason = DirectSdkUnavailable | IdentityLookupFailed

// Lifecycle payloads are typed and event-linked: the event value carries its own facts, and the
// emitter derives the JSON details from them (no hand-typed keys, no wrong-shape mistakes).

type visaUctpGetCardsCode = Success | PendingConsumerIdv | Failed | Error | AddCard
type getCardsResultDetails = {
  code: visaUctpGetCardsCode,
  providerError: option<providerErrorSummary>,
}
type recognizedCardCounts = {visaCount: int, mastercardCount: int, totalCount: int}
type directSdkAvailability = {visaLoaded: bool, mastercardLoaded: bool}
type directSdkReadiness = {
  visaReadiness: directProviderReadiness,
  mastercardReadiness: directProviderReadiness,
}
type authenticationSessionRejection = {reason: sessionValidationError}
type customerAuthenticationRequiredDetails = {
  maskedValidationChannelProvided: bool,
  supportedValidationChannelCount: int,
}
type checkoutCardNotFoundDetails = {totalCardsCount: int}
type customerPresenceDetails = {
  visaPresent: bool,
  mastercardPresent: bool,
  visaReadiness: directProviderReadiness,
  mastercardReadiness: directProviderReadiness,
  degradationReason: option<customerPresenceDegradationReason>,
}
type checkoutWindowDetails = {source: checkoutWindowSource}
type providerCodeDetails = {code: string}

type clickToPayLifecycle =
  | AuthenticationSessionRejected(authenticationSessionRejection)
  | TokenCacheReused
  | CustomerAuthenticationRequired(customerAuthenticationRequiredDetails)
  | RecognizedCardsPresent(recognizedCardCounts)
  | NoCardsPresent
  | CustomerPresent(customerPresenceDetails)
  | CustomerNotPresent(customerPresenceDetails)
  | CustomerPresenceDegraded(customerPresenceDetails)
  | CheckoutCardNotFound(checkoutCardNotFoundDetails)
  | DirectSdkScriptsDegraded(directSdkAvailability)
  | DirectSdkScriptsUnavailable(directSdkAvailability)
  | DirectSdksDegraded(directSdkReadiness)
  | DirectSdksUnavailable(directSdkReadiness)
  | CheckoutWindowUnavailable(checkoutWindowDetails)

type visaUctpLifecycle =
  | UserTypeResult(getCardsResultDetails)
  | CustomerAuthenticationResult(getCardsResultDetails)
  | CheckoutSucceeded(providerCodeDetails)
  | CheckoutChangeCard(providerCodeDetails)
  | CheckoutSwitchConsumer(providerCodeDetails)
  | CheckoutRejected(providerCodeDetails)
  | UnbindAppInstanceSucceeded
  | UnbindAppInstanceRejected(providerErrorSummary)

type visaDirectLifecycle = SrciAdapterCreationFailed

type lifecycleEvent =
  | ClickToPay(clickToPayLifecycle)
  | VisaUctp(visaUctpLifecycle)
  | VisaDirect(visaDirectLifecycle)

type providerEvent<'a, 'b, 'c> =
  | VisaUctp('a)
  | VisaDirect('b)
  | MastercardDirect('c)

type visaUctpFunction = Initialize | GetCards | Checkout | UnbindAppInstance
type directFunction = Init | IdentityLookup
type functionEvent = providerEvent<visaUctpFunction, directFunction, directFunction>

type apiEvent = EnabledAuthnMethodsToken | EligibilityCheck | AuthenticationSync

type visaUctpResource = VsdkScript
type visaDirectResource = SrciAdapterScript
type mastercardDirectResource = SrcSdkScript
type resourceEvent = providerEvent<visaUctpResource, visaDirectResource, mastercardDirectResource>

type navigationTimeoutDetails = {timeoutMs: int}

type stateEvent =
  | CheckoutWindowNavigated
  | CheckoutWindowTimedOut(navigationTimeoutDetails)

let paymentMethod = "CLICK_TO_PAY"
let providerDimension = "ctp_provider"
let eventIdPrefix = "ctpe_"

let clickToPayLifecycleSeverity = (event: clickToPayLifecycle) =>
  switch event {
  | CustomerAuthenticationRequired(_)
  | RecognizedCardsPresent(_)
  | NoCardsPresent
  | CustomerPresent(_)
  | CustomerNotPresent(_) =>
    Info
  | AuthenticationSessionRejected(_) => LoggerCommonHelpers.Error
  | CustomerPresenceDegraded(_) => Warning
  | DirectSdkScriptsDegraded(_)
  | DirectSdkScriptsUnavailable(_)
  | DirectSdksDegraded(_)
  | DirectSdksUnavailable(_) =>
    Warning
  | CheckoutCardNotFound(_)
  | CheckoutWindowUnavailable(_) =>
    Warning
  | _ => Debug
  }

let visaUctpLifecycleSeverity = (event: visaUctpLifecycle) =>
  switch event {
  | UserTypeResult(details)
  | CustomerAuthenticationResult(details) =>
    switch details.code {
    | Failed | Error => LoggerCommonHelpers.Error
    | PendingConsumerIdv | AddCard => Info
    | _ => Debug
    }
  | CheckoutChangeCard(_)
  | CheckoutSwitchConsumer(_) =>
    Info
  | CheckoutRejected(_) => LoggerCommonHelpers.Error
  | UnbindAppInstanceRejected(_) => LoggerCommonHelpers.Error
  | _ => Debug
  }

let visaDirectLifecycleSeverity = (event: visaDirectLifecycle) =>
  switch event {
  | SrciAdapterCreationFailed => LoggerCommonHelpers.Error
  | _ => Debug
  }

let stateSeverity = (event: stateEvent) =>
  switch event {
  | CheckoutWindowTimedOut(_) => Warning
  | _ => Debug
  }

let logLifecycle = (~event: lifecycleEvent, ~message=?) =>
  switch event {
  | ClickToPay(event) =>
    LoggerRuntime.logEvent(
      ~category=Lifecycle,
      ~severity=clickToPayLifecycleSeverity(event),
      ~event,
      ~providerDimension,
      ~paymentMethod,
      ~message?,
      ~eventIdPrefix,
    )
  | VisaUctp(providerEvent) =>
    LoggerRuntime.logProviderEvent(
      ~category=Lifecycle,
      ~severity=visaUctpLifecycleSeverity(providerEvent),
      ~event,
      ~providerDimension,
      ~paymentMethod,
      ~message?,
      ~eventIdPrefix,
    )
  | VisaDirect(providerEvent) =>
    LoggerRuntime.logProviderEvent(
      ~category=Lifecycle,
      ~severity=visaDirectLifecycleSeverity(providerEvent),
      ~event,
      ~providerDimension,
      ~paymentMethod,
      ~message?,
      ~eventIdPrefix,
    )
  }

let observeMerchant = (
  ~event: merchantEvent,
  ~message=?,
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~call,
) => {
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
}

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
) => {
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
}

let observeApi = (
  ~event: apiEvent,
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
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
    ~resultDetails?,
    ~call,
  )

let observeResource = (
  ~event,
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

let logState = (~event: stateEvent, ~message=?) =>
  LoggerRuntime.logEvent(
    ~category=State,
    ~severity=stateSeverity(event),
    ~event,
    ~providerDimension,
    ~paymentMethod,
    ~message?,
    ~eventIdPrefix,
  )

let validateAuthenticationSession = (~clientSecret) => {
  let authenticationId = LoggerContext.current().authenticationId
  let clientSecretIsValid = switch GlobalVars.sdkVersion {
  | V1 => RegExp.test(".+_secret_[A-Za-z0-9]+"->RegExp.fromString, clientSecret)
  | V2 => true
  }

  if !clientSecretIsValid {
    Invalid(InvalidClientSecret)
  } else if authenticationId === "" || authenticationId === "null" {
    Invalid(MissingAuthenticationId)
  } else {
    Valid
  }
}
