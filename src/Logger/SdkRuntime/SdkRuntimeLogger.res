open LoggerCommonHelpers

type loadState = Loaded | Loading | SemiLoaded | LoadError
type loaderChangedDetails = {state: loadState}
type networkStateDetails = {online: bool}

type phase = Started | Progressed | Failed

type lifecycleEvent =
  | LogInitiated
  | AppRendered
  | LoaderChanged(loaderChangedDetails)
  | PaymentOptionsProvided
  | DynamicFieldsRendered
  | DisplayThreeDsSdk
  | DisplayThreeDsSdkFailed
  | ThreeDsMethodResult
  | ThreeDsMethodFailed
  | CardFormCreated
  | CardFormFieldCreated
  | CardFormDeinitialized

type stateEvent = NetworkStateChanged(networkStateDetails)

type userEvent =
  | PaymentMethodSelected
  | PaymentDataFilled
  | InputFieldChanged
  | FieldBlurred
  | FieldFocused
  | FieldCleared
  | CardSchemeSelected

type walletProvider =
  | ApplePay
  | GooglePay
  | Paypal
  | PaypalSdk
  | Klarna
  | KlarnaSdk
  | Paze
  | SamsungPay
  | Plaid
  | Vgs

type functionEvent =
  | WalletFlow(walletProvider, phase)
  | OneClickHandlerCallback(phase)
  | CardFormConfirm(phase)
  | PaymentMethodTypeDetectionFailed
  | S3Api

type resourceProvider =
  | GooglePayScript
  | SamsungPayScript
  | TrustpayScript
  | PmAuthConnectorScript
  | ApplePayBraintreeScript
  | BraintreeClientScript

type resourceEvent = ScriptLoad(resourceProvider, phase)

type crashEvent = SdkCrash

let eventIdPrefix = "sre_"

let phaseSeverity = phase =>
  switch phase {
  | Started => Debug
  | Progressed => Info
  | Failed => Error
  }

let lifecycleSeverity = event =>
  switch event {
  | LoaderChanged({state: LoadError})
  | DisplayThreeDsSdkFailed
  | ThreeDsMethodFailed =>
    Error
  | _ => Info
  }

let stateSeverity = event =>
  switch event {
  | NetworkStateChanged({online: false}) => Warning
  | _ => Debug
  }

let functionSeverity = event =>
  switch event {
  | WalletFlow(_, phase)
  | OneClickHandlerCallback(phase)
  | CardFormConfirm(phase) =>
    phaseSeverity(phase)
  | PaymentMethodTypeDetectionFailed
  | S3Api =>
    Error
  }

let resourceSeverity = event =>
  switch event {
  | ScriptLoad(_, phase) => phaseSeverity(phase)
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

let logState = (~event: stateEvent, ~message=?) =>
  LoggerRuntime.logEvent(
    ~category=State,
    ~severity=stateSeverity(event),
    ~event,
    ~message?,
    ~eventIdPrefix,
  )

let logUser = (~event: userEvent, ~paymentMethod="", ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=User,
    ~severity=Info,
    ~event,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logFunction = (~event: functionEvent, ~paymentMethod="", ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Function,
    ~severity=functionSeverity(event),
    ~event,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logResource = (~event: resourceEvent, ~paymentMethod="", ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Resource,
    ~severity=resourceSeverity(event),
    ~event,
    ~paymentMethod,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )

let logCrash = (~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=Crash,
    ~severity=Error,
    ~event=SdkCrash,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )
