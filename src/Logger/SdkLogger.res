open LoggerTypes

type walletStage =
  | SdkLoaded
  | InstanceCreated
  | SessionStarted
  | CollectFormCreated
  | ConfirmRequestReceived
  | PaymentCompleted
  | OneClickDeclined

type walletFlow =
  | Normal
  | Delayed
  | ThirdParty
  | Connector
  | PaypalSdkTabs

type walletFailure =
  | MissingIntent
  | MissingCurrency
  | MissingNonce
  | ConnectorNotFound
  | ClientUnavailable
  | PaymentsNotAllowed
  | ClientCreationFailed
  | AvailabilityCheckFailed
  | ListenerSetupFailed
  | MessageHandlingFailed
  | PaymentDataFailed
  | PaymentSyncFailed
  | SdkMountFailed
  | VaultBrokerFailed

type threeDsMethodFailure =
  | MissingContainer
  | FormSubmitFailed
  | IframeLoadFailed

type ddcFailure =
  | MissingUrl
  | InvalidNextAction
  | UnreadableResponse

type walletStageData = {stage: walletStage, connector?: string}
type walletFlowData = {flow: walletFlow, connector?: string}

type walletFailureData = {reason: walletFailure, connector?: string}
type threeDsChallengeData = {transStatus: string}
type threeDsMethodFailureData = {reason: threeDsMethodFailure}
type ddcFailureData = {reason: ddcFailure}
type paymentRequestData = {bodySize: int}

type paymentOutcomeData = {status: string, manualRetryAllowed: bool}
type customerRedirectData = {nextAction: string, redirectOrigin: string}
type redirectFailureData = {nextAction: string}
type voucherData = {downloads: int}
type unknownPaymentMethodData = {value: string}

type lifecycleEvent =
  | SdkInitialised
  | SdkConfigUpdated
  | AppRendered
  | PaymentRequested(paymentRequestData)
  | PaymentSucceeded(paymentOutcomeData)
  | PaymentFailed(paymentOutcomeData)
  | WalletFlowResolved(walletFlowData)
  | WalletStageReached(walletStageData)
  | WalletFlowFailed(walletFailureData)
  | CustomerRedirectCompleted(customerRedirectData)
  | RedirectUnsupported(redirectFailureData)
  | ThreeDsPopupOpened
  | ThreeDsPopupClosed
  | ThreeDsPopupFailed
  | ThreeDsChallengeShown(threeDsChallengeData)
  | ThreeDsChallengeFailed
  | ThreeDsMethodStarted
  | ThreeDsMethodCompleted
  | ThreeDsMethodFailed(threeDsMethodFailureData)
  | ThreeDsMethodTimedOut
  | DdcStarted
  | DdcCompleted
  | DdcFailed(ddcFailureData)
  | DdcTimedOut
  | QrCodeShown
  | VoucherShown(voucherData)
  | BankTransferShown
  | PaymentMethodUnresolved(unknownPaymentMethodData)
  | CountryDataUnavailable
  | EligibilityCheckFailed
  | VaultScriptUnavailable

let walletFailureSeverity = reason =>
  switch reason {
  | MissingIntent
  | MissingCurrency
  | ConnectorNotFound
  | PaymentsNotAllowed
  | ClientCreationFailed
  | AvailabilityCheckFailed
  | ListenerSetupFailed
  | SdkMountFailed => Warning
  | MissingNonce
  | ClientUnavailable
  | MessageHandlingFailed
  | PaymentDataFailed
  | PaymentSyncFailed
  | VaultBrokerFailed => Error
  }

let lifecycleSeverity = value =>
  switch value {
  | SdkInitialised
  | SdkConfigUpdated
  | PaymentRequested(_)
  | WalletFlowResolved(_)
  | WalletStageReached(_)
  | CustomerRedirectCompleted(_)
  | ThreeDsPopupOpened
  | ThreeDsPopupClosed
  | ThreeDsMethodStarted
  | DdcStarted => Debug

  | AppRendered
  | PaymentSucceeded(_)
  | PaymentFailed(_)
  | ThreeDsChallengeShown(_)
  | ThreeDsMethodCompleted
  | DdcCompleted
  | QrCodeShown
  | VoucherShown(_)
  | BankTransferShown => Info

  | ThreeDsMethodFailed(_)
  | ThreeDsMethodTimedOut
  | PaymentMethodUnresolved(_)
  | CountryDataUnavailable
  | EligibilityCheckFailed
  | VaultScriptUnavailable => Warning

  | RedirectUnsupported(_)
  | ThreeDsPopupFailed
  | ThreeDsChallengeFailed
  | DdcFailed(_)
  | DdcTimedOut => Error

  | WalletFlowFailed({reason}) => reason->walletFailureSeverity
  }

type cardFormScope = PaymentForm | VaultForm
type loaderState = Loading | SemiLoaded | Loaded | LoadFailed

type networkData = {online: bool}
type cardFormData = {scope: cardFormScope}
type cardFieldData = {scope: cardFormScope, field: string}
type loaderData = {state: loaderState}
type clickToPayViewData = {view: string}
type updateIntentData = {inProgress: bool}

type stateEvent =
  | NetworkStatusChanged(networkData)
  | LoaderStateChanged(loaderData)
  | CardFormMounted(cardFormData)
  | CardFormUnmounted(cardFormData)
  | CardFieldMounted(cardFieldData)
  | DynamicFieldsChanged
  | UpdateIntentProgressChanged(updateIntentData)
  | ClickToPayViewChanged(clickToPayViewData)

let stateSeverity = value =>
  switch value {
  | LoaderStateChanged({state: LoadFailed}) => Error
  | LoaderStateChanged({state: Loaded}) => Info
  | NetworkStatusChanged({online}) => online ? Debug : Warning
  | LoaderStateChanged(_)
  | CardFormMounted(_)
  | CardFormUnmounted(_)
  | CardFieldMounted(_)
  | DynamicFieldsChanged
  | UpdateIntentProgressChanged(_)
  | ClickToPayViewChanged(_) => Debug
  }

type view =
  | CardSchemeMenu
  | ShowMore
  | ShowLess
  | MorePaymentMethods
  | InstallmentOptions
  | NewPaymentMethods
  | ManageSavedMethod
  | ClickToPayNotYou
  | ClickToPayOtpResend

type fieldData = {field: string}
type methodData = {method: string}
type savedMethodData = {savedMethod: bool}
type savedMethodSelectionData = {requiresCvv: bool, isCardExpired: bool}
type viewData = {view: view}

type userEvent =
  | PaymentMethodSelected(methodData)
  | CardSchemeSelected(methodData)
  | SavedMethodSelected(savedMethodSelectionData)
  | SavedMethodUpdated
  | SavedMethodDeleted
  | PaymentDetailsCompleted(savedMethodData)
  | PayButtonClicked
  | WalletButtonClicked
  | WalletSheetDismissed
  | VoucherDownloaded
  | QrCodeCopied
  | FieldEdited(fieldData)
  | FieldFocused(fieldData)
  | FieldBlurred(fieldData)
  | ViewToggled(viewData)

let userSeverity = value =>
  switch value {
  | PaymentMethodSelected(_)
  | CardSchemeSelected(_)
  | SavedMethodSelected(_)
  | SavedMethodUpdated
  | SavedMethodDeleted
  | PaymentDetailsCompleted(_)
  | PayButtonClicked
  | WalletButtonClicked
  | WalletSheetDismissed
  | VoucherDownloaded
  | QrCodeCopied => Info
  | FieldEdited(_)
  | FieldFocused(_)
  | FieldBlurred(_)
  | ViewToggled(_) => Debug
  }

type apiEvent =
  | RetrievePaymentIntent
  | ConfirmCall
  | ConfirmPayoutCall
  | CompleteAuthorize
  | PostSessionTokens
  | Sessions
  | Authentication
  | PollStatus
  | PaymentMethodsList
  | CreateCustomerPaymentMethods
  | RetrievePaymentMethodSession
  | SavePaymentMethod
  | UpdatePaymentMethod
  | DeletePaymentMethod
  | PaymentMethodEligibility
  | PaymentMethodsAuthLink
  | PaymentMethodsAuthExchange
  | TaxCalculation
  | SdkConfigs
  | ClientList
  | CountryStateData

let apiSpec = value => makeOperation(request, value->LoggerUtils.variantName)

let apiSeverity = value =>
  switch value {
  | CountryStateData
  | Sessions
  | TaxCalculation
  | PaymentMethodEligibility
  | PollStatus => {success: Info, failure: Warning}
  | _ => {success: Info, failure: Error}
  }

type functionEvent =
  | LoadPaymentSheet
  | IsReadyToPay
  | Authorize
  | Tokenize

let functionSpec = value => makeOperation(call, value->LoggerUtils.variantName)

let functionSeverity = value =>
  switch value {
  | IsReadyToPay => {success: Debug, failure: Warning}
  | LoadPaymentSheet | Authorize | Tokenize => {success: Debug, failure: Error}
  }

type resourceEvent =
  | GooglePayScript
  | SamsungPayScript
  | ApplePayScript
  | PaypalScript
  | PazeScript
  | KlarnaScript
  | TrustpayScript
  | BraintreeClientScript
  | BraintreeApplePayScript
  | PmAuthConnectorScript
  | VgsScript
  | FontStylesheet

let resourceSpec = value => makeOperation(load, value->LoggerUtils.variantName)

let resourceSeverity = value =>
  switch value {
  | VgsScript => {success: Debug, failure: Error}
  | GooglePayScript
  | SamsungPayScript
  | ApplePayScript
  | PaypalScript
  | PazeScript
  | KlarnaScript
  | TrustpayScript
  | BraintreeClientScript
  | BraintreeApplePayScript
  | PmAuthConnectorScript
  | FontStylesheet => {success: Debug, failure: Warning}
  }

let resourceKind = (value): ResourceLoader.resource =>
  switch value {
  | FontStylesheet => Stylesheet
  | _ => Script
  }

type crashOrigin =
  | ErrorBoundary
  | UncaughtError
  | UnhandledRejection
  | ParentWindowMessage
  | EntryPoint

let logLifecycle = (~event: lifecycleEvent, ~details=[], ~exn=?, ~failure=?, ~paymentMethod=?) =>
  LoggerRuntime.emit(
    ~category=Lifecycle,
    ~spec=event->LoggerUtils.deriveEvent,
    ~severity=event->lifecycleSeverity,
    ~data=event->LoggerUtils.recordDetails,
    ~details,
    ~exn?,
    ~failure?,
    ~paymentMethod?,
  )

let logState = (~event: stateEvent, ~details=[], ~exn=?, ~failure=?, ~paymentMethod=?) =>
  LoggerRuntime.emit(
    ~category=State,
    ~spec=event->LoggerUtils.deriveNotification,
    ~severity=event->stateSeverity,
    ~data=event->LoggerUtils.recordDetails,
    ~details,
    ~exn?,
    ~failure?,
    ~paymentMethod?,
  )

let namedField = field => field->String.trim === "" ? "unnamed" : field

let identify = event =>
  switch event {
  | FieldEdited({field}) => FieldEdited({field: field->namedField})
  | FieldFocused({field}) => FieldFocused({field: field->namedField})
  | FieldBlurred({field}) => FieldBlurred({field: field->namedField})
  | event => event
  }

let editedFields = ref(("", Set.make()))

let isFirstEditOf = field => {
  let sessionId = LoggerContext.current().sessionId
  let (knownSessionId, fields) = editedFields.contents
  let fields = if knownSessionId === sessionId {
    fields
  } else {
    let fields = Set.make()
    editedFields := (sessionId, fields)
    fields
  }
  fields->Set.has(field) ? false : {fields->Set.add(field); true}
}

let logUser = (~event: userEvent, ~details=[], ~paymentMethod=?) => {
  let event = event->identify
  switch (event, paymentMethod) {
  | (PaymentMethodSelected({method}), None) =>
    method->LoggerTaxonomy.fromBackendValue->Option.forEach(LoggerContext.setPaymentMethod)
  | (PaymentMethodSelected(_), Some(paymentMethod)) => LoggerContext.setPaymentMethod(paymentMethod)
  | _ => ()
  }
  let shouldEmit = switch event {
  | FieldEdited({field}) => field->isFirstEditOf
  | _ => true
  }
  if shouldEmit {
    LoggerRuntime.emit(
      ~category=User,
      ~spec=event->LoggerUtils.deriveNotification,
      ~severity=event->userSeverity,
      ~data=event->LoggerUtils.recordDetails,
      ~details,
      ~paymentMethod?,
    )
  }
}

let logCrash = (~origin: crashOrigin, ~exn=?, ~details=[]) =>
  LoggerRuntime.emit(
    ~category=Crash,
    ~spec={action: None, subject: origin->LoggerUtils.variantName, outcome: None},
    ~severity=Error,
    ~details,
    ~exn?,
  )

let catchGlobalCrashes = () => {
  let reporting = ref(false)
  let report = (~origin, ~details) =>
    if !reporting.contents {
      reporting := true
      logCrash(~origin, ~details)
      reporting := false
    }

  let field = (json, key) =>
    json
    ->JSON.Decode.object
    ->Option.flatMap(object => object->Dict.get(key))
    ->Option.getOr(JSON.Encode.null)

  let describe = json =>
    switch json->JSON.Decode.string {
    | Some(text) => text
    | None => json->field("message")->JSON.Decode.string->Option.getOr("UNKNOWN")
    }

  Window.addEventListener("error", (event: JSON.t) =>
    report(
      ~origin=UncaughtError,
      ~details=[
        ("error_message", event->field("message")->describe->JSON.Encode.string),
        ("error_source", event->field("filename")),
      ],
    )
  )

  Window.addEventListener("unhandledrejection", (event: JSON.t) =>
    report(
      ~origin=UnhandledRejection,
      ~details=[("error_message", event->field("reason")->describe->JSON.Encode.string)],
    )
  )
}

let httpFailure = response =>
  response->Fetch.Response.ok
    ? None
    : Some({
        name: "HTTP_ERROR",
        message: Some(response->Fetch.Response.status->Int.toString),
        details: [],
      })

let httpDetails = response => [("status_code", response->Fetch.Response.status->JSON.Encode.int)]

let observeApi = (
  ~event: apiEvent,
  ~url,
  ~details=[],
  ~timeoutMs=?,
  ~failureOf=httpFailure,
  ~detailsOf=httpDetails,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Api,
    ~spec=event->apiSpec,
    ~severity=event->apiSeverity,
    ~data=[("url", url->JSON.Encode.string)],
    ~details,
    ~timeoutMs?,
    ~failureOf,
    ~detailsOf,
    ~call,
  )

let observeFunction = (
  ~event: functionEvent,
  ~details=[],
  ~timeoutMs=?,
  ~failureOf=?,
  ~detailsOf=?,
  ~paymentMethod=?,
  ~call,
) =>
  LoggerRuntime.observe(
    ~category=Function,
    ~spec=event->functionSpec,
    ~severity=event->functionSeverity,
    ~details,
    ~timeoutMs?,
    ~failureOf?,
    ~detailsOf?,
    ~paymentMethod?,
    ~call,
  )

let observeResource = (
  ~event: resourceEvent,
  ~url,
  ~attributes=[],
  ~matchQuery=false,
  ~dedupe=true,
  ~paymentMethod=?,
  ~abandoned=() => false,
  ~onLoad=() => (),
  ~onError=_ => (),
) =>
  LoggerRuntime.observeResource(
    ~spec=event->resourceSpec,
    ~severity=event->resourceSeverity,
    ~url,
    ~resource=event->resourceKind,
    ~attributes,
    ~matchQuery,
    ~dedupe,
    ~paymentMethod?,
    ~abandoned,
    ~onLoad,
    ~onError,
  )
