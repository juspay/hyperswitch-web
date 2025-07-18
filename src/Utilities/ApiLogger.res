open Utils
open LoggerUtils
open IntentCallTypes
open HyperLoggerTypes

// Log API request initiation
let logRequest = (context: apiCallContext, params: intentCallParams): unit => {
  logApi(
    ~optLogger=params.optLogger,
    ~url=params.uri,
    ~statusCode=0,
    ~apiLogType=Request,
    ~eventName=context.initEventName,
    ~isPaymentSession=params.isPaymentSession,
  )
}

// Log retry attempt
let logRetry = (
  _context: apiCallContext,
  params: intentCallParams,
  retryCount: int,
  delay: int,
  error: JSON.t,
): unit => {
  let errorMessage = error->JSON.stringify
  let logMessage = `Retry attempt ${retryCount->Int.toString} after ${delay->Int.toString}ms delay. Error: ${errorMessage}`

  logApi(
    ~optLogger=params.optLogger,
    ~url=params.uri,
    ~data=logMessage->JSON.Encode.string,
    ~statusCode=0,
    ~apiLogType=NoResponse,
    ~eventName=RETRIEVE_CALL,
    ~logType=INFO,
    ~logCategory=API,
    ~isPaymentSession=params.isPaymentSession,
  )
}
