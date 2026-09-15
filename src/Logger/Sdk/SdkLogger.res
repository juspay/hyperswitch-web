open LoggerCommonHelpers

type networkStateDetails = {online: bool}

type phase = Init | Done | Failed | Reused

type paymentStatusDetails = {status: string}
type failureCauseDetails = {cause: string}
type stageDetails = {stage: string}
type redirectFailureDetails = {nextAction: string}
type paymentAttemptDetails = {bodySize: int}
type voucherDisplayDetails = {count: int}
type threeDsMethodDetails = {methodCall: bool}
type threeDsDisplayDetails = {transStatus: string}

type lifecycleEvent =
  | LogInitiated
  | DisplayThreeDsSdk(threeDsDisplayDetails)
  | DisplayThreeDsSdkFailed
  | ThreeDsMethodResult
  | ThreeDsMethodFailed(failureCauseDetails)
  | WalletInteraction(stageDetails)
  | WalletInteractionFailed(failureCauseDetails)
  | PaymentMethodTypeDetectionFailed
  | S3DataFetchFailed
  | PaymentAttempt(paymentAttemptDetails)
  | PaymentSuccess(paymentStatusDetails)
  | PaymentFailed(paymentStatusDetails)
  | RedirectingUser
  | RedirectingUserFailed(redirectFailureDetails)
  | ThreeDsPopupRedirection
  | ThreeDsPopupRedirectionFailed
  | ThreeDsMethod(threeDsMethodDetails)
  | DdcFlow
  | DdcFlowCompleted
  | DdcFlowFailed(failureCauseDetails)
  | DdcFlowTimedOut
  | DisplayQrCode
  | DisplayVoucher(voucherDisplayDetails)
  | DisplayBankTransfer
  | IsReadyStatusCheck
  | ConfirmPayment
  | ConfirmCardPayment
  | PaymentElementOptions
  | UpdateIntent
  | UpdateIntentFailed
  | UpdateSdk
  | AppInitiated
  | LoaderCalled
  | ElementsCalled
  | PaymentManagementElementsCalled
  | PaymentSessionInitiated
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
  | EligibilityCheckFailed

type cardFormScope = PaymentForm | VaultForm
type cardFormChangedDetails = {scope: cardFormScope}
type componentVisibilityDetails = {visible: bool}
type clickToPayViewDetails = {view: string}
type loadState = Loaded | Loading | SemiLoaded | LoadError
type loaderChangedDetails = {state: loadState}

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
  | LoaderChanged(loaderChangedDetails)
  | AppRendered
  | PaymentOptionsProvided

type methodSelectionDetails = {method: string}
type fieldDetails = {field: string}
type dataFillDetails = {savedMethod: bool}
type viewToggleDetails = {view: string}

type userEvent =
  | PaymentMethodSelected(methodSelectionDetails)
  | PaymentDataFilled(dataFillDetails)
  | InputFieldChanged(fieldDetails)
  | FieldBlurred(fieldDetails)
  | FieldFocused(fieldDetails)
  | CardSchemeSelected(methodSelectionDetails)
  | WalletButtonClicked
  | PayButtonClicked
  | SavedMethodSelected
  | SavedMethodDeleted
  | SavedMethodUpdated
  | WalletSheetCancelled
  | ViewToggled(viewToggleDetails)

type functionEvent =
  | LoadPaymentData
  | LoadPaymentSheet
  | IsReadyToPay
  | Authorize
  | CreateInstance
  | Tokenize
  | SubmitVaultForm

type apiEvent =
  | RetrievePaymentIntent
  | ConfirmCall
  | ConfirmPayoutCall
  | Sessions
  | PaymentMethodsList
  | CreateCustomerPaymentMethods
  | CompleteAuthorize
  | Authentication
  | PollStatus
  | TaxCalculation
  | SdkConfigs
  | ClientList
  | PaymentMethodsAuthLink
  | PaymentMethodsAuthExchange
  | PaymentMethodEligibility
  | PostSessionTokens
  | RetrievePaymentMethodSession
  | DeletePaymentMethod
  | UpdatePaymentMethod
  | SavePaymentMethod
  | S3CountryStateData

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

type outcome = Started | Done | Failed | TimedOut | Reused

type initSubject =
  | Log(outcome)
  | App(outcome)
  | Loader(outcome)
  | Elements(outcome)
  | PaymentManagementElements(outcome)
  | PaymentSession(outcome)
  | PaymentElementOptions(outcome)
  | TestMode(outcome)

type confirmSubject =
  | Payment(outcome)
  | CardPayment(outcome)
  | PaymentIntent(outcome)
  | Wallet(outcome)

type validateSubject =
  | PublishableKey(outcome)
  | Protocol(outcome)
  | RequiredParameter(outcome)
  | Format(outcome)
  | BoolType(outcome)
  | StringType(outcome)
  | IntType(outcome)
  | ValueRange(outcome)
  | SdkConnector(outcome)
  | PaymentMethodType(outcome)
  | ReadyStatus(outcome)
  | InternalApi(outcome)
  | Eligibility(outcome)

type displaySubject =
  | ThreeDsSdk(outcome)
  | QrCode(outcome)
  | Voucher(outcome)
  | BankTransfer(outcome)

type loadSubject = SdkPreload(outcome)

type updateSubject = Intent(outcome) | Sdk(outcome)

type redirectSubject = User(outcome) | ThreeDsPopup(outcome)

type syncSubject = ThreeDsMethod(outcome) | Ddc(outcome)

type retrieveSubject = S3Data(outcome)

type deprecateSubject = LoadStripe(outcome)

type lifecycleAxes =
  | Init(initSubject)
  | Confirm(confirmSubject)
  | Validate(validateSubject)
  | Display(displaySubject)
  | Load(loadSubject)
  | Update(updateSubject)
  | Redirect(redirectSubject)
  | Sync(syncSubject)
  | Retrieve(retrieveSubject)
  | Deprecate(deprecateSubject)

type stateSubject =
  | NetworkStateChanged(outcome)
  | CardFormMounted(outcome)
  | CardFormFieldMounted(outcome)
  | CardFormUnmounted(outcome)
  | DynamicFieldsUpdated(outcome)
  | UpdateIntentLoadingChanged(outcome)
  | SavedMethodsViewToggled(outcome)
  | VaultScriptReadyChanged(outcome)
  | ClickToPayViewChanged(outcome)
  | LoaderChanged(outcome)
  | AppRendered(outcome)
  | PaymentOptionsProvided(outcome)

type stateAxes = Change(stateSubject)

type selectSubject =
  | PaymentMethod(outcome)
  | CardScheme(outcome)
  | SavedMethod(outcome)

type fillSubject = PaymentData(outcome)

type inputSubject = InputField(outcome)

type fieldSubject = Field(outcome)

type clickSubject = WalletButton(outcome) | PayButton(outcome)

type mutateSubject = SavedMethod(outcome)

type cancelSubject = WalletSheet(outcome)

type toggleSubject = View(outcome)

type userAxes =
  | Select(selectSubject)
  | Fill(fillSubject)
  | Change(inputSubject)
  | Blur(fieldSubject)
  | Focus(fieldSubject)
  | Click(clickSubject)
  | Delete(mutateSubject)
  | Update(mutateSubject)
  | Cancel(cancelSubject)
  | Toggle(toggleSubject)

type crashOrigin = Sdk(outcome)

type crashAxes = Throw(crashOrigin)

type resourceSubject =
  | GooglePayScript(outcome)
  | SamsungPayScript(outcome)
  | TrustpayScript(outcome)
  | PmAuthConnectorScript(outcome)
  | ApplePayBraintreeScript(outcome)
  | BraintreeClientScript(outcome)
  | ApplePayScript(outcome)
  | PaypalScript(outcome)
  | PazeScript(outcome)
  | KlarnaScript(outcome)
  | VgsScript(outcome)
  | FontStylesheet(outcome)

type resourceAxes = Load(resourceSubject)

let phaseOutcome = (phase: phase): outcome =>
  switch phase {
  | Init => Started
  | Done => Done
  | Failed => Failed
  | Reused => Reused
  }

let lifecycleAxes = (event: lifecycleEvent): lifecycleAxes =>
  switch event {
  | LogInitiated => Init(Log(Done))
  | DisplayThreeDsSdk(_) => Display(ThreeDsSdk(Done))
  | DisplayThreeDsSdkFailed => Display(ThreeDsSdk(Failed))
  | ThreeDsMethodResult => Sync(ThreeDsMethod(Done))
  | ThreeDsMethodFailed(_) => Sync(ThreeDsMethod(Failed))
  | WalletInteraction(_) => Confirm(Wallet(Started))
  | WalletInteractionFailed(_) => Confirm(Wallet(Failed))
  | PaymentMethodTypeDetectionFailed => Validate(PaymentMethodType(Failed))
  | S3DataFetchFailed => Retrieve(S3Data(Failed))
  | PaymentAttempt(_) => Confirm(Payment(Started))
  | PaymentSuccess(_) => Confirm(Payment(Done))
  | PaymentFailed(_) => Confirm(Payment(Failed))
  | RedirectingUser => Redirect(User(Started))
  | RedirectingUserFailed(_) => Redirect(User(Failed))
  | ThreeDsPopupRedirection => Redirect(ThreeDsPopup(Started))
  | ThreeDsPopupRedirectionFailed => Redirect(ThreeDsPopup(Failed))
  | ThreeDsMethod(_) => Sync(ThreeDsMethod(Started))
  | DdcFlow => Sync(Ddc(Started))
  | DdcFlowCompleted => Sync(Ddc(Done))
  | DdcFlowFailed(_) => Sync(Ddc(Failed))
  | DdcFlowTimedOut => Sync(Ddc(TimedOut))
  | DisplayQrCode => Display(QrCode(Done))
  | DisplayVoucher(_) => Display(Voucher(Done))
  | DisplayBankTransfer => Display(BankTransfer(Done))
  | IsReadyStatusCheck => Validate(ReadyStatus(Started))
  | ConfirmPayment => Confirm(PaymentIntent(Started))
  | ConfirmCardPayment => Confirm(CardPayment(Started))
  | PaymentElementOptions => Init(PaymentElementOptions(Done))
  | UpdateIntent => Update(Intent(Started))
  | UpdateIntentFailed => Update(Intent(Failed))
  | UpdateSdk => Update(Sdk(Done))
  | AppInitiated => Init(App(Started))
  | LoaderCalled => Init(Loader(Started))
  | ElementsCalled => Init(Elements(Started))
  | PaymentManagementElementsCalled => Init(PaymentManagementElements(Started))
  | PaymentSessionInitiated => Init(PaymentSession(Started))
  | TestMode => Init(TestMode(Done))
  | PreloadSdkWithParams => Load(SdkPreload(Started))
  | InvalidPublishableKey => Validate(PublishableKey(Failed))
  | HttpNotAllowed => Validate(Protocol(Failed))
  | DeprecatedLoadStripe => Deprecate(LoadStripe(Done))
  | RequiredParameter => Validate(RequiredParameter(Failed))
  | InvalidFormat => Validate(Format(Failed))
  | TypeBoolError => Validate(BoolType(Failed))
  | TypeStringError => Validate(StringType(Failed))
  | TypeIntError => Validate(IntType(Failed))
  | ValueOutOfRange => Validate(ValueRange(Failed))
  | SdkConnectorWarning => Validate(SdkConnector(Failed))
  | InternalApiDown => Validate(InternalApi(Failed))
  | EligibilityCheckFailed => Validate(Eligibility(Failed))
  }

let stateAxes = (event: stateEvent): stateAxes =>
  switch event {
  | NetworkStateChanged(_) => Change(NetworkStateChanged(Done))
  | CardFormMounted(_) => Change(CardFormMounted(Done))
  | CardFormFieldMounted(_) => Change(CardFormFieldMounted(Done))
  | CardFormUnmounted(_) => Change(CardFormUnmounted(Done))
  | DynamicFieldsUpdated => Change(DynamicFieldsUpdated(Done))
  | UpdateIntentLoadingChanged(_) => Change(UpdateIntentLoadingChanged(Done))
  | SavedMethodsViewToggled(_) => Change(SavedMethodsViewToggled(Done))
  | VaultScriptReadyChanged(_) => Change(VaultScriptReadyChanged(Done))
  | ClickToPayViewChanged(_) => Change(ClickToPayViewChanged(Done))
  | LoaderChanged(_) => Change(LoaderChanged(Done))
  | AppRendered => Change(AppRendered(Done))
  | PaymentOptionsProvided => Change(PaymentOptionsProvided(Done))
  }

let userAxes = (event: userEvent): userAxes =>
  switch event {
  | PaymentMethodSelected(_) => Select(PaymentMethod(Done))
  | PaymentDataFilled(_) => Fill(PaymentData(Done))
  | InputFieldChanged(_) => Change(InputField(Done))
  | FieldBlurred(_) => Blur(Field(Done))
  | FieldFocused(_) => Focus(Field(Done))
  | CardSchemeSelected(_) => Select(CardScheme(Done))
  | WalletButtonClicked => Click(WalletButton(Done))
  | PayButtonClicked => Click(PayButton(Done))
  | SavedMethodSelected => Select(SavedMethod(Done))
  | SavedMethodDeleted => Delete(SavedMethod(Done))
  | SavedMethodUpdated => Update(SavedMethod(Done))
  | WalletSheetCancelled => Cancel(WalletSheet(Done))
  | ViewToggled(_) => Toggle(View(Done))
  }

let crashAxes = (event: crashEvent): crashAxes =>
  switch event {
  | SdkCrash => Throw(Sdk(Failed))
  }

let resourceAxes = (event: resourceEvent): resourceAxes =>
  switch event {
  | ScriptLoad(provider, phase) =>
    switch provider {
    | GooglePayScript => Load(GooglePayScript(phaseOutcome(phase)))
    | SamsungPayScript => Load(SamsungPayScript(phaseOutcome(phase)))
    | TrustpayScript => Load(TrustpayScript(phaseOutcome(phase)))
    | PmAuthConnectorScript => Load(PmAuthConnectorScript(phaseOutcome(phase)))
    | ApplePayBraintreeScript => Load(ApplePayBraintreeScript(phaseOutcome(phase)))
    | BraintreeClientScript => Load(BraintreeClientScript(phaseOutcome(phase)))
    | ApplePayScript => Load(ApplePayScript(phaseOutcome(phase)))
    | PaypalScript => Load(PaypalScript(phaseOutcome(phase)))
    | PazeScript => Load(PazeScript(phaseOutcome(phase)))
    | KlarnaScript => Load(KlarnaScript(phaseOutcome(phase)))
    | VgsScript => Load(VgsScript(phaseOutcome(phase)))
    | FontStylesheet => Load(FontStylesheet(phaseOutcome(phase)))
    }
  }

let axesEmission = (axes): (string, details) => {
  let segments = axes->axesSegments
  let taxonomyDetails = switch segments {
  | [action, subject, outcome] => [
      ("action", action->JSON.Encode.string),
      ("subject", subject->JSON.Encode.string),
      ("outcome", outcome->JSON.Encode.string),
    ]
  | _ => []
  }
  (segments->Array.joinWith("."), taxonomyDetails)
}

let eventIdPrefix = "sdk_"

let phaseSeverity = (phase: phase) =>
  switch phase {
  | Init => Debug
  | Done | Reused => Info
  | Failed => Error
  }

let lifecycleSeverity = (event: lifecycleEvent) =>
  switch event {
  | DisplayThreeDsSdkFailed
  | ThreeDsMethodFailed(_)
  | PaymentMethodTypeDetectionFailed
  | S3DataFetchFailed
  | WalletInteractionFailed(_)
  | PaymentFailed(_)
  | RedirectingUserFailed(_)
  | ThreeDsPopupRedirectionFailed
  | DdcFlowFailed(_)
  | DdcFlowTimedOut
  | EligibilityCheckFailed
  | UpdateIntentFailed
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

let stateSeverity = (event: stateEvent) =>
  switch event {
  | NetworkStateChanged({online: false}) => Warning
  | LoaderChanged({state: LoadError}) => Error
  | LoaderChanged(_) | AppRendered | PaymentOptionsProvided => Info
  | _ => Debug
  }

let resourceSeverity = (event: resourceEvent) =>
  switch event {
  | ScriptLoad(_, phase) => phaseSeverity(phase)
  }

let logLifecycle = (~event: lifecycleEvent, ~paymentMethod=?, ~message=?, ~details=[], ~exn=?) => {
  let (eventName, taxonomyDetails) = event->lifecycleAxes->axesEmission
  LoggerRuntime.logEvent(
    ~category=Lifecycle,
    ~severity=lifecycleSeverity(event),
    ~event,
    ~eventNameOverride=eventName,
    ~taxonomyDetails,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~exn?,
  )
}

let logState = (~event: stateEvent, ~paymentMethod=?, ~message=?, ~details=[], ~exn=?) => {
  let (eventName, taxonomyDetails) = event->stateAxes->axesEmission
  LoggerRuntime.logEvent(
    ~category=State,
    ~severity=stateSeverity(event),
    ~event,
    ~eventNameOverride=eventName,
    ~taxonomyDetails,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~exn?,
  )
}

let logUser = (~event: userEvent, ~paymentMethod=?, ~message=?, ~details=[], ~exn=?) => {
  let (eventName, taxonomyDetails) = event->userAxes->axesEmission
  LoggerRuntime.logEvent(
    ~category=User,
    ~severity=Info,
    ~event,
    ~eventNameOverride=eventName,
    ~taxonomyDetails,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~exn?,
  )
}

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

let observeApi = (
  ~event: apiEvent,
  ~paymentMethod=?,
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
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~timeoutMs,
    ~resultFailure?,
    ~resultDetails?,
    ~call,
  )

let logResource = (~event: resourceEvent, ~paymentMethod=?, ~message=?, ~details=[], ~exn=?) => {
  let (eventName, taxonomyDetails) = event->resourceAxes->axesEmission
  LoggerRuntime.logEvent(
    ~category=Resource,
    ~severity=resourceSeverity(event),
    ~event,
    ~eventNameOverride=eventName,
    ~taxonomyDetails,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~exn?,
  )
}

let logCrash = (~paymentMethod=?, ~message=?, ~details=[], ~exn=?) => {
  let (eventName, taxonomyDetails) = SdkCrash->crashAxes->axesEmission
  LoggerRuntime.logEvent(
    ~category=Crash,
    ~severity=Error,
    ~event=SdkCrash,
    ~eventNameOverride=eventName,
    ~taxonomyDetails,
    ~paymentMethod?,
    ~message?,
    ~details,
    ~eventIdPrefix,
    ~exn?,
  )
}
