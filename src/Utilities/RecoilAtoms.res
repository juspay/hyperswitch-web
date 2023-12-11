type load = Loading | Loaded(Js.Json.t) | LoadError

let keys = Recoil.atom(. "keys", CommonHooks.defaultkeys)
let configAtom = Recoil.atom(. "defaultRecoilConfig", CardTheme.defaultRecoilConfig)
let portalNodes = Recoil.atom(. "portalNodes", PortalState.defaultDict)
let elementOptions = Recoil.atom(. "elementOptions", ElementType.defaultOptions)
let optionAtom = Recoil.atom(. "options", PaymentType.defaultOptions)
let sessions = Recoil.atom(. "sessions", PaymentType.Loading)
let list = Recoil.atom(. "paymentMethodList", PaymentType.Loading)
let loggerAtom = Recoil.atom(. "component", OrcaLogger.defaultLoggerConfig)
let sessionId = Recoil.atom(. "sessionId", "")
let isConfirmBlocked = Recoil.atom(. "isConfirmBlocked", false)
let switchToCustomPod = Recoil.atom(. "switchToCustomPod", false)
let selectedOptionAtom = Recoil.atom(. "selectedOption", "")
let paymentTokenAtom = Recoil.atom(. "paymentToken", ("", ""))
let showCardFeildsAtom = Recoil.atom(. "showCardFeilds", false)
let phoneJson = Recoil.atom(. "phoneJson", Loading)
let cardBrand = Recoil.atom(. "cardBrand", "")

open RecoilAtomTypes

let defaultFieldValues = {
  value: "",
  isValid: None,
  errorString: "",
}

let userFullName = Recoil.atom(. "userFullName", defaultFieldValues)
let userEmailAddress = Recoil.atom(. "userEmailAddress", defaultFieldValues)
let userPhoneNumber = Recoil.atom(.
  "userPhoneNumber",
  {
    value: "+351 ",
    isValid: None,
    errorString: "",
  },
)
let isGooglePayReady = Recoil.atom(. "isGooglePayReady", false)
let userCountry = Recoil.atom(. "userCountry", "")
let userBank = Recoil.atom(. "userBank", "")
let userAddressline1 = Recoil.atom(. "userAddressline1", defaultFieldValues)
let userAddressline2 = Recoil.atom(. "userAddressline2", defaultFieldValues)
let userAddressCity = Recoil.atom(. "userAddressCity", defaultFieldValues)
let userAddressPincode = Recoil.atom(. "userAddressPincode", defaultFieldValues)
let userAddressState = Recoil.atom(. "userAddressState", defaultFieldValues)
let userAddressCountry = Recoil.atom(. "userAddressCountry", defaultFieldValues)
let userBlikCode = Recoil.atom(. "userBlikCode", defaultFieldValues)
let fieldsComplete = Recoil.atom(. "fieldsComplete", false)
let isManualRetryEnabled = Recoil.atom(. "isManualRetryEnabled", false)
let userCurrency = Recoil.atom(. "userCurrency", "")
let isShowOrPayUsing = Recoil.atom(. "isShowOrPayUsing", false)
let areRequiredFieldsValid = Recoil.atom(. "areRequiredFieldsValid", true)
let areRequiredFieldsEmpty = Recoil.atom(. "areRequiredFieldsEmpty", false)
let userBillingName = Recoil.atom(. "userBillingName", defaultFieldValues)
