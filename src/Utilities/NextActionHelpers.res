open Utils

let handleDDC = (
  ~ddcData: option<PaymentConfirmTypes.ddcData>,
  ~iframeId,
  ~isPaymentSession,
  ~resolve,
  ~data,
  ~optLogger,
  ~paymentMethod,
) => {
  let iframeUrl = ddcData->Option.map(data => data.iframe_url)->Option.getOr("")
  let timeoutMs = ddcData->Option.map(data => data.timeout_ms)->Option.getOr(30000)

  messageParentWindow([
    ("fullscreen", true->JSON.Encode.bool),
    ("param", "paymentloader"->JSON.Encode.string),
    ("iframeId", iframeId->JSON.Encode.string),
  ])

  let errorType = "confirm_payment_failed"
  let errorMessage = "Something went wrong"

  if iframeUrl === "" {
    if !isPaymentSession {
      closePaymentLoaderIfAny()
      postFailedSubmitResponse(~errortype=errorType, ~message=errorMessage)
    } else {
      let failedSubmitResponse = getFailedSubmitResponse(~errorType, ~message=errorMessage)
      resolve(failedSubmitResponse)
    }
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

    let handleFailure = () =>
      if !isPaymentSession {
        closePaymentLoaderIfAny()
        postFailedSubmitResponse(~errortype=errorType, ~message=errorMessage)
      } else {
        let failedSubmitResponse = getFailedSubmitResponse(~errorType, ~message=errorMessage)
        resolve(failedSubmitResponse)
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
          LoggerUtils.handleLogging(
            ~optLogger,
            ~eventName=REDIRECTING_USER,
            ~value=redirectUrl,
            ~paymentMethod,
            ~logType=INFO,
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
            handleRedirectToUrl(redirectUrl, redirectMode)
          } else {
            handleFailure()
          }
        }
      } catch {
      | _ =>
        cleanup()
        handleFailure()
      }
    }

    let iframe = Window.body->makeHiddenIframe(~src=iframeUrl, ~id="ddc-iframe")
    iframeRef := Some(iframe)

    timeoutIdRef := Some(setTimeout(() => {
          cleanup()
          handleFailure()
        }, timeoutMs))

    messageHandlerRef := Some(handleMessage)
    Window.addEventListener("message", handleMessage)
  }
}
