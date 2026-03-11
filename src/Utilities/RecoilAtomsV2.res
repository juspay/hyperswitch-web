let paymentManagementList = Recoil.atom("paymentManagementList", UnifiedPaymentsTypesV2.LoadingV2)
let showAddScreen = Recoil.atom("showAddScreen", false)
let managePaymentMethod = Recoil.atom("managePaymentMethod", "")
let savedMethodsV2 = Recoil.atom("savedMethodsV2", [UnifiedHelpersV2.defaultCustomerMethods])
