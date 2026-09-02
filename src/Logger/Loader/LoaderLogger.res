open LoggerCommonHelpers

type lifecycleEvent =
  | AppInitiated
  | AppReinitiated
  | LoaderCalled
  | ElementsCalled
  | PaymentManagementElementsCalled
  | PaymentSessionInitiated
  | AppRendered
  | PaymentOptionsProvided
  | TestMode
  | PreloadSdkWithParams
  | InvalidPublishableKey
  | HttpNotAllowed
  | DeprecatedLoadStripe
  | RequiredParameter
  | InvalidFormat
  | TypeBoolError
  | TypeStringError
  | TypeIntError
  | ValueOutOfRange
  | SdkConnectorWarning
  | InternalApiDown

type loadState = Loaded | Loading | SemiLoaded | LoadError
type loaderChangedDetails = {state: loadState}
type stateEvent = LoaderChanged(loaderChangedDetails)

let eventIdPrefix = "lde_"

let lifecycleSeverity = event =>
  switch event {
  | InvalidPublishableKey
  | HttpNotAllowed
  | RequiredParameter
  | InvalidFormat
  | TypeBoolError
  | TypeStringError
  | TypeIntError =>
    Error
  | DeprecatedLoadStripe
  | ValueOutOfRange
  | SdkConnectorWarning
  | InternalApiDown =>
    Warning
  | _ => Info
  }

let stateSeverity = event =>
  switch event {
  | LoaderChanged({state: LoadError}) => Error
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

let logState = (~event: stateEvent, ~message=?, ~details=[]) =>
  LoggerRuntime.logEvent(
    ~category=State,
    ~severity=stateSeverity(event),
    ~event,
    ~message?,
    ~details,
    ~eventIdPrefix,
  )
