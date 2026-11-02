// Host capability adapter and public calling facade. State and orchestration are shared.
open! LoggerTypes
type source =
  | HyperLoader
  | PreMountLoader
  | Headless
  | AuthenticationSession
  | Elements(CardThemeType.mode)
  | Fullscreen(string)

let sourceName = source =>
  switch source {
  | HyperLoader => "HYPER_LOADER"
  | PreMountLoader => "PRE_MOUNT_LOADER"
  | Headless => "HEADLESS"
  | AuthenticationSession => "AUTHENTICATION_SESSION"
  | Elements(mode) =>
    `ELEMENTS_${mode->CardThemeType.getPaymentModeToStrMapper->LoggerUtils.screamingSnakeCase}`
  | Fullscreen(overlay) => `FULLSCREEN_${overlay->LoggerUtils.screamingSnakeCase}`
  }

type browserInfo = SharedLoggerRuntime.browserInfo

let detectBrowser = SharedLoggerRuntime.detectBrowser

let browser = detectBrowser()
let platformName = Window.Navigator.platform->LoggerUtils.screamingSnakeCase
let browserName = browser.name->LoggerUtils.screamingSnakeCase
let browserVersion = browser.version
let userAgent = Window.Navigator.userAgent->LoggerUtils.truncateTo(LoggerConfig.maxRowTextLength)
let pageHref = Window.hrefWithoutSearch->LoggerUtils.truncateTo(LoggerConfig.maxRowTextLength)

let rethrow = error =>
  switch error {
  | JsExn(jsError) => JsExn.throw(jsError)
  | error => throw(error)
  }

module Host = {
 type sourceType = source
 type contextType = LoggerContext.t
 type paymentMethodType = LoggerPaymentMethod.paymentMethod
 type resourceType = ResourceLoader.resource
 let sourceName = sourceName
 let initialSource = "UNKNOWN"
 let metadata: SharedLogger.Platform.metadata = {component: "WEB", platformName, browserName, browserVersion, pageHref, userAgent}
 let version = () => GlobalVars.repoVersion
 let mutableDevice = false
 let notifyOnEmit = false
 let detailsBeforeFailure = false
 let enabled = LoggerConfig.enabled
 let minimumRank = () => LoggerConfig.minimumRank
 let maxRowsPerEventName = LoggerConfig.maxRowsPerEventName
 let maxUserEventsPerName = LoggerConfig.maxUserEventsPerName
 let currentContext = LoggerContext.current
 let fillContext = LoggerContext.fillFrom
 let identifiers = SharedLogger.Platform.webIdentifiers
 let onSessionChange = LoggerContext.onSessionChange
 let qualifiedPayment = LoggerPaymentMethod.qualifiedName
 let droppedRows = LoggerQueue.droppedRows
 let sendFailures = LoggerQueue.sendFailures
 let push = (row, ~isError, ~context: LoggerContext.t) => LoggerQueue.push(row, ~isError, ~backfill=!context.scoped, ~pmSessionId=context.pmSessionId)
 let rethrow = rethrow
 let resourceName = ResourceLoader.resourceName
 let loadResource = (~url, ~resource, ~attributes=?, ~matchQuery=?, ~onStart, ~onLoad, ~onError) => ResourceLoader.load(~url, ~resource, ~attributes?, ~matchQuery?, ~onStart, ~onLoad=result=>onLoad(result === ResourceLoader.Reused), ~onError)
}
module Engine = SharedLogger.Engine.Make(LoggerConfig, LoggerUtils, Host)
include Engine
let observe = (
  ~category,
  ~spec: eventSpec,
  ~severity: operationSeverity,
  ~data=?,
  ~details=?,
  ~timeoutMs=LoggerConfig.defaultTimeoutMs,
  ~failureOf: option<'result => option<errorSummary>>=?,
  ~detailsOf: option<'result => details>=?,
  ~paymentMethod=?,
  ~context=LoggerContext.current(),
  ~source=?,
  ~syncOutcome=Returned,
  ~message=?,
  ~call: unit => 'value,
): 'value => Engine.observe(~category, ~spec, ~severity, ~data?, ~details?, ~timeoutMs, ~failureOf?, ~detailsOf?, ~paymentMethod?, ~context, ~source?, ~syncOutcome, ~message?, ~call)

let emitPhase = (
  ~category,
  ~spec,
  ~severity,
  ~outcome,
  ~data=?,
  ~details=?,
  ~startedAt=?,
  ~exn=?,
  ~paymentMethod=?,
  ~context=?,
  ~source=?,
  ~message=?,
) => Engine.emitPhase(~category, ~spec, ~severity, ~outcome, ~data?, ~details?, ~startedAt?, ~exn?, ~paymentMethod?, ~context?, ~source?, ~message?)

let observeCallback = (
  ~category,
  ~spec,
  ~severity,
  ~data=?,
  ~details=?,
  ~timeoutMs=?,
  ~failureOf=?,
  ~paymentMethod=?,
  ~context=?,
  ~source=?,
  ~message=?,
  ~callback: 'fn,
): 'fn => Engine.observeCallback(~category, ~spec, ~severity, ~data?, ~details?, ~timeoutMs?, ~failureOf?, ~paymentMethod?, ~context?, ~source?, ~message?, ~callback)


let configure=(~source)=>Engine.configure(~source,~version="",~appId="",~userAgent="")

let emit = (
  ~category,
  ~spec: eventSpec,
  ~severity: severity,
  ~data: option<details>=?,
  ~details: option<details>=?,
  ~verbatim: option<details>=?,
  ~exn: option<exn>=?,
  ~failure: option<'response>=?,
  ~durationMs: option<float>=?,
  ~paymentMethod: option<LoggerPaymentMethod.paymentMethod>=?,
  ~context: option<LoggerContext.t>=?,
  ~source: option<source>=?,
  ~limit: option<int>=?,
  ~message: option<string>=?,
  ~once=false,
) => Engine.emit(~category,~spec,~severity,~data?,~details?,~verbatim?,~exn?,~failure?,~durationMs?,~paymentMethod?,~context?,~source?,~limit?,~message?,~once)
