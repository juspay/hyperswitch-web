@val @scope("window") @return(nullable)
external existingSessionId: option<string> = "__hyperSdkLoadSessionId"
@val external window: {..} = "window"

let sessionId = switch existingSessionId {
| Some(id) if id !== "" => id
| _ =>
  let id = "hyp_" ++ Utils.generateRandomString(8)
  window["__hyperSdkLoadSessionId"] = id
  id
}
