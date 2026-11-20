open LoggerTypes

type crashEvent = {message?: JSON.t, filename?: JSON.t, reason?: JSON.t}

let describe: option<JSON.t> => string = %raw(`
  (v) => typeof v == "string" ? v : (v && typeof v.message == "string" ? v.message : "UNKNOWN")
`)

let stackUrl: option<JSON.t> => string = %raw(`
  (v) => (v && typeof v.stack == "string" && /(?:https?|blob|file):\/\/[^\s)]+/.exec(v.stack) || [""])[0]
`)

let catchGlobalCrashes = (~ownsDocument) => {
  let sdkOrigins =
    [GlobalVars.sdkUrl, GlobalVars.repoPublicPath]->Array.filter(value => value->String.trim !== "")
  let reporting = ref(false)

  let report = (~origin, ~message, ~source) =>
    if (
      !reporting.contents &&
      (ownsDocument ||
      (source->String.trim !== "" &&
        sdkOrigins->Array.some(origin => source->String.startsWith(origin))))
    ) {
      reporting := true
      SdkLogger.logCrash(
        ~origin,
        ~details=[
          ("error_message", message->JSON.Encode.string),
          ("error_source", source->WebLoggerUtils.sanitizeUrl->JSON.Encode.string),
        ],
      )
      reporting := false
    }

  Window.addEventListener("error", (event: crashEvent) =>
    report(
      ~origin=SdkLogger.UncaughtError,
      ~message=event.message->describe,
      ~source=event.filename->Option.flatMap(JSON.Decode.string)->Option.getOr(""),
    )
  )

  Window.addEventListener("unhandledrejection", (event: crashEvent) =>
    report(
      ~origin=SdkLogger.UnhandledRejection,
      ~message=event.reason->describe,
      ~source=event.reason->stackUrl,
    )
  )
}
