// Web adapter: injected values remain direct external reads, not snapshots.
include SharedLogger.Config.Web
@scope("__SDK_CONFIG__") @val external enabled: bool = "enableLogging"
let endpoint = GlobalVars.logEndpoint->SharedLogger.Config.normalizeEndpoint
let minimumRank = GlobalVars.loggingLevelStr->SharedLogger.Config.rankOfLevel
@scope("__SDK_CONFIG__") @val
external maxRowsPerEventName: int = "maxLogsPushedPerEventName"
@scope("__SDK_CONFIG__") @val
external maxUserEventsPerName: int = "maxUserEventsPerName"
