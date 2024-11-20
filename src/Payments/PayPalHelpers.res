open PaymentMethodsRecord
open SessionsType

type paypalExperienceData = {
  paypalToken: optionalTokenType,
  isPaypalSDKFlow: bool,
  isPaypalRedirectFlow: bool,
}

let usePaymentMethodExperience = (~paymentMethodListValue, ~sessionObj: sessions) => {
  let paypalPaymentMethodExperience = React.useMemo(() => {
    getPaymentExperienceTypeFromPML(
      ~paymentMethodList=paymentMethodListValue,
      ~paymentMethodName="wallet",
      ~paymentMethodType="paypal",
    )
  }, [paymentMethodListValue])

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
