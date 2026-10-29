module Runtime={include LoggerRuntime.Engine
 type sourceType=LoggerRuntime.source
 type contextType=LoggerContext.t
 type paymentMethodType=LoggerPaymentMethod.paymentMethod
 type resourceType=ResourceLoader.resource
}
@val @scope("window") external parentWindow: Dom.element = "parent"
module Hooks={
 let listenParentMessage=callback=>Window.addEventListener("message",(ev:Window.event)=>if ev.source===parentWindow {callback(ev.data)})
 let sdkOrigins=()=>[GlobalVars.sdkUrl,GlobalVars.repoPublicPath]
 let addWindowEvent=(name,callback)=>Window.addEventListener(name,callback)
 let script=ResourceLoader.Script
 let stylesheet=ResourceLoader.Stylesheet
}
include SharedLogger.Controllers.WebSdk(Runtime,LoggerContext,LoggerUtils,Hooks)
