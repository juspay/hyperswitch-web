open RecoilAtomTypes

let keys = Recoil.atom("keys", CommonHooks.defaultkeys)
let configAtom = Recoil.atom("defaultRecoilConfig", CardTheme.defaultRecoilConfig)
let portalNodes = Recoil.atom("portalNodes", PortalState.defaultDict)
let elementOptions = Recoil.atom("elementOptions", ElementType.defaultOptions)
let optionAtom = Recoil.atom("options", PaymentType.defaultOptions)
let sessions = Recoil.atom("sessions", PaymentType.Loading)
let paymentMethodList = Recoil.atom("paymentMethodList", PaymentType.Loading)
let loggerAtom = Recoil.atom("component", OrcaLogger.defaultLoggerConfig)
let sessionId = Recoil.atom("sessionId", "")
let isConfirmBlocked = Recoil.atom("isConfirmBlocked", false)
let switchToCustomPod = Recoil.atom("switchToCustomPod", false)
let selectedOptionAtom = Recoil.atom("selectedOption", "")
let paymentTokenAtom = Recoil.atom(
  "paymentToken",
  {
    paymentToken: "",
    customerId: "",
  },
)
let showCardFieldsAtom = Recoil.atom("showCardFields", false)
let phoneJson = Recoil.atom("phoneJson", Loading)
let cardBrand = Recoil.atom("cardBrand", "")
let payNowButtonDisable = Recoil.atom("payNowButtonDisable", true)

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
let isGooglePayReady = Recoil.atom("isGooglePayReady", false)
let isApplePayReady = Recoil.atom("isApplePayReady", false)
let userCountry = Recoil.atom("userCountry", "")
let userBank = Recoil.atom("userBank", "")
let userAddressline1 = Recoil.atom("userAddressline1", defaultFieldValues)
let userAddressline2 = Recoil.atom("userAddressline2", defaultFieldValues)
let userAddressCity = Recoil.atom("userAddressCity", defaultFieldValues)
let userAddressPincode = Recoil.atom("userAddressPincode", defaultFieldValues)
let userAddressState = Recoil.atom("userAddressState", defaultFieldValues)
let userAddressCountry = Recoil.atom("userAddressCountry", defaultFieldValues)
let userBlikCode = Recoil.atom("userBlikCode", defaultFieldValues)
let fieldsComplete = Recoil.atom("fieldsComplete", false)
let isManualRetryEnabled = Recoil.atom("isManualRetryEnabled", false)
let userCurrency = Recoil.atom("userCurrency", "")
let cryptoCurrencyNetworks = Recoil.atom("cryptoCurrencyNetworks", "")
let isShowOrPayUsing = Recoil.atom("isShowOrPayUsing", false)
let areRequiredFieldsValid = Recoil.atom("areRequiredFieldsValid", true)
let areRequiredFieldsEmpty = Recoil.atom("areRequiredFieldsEmpty", false)
let userBillingName = Recoil.atom("userBillingName", defaultFieldValues)

type areOneClickWalletsRendered = {
  isGooglePay: bool,
  isApplePay: bool,
  isPaypal: bool,
  isKlarna: bool,
}

let defaultAreOneClickWalletsRendered = {
  isGooglePay: false,
  isApplePay: false,
  isPaypal: false,
  isKlarna: false,
}

let areOneClickWalletsRendered = Recoil.atom(
  "areOneClickWalletsBtnRendered",
  defaultAreOneClickWalletsRendered,
)
