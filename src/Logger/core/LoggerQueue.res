module Transport = SharedLogger.Transport.Web({
 let endpoint = () => LoggerConfig.endpoint
 let hasSendBeacon = () => Window.Navigator.hasSendBeacon()
 let sendBeacon = (url,payload) => Window.Navigator.sendBeacon(url,payload)
})
module Hooks = {
 type contextType = LoggerTypes.context
 let native = false
 let identifiers = SharedLogger.Platform.webIdentifiers
 let utf8Length = LoggerUtils.utf8Length
 let sendAsync = _ => Promise.resolve(false)
 let sendSync = Transport.sendPayload
 let installLifecycle = drain => {
 Window.addEventListener("visibilitychange",_=>Window.visibilityState === "hidden"?drain():())
 Window.addEventListener("pagehide",_=>drain())
 }
}
include SharedLogger.Queue.Engine(LoggerConfig, Hooks)
let sendPayload = Transport.sendPayload
