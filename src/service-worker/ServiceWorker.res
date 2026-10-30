@val @scope("self.clients") external claim: unit => unit = "claim"
@val @scope("self") external skipWaiting: unit => unit = "skipWaiting"
@val @scope("self")
external selfAddEventListener: (string, 'event => unit) => unit = "addEventListener"

let sendLogs = async (logs: array<JSON.t>) => {
  if logs->Array.length > 0 {
    try {
      let bodyStr = logs->JSON.Encode.array->JSON.stringify
      let response = await Fetch.fetch(
        GlobalVars.logEndpoint,
        {
          method: #POST,
          body: Fetch.Body.string(bodyStr),
          headers: Fetch.Headers.fromObject(
            Dict.fromArray([("Content-Type", "application/json")])->Utils.dictToObj,
          ),
        },
      )
      let _ = response->Fetch.Response.ok
    } catch {
    | err => Console.error2("[ServiceWorker] Failed to send logs:", err)
    }
  }
}

let sendIdbLogs = async () => {
  try {
    let logs = await LoggerUtils.retrieveAndClearLogsFromIndexedDB()
    if logs->Array.length > 0 {
      logs->sendLogs->ignore
    }
  } catch {
  | err => Console.error2("[ServiceWorker] Failed to send iDB logs:", err)
  }
}

let processMessage = event => {
  try {
    let data = event["data"]
    let type_ = data->Dict.get("type")->CommonUtils.getStringFromOptionalJson("")
    if type_ === "SEND_LOGS" {
      sendIdbLogs()->ignore
      let newLogs = data->CommonUtils.getArray("logs")
      if newLogs->Array.length > 0 {
        newLogs->sendLogs->ignore
      }
    }
  } catch {
  | err => Console.error2("[ServiceWorker] Error:", err)
  }
}

selfAddEventListener("message", event => processMessage(event))

let processActivate = async () => {
  try {
    let logs = await LoggerUtils.retrieveAndClearLogsFromIndexedDB()
    logs->sendLogs->ignore
  } catch {
  | err => Console.error2("[ServiceWorker] Failed to send logs on activate:", err)
  }
}

selfAddEventListener("install", _ => skipWaiting())

selfAddEventListener("activate", _ => {
  claim()
  processActivate()->ignore
})
