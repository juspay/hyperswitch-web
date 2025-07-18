// Type definitions for intent call processing
open PaymentHelpersTypes

type intentCallParams = {
  fetchApi: (
    string,
    ~bodyStr: string=?,
    ~headers: Dict.t<string>=?,
    ~method: Fetch.method,
    ~customPodUri: option<string>=?,
    ~publishableKey: option<string>=?,
  ) => promise<Fetch.Response.t>,
  uri: string,
  headers: array<(string, string)>,
  bodyStr: string,
  confirmParam: ConfirmType.confirmParams,
  clientSecret: string,
  optLogger: option<HyperLoggerTypes.loggerMake>,
  handleUserError: bool,
  paymentType: payment,
  iframeId: string,
  fetchMethod: Fetch.method,
  setIsManualRetryEnabled: (bool => bool) => unit,
  customPodUri: string,
  sdkHandleOneClickConfirmPayment: bool,
  counter: int,
  isPaymentSession: bool,
  isCallbackUsedVal: option<bool>,
  componentName: string,
  redirectionFlags: RecoilAtomTypes.redirectionFlags,
}

type intentCallResult =
  | Success(JSON.t)
  | Failure(string, string) // errorType, message
  | Retry(intentCallParams)

type apiCallContext = {
  eventName: HyperLoggerTypes.eventName,
  initEventName: HyperLoggerTypes.eventName,
  isConfirm: bool,
  isCompleteAuthorize: bool,
  isPostSessionTokens: bool,
}

type voucherDetails = {
  download_url: string,
  reference: string,
}

type nextActionType =
  | RedirectToUrl(string)
  | RedirectInsidePopup(string, string) // popupUrl, redirectResponseUrl
  | DisplayBankTransferInfo(option<JSON.t>)
  | QrCodeInformation(string, string, string, float) // qrData, displayText, borderColor, expiryTime
  | ThreeDsInvoke(Dict.t<JSON.t>)
  | InvokeHiddenIframe(Dict.t<JSON.t>)
  | DisplayVoucherInfo(voucherDetails)
  | ThirdPartySdkSessionToken(Dict.t<JSON.t>)
  | InvokeSdkClient(JSON.t)
  | Unknown(string)

type retryConfig = {
  maxRetries: int,
  currentRetry: int,
  retryDelay: int,
}
