open LoggerTypes

type paymentOutcomeData = {status: string, manualRetryAllowed?: bool}
type retryExhaustionData = {operation: string, attempts: int}
type paymentStatusUnknownData = {inferred: bool}

type lifecycleEvent =
  | PaymentAttempted
  | PaymentSucceeded(paymentOutcomeData)
  | PaymentFailed(paymentOutcomeData)
  | PaymentRejected
  | PaymentStatusUnknown(paymentStatusUnknownData)
  | PaymentRetriesExhausted(retryExhaustionData)
  | PaymentErrorHandlingFailed
  | PaymentStatusPollExhausted

let lifecycleSeverity = event =>
  switch event {
  | PaymentAttempted | PaymentSucceeded(_) | PaymentFailed(_) => Info
  | PaymentStatusUnknown(_) | PaymentStatusPollExhausted => Warning
  | PaymentRejected | PaymentRetriesExhausted(_) | PaymentErrorHandlingFailed => Error
  }
