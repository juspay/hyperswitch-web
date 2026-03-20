@val @scope("self.clients") external claim: unit => unit = "claim"
@val @scope("self") external skipWaiting: unit => unit = "skipWaiting"

let sendLogs = async (logs, endpoint) =>
  if logs->Array.length > 0 {
    try {
      let bodyStr = logs->JSON.Encode.array->JSON.stringify
      let response = await Fetch.fetch(
        endpoint,
        {
          method: #POST,
          body: Fetch.Body.string(bodyStr),
          headers: Fetch.Headers.fromObject(
            Dict.fromArray([("Content-Type", "application/json")])->Utils.dictToObj,
          ),
        },
      )
      if response->Fetch.Response.ok {
        await LoggerUtils.clearLogsFromIndexedDB()
      }
    } catch {
    | err => Console.error2("[ServiceWorker] Failed to send logs:", err)
    }
  }

@val @scope("self") external addEventListener: (string, 'event => unit) => unit = "addEventListener"

let processMessage = async event =>
  try {
    let data = event["data"]
    let type_ = data->Dict.get("type")->CommonUtils.getStringFromOptionalJson("")
    if type_ === "SEND_LOGS" {
      let existingLogs = try {
        await LoggerUtils.retrieveLogsFromIndexedDB()
      } catch {
      | _ => []
      }

      let allLogs =
        data
        ->CommonUtils.getOptionalArrayFromDict("logs")
        ->Option.map(newLogs => Array.concat(existingLogs, newLogs))
        ->Option.getOr(existingLogs)

      await sendLogs(allLogs, GlobalVars.logEndpoint)
    }
  } catch {
  | err => Console.error2("[ServiceWorker] Error:", err)
  }

addEventListener("message", event => processMessage(event)->ignore)

let processActivate = async () =>
  try {
    let logs = await LoggerUtils.retrieveLogsFromIndexedDB()
    await sendLogs(logs, GlobalVars.logEndpoint)
  } catch {
  | err => Console.error2("[ServiceWorker] Failed to send logs on activate:", err)
  }

addEventListener("install", _ => skipWaiting())

addEventListener("activate", _ => {
  claim()
  processActivate()->ignore
})
