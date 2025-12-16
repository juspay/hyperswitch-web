let buildFromPaymentListV2 = (
  pList: UnifiedPaymentsTypesV2.paymentMethodsManagement,
  ~localeString,
) => {
  let paymentMethodArr = pList.paymentMethodsEnabled
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
