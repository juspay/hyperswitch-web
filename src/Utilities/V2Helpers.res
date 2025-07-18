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
