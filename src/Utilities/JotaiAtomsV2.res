let paymentManagementList = Jotai.atom(UnifiedPaymentsTypesV2.LoadingV2)
let showAddScreen = Jotai.atom(false)
let managePaymentMethod = Jotai.atom("")
let savedMethodsV2 = Jotai.atom([UnifiedHelpersV2.defaultCustomerMethods])
