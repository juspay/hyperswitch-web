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

  CorePaymentLogger.logLifecycle(~event=DdcFlow, ~message="DDC initiated", ~paymentMethod)

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
    CorePaymentLogger.logLifecycle(
      ~event=DdcFlowFailed,
      ~message="DDC failed: empty iframe URL",
      ~paymentMethod,
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
          CorePaymentLogger.logLifecycle(
            ~event=RedirectingUser,
            ~message="Post DDC redirection",
            ~paymentMethod,
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
            CorePaymentLogger.logLifecycle(
              ~event=DdcFlow,
              ~message="DDC completed successfully",
              ~paymentMethod,
            )
            handleRedirectToUrl(redirectUrl, redirectMode)
          } else {
            CorePaymentLogger.logLifecycle(
              ~event=DdcFlowFailed,
              ~message=`DDC failed: invalid next action type - ${nextActionType}`,
              ~paymentMethod,
            )
            handleFailure()
          }
        }
      } catch {
      | exn =>
        let err = exn->Identity.anyTypeToJson->JSON.stringify
        CorePaymentLogger.logLifecycle(
          ~event=DdcFlowFailed,
          ~message=`DDC failed: message parse error - ${err}`,
          ~paymentMethod,
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
          CorePaymentLogger.logLifecycle(
            ~event=DdcFlowFailed,
            ~message="DDC timed out",
            ~paymentMethod,
          )
          cleanup()
          handleFailure()
        }, timeoutMs))
  }
}
