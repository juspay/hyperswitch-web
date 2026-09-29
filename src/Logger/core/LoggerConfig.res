@scope("__SDK_CONFIG__") @val external enabled: bool = "enableLogging"
let endpoint = GlobalVars.logEndpoint->String.trim

let minimumRank = switch GlobalVars.loggingLevelStr->String.trim->String.toUpperCase {
| "INFO" => 1
| "WARNING" | "WARN" => 2
| "ERROR" => 3
| "SILENT" => 4
| _ => 0
}

@inline let schemaVersion = 8

@scope("__SDK_CONFIG__") @val
external maxRowsPerEventName: int = "maxLogsPushedPerEventName"
@scope("__SDK_CONFIG__") @val
external maxUserEventsPerName: int = "maxUserEventsPerName"

@inline let defaultTimeoutMs = 30000
@inline let userGatedTimeoutMs = 600000

@inline let flushDelayMs = 2000
@inline let maxFlushBackoffMs = 60000
@inline let maxBatchBytes = 30000
@inline let maxQueuedRows = 100
@inline let maxSendAttemptsPerBatch = 4

@inline let maxTextLength = 256
@inline let maxRowTextLength = 1024
@inline let maxDetailBytes = 8192
@inline let maxPayloadFields = 120

@inline let maxConfigBytes = 2048
@inline let maxConfigDepth = 6
@inline let maxConfigArrayItems = 20
@inline let maxConfigOmitted = 10
