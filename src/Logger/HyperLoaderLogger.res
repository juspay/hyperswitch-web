open LoggerTypes

type method =
  | Init
  | Reinit
  | Deinit
  | LoadHyper
  | CreateElements
  | CreateWidgets
  | Create
  | GetElement
  | Mount
  | Unmount
  | Destroy
  | Update
  | Clear
  | Collapse
  | Focus
  | Blur
  | ConfirmPayment
  | ConfirmCardPayment
  | ConfirmOneClickPayment
  | ConfirmWithCustomerDefaultPaymentMethod
  | ConfirmWithLastUsedPaymentMethod
  | RetrievePaymentIntent
  | PaymentRequest
  | InitPaymentSession
  | InitPaymentMethodSession
  | PaymentManagementElements
  | GetCustomerSavedPaymentMethods
  | UpdateIntent
  | InitiateUpdateIntent
  | CompleteUpdateIntent
  | FetchUpdates
  | OneClickHandler
  | Tokenize

type merchantCallEvent =
  | Hyper(method)
  | Elements(method)
  | PaymentElement(method)
  | CardForm(method)
  | PaymentSession(method)
  | PaymentMethodsSession(method)

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
  | PaymentElementOptions
  | PreloadSdkWithParams
  | TestMode
  | BlockConfirm
  | CustomPodUri
  | CustomBackendUrl
  | RedirectionFlags

type merchantPropEvent =
  | HyperProp(merchantProp)
  | ElementsProp(merchantProp)

type merchantIssue =
  | InvalidPublishableKey
  | InsecureProtocol
  | MissingParameter
  | MalformedValue
  | ExpectedBoolean
  | ExpectedString
  | ExpectedNumber
  | ValueOutOfRange
  | ConnectorMisconfigured
  | DeprecatedMethod

let namespace = event => event->LoggerUtils.variantName

let methodOf = event =>
  switch event {
  | Hyper(method)
  | Elements(method)
  | PaymentElement(method)
  | CardForm(method)
  | PaymentSession(method)
  | PaymentMethodsSession(method) => method
  }

let merchantCallSpec = event =>
  makeOperation(call, `${event->namespace}_${event->methodOf->LoggerUtils.variantName}`)

let merchantCallSeverity = event =>
  switch event->methodOf {
  | ConfirmPayment
  | ConfirmCardPayment
  | ConfirmOneClickPayment
  | ConfirmWithCustomerDefaultPaymentMethod
  | ConfirmWithLastUsedPaymentMethod
  | PaymentRequest
  | Tokenize => {success: Info, failure: Error}
  | _ => {success: Debug, failure: Error}
  }

let merchantPropSpec = event => {
  let merchantProp = switch event {
  | HyperProp(merchantProp) | ElementsProp(merchantProp) => merchantProp
  }
  {action: Some("prop"), subject: merchantProp->LoggerUtils.variantName, outcome: None}
}

let merchantPropDetails = event => [
  (
    "surface",
    switch event {
    | HyperProp(_) => "hyper"
    | ElementsProp(_) => "elements"
    }->JSON.Encode.string,
  ),
]

let merchantPropSeverity = Debug

let merchantIssueSpec = issue => {
  action: None,
  subject: issue->LoggerUtils.variantName,
  outcome: Some(Failed),
}

let merchantIssueSeverity = issue =>
  switch issue {
  | InsecureProtocol => Error
  | InvalidPublishableKey
  | MissingParameter
  | MalformedValue
  | ExpectedBoolean
  | ExpectedString
  | ExpectedNumber
  | ValueOutOfRange
  | ConnectorMisconfigured
  | DeprecatedMethod => Warning
  }

let observeMerchantCall = (
  ~event: merchantCallEvent,
  ~details=[],
  ~timeoutMs=?,
  ~failureOf=LoggerUtils.summarizeErrorResponse,
  ~detailsOf=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Merchant,
    ~spec=event->merchantCallSpec,
    ~severity=event->merchantCallSeverity,
    ~details,
    ~timeoutMs?,
    ~failureOf,
    ~detailsOf?,
    ~call,
  )

let logMerchantCall = (~event: merchantCallEvent, ~details=[], ~call) =>
  LoggerRuntime.observeSync(
    ~category=Merchant,
    ~spec=event->merchantCallSpec,
    ~severity=event->merchantCallSeverity,
    ~details,
    ~call,
  )

let recordMerchantCall = (~event: merchantCallEvent, ~details=[]) =>
  LoggerRuntime.record(
    ~category=Merchant,
    ~spec=event->merchantCallSpec,
    ~severity=(event->merchantCallSeverity).success,
    ~details,
  )

let logMerchantProps = (~event: merchantPropEvent, ~details=[]) =>
  LoggerRuntime.emit(
    ~category=Merchant,
    ~spec=event->merchantPropSpec,
    ~severity=merchantPropSeverity,
    ~details=event->merchantPropDetails->Array.concat(details),
  )

let logMerchantIssue = (~issue: merchantIssue, ~details=[]) =>
  LoggerRuntime.emit(
    ~category=Merchant,
    ~spec=issue->merchantIssueSpec,
    ~severity=issue->merchantIssueSeverity,
    ~details,
  )

let startSession = (~sessionId=?, ~merchantId=?, ~profileId=?) => {
  LoggerRuntime.configure(~source=HyperLoader)
  LoggerContext.setSessionData(~sessionId?, ~merchantId?, ~profileId?, ())
}
