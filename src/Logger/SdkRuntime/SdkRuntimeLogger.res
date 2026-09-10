open LoggerCommonHelpers

type networkStateDetails = {online: bool}

type phase = Init | Done | Failed

type lifecycleEvent =
  | LogInitiated
  | DisplayThreeDsSdk
  | DisplayThreeDsSdkFailed
  | ThreeDsMethodResult
  | ThreeDsMethodFailed
  | WalletInteraction
  | WalletInteractionFailed
  | PaymentMethodTypeDetectionFailed
  | S3DataFetchFailed

type cardFormScope = PaymentForm | VaultForm
type cardFormChangedDetails = {scope: cardFormScope}
type componentVisibilityDetails = {visible: bool}
type clickToPayViewDetails = {view: string}

type stateEvent =
  | NetworkStateChanged(networkStateDetails)
  | CardFormMounted(cardFormChangedDetails)
  | CardFormFieldMounted(cardFormChangedDetails)
  | CardFormUnmounted(cardFormChangedDetails)
  | DynamicFieldsUpdated
  | UpdateIntentLoadingChanged(componentVisibilityDetails)
  | SavedMethodsViewToggled(componentVisibilityDetails)
  | VaultScriptReadyChanged(componentVisibilityDetails)
  | ClickToPayViewChanged(clickToPayViewDetails)

type userEvent =
  | PaymentMethodSelected
  | PaymentDataFilled
  | InputFieldChanged
  | FieldBlurred
  | FieldFocused
  | FieldCleared
  | CardSchemeSelected
  | WalletButtonClicked
  | PayButtonClicked
  | SavedMethodSelected
  | SavedMethodDeleted
  | SavedMethodUpdated
  | WalletSheetCancelled
  | ViewToggled

type functionEvent =
  | LoadPaymentData
  | LoadPaymentSheet
  | IsReadyToPay
  | Authorize
  | CreateInstance
  | Tokenize
  | SubmitVaultForm

type providerFunctionEvent =
  | GooglePay(functionEvent)
  | SamsungPay(functionEvent)
  | ApplePay(functionEvent)
  | Trustpay(functionEvent)
  | Braintree(functionEvent)
  | Paypal(functionEvent)
  | Klarna(functionEvent)
  | Plaid(functionEvent)
  | Paze(functionEvent)
  | Vgs(functionEvent)

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

type resourceProvider =
  | GooglePayScript
  | SamsungPayScript
  | TrustpayScript
  | PmAuthConnectorScript
  | ApplePayBraintreeScript
  | BraintreeClientScript
  | ApplePayScript
  | PaypalScript
  | PazeScript
  | KlarnaScript
  | VgsScript
  | FontStylesheet

type resourceEvent = ScriptLoad(resourceProvider, phase)

type crashEvent = SdkCrash

let eventIdPrefix = "sre_"

let phaseSeverity = (phase: phase) =>
  switch phase {
  | Init => Debug
  | Done => Info
  | Failed => Error
  }

let lifecycleSeverity = event =>
  switch event {
  | DisplayThreeDsSdkFailed
  | ThreeDsMethodFailed
  | PaymentMethodTypeDetectionFailed
  | S3DataFetchFailed
  | WalletInteractionFailed =>
    Error
  | _ => Info
  }

let stateSeverity = event =>
  switch event {
  | NetworkStateChanged({online: false}) => Warning
  | _ => Debug
  }

let merchantDimension = "merchant_api"

let resourceSeverity = event =>
  switch event {
  | ScriptLoad(_, phase) => phaseSeverity(phase)
  }

let logLifecycle = (~event: lifecycleEvent, ~paymentMethod=?, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Lifecycle,
    ~severity=lifecycleSeverity(event),
    ~event,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logState = (~event: stateEvent, ~paymentMethod=?, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=State,
    ~severity=stateSeverity(event),
    ~event,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logUser = (~event: userEvent, ~paymentMethod=?, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=User,
    ~severity=Info,
    ~event,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let observeFunction = (
  ~event: functionEvent,
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) =>
  LoggerRuntime.observeEventAsync(
    ~category=Function,
    ~event,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure?,
    ~resultDetails?,
    ~call,
  )

let observeProviderFunction = (
  ~event: providerFunctionEvent,
  ~paymentMethod=?,
  ~message=?,
  ~details=[],
  ~timeoutMs=LoggerCommonHelpers.defaultOperationTimeoutMs,
  ~resultFailure=?,
  ~resultDetails=?,
  ~call,
) =>
  LoggerRuntime.observeProviderAsync(
    ~category=Function,
    ~event,
    ~paymentMethod?,
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

let logResource = (~event: resourceEvent, ~paymentMethod=?, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Resource,
    ~severity=resourceSeverity(event),
    ~event,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logCrash = (~paymentMethod=?, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Crash,
    ~severity=Error,
    ~event=SdkCrash,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )
