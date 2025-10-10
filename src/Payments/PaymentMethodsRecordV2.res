let buildFromPaymentListV2 = (
  plist: UnifiedPaymentsTypesV2.paymentMethodsManagement,
  ~localeString,
) => {
  let paymentMethodArr = plist.paymentMethodsEnabled
  paymentMethodArr->Array.map(paymentMethodObject => {
    let methodType = paymentMethodObject.paymentMethodType
    let handleUserError = methodType === "wallet"
    let paymentMethodName = paymentMethodObject.paymentMethodSubtype
    let bankNamesList = paymentMethodObject.bankNames->Option.getOr([])
    // TODO - Handle Payment Experience
    let value: PaymentMethodsRecord.paymentMethodsContent = {
      paymentMethodName,
      fields: PaymentMethodsRecord.getPaymentMethodFields(
        paymentMethodName,
        paymentMethodObject.requiredFields,
        ~localeString,
      ),
      paymentFlow: [],
      handleUserError,
      methodType,
      bankNames: bankNamesList,
    }
    value
  })
}

let getPaymentExperienceTypeFromPML = (
  ~paymentMethodList: UnifiedPaymentsTypesV2.paymentMethodsManagement,
  ~paymentMethodName,
  ~paymentMethodType,
) => {
  paymentMethodList.paymentMethodsEnabled->Array.reduce([], (acc, ele) => {
    ele.paymentMethodType === paymentMethodName && ele.paymentMethodSubtype === paymentMethodType
      ? [...acc, ...ele.paymentExperience->Option.getOr([])]
      : acc
  })
}
test("generateApiUrl replaces paymentMethodId in v2.deletePaymentMethod", () => {
  const tpl = APIUtils.v2.deletePaymentMethod
  expect(generateApiUrl({ template: tpl, params: { paymentMethodId: "pm_123" } }))
    .toBe("/v2/payment-methods/pm_123")
})
