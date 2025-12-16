let paymentManagementList = Recoil.atom("paymentManagementList", UnifiedPaymentsTypesV2.LoadingV2)
let showAddScreen = Recoil.atom("showAddScreen", false)
let vaultMode = Recoil.atom("vaultMode", VaultHelpers.None)
let managePaymentMethod = Recoil.atom("managePaymentMethod", "")
let savedMethodsV2 = Recoil.atom("savedMethodsV2", [UnifiedHelpersV2.defaultCustomerMethods])
let paymentMethodsListV2 = Recoil.atom("paymentMethodsListV2", UnifiedPaymentsTypesV2.LoadingV2)
let intentList = Recoil.atom("intentList", UnifiedPaymentsTypesV2.LoadingIntent)
let paymentMethodListValueV2 = Recoil.atom(
  "paymentMethodListValueV2",
  UnifiedHelpersV2.defaultPaymentsList,
)
let vaultPublishableKey = Recoil.atom("vaultPublishableKey", "")
let vaultProfileId = Recoil.atom("vaultProfileId", "")

type appliedGiftCard = {
  giftCardType: string,
  maskedNumber: string,
  balance: float,
  currency: string,
  id: string,
  requiredFieldsBody: Dict.t<Core__JSON.t>,
}

type giftCardInfo = {
  appliedGiftCards: array<appliedGiftCard>,
  remainingAmount: float,
}

let defaultGiftCardInfo: giftCardInfo = {
  appliedGiftCards: [],
  remainingAmount: 0.0,
}

let giftCardInfoAtom: Recoil.recoilAtom<giftCardInfo> = Recoil.atom(
  "giftCardInfo",
  defaultGiftCardInfo,
)
