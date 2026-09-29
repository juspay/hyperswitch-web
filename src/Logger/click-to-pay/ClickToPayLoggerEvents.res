open LoggerTypes

// Shared

type provider =
  | VisaUctp
  | VisaDirect
  | MastercardUctp
  | MastercardDirect

type providerDetails = {provider: provider}

type cardsData = {provider: provider, actionCode: string, visa: int, mastercard: int}

type declineData = {provider: provider, code: string}

// Lifecycle

type lifecycleEvent =
  | ProviderReady(providerDetails)
  | ProviderUnavailable(providerDetails)
  | RecognitionTokenFound(providerDetails)
  | CardsListed(cardsData)
  | CardsUnavailable(declineData)
  | CustomerVerificationRequired(providerDetails)
  | CustomerRecognised(providerDetails)
  | CheckoutCompleted(providerDetails)
  | CheckoutDeclined(declineData)
  | CheckoutCancelled(declineData)
  | CheckoutFailed(providerDetails)
  | OtpRejected(providerDetails)
  | AuthenticationFailed(providerDetails)
  | PopupBlocked(providerDetails)
  | SignOutFailed(providerDetails)

let lifecycleSeverity = event =>
  switch event {
  | ProviderReady(_)
  | RecognitionTokenFound(_)
  | CheckoutCancelled(_)
  | CardsListed(_) =>
    Debug
  | CustomerVerificationRequired(_)
  | CustomerRecognised(_)
  | CheckoutCompleted(_)
  | CheckoutDeclined(_) =>
    Info
  | ProviderUnavailable(_)
  | CardsUnavailable(_)
  | OtpRejected(_)
  | SignOutFailed(_) =>
    Warning
  | CheckoutFailed(_)
  | AuthenticationFailed(_)
  | PopupBlocked(_) =>
    Error
  }

// Function

type functionEvent =
  | Initialize(providerDetails)
  | Init(providerDetails)
  | IdentityLookup(providerDetails)
  | GetCards(providerDetails)
  | Authenticate(providerDetails)
  | EncryptCard(providerDetails)
  | Checkout(providerDetails)
  | CheckoutWithCard(providerDetails)
  | CheckoutWithNewCard(providerDetails)
  | UnbindAppInstance(providerDetails)
  | SignOut(providerDetails)

let functionSeverity = event =>
  switch event {
  | Initialize(_)
  | Init(_)
  | IdentityLookup(_)
  | GetCards(_)
  | Authenticate(_)
  | UnbindAppInstance(_)
  | SignOut(_) => quietSuccessSoftFailure
  | EncryptCard(_)
  | Checkout(_)
  | CheckoutWithCard(_)
  | CheckoutWithNewCard(_) => quietSuccess
  }

// Merchant call

type merchantMethod =
  | InitSession
  | GetActiveSession
  | IsCustomerPresent
  | GetUserType
  | GetRecognizedCards
  | ValidateAuthentication
  | CheckoutWithCard
  | SignOut

let merchantCallSeverity = (method: merchantMethod) =>
  switch method {
  | CheckoutWithCard => defaultSeverity
  | InitSession
  | GetActiveSession
  | IsCustomerPresent
  | GetUserType
  | GetRecognizedCards
  | ValidateAuthentication
  | SignOut => quietSuccessSoftFailure
  }

// Api

type apiEvent =
  | EnabledAuthnMethodsToken
  | EligibilityCheck
  | AuthenticationSync

let apiSeverity = event =>
  switch event {
  | EnabledAuthnMethodsToken
  | EligibilityCheck
  | AuthenticationSync => defaultSeverity
  }

// Resource

type resourceEvent =
  | VisaSdkScript
  | MastercardSdkScript
  | UiKitScript
  | UiKitStylesheet

let resourceSeverity = event =>
  switch event {
  | VisaSdkScript
  | MastercardSdkScript
  | UiKitScript
  | UiKitStylesheet => quietSuccessSoftFailure
  }

let resourceKind = (value): ResourceLoader.resource =>
  switch value {
  | UiKitStylesheet => Stylesheet
  | VisaSdkScript | MastercardSdkScript | UiKitScript => Script
  }
