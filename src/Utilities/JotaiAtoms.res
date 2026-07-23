open JotaiAtomTypes

let keys = Jotai.atom(CommonHooks.defaultkeys)
let configAtom = Jotai.atom(CardTheme.defaultJotaiConfig)
let portalNodes = Jotai.atom(PortalState.defaultDict)
let elementOptions = Jotai.atom(ElementType.defaultOptions)
let optionAtom = Jotai.atom(PaymentType.defaultOptions)
let sessions = Jotai.atom(PaymentType.Loading)
let updateSession = Jotai.atom(false)
let isTokenize = Jotai.atom(false)
let paymentMethodList = Jotai.atom(PaymentType.Loading)
let sdkConfigs = Jotai.atom(PaymentType.Loading)
let loggerAtom = Jotai.atom(LoggerUtils.defaultLoggerConfig)
let sessionId = Jotai.atom("")
let isConfirmBlocked = Jotai.atom(false)
let customPodUri = Jotai.atom("")
let selectedOptionAtom = Jotai.atom("")
let paymentTokenAtom = Jotai.atom(JotaiAtomTypes.defaultPaymentToken)
let showPaymentMethodsScreen = Jotai.atom(false)
// Typed vault credentials decoded from the vaultConfig blob in fullScreenIframeMounted.
// Set by PaymentMethodsSDK; read by CardsSDK / vault-specific card components.
let vaultCredentials = Jotai.atom(VaultHelpers.defaultVaultCredentials)
let phoneJson = Jotai.atom(Loading)
let cardBrand = Jotai.atom("")
let paymentMethodCollectOptionAtom = Jotai.atom(
  PaymentMethodCollectUtils.defaultPaymentMethodCollectOptions,
)
let payoutDynamicFieldsAtom = Jotai.atom(PaymentMethodCollectUtils.defaultPayoutDynamicFields())
let paymentMethodTypeAtom = Jotai.atom(PaymentMethodCollectUtils.defaultPmt())
let formDataAtom = Jotai.atom(PaymentMethodCollectUtils.defaultFormDataDict)
let validityDictAtom = Jotai.atom(PaymentMethodCollectUtils.defaultValidityDict)

let defaultFieldValues = {
  value: "",
  isValid: None,
  errorString: "",
}

let userFullName = Jotai.atom(defaultFieldValues)
let userEmailAddress = Jotai.atom(defaultFieldValues)
let userPhoneNumber = Jotai.atom({
  ...defaultFieldValues,
  countryCode: "",
})
let userCardNickName = Jotai.atom(defaultFieldValues)
let isGooglePayReady = Jotai.atom(false)
let trustPayScriptStatus = Jotai.atom(NotLoaded)
let isApplePayReady = Jotai.atom(false)
let isSamsungPayReady = Jotai.atom(false)
// Card payments via the VGS vault need the VGS Collect.js script. Ready by
// default; set false when the script fails to load so the card method can be
// removed from the list (a card form without VGS cannot tokenise).
let isVgsScriptReady = Jotai.atom(true)
// True inside the inner Cards SDK iframe when it was mounted for the saved-card
// (return user) CVC flow rather than the new-card flow. Set by LoaderController
// from the `isSavedCardCvcFlow` field of the paymentElementCreate mount message;
// read by PaymentMethodsSDK / CardsSDK to render only the vault CVC field.
let isSavedCardCvcFlow = Jotai.atom(false)
let userCountry = Jotai.atom("")
let userBank = Jotai.atom("")
let userAddressline1 = Jotai.atom(defaultFieldValues)
let userAddressline2 = Jotai.atom(defaultFieldValues)
let userAddressCity = Jotai.atom(defaultFieldValues)
let userAddressPincode = Jotai.atom(defaultFieldValues)
let userAddressState = Jotai.atom(defaultFieldValues)
let userAddressCountry = Jotai.atom(defaultFieldValues)
let userBlikCode = Jotai.atom(defaultFieldValues)
let userGiftCardNumber = Jotai.atom(defaultFieldValues)
let userGiftCardPin = Jotai.atom(defaultFieldValues)
let fieldsComplete = Jotai.atom(false)
let isManualRetryEnabled = Jotai.atom(false)
let userCurrency = Jotai.atom("")
let cryptoCurrencyNetworks = Jotai.atom("")
let isShowOrPayUsing = Jotai.atom(false)
let isShowOrPayUsingWhileLoading = Jotai.atom(false)
let areRequiredFieldsValid = Jotai.atom(true)
let areRequiredFieldsEmpty = Jotai.atom(false)
let dateOfBirth = Jotai.atom((Nullable.null: Nullable.t<Date.t>))
let userBillingName = Jotai.atom(defaultFieldValues)
let userVpaId = Jotai.atom(defaultFieldValues)
let userPixKey = Jotai.atom(defaultFieldValues)
let userPixCPF = Jotai.atom(defaultFieldValues)
let userPixCNPJ = Jotai.atom(defaultFieldValues)
let userDocumentType = Jotai.atom("")
let userDocumentNumber = Jotai.atom(defaultFieldValues)
let isCompleteCallbackUsed = Jotai.atom(false)
let isPaymentButtonHandlerProvidedAtom = Jotai.atom(false)
let userBankAccountNumber = Jotai.atom(defaultFieldValues)
let sourceBankAccountId = Jotai.atom(defaultFieldValues)

type areOneClickWalletsRendered = {
  isGooglePay: bool,
  isApplePay: bool,
  isPaypal: bool,
  isKlarna: bool,
  isSamsungPay: bool,
}

let defaultAreOneClickWalletsRendered = {
  isGooglePay: false,
  isApplePay: false,
  isPaypal: false,
  isKlarna: false,
  isSamsungPay: false,
}

let areOneClickWalletsRendered = Jotai.atom(defaultAreOneClickWalletsRendered)

type clickToPayConfig = {
  isReady: option<bool>,
  availableCardBrands: array<string>,
  email: string,
  clickToPayCards: option<array<ClickToPayHelpers.clickToPayCard>>,
  dpaName: string,
  clickToPayProvider: ClickToPayHelpers.ctpProviderType,
  visaComponentState: ClickToPayHelpers.visaComponentState,
  maskedIdentity: string,
  otpError: string,
  consumerIdentity: ClickToPayHelpers.consumerIdentity,
  clickToPayToken?: ClickToPayHelpers.clickToPayToken,
}

let defaultClickToPayConfig = {
  isReady: None,
  availableCardBrands: [],
  email: "",
  clickToPayCards: None,
  dpaName: "",
  clickToPayProvider: NONE,
  visaComponentState: NONE,
  maskedIdentity: "",
  otpError: "",
  consumerIdentity: {
    identityType: EMAIL_ADDRESS,
    identityValue: "",
  },
}

let clickToPayConfig = Jotai.atom(defaultClickToPayConfig)
let defaultRedirectionFlags: redirectionFlags = {
  shouldUseTopRedirection: false,
  shouldRemoveBeforeUnloadEvents: false,
}
let redirectionFlagsAtom = Jotai.atom(defaultRedirectionFlags)
let isTestMode = Jotai.atom(false)
let isUpdateIntentLoading = Jotai.atom(false)
