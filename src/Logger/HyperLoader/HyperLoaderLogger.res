open LoggerCommonHelpers

type merchantFunction =
  | Init
  | Reinit
  | LoadHyper
  | CreateElements
  | CreateWidgets
  | Create
  | Mount
  | Unmount
  | Destroy
  | Update
  | Clear
  | Focus
  | Blur
  | ConfirmPayment
  | ConfirmCardPayment
  | ConfirmOneClickPayment
  | RetrievePaymentIntent
  | PaymentRequest
  | UpdateIntent
  | InitiateUpdateIntent
  | CompleteUpdateIntent
  | InitPaymentSession
  | GetCustomerSavedPaymentMethods
  | ConfirmWithCustomerDefaultPaymentMethod
  | ConfirmWithLastUsedPaymentMethod
  | PaymentManagementElements
  | Deinit
  | Tokenize
  | OneClickHandler
  | Collapse
  | On
  | GetElement
  | FetchUpdates

type merchantEvent =
  | Hyper(merchantFunction)
  | Elements(merchantFunction)
  | PaymentElement(merchantFunction)
  | CardForm(merchantFunction)
  | PaymentSession(merchantFunction)
  | PaymentMethodsSession(merchantFunction)

type merchantProp =
  | Appearance
  | Layout
  | Fields
  | Wallets
  | Terms
  | Business
  | DefaultValues
  | Branding
  | Locale
  | Loader
  | Fonts
  | CustomerPaymentMethods
  | PaymentMethodsConfig
  | PreloadSdkWithParams
  | TestMode
  | BlockConfirm
  | CustomPodUri
  | RedirectionFlags
  | CustomBackendUrl
  | Options

type merchantPropsEvent =
  | HyperProp(merchantProp)
  | ElementsProp(merchantProp)
  | PaymentElementProp(merchantProp)
  | CardFormProp(merchantProp)
  | PaymentSessionProp(merchantProp)

let eventIdPrefix = "hl_"
let merchantDimension = "merchant_api"

let observeMerchant = (
  ~event: merchantEvent,
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) =>
  LoggerRuntime.observeProviderAsync(
    ~category=Merchant,
    ~event,
    ~providerDimension=merchantDimension,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure?,
    ~resultDetails?,
    ~call,
  )

let observeMerchantSync = (~event: merchantEvent, ~message=?, ~details=[], ~call) =>
  LoggerRuntime.observeProviderSync(
    ~category=Merchant,
    ~event,
    ~providerDimension=merchantDimension,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~call,
  )

let logMerchantProps = (~event: merchantPropsEvent, ~message=?, ~details=[]) =>
  LoggerRuntime.logNamespacedEvent(
    ~category=Merchant,
    ~severity=Info,
    ~action="props",
    ~event,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logLifecycle = (
  ~event: SdkLogger.lifecycleEvent,
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~exn=?,
) => SdkLogger.logLifecycle(~event, ~paymentMethod?, ~message?, ~details, ~exn?)

let logState = (~event: SdkLogger.stateEvent, ~paymentMethod=?, ~message=?, ~details=[], ~exn=?) =>
  SdkLogger.logState(~event, ~paymentMethod?, ~message?, ~details, ~exn?)

let logUser = (~event: SdkLogger.userEvent, ~paymentMethod=?, ~message=?, ~details=[], ~exn=?) =>
  SdkLogger.logUser(~event, ~paymentMethod?, ~message?, ~details, ~exn?)

let logResource = (
  ~event: SdkLogger.resourceEvent,
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~exn=?,
) => SdkLogger.logResource(~event, ~paymentMethod?, ~message?, ~details, ~exn?)

let logCrash = (~paymentMethod=?, ~message=?, ~details=[], ~exn=?) =>
  SdkLogger.logCrash(~paymentMethod?, ~message?, ~details, ~exn?)

let observeFunction = (
  ~event: SdkLogger.functionEvent,
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) =>
  SdkLogger.observeFunction(
    ~event,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~timeoutMs,
    ~resultFailure?,
    ~resultDetails?,
    ~call,
  )
