open PaymentMethodsRecord
open SessionsType

type paypalExperienceData = {
  paypalToken: optionalTokenType,
  isPaypalSDKFlow: bool,
  isPaypalRedirectFlow: bool,
}

let usePaymentMethodExperience = (
  ~paymentMethodListValue,
  ~paymentMethodsListV2: UnifiedPaymentsTypesV2.paymentMethodsManagement,
  ~sessionObj: sessions,
) => {
  let paypalPaymentMethodExperience = React.useMemo(() => {
    switch GlobalVars.sdkVersion {
    | V1 =>
      getPaymentExperienceTypeFromPML(
        ~paymentMethodList=paymentMethodListValue,
        ~paymentMethodName="wallet",
        ~paymentMethodType="paypal",
      )
    | V2 =>
      V2Helpers.getPaymentExperienceTypeFromPML(
        ~paymentMethodList=paymentMethodsListV2,
        ~paymentMethodName="wallet",
        ~paymentMethodType="paypal",
      )
    }
  }, (paymentMethodListValue, paymentMethodsListV2))

  let paypalToken = React.useMemo(
    () => getPaymentSessionObj(sessionObj.sessionsToken, Paypal),
    [sessionObj],
  )
  let isPaypalSDKFlow = paypalPaymentMethodExperience->Array.includes(InvokeSDK)
  let isPaypalRedirectFlow = paypalPaymentMethodExperience->Array.includes(RedirectToURL)

  {
    paypalToken,
    isPaypalSDKFlow,
    isPaypalRedirectFlow,
  }
}
