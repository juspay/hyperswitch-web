open RecoilAtomTypes

let keys = Recoil.atom("keys", CommonHooks.defaultkeys)
let configAtom = Recoil.atom("defaultRecoilConfig", CardTheme.defaultRecoilConfig)
let portalNodes = Recoil.atom("portalNodes", PortalState.defaultDict)
let elementOptions = Recoil.atom("elementOptions", ElementType.defaultOptions)
let optionAtom = Recoil.atom("options", PaymentType.defaultOptions)
let sessions = Recoil.atom("sessions", PaymentType.Loading)
let blockedBins = Recoil.atom("blockedBins", PaymentType.Loading)
let updateSession = Recoil.atom("updateSession", false)
let paymentMethodList = Recoil.atom("paymentMethodList", PaymentType.Loading)
let loggerAtom = Recoil.atom("component", LoggerUtils.defaultLoggerConfig)
let sessionId = Recoil.atom("sessionId", "")
let isConfirmBlocked = Recoil.atom("isConfirmBlocked", false)
let customPodUri = Recoil.atom("customPodUri", "")
let selectedOptionAtom = Recoil.atom("selectedOption", "")
let paymentTokenAtom = Recoil.atom("paymentToken", RecoilAtomTypes.defaultPaymentToken)
let showPaymentMethodsScreen = Recoil.atom("showPaymentMethodsScreen", false)
let phoneJson = Recoil.atom("phoneJson", Loading)
let cardBrand = Recoil.atom("cardBrand", "")
let paymentMethodCollectOptionAtom = Recoil.atom(
  "paymentMethodCollectOptions",
  PaymentMethodCollectUtils.defaultPaymentMethodCollectOptions,
)
let payoutDynamicFieldsAtom = Recoil.atom(
  "payoutDynamicFields",
  PaymentMethodCollectUtils.defaultPayoutDynamicFields(),
)
let paymentMethodTypeAtom = Recoil.atom("paymentMethodType", PaymentMethodCollectUtils.defaultPmt())
let formDataAtom = Recoil.atom("formData", PaymentMethodCollectUtils.defaultFormDataDict)
let validityDictAtom = Recoil.atom("validityDict", PaymentMethodCollectUtils.defaultValidityDict)

let defaultFieldValues = {
  value: "",
  isValid: None,
  errorString: "",
}

let userFullName = Recoil.atom("userFullName", defaultFieldValues)
let userEmailAddress = Recoil.atom("userEmailAddress", defaultFieldValues)
let userPhoneNumber = Recoil.atom(
  "userPhoneNumber",
  {
    ...defaultFieldValues,
    countryCode: "",
  },
)
let userCardNickName = Recoil.atom("userCardNickName", defaultFieldValues)
let isGooglePayReady = Recoil.atom("isGooglePayReady", false)
let isApplePayReady = Recoil.atom("isApplePayReady", false)
let isSamsungPayReady = Recoil.atom("isSamsungPayReady", false)
let userCountry = Recoil.atom("userCountry", "")
let userBank = Recoil.atom("userBank", "")
let userAddressline1 = Recoil.atom("userAddressline1", defaultFieldValues)
let userAddressline2 = Recoil.atom("userAddressline2", defaultFieldValues)
let userAddressCity = Recoil.atom("userAddressCity", defaultFieldValues)
let userAddressPincode = Recoil.atom("userAddressPincode", defaultFieldValues)
let userAddressState = Recoil.atom("userAddressState", defaultFieldValues)
let userAddressCountry = Recoil.atom("userAddressCountry", defaultFieldValues)
let userBlikCode = Recoil.atom("userBlikCode", defaultFieldValues)
let userGiftCardNumber = Recoil.atom("userGiftCardNumber", defaultFieldValues)
let userGiftCardPin = Recoil.atom("userGiftCardPin", defaultFieldValues)
let fieldsComplete = Recoil.atom("fieldsComplete", false)
let isManualRetryEnabled = Recoil.atom("isManualRetryEnabled", false)
let userCurrency = Recoil.atom("userCurrency", "")
let cryptoCurrencyNetworks = Recoil.atom("cryptoCurrencyNetworks", "")
let isShowOrPayUsing = Recoil.atom("isShowOrPayUsing", false)
let areRequiredFieldsValid = Recoil.atom("areRequiredFieldsValid", true)
let areRequiredFieldsEmpty = Recoil.atom("areRequiredFieldsEmpty", false)
let dateOfBirth = Recoil.atom("dateOfBirth", Nullable.null)
let userBillingName = Recoil.atom("userBillingName", defaultFieldValues)
let userVpaId = Recoil.atom("userVpaId", defaultFieldValues)
let userPixKey = Recoil.atom("userPixKey", defaultFieldValues)
let userPixCPF = Recoil.atom("userPixCPF", defaultFieldValues)
let userPixCNPJ = Recoil.atom("userPixCNPJ", defaultFieldValues)
let userDocumentType = Recoil.atom("userDocumentType", "")
let userDocumentNumber = Recoil.atom("userDocumentNumber", defaultFieldValues)
let isCompleteCallbackUsed = Recoil.atom("isCompleteCallbackUsed", false)
let isPaymentButtonHandlerProvidedAtom = Recoil.atom("isPaymentButtonHandlerProvidedAtom", false)
let userBankAccountNumber = Recoil.atom("userBankAccountNumber", defaultFieldValues)
let sourceBankAccountId = Recoil.atom("sourceBankAccountId", defaultFieldValues)

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

let areOneClickWalletsRendered = Recoil.atom(
  "areOneClickWalletsBtnRendered",
  defaultAreOneClickWalletsRendered,
)

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

let clickToPayConfig = Recoil.atom("clickToPayConfig", defaultClickToPayConfig)
let defaultRedirectionFlags: redirectionFlags = {
  shouldUseTopRedirection: false,
  shouldRemoveBeforeUnloadEvents: false,
}
let redirectionFlagsAtom = Recoil.atom("redirectionFlags", defaultRedirectionFlags)
