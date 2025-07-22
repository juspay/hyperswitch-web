let buildFromPaymentListV2 = (plist: UnifiedPaymentsTypesV2.paymentMethodsManagement) => {
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
      ),
      paymentFlow: [],
      handleUserError,
      methodType,
      bankNames: bankNamesList,
    }
    value
  })
}
