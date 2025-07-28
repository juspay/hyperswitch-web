open PaymentMethodsRecord
open SessionsType

type paypalExperienceData = {
  paypalToken: optionalTokenType,
  isPaypalSDKFlow: bool,
  isPaypalRedirectFlow: bool,
}

let usePaypalTokenAndFlowFromExperience = (~paypalExperience, ~sessionObj: sessions) => {
  let paypalToken = React.useMemo(
    () => getPaymentSessionObj(sessionObj.sessionsToken, Paypal),
    [sessionObj],
  )

  let isPaypalSDKFlow = paypalExperience->Array.includes(InvokeSDK)
  let isPaypalRedirectFlow = paypalExperience->Array.includes(RedirectToURL)

  {
    paypalToken,
    isPaypalSDKFlow,
    isPaypalRedirectFlow,
  }
}

let usePaymentMethodExperience = (~paymentMethodListValue, ~sessionObj: sessions) => {
  let paypalPaymentMethodExperience = React.useMemo(() => {
    getPaymentExperienceTypeFromPML(
      ~paymentMethodList=paymentMethodListValue,
      ~paymentMethodName="wallet",
      ~paymentMethodType="paypal",
    )
  }, [paymentMethodListValue])

  usePaypalTokenAndFlowFromExperience(~paypalExperience=paypalPaymentMethodExperience, ~sessionObj)
}

let usePaymentMethodExperienceV2 = (
  ~paymentMethodsListV2: UnifiedPaymentsTypesV2.paymentMethodsManagement,
  ~sessionObj: sessions,
) => {
  let paypalPaymentMethodExperience = React.useMemo(() => {
    PaymentMethodsRecordV2.getPaymentExperienceTypeFromPML(
      ~paymentMethodList=paymentMethodsListV2,
      ~paymentMethodName="wallet",
      ~paymentMethodType="paypal",
    )
  }, [paymentMethodsListV2])

  usePaypalTokenAndFlowFromExperience(~paypalExperience=paypalPaymentMethodExperience, ~sessionObj)
}
