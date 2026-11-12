@val @scope("window") external parentWindow: Dom.element = "parent"

let adoptSessionFromParent = (~source) => {
  LoggerRuntime.configure(~source)
  Window.addEventListener("message", (ev: Window.event) =>
    if ev.source === parentWindow && ev.data->LoggerContext.mayCarryContext {
      switch JSON.parseExn(ev.data)->JSON.Decode.object {
      | Some(message) => message->LoggerContext.startSessionFromMessage
      | None => ()
      | exception _ => ()
      }
    }
  )
}
