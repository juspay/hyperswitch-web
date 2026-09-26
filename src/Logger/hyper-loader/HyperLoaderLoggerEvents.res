open LoggerTypes

// Surface

type surface =
  | Hyper
  | Elements
  | PaymentElement
  | CardForm
  | CardField
  | PaymentSession
  | PaymentMethodsSession

type surfaceData = {surface: surface}

// Merchant call

type merchantCallEvent =
  | Init(surfaceData)
  | Reinit(surfaceData)
  | Deinit(surfaceData)
  | LoadHyper(surfaceData)
  | CreateElements(surfaceData)
  | CreateWidgets(surfaceData)
  | Create(surfaceData)
  | CreateCardForm(surfaceData)
  | GetElement(surfaceData)
  | Mount(surfaceData)
  | Unmount(surfaceData)
  | Destroy(surfaceData)
  | Update(surfaceData)
  | ConfirmPayment(surfaceData)
  | ConfirmCardPayment(surfaceData)
  | ConfirmOneClickPayment(surfaceData)
  | ConfirmWithCustomerDefaultPaymentMethod(surfaceData)
  | ConfirmWithLastUsedPaymentMethod(surfaceData)
  | RetrievePaymentIntent(surfaceData)
  | PaymentRequest(surfaceData)
  | InitPaymentSession(surfaceData)
  | InitPaymentMethodSession(surfaceData)
  | InitAuthenticationSession(surfaceData)
  | PaymentMethodsManagementElements(surfaceData)
  | GetCustomerSavedPaymentMethods(surfaceData)
  | GetCustomerDefaultSavedPaymentMethodData(surfaceData)
  | GetCustomerLastUsedPaymentMethodData(surfaceData)
  | UpdateIntent(surfaceData)
  | InitiateUpdateIntent(surfaceData)
  | CompleteUpdateIntent(surfaceData)
  | FetchUpdates(surfaceData)
  | Tokenize(surfaceData)
  | ConfirmTokenization(surfaceData)

let merchantCallSeverity = event =>
  switch event {
  | ConfirmPayment(_)
  | ConfirmCardPayment(_)
  | ConfirmOneClickPayment(_)
  | ConfirmWithCustomerDefaultPaymentMethod(_)
  | ConfirmWithLastUsedPaymentMethod(_)
  | PaymentRequest(_)
  | Tokenize(_)
  | ConfirmTokenization(_) => defaultSeverity
  | Init(_)
  | Reinit(_)
  | Deinit(_)
  | LoadHyper(_)
  | CreateElements(_)
  | CreateWidgets(_)
  | Create(_)
  | CreateCardForm(_)
  | GetElement(_)
  | Mount(_)
  | Unmount(_)
  | Destroy(_)
  | Update(_)
  | RetrievePaymentIntent(_)
  | InitPaymentSession(_)
  | InitPaymentMethodSession(_)
  | InitAuthenticationSession(_)
  | PaymentMethodsManagementElements(_)
  | GetCustomerSavedPaymentMethods(_)
  | GetCustomerDefaultSavedPaymentMethodData(_)
  | GetCustomerLastUsedPaymentMethodData(_)
  | UpdateIntent(_)
  | InitiateUpdateIntent(_)
  | CompleteUpdateIntent(_)
  | FetchUpdates(_) => {...defaultSeverity, success: Debug}
  }

// Merchant prop

type merchantPropEvent =
  | Appearance(surfaceData)
  | Locale(surfaceData)
  | Loader(surfaceData)
  | Fonts(surfaceData)
  | PaymentElementOptions(surfaceData)
  | PreloadSdkWithParams(surfaceData)
  | TestMode(surfaceData)
  | BlockConfirm(surfaceData)
  | CustomPodUri(surfaceData)
  | CustomBackendUrl(surfaceData)
  | RedirectionFlags(surfaceData)

let merchantPropSeverity = event =>
  switch event {
  | Appearance(_)
  | Locale(_)
  | Loader(_)
  | Fonts(_)
  | PaymentElementOptions(_)
  | PreloadSdkWithParams(_)
  | TestMode(_)
  | BlockConfirm(_)
  | CustomPodUri(_)
  | CustomBackendUrl(_)
  | RedirectionFlags(_) =>
    Debug
  }

// Merchant callback

type merchantCallbackEvent =
  | OnSdkHandleClick(surfaceData)
  | UpdateIntent(surfaceData)

let merchantCallbackSeverity = event =>
  switch event {
  | OnSdkHandleClick(_)
  | UpdateIntent(_) => {...defaultSeverity, success: Debug, failure: Warning}
  }

// Merchant issue

type merchantIssue =
  | InvalidPublishableKey
  | InsecureProtocol
  | MissingParameter
  | MalformedValue
  | ImmutableAfterMount
  | ExpectedBoolean
  | ExpectedString
  | ExpectedNumber
  | ValueOutOfRange
  | ConnectorMisconfigured
  | UnsupportedOptionValue
  | UnknownOptionKey
  | DeprecatedMethod

let merchantIssueSeverity = (issue): severity =>
  switch issue {
  | InvalidPublishableKey
  | InsecureProtocol
  | MissingParameter
  | MalformedValue =>
    Error
  | ImmutableAfterMount
  | ExpectedBoolean
  | ExpectedString
  | ExpectedNumber
  | ValueOutOfRange
  | ConnectorMisconfigured
  | UnsupportedOptionValue
  | UnknownOptionKey
  | DeprecatedMethod =>
    Warning
  }
