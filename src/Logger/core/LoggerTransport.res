let isConfigured = () => GlobalVars.logEndpoint->String.trim !== ""

let sendViaBeacon = payload =>
  Window.Navigator.hasSendBeacon()
    ? try Window.Navigator.sendBeacon(GlobalVars.logEndpoint, payload) catch {
      | _ => false
      }
    : false

let send = (rows: array<JSON.t>) =>
  isConfigured() ? rows->JSON.Encode.array->JSON.stringify->sendViaBeacon : false
