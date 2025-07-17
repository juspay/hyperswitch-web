open UnifiedPaymentsTypesV2
let getPaymentExperienceTypeFromPML = (
  ~paymentMethodList: paymentMethodsManagement,
  ~paymentMethodName,
  ~paymentMethodType,
) => {
  paymentMethodList.paymentMethodsEnabled
  ->Array.filter(paymentMethod =>
    paymentMethod.paymentMethodType === paymentMethodName &&
      paymentMethod.paymentMethodSubtype === paymentMethodType
  )
  ->Array.get(0)
  ->Option.flatMap(val => val.paymentExperience)
  ->Option.getOr([])
}
