let paymentMethodCollectOptionAtom = Jotai.atom(
  PaymentMethodCollectUtils.defaultPaymentMethodCollectOptions,
)
let payoutDynamicFieldsAtom = Jotai.atom(PaymentMethodCollectUtils.defaultPayoutDynamicFields())
let paymentMethodTypeAtom = Jotai.atom(PaymentMethodCollectUtils.defaultPmt())
let formDataAtom = Jotai.atom(PaymentMethodCollectUtils.defaultFormDataDict)
let validityDictAtom = Jotai.atom(PaymentMethodCollectUtils.defaultValidityDict)
