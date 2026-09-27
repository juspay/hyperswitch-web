open LoggerTypes

// Lifecycle

type walletStage =
  | ConfirmRequestReceived
  | OneClickDeclined

type walletFlow =
  | Normal
  | Delayed
  | ThirdParty
  | PaypalSdkTabs

type walletFailure =
  | MissingIntent
  | MissingCurrency
  | MissingNonce
  | ConnectorUnsupported
  | ClientUnavailable
  | BrowserUnsupported
  | PaymentsNotAllowed
  | ClientCreationFailed
  | AvailabilityCheckFailed
  | ListenerSetupFailed
  | MessageHandlingFailed
  | PaymentDataFailed
  | SdkMountFailed
  | SheetFailed

type vaultFailure =
  | FieldBindingFailed
  | FieldMountFailed
  | FieldUpdateFailed
  | FieldUnmountFailed
  | FormCreationFailed
  | TokenizationFailed

type threeDsMethodFailure =
  | MissingContainer
  | FormSubmitFailed
  | IframeLoadFailed

type threeDsPopupFailure = MessageHandlingFailed

type ddcFailure =
  | MissingUrl
  | MissingRedirectUrl
  | InvalidNextAction
  | UnreadableResponse

type walletStageData = {stage: walletStage, connector?: string}

type walletFlowData = {flow: walletFlow, connector?: string}

type walletFailureData = {reason: walletFailure, connector?: string}

type vaultFailureData = {reason: vaultFailure}

type transStatusData = {transStatus: string}

type threeDsMethodFailureData = {reason: threeDsMethodFailure}

type threeDsPopupFailureData = {reason: threeDsPopupFailure}

type ddcFailureData = {reason: ddcFailure}

type paymentOutcomeData = {status: string, manualRetryAllowed?: bool}

type bankAuthSyncFailureData = {status: string}

type customerRedirectData = {nextAction: string, redirectMode?: string, redirectOrigin: string}

type nextActionFailureData = {nextAction: string, recovered: bool}

type unknownPaymentMethodData = {value: string}

type unsupportedConnectorData = {connector: string}

type paymentStatusUnknownData = {inferred: bool}

type validationFailureData = {reason: string}

type blockedOperation =
  | PaymentConfirm
  | PaymentSync
  | PaymentCompleteAuthorize
  | PaymentPostSessionTokens
  | PaymentMethodSave
  | PaymentMethodUpdate
  | IntentUpdate

type operationBlockedData = {operation: blockedOperation, reason: string}

type paymentMethodSaveOperation =
  | Save
  | Update

type paymentMethodSaveData = {operation: paymentMethodSaveOperation}

type paymentMethodSaveOutcomeData = {operation: paymentMethodSaveOperation, status: string}

type retryExhaustionData = {operation: string, attempts: int}

type lifecycleEvent =
  | ElementIframeMounted
  | ElementInitReceived
  | AppRendered
  | PaymentAttempted
  | PaymentSucceeded(paymentOutcomeData)
  | PaymentFailed(paymentOutcomeData)
  | PaymentRejected
  | PaymentStatusUnknown(paymentStatusUnknownData)
  | PaymentRetriesExhausted(retryExhaustionData)
  | PaymentErrorHandlingFailed
  | PaymentStatusPollExhausted
  | PaymentMethodSaveRejected(paymentMethodSaveData)
  | PaymentMethodSaveSucceeded(paymentMethodSaveOutcomeData)
  | PaymentMethodSaveFailed(paymentMethodSaveOutcomeData)
  | OperationBlocked(operationBlockedData)
  | FormValidationFailed(validationFailureData)
  | WalletFlowResolved(walletFlowData)
  | WalletStageReached(walletStageData)
  | WalletFlowFailed(walletFailureData)
  | WalletFlowExited
  | WalletTokenReceived
  | VaultFlowFailed(vaultFailureData)
  | BankAuthSyncFailed(bankAuthSyncFailureData)
  | BankAuthConnectorUnsupported(unsupportedConnectorData)
  | CustomerRedirectStarted(customerRedirectData)
  | NextActionUnsupported(nextActionFailureData)
  | ThreeDsPopupRequested
  | ThreeDsPopupFailed(threeDsPopupFailureData)
  | ThreeDsChallengeShown(transStatusData)
  | ThreeDsFrictionlessResolved(transStatusData)
  | ThreeDsAuthContainerMissing(transStatusData)
  | ThreeDsAuthRequestFailed
  | ThreeDsMethodStarted
  | ThreeDsMethodCompleted
  | ThreeDsMethodSkipped
  | ThreeDsMethodFailed(threeDsMethodFailureData)
  | ThreeDsMethodTimedOut
  | DdcStarted
  | DdcCompleted
  | DdcFailed(ddcFailureData)
  | DdcTimedOut
  | QrCodeShown
  | QrCodeExpired
  | VoucherShown
  | BankTransferShown
  | PaymentMethodUnresolved(unknownPaymentMethodData)
  | CountryDataServedFromBundle
  | CountryDataUnavailable
  | EligibilityCheckCancelled
  | EligibilityCheckFailed

let walletFailureSeverity = reason =>
  switch reason {
  | BrowserUnsupported => Debug
  | MissingIntent
  | MissingCurrency
  | ConnectorUnsupported
  | PaymentsNotAllowed
  | ClientCreationFailed
  | AvailabilityCheckFailed
  | ListenerSetupFailed
  | SdkMountFailed =>
    Warning
  | MissingNonce
  | ClientUnavailable
  | MessageHandlingFailed
  | PaymentDataFailed
  | SheetFailed =>
    Error
  }

let threeDsMethodFailureSeverity = reason =>
  switch reason {
  | MissingContainer | FormSubmitFailed => Error
  | IframeLoadFailed => Warning
  }

let vaultFailureSeverity = reason =>
  switch reason {
  | FieldBindingFailed
  | FieldMountFailed
  | FormCreationFailed
  | FieldUpdateFailed
  | FieldUnmountFailed
  | TokenizationFailed =>
    Error
  }

let lifecycleSeverity = value =>
  switch value {
  | ElementIframeMounted
  | WalletFlowResolved(_)
  | WalletStageReached(_)
  | ThreeDsPopupRequested
  | ThreeDsMethodStarted
  | ThreeDsMethodCompleted
  | ThreeDsMethodSkipped
  | DdcStarted
  | DdcCompleted
  | CountryDataServedFromBundle
  | EligibilityCheckCancelled =>
    Debug
  | ElementInitReceived
  | AppRendered
  | PaymentAttempted
  | PaymentSucceeded(_)
  | PaymentFailed(_)
  | PaymentMethodSaveSucceeded(_)
  | PaymentMethodSaveFailed(_)
  | WalletTokenReceived
  | CustomerRedirectStarted(_)
  | ThreeDsChallengeShown(_)
  | ThreeDsFrictionlessResolved(_)
  | QrCodeShown
  | VoucherShown
  | BankTransferShown =>
    Info
  | ThreeDsMethodTimedOut
  | DdcTimedOut
  | BankAuthConnectorUnsupported(_)
  | PaymentMethodUnresolved(_)
  | PaymentStatusUnknown(_)
  | WalletFlowExited
  | QrCodeExpired
  | OperationBlocked(_)
  | PaymentStatusPollExhausted
  | FormValidationFailed(_)
  | EligibilityCheckFailed =>
    Warning
  | PaymentRetriesExhausted(_) => Error
  | PaymentErrorHandlingFailed
  | PaymentMethodSaveRejected(_)
  | PaymentRejected
  | ThreeDsAuthContainerMissing(_)
  | ThreeDsAuthRequestFailed
  | BankAuthSyncFailed(_)
  | CountryDataUnavailable
  | DdcFailed(_) =>
    Error
  | ThreeDsPopupFailed(_) => Error
  | NextActionUnsupported({recovered}) => recovered ? Warning : Error
  | VaultFlowFailed({reason}) => reason->vaultFailureSeverity
  | WalletFlowFailed({reason}) => reason->walletFailureSeverity
  | ThreeDsMethodFailed({reason}) => reason->threeDsMethodFailureSeverity
  }

// State

type cardFormScope = PaymentForm | VaultForm

type loaderState = Loading | SemiLoaded | Loaded | LoadFailed

type networkData = {online: bool}

type cardFormData = {scope: cardFormScope}

type cardFieldData = {scope: cardFormScope, field: string}

type loaderSource = IframeMount | PaymentMethodsList | SdkConfigs

type loaderData = {state: loaderState, source: loaderSource}

type clickToPayViewData = {view: string}

type updateIntentData = {inProgress: bool}

type formCompletionData = {savedMethod: bool}

type merchantControlData = {control: string}

type stateEvent =
  | NetworkStatusChanged(networkData)
  | ElementOptionsChanged
  | LoaderStateChanged(loaderData)
  | CardFormCreated(cardFormData)
  | CardFormDestroyed(cardFormData)
  | CardFieldCreated(cardFieldData)
  | CardFieldUnmounted(cardFieldData)
  | CardCoBadgeDetected
  | MerchantControlReceived(merchantControlData)
  | DynamicFieldsChanged
  | PaymentFormCompleted(formCompletionData)
  | UpdateIntentProgressChanged(updateIntentData)
  | ClickToPayViewChanged(clickToPayViewData)

let stateSeverity = value =>
  switch value {
  | LoaderStateChanged({state: LoadFailed}) => Error
  | LoaderStateChanged({state: Loaded}) => Info
  | NetworkStatusChanged({online}) => online ? Debug : Warning
  | LoaderStateChanged(_)
  | ElementOptionsChanged
  | CardFormCreated(_)
  | CardFormDestroyed(_)
  | CardFieldCreated(_)
  | CardFieldUnmounted(_)
  | CardCoBadgeDetected
  | MerchantControlReceived(_)
  | DynamicFieldsChanged
  | PaymentFormCompleted(_)
  | UpdateIntentProgressChanged(_)
  | ClickToPayViewChanged(_) =>
    Debug
  }

// User

type view =
  | SavedMethodList
  | MorePaymentMethods
  | InstallmentOptions

type openedView =
  | NewPaymentMethods
  | ManageSavedMethod
  | ClickToPayIdentityChange
  | CardSchemeMenu

type submitSource =
  | PayButton
  | SaveCardButton
  | MerchantApi

type verificationSource =
  | ClickToPayOtp
  | ClickToPayIdentity

type fieldData = {field: string}

type fieldToggleData = {field: string, enabled: bool}

type methodData = {method: string}

type savedMethodSelectionData = {requiresCvv: bool, isCardExpired: bool}

type viewData = {view: view, expanded: bool}

type openedViewData = {view: openedView}

type submitData = {source: submitSource}

type verificationData = {
  source: verificationSource,
  provider: option<ClickToPayLoggerEvents.provider>,
}

type userEvent =
  | PaymentMethodSelected(methodData)
  | CardSchemeSelected(methodData)
  | SavedMethodSelected(savedMethodSelectionData)
  | SavedMethodUpdateRequested
  | SavedMethodDeleteRequested
  | PaymentSubmitted(submitData)
  | CustomerVerificationSubmitted(verificationData)
  | BankDetailsConfirmed
  | ExpressCheckoutClicked
  | VoucherDownloadRequested
  | QrCodeCopyRequested
  | ThreeDsPopupDismissed
  | ClickToPayOtpResendRequested
  | FieldEdited(fieldData)
  | FieldToggled(fieldToggleData)
  | FieldFocused(fieldData)
  | FieldBlurred(fieldData)
  | ViewToggled(viewData)
  | ViewOpened(openedViewData)

let userSeverity = value =>
  switch value {
  | PaymentMethodSelected(_)
  | CardSchemeSelected(_)
  | SavedMethodSelected(_)
  | SavedMethodUpdateRequested
  | SavedMethodDeleteRequested
  | PaymentSubmitted(_)
  | CustomerVerificationSubmitted(_)
  | ExpressCheckoutClicked
  | ThreeDsPopupDismissed
  | VoucherDownloadRequested
  | QrCodeCopyRequested
  | BankDetailsConfirmed
  | ClickToPayOtpResendRequested =>
    Info
  | FieldEdited(_)
  | FieldToggled(_)
  | FieldFocused(_)
  | FieldBlurred(_)
  | ViewToggled(_)
  | ViewOpened(_) =>
    Debug
  }

// Api

type vaultTokenizeScope =
  | SaveCardCvc
  | FullCard

type vaultTokenizeData = {scope: vaultTokenizeScope}

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
  | ClientList
  | VaultTokenization(vaultTokenizeData)

let apiSeverity = value =>
  switch value {
  | Sessions
  | TaxCalculation
  | PaymentMethodEligibility
  | PollStatus => {...defaultSeverity, failure: Warning}
  | RetrievePaymentIntent
  | ConfirmCall
  | ConfirmPayoutCall
  | CompleteAuthorize
  | PostSessionTokens
  | Authentication
  | PaymentMethodsList
  | CreateCustomerPaymentMethods
  | RetrievePaymentMethodSession
  | SavePaymentMethod
  | UpdatePaymentMethod
  | DeletePaymentMethod
  | PaymentMethodsAuthLink
  | PaymentMethodsAuthExchange
  | ClientList
  | VaultTokenization(_) => defaultSeverity
  }

// Function

type functionEvent =
  | LoadPaymentSheet
  | LoadPaymentData
  | IsReadyToPay
  | FinishApplePaymentV2
  | ExecuteGooglePayment
  | BraintreeClientCreate
  | BraintreeApplePayCreate
  | KlarnaInit
  | KlarnaLoad
  | PaypalButtonsRender
  | PlaidCreate
  | VaultFormCreate

let functionSeverity = value =>
  switch value {
  | IsReadyToPay => {...defaultSeverity, success: Debug, failure: Warning}
  | LoadPaymentSheet
  | LoadPaymentData
  | FinishApplePaymentV2
  | ExecuteGooglePayment
  | BraintreeClientCreate
  | BraintreeApplePayCreate
  | KlarnaInit
  | KlarnaLoad
  | PaypalButtonsRender
  | PlaidCreate
  | VaultFormCreate => {...defaultSeverity, success: Debug}
  }

// Function callback

type functionCallbackEvent =
  | OnValidateMerchant
  | OnPaymentAuthorized
  | OnShippingContactSelected
  | OnCancel
  | OnPaymentDataChanged
  | CreateOrder
  | CreateBillingAgreement
  | OnApprove
  | OnShippingAddressChange
  | OnError
  | OnClick
  | OnLoad
  | OnSuccess
  | OnExit
  | OnFormStateChange

let functionCallbackSeverity = value =>
  switch value {
  | OnFormStateChange
  | OnShippingContactSelected
  | OnShippingAddressChange
  | OnPaymentDataChanged
  | OnClick
  | OnCancel
  | OnExit
  | OnLoad => {...defaultSeverity, success: Debug, failure: Warning}
  | OnValidateMerchant
  | OnPaymentAuthorized
  | CreateOrder
  | CreateBillingAgreement
  | OnApprove
  | OnSuccess
  | OnError => {...defaultSeverity, success: Debug}
  }

// Resource

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
  | VaultScript
  | FontStylesheet

let resourceSeverity = value =>
  switch value {
  | VaultScript => {...defaultSeverity, success: Debug}
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
  | FontStylesheet => {...defaultSeverity, success: Debug, failure: Warning}
  }

let resourceKind = (value): ResourceLoader.resource =>
  switch value {
  | FontStylesheet => Stylesheet
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
  | VaultScript =>
    Script
  }

// Static asset

type staticAssetEvent =
  | CountryStateData
  | CountryStateDataFallback
  | SdkConfigs

let staticAssetSeverity = value =>
  switch value {
  | SdkConfigs => {...defaultSeverity, success: Debug}
  | CountryStateData => {...defaultSeverity, success: Debug, failure: Debug}
  | CountryStateDataFallback => {...defaultSeverity, success: Debug, failure: Warning}
  }

// Crash

type crashOrigin =
  | ErrorBoundary
  | UncaughtError
  | UnhandledRejection
  | EntryPoint
  | ElementConstructor
  | ParentWindowMessage
  | MerchantCallback

let crashSeverity = origin =>
  switch origin {
  | ErrorBoundary
  | UncaughtError
  | UnhandledRejection
  | EntryPoint
  | ElementConstructor
  | ParentWindowMessage
  | MerchantCallback =>
    Error
  }
