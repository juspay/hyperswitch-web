// Defaults are typed shared ReScript; webpack supplies only explicit overrides.
include SharedLogger.Config.Web
@scope("__SDK_CONFIG__") @val external enabledOverride: option<bool> = "enableLogging"
@scope("__SDK_CONFIG__") @val external endpointOverride: option<string> = "logEndpoint"
@scope("__SDK_CONFIG__") @val external levelOverride: option<string> = "loggingLevel"
@scope("__SDK_CONFIG__") @val external maxRowsOverride: option<int> = "maxLogsPushedPerEventName"
@scope("__SDK_CONFIG__") @val external maxUserOverride: option<int> = "maxUserEventsPerName"

// Preserve live reads for enablement/caps and module-time resolution for endpoint/level.
let enabled = () => SharedLogger.Config.Web.resolveEnabled(enabledOverride)
let maxRowsPerEventName = () => SharedLogger.Config.Web.resolveMaxRowsPerEventName(maxRowsOverride)
let maxUserEventsPerName = () => SharedLogger.Config.Web.resolveMaxUserEventsPerName(maxUserOverride)
let endpoint = SharedLogger.Config.Web.resolveEndpoint(endpointOverride)
let minimumRank = SharedLogger.Config.Web.resolveMinimumRank(levelOverride)
