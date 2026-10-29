module Runtime={include LoggerRuntime.Engine
 type sourceType=LoggerRuntime.source
 type contextType=LoggerContext.t
 type paymentMethodType=LoggerPaymentMethod.paymentMethod
 type resourceType=ResourceLoader.resource
}
include SharedLogger.Controllers.WebMerchant(Runtime,LoggerContext,LoggerUtils)
