open PaymentMethodsRecord
open SessionsType

type klarnaExperienceData = {
  klarnaTokenObj: optionalTokenType,
  isKlarnaSDKFlow: bool,
  isKlarnaCheckoutFlow: bool,
}

let usePaymentMethodExperience = (~paymentMethodListValue, ~sessionObj: sessions) => {
  let klarnaPaymentMethodExperience = React.useMemo(() => {
    getPaymentExperienceTypeFromPML(
      ~paymentMethodList=paymentMethodListValue,
      ~paymentMethodName="pay_later",
      ~paymentMethodType="klarna",
    )
  }, [paymentMethodListValue])

  let klarnaTokenObj = React.useMemo(
    () => getPaymentSessionObj(sessionObj.sessionsToken, Klarna),
    [sessionObj],
  )

  let isKlarnaSDKFlow = klarnaPaymentMethodExperience->Array.includes(InvokeSDK)
  let isKlarnaCheckoutFlow = klarnaPaymentMethodExperience->Array.includes(RedirectToURL)

  {
    klarnaTokenObj,
    isKlarnaSDKFlow,
    isKlarnaCheckoutFlow,
  }
}
