/*
 Atoms for the payout (paymentMethodCollect) widget, kept out of `JotaiAtoms` on purpose: an
 atom's initial value is evaluated at import time, so declaring these there made every bundle
 load `PaymentMethodCollectUtils` (and, through it, `BrowserSpec`) even on a checkout page that
 can never render the payout widget. Only the payout components below import this module.
 */
let paymentMethodCollectOptionAtom = Jotai.atom(
  PaymentMethodCollectUtils.defaultPaymentMethodCollectOptions,
)
let payoutDynamicFieldsAtom = Jotai.atom(PaymentMethodCollectUtils.defaultPayoutDynamicFields())
let paymentMethodTypeAtom = Jotai.atom(PaymentMethodCollectUtils.defaultPmt())
let formDataAtom = Jotai.atom(PaymentMethodCollectUtils.defaultFormDataDict)
let validityDictAtom = Jotai.atom(PaymentMethodCollectUtils.defaultValidityDict)
