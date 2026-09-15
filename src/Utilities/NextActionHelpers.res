open Utils
open LoggerCommonHelpers

let handleDDC = (
  ~ddcData: option<PaymentConfirmTypes.ddcData>,
  ~iframeId,
  ~isPaymentSession,
  ~resolve,
  ~data,
  ~paymentMethod,
) => {
  let {iframeUrl, timeoutMs} = ddcData->Option.getOr(PaymentConfirmTypes.defaultDdcData)

  let loggedPaymentMethod = paymentMethod->LoggerTaxonomy.fromBackendValue
  SdkLogger.logLifecycle(~event=DdcFlow, ~paymentMethod=?loggedPaymentMethod)

  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", "paymentloader"->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
  ])

  let errorType = "error"
  let errorMessage = "Something went wrong"

  let handleFailure = () => {
    closePaymentLoaderIfAny()
    if !isPaymentSession {
      postFailedSubmitResponse(~errortype=errorType, ~message=errorMessage)
    }
    let failedSubmitResponse = getFailedSubmitResponse(~errorType, ~message=errorMessage)
    resolve(failedSubmitResponse)
  }

  if iframeUrl === "" {
    SdkLogger.logLifecycle(
      ~event=DdcFlowFailed({cause: "empty_url"}),
      ~paymentMethod=?loggedPaymentMethod,
    )
    handleFailure()
  } else {
    let timeoutIdRef = ref(None)
    let messageHandlerRef = ref(None)
    let iframeRef = ref(None)

    let cleanup = () => {
      timeoutIdRef.contents->Option.forEach(clearTimeout)
      messageHandlerRef.contents->Option.forEach(h => Window.removeEventListener("message", h))
      iframeRef.contents->Option.forEach(Window.remove)
      timeoutIdRef := None
      messageHandlerRef := None
      iframeRef := None
    }

    let handleRedirectToUrl = (redirectUrl, redirectMode) => {
      closePaymentLoaderIfAny()
      switch redirectMode {
      | "if_required" =>
        if !isPaymentSession {
          messageParentWindow([("openurl_if_required", redirectUrl->JSON.Encode.string)])
        } else {
          resolve(data)
        }
      | _ => {
          SdkLogger.logLifecycle(
            ~event=RedirectingUser,
            ~message="Post DDC redirection",
            ~paymentMethod=?loggedPaymentMethod,
          )
          openUrl(redirectUrl)
        }
      }
    }

    let handleMessage = (ev: Window.event) => {
      try {
        let json = ev.data->Identity.anyTypeToJson
        let dict = json->getDictFromJson

        if dict->Dict.get("next_action")->Option.isSome {
          let nextAction = PaymentConfirmTypes.getNextAction(dict, "next_action")
          let nextActionType = nextAction.type_
          let redirectUrl = nextAction.postDdcRedirectUrl
          let redirectMode = nextAction.redirectMode
          cleanup()
          if nextActionType === "redirect_to_url" && redirectUrl !== "" {
            SdkLogger.logLifecycle(~event=DdcFlowCompleted, ~paymentMethod=?loggedPaymentMethod)
            handleRedirectToUrl(redirectUrl, redirectMode)
          } else {
            SdkLogger.logLifecycle(
              ~event=DdcFlowFailed({cause: "invalid_next_action"}),
              ~details=[("next_action", nextActionType->JSON.Encode.string)],
              ~paymentMethod=?loggedPaymentMethod,
            )
            handleFailure()
          }
        }
      } catch {
      | exn =>
        SdkLogger.logLifecycle(
          ~event=DdcFlowFailed({cause: "parse_error"}),
          ~exn,
          ~paymentMethod=?loggedPaymentMethod,
        )
        cleanup()
        handleFailure()
      }
    }

    messageHandlerRef := Some(handleMessage)
    Window.addEventListener("message", handleMessage)

    let iframe = Window.body->makeHiddenIframe(~src=iframeUrl, ~id="ddc-iframe")
    iframeRef := Some(iframe)

    timeoutIdRef := Some(setTimeout(() => {
          SdkLogger.logLifecycle(~event=DdcFlowTimedOut, ~paymentMethod=?loggedPaymentMethod)
          cleanup()
          handleFailure()
        }, timeoutMs))
  }
}
