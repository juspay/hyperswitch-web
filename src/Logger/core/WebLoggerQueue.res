let sendPayload = payload =>
  LoggerConfig.endpoint.contents !== "" && Window.Navigator.hasSendBeacon()
    ? try Window.Navigator.trySendBeacon(LoggerConfig.endpoint.contents, payload) catch {
      | _ => false
      }
    : false

let configure = () => {
  LoggerQueue.configure(~sendPayload)
  Window.addEventListener("visibilitychange", _ =>
    Window.visibilityState === "hidden" ? LoggerQueue.drain() : ()
  )
  Window.addEventListener("pagehide", _ => LoggerQueue.drain())
}
