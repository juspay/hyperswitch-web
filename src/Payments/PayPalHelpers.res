open PaymentMethodsRecord
open SessionsType

type paypalExperienceData = {
  paypalToken: optionalTokenType,
  isPaypalSDKFlow: bool,
  isPaypalRedirectFlow: bool,
}

let usePaypalTokenAndFlowFromExperience = (
  ~paypalPaymentMethodExperience,
  ~sessionObj: sessions,
) => {
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

let usePaymentMethodData = (~paymentMethodListValue, ~sessionObj: sessions) => {
  let paypalPaymentMethodExperience = React.useMemo(() => {
    getPaymentExperienceTypeFromPML(
      ~paymentMethodList=paymentMethodListValue,
      ~paymentMethodName="wallet",
      ~paymentMethodType="paypal",
    )
  }, [paymentMethodListValue])

  usePaypalTokenAndFlowFromExperience(~paypalPaymentMethodExperience, ~sessionObj)
}

let usePaymentMethodDataV2 = (
  ~paymentMethodListValueV2: UnifiedPaymentsTypesV2.paymentMethodsManagement,
  ~sessionObj: sessions,
) => {
  let paypalPaymentMethodExperience = React.useMemo(() => {
    PaymentMethodsRecordV2.getPaymentExperienceTypeFromPML(
      ~paymentMethodList=paymentMethodListValueV2,
      ~paymentMethodName="wallet",
      ~paymentMethodType="paypal",
    )
  }, [paymentMethodListValueV2])

  usePaypalTokenAndFlowFromExperience(~paypalPaymentMethodExperience, ~sessionObj)
}
