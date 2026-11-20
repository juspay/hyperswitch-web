let sendPayload = payload =>
  LoggerConfig.endpoint.contents !== "" && Window.Navigator.hasSendBeacon()
    ? try Window.Navigator.trySendBeacon(LoggerConfig.endpoint.contents, payload) catch {
      | _ => false
      }
    : false

let configure = () => {
  LoggerQueue.configure(~sendPayload)
  Window.addEventListener("pagehide", _ => {
    if LoggerContext.current().sessionId !== "" || !LoggerQueue.waitingForInitialSession() {
      LoggerQueue.drain()
    }
  })
}
