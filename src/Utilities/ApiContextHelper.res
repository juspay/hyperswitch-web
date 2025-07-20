open PaymentHelpersTypes
open IntentCallTypes
open HyperLoggerTypes

// Create API call context from URI
let createApiCallContext = uri => {
  let isConfirm = uri->String.includes("/confirm")
  let isCompleteAuthorize = uri->String.includes("/complete_authorize")
  let isPostSessionTokens = uri->String.includes("/post_session_tokens")

  let (eventName, initEventName) = switch (isConfirm, isCompleteAuthorize, isPostSessionTokens) {
  | (true, _, _) => (CONFIRM_CALL, CONFIRM_CALL_INIT)
  | (_, true, _) => (COMPLETE_AUTHORIZE_CALL, COMPLETE_AUTHORIZE_CALL_INIT)
  | (_, _, true) => (POST_SESSION_TOKENS_CALL, POST_SESSION_TOKENS_CALL_INIT)
  | _ => (RETRIEVE_CALL, RETRIEVE_CALL_INIT)
  }

  {
    eventName,
    initEventName,
    isConfirm,
    isCompleteAuthorize,
    isPostSessionTokens,
  }
}

// Get payment method string for context
let getPaymentMethodFromParams = (params: intentCallParams): string => {
  switch params.paymentType {
  | Card => "CARD"
  | Gpay => "GOOGLE_PAY"
  | Applepay => "APPLE_PAY"
  | Paypal => "PAYPAL"
  | _ => "OTHER"
  }
}
