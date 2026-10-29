module Runtime={include LoggerRuntime.Engine
 type sourceType=LoggerRuntime.source
 type contextType=LoggerContext.t
 type paymentMethodType=LoggerPaymentMethod.paymentMethod
 type resourceType=ResourceLoader.resource
}
include SharedLogger.Controllers.WebClickToPay(Runtime,LoggerUtils,{
 let card=LoggerPaymentMethod.Card
 let authenticationSource=LoggerRuntime.AuthenticationSession
 let script=ResourceLoader.Script
 let stylesheet=ResourceLoader.Stylesheet
})
