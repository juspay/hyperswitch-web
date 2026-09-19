open LoggerTypes

type provider =
  | VisaUctp
  | VisaDirect
  | MastercardUctp
  | MastercardDirect

type providerFunction =
  | Initialize
  | IdentityLookup
  | GetCards
  | Authenticate
  | EncryptCard
  | Checkout
  | UnbindAppInstance

type merchantMethod =
  | InitSession
  | GetActiveSession
  | GetUserType
  | GetRecognizedCards
  | ValidateAuthentication
  | CheckoutWithCard
  | SignOut

type apiEvent =
  | EnabledAuthnMethodsToken
  | EligibilityCheck
  | AuthenticationSync

type resourceEvent =
  | VisaSdkScript
  | MastercardSdkScript
  | UiKitScript
  | UiKitStylesheet

type cardsData = {visa: int, mastercard: int}
type declineData = {code: string}

type lifecycleEvent =
  | ProviderReady
  | ProviderUnavailable
  | RecognitionTokenFound
  | CardsListed(cardsData)
  | CardsUnavailable(declineData)
  | CustomerVerificationRequired
  | CustomerRecognised
  | CheckoutCompleted
  | CheckoutDeclined(declineData)
  | CheckoutFailed
  | OtpRejected
  | PopupBlocked

let providerName = provider => provider->LoggerUtils.variantValue

let lifecycleSeverity = value =>
  switch value {
  | ProviderReady
  | RecognitionTokenFound
  | CardsListed(_) => Debug
  | CustomerVerificationRequired
  | CustomerRecognised
  | CheckoutCompleted
  | CheckoutDeclined(_) => Info
  | ProviderUnavailable
  | CardsUnavailable(_)
  | OtpRejected => Warning
  | CheckoutFailed
  | PopupBlocked => Error
  }

let functionSpec = (~provider: provider, ~function: providerFunction) =>
  makeOperation(
    call,
    `${provider->LoggerUtils.variantName}_${function->LoggerUtils.variantName}`,
  )

let functionSeverity = function =>
  switch function {
  | Initialize
  | IdentityLookup
  | GetCards
  | Authenticate
  | UnbindAppInstance => {success: Debug, failure: Warning}
  | EncryptCard | Checkout => {success: Debug, failure: Error}
  }

let merchantCallSpec = method => makeOperation(call, method->LoggerUtils.variantName)

let merchantCallSeverity = method =>
  switch method {
  | CheckoutWithCard => {success: Info, failure: Error}
  | InitSession
  | GetActiveSession
  | GetUserType
  | GetRecognizedCards
  | ValidateAuthentication
  | SignOut => {success: Debug, failure: Warning}
  }

let apiSpec = value => makeOperation(request, value->LoggerUtils.variantName)

let apiSeverity = {success: Info, failure: Error}

let resourceSpec = value => makeOperation(load, value->LoggerUtils.variantName)

let resourceSeverity = {success: Debug, failure: Warning}

let resourceKind = (value): ResourceLoader.resource =>
  switch value {
  | UiKitStylesheet => Stylesheet
  | VisaSdkScript | MastercardSdkScript | UiKitScript => Script
  }

let providerDetails = provider => [("provider", provider->providerName->JSON.Encode.string)]

let paymentMethod = LoggerTaxonomy.Card(Unspecified)

let logLifecycle = (~event: lifecycleEvent, ~provider: option<provider>=?, ~details=[], ~exn=?) =>
  LoggerRuntime.emit(
    ~category=Lifecycle,
    ~spec=event->LoggerUtils.deriveEvent,
    ~severity=event->lifecycleSeverity,
    ~data=event->LoggerUtils.recordDetails,
    ~details=provider->Option.map(providerDetails)->Option.getOr([])->Array.concat(details),
    ~exn?,
    ~paymentMethod,
  )

let observeFunction = (
  ~provider: provider,
  ~function: providerFunction,
  ~details=[],
  ~timeoutMs=?,
  ~detailsOf=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Function,
    ~spec=functionSpec(~provider, ~function),
    ~severity=function->functionSeverity,
    ~data=provider->providerDetails,
    ~details,
    ~timeoutMs?,
    ~failureOf=LoggerUtils.summarizeErrorResponse,
    ~detailsOf?,
    ~paymentMethod,
    ~call,
  )

let observeMerchantCall = (
  ~method: merchantMethod,
  ~details=[],
  ~timeoutMs=?,
  ~detailsOf=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Merchant,
    ~spec=method->merchantCallSpec,
    ~severity=method->merchantCallSeverity,
    ~details,
    ~timeoutMs?,
    ~failureOf=LoggerUtils.summarizeErrorResponse,
    ~detailsOf?,
    ~paymentMethod,
    ~call,
  )

let logMerchantCall = (~method: merchantMethod, ~details=[], ~call) =>
  LoggerRuntime.observeSync(
    ~category=Merchant,
    ~spec=method->merchantCallSpec,
    ~severity=method->merchantCallSeverity,
    ~details,
    ~paymentMethod,
    ~call,
  )

let observeApi = (
  ~event: apiEvent,
  ~url,
  ~details=[],
  ~failureOf=SdkLogger.httpFailure,
  ~detailsOf=SdkLogger.httpDetails,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Api,
    ~spec=event->apiSpec,
    ~severity=apiSeverity,
    ~data=[("url", url->JSON.Encode.string)],
    ~details,
    ~failureOf,
    ~detailsOf,
    ~paymentMethod,
    ~call,
  )

let observeResource = (~event: resourceEvent, ~url, ~onLoad=() => (), ~onError=_ => ()) =>
  LoggerRuntime.observeResource(
    ~spec=event->resourceSpec,
    ~severity=resourceSeverity,
    ~url,
    ~resource=event->resourceKind,
    ~paymentMethod,
    ~onLoad,
    ~onError,
  )
