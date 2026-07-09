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
  let {iframeUrl, timeoutMs} = ddcData->Option.getOr(PaymentConfirmTypes.defaultDdcData)
  let emitCardDdcDemoEvent = (~eventName, ~extra=[]) => {
    if paymentMethod === "CARD" {
      let payload = [
        ("iframeId", iframeId->JSON.Encode.string),
        ("iframeUrl", iframeUrl->JSON.Encode.string),
        ("timeoutMs", timeoutMs->JSON.Encode.int),
        ("response", data),
      ]
      extra->Array.forEach(item => payload->Array.push(item))
      DemoTelemetry.emit(~flow="card", ~eventName, ~payload=payload->getJsonFromArrayOfJson, ())
    }
  }

  LoggerUtils.handleLogging(~optLogger, ~eventName=DDC_FLOW, ~value="DDC initiated", ~paymentMethod)
  emitCardDdcDemoEvent(~eventName="ddc_collection_started")

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
    LoggerUtils.handleLogging(
      ~optLogger,
      ~eventName=DDC_FLOW,
      ~value="DDC failed: empty iframe URL",
      ~paymentMethod,
      ~logType=ERROR,
    )
    emitCardDdcDemoEvent(
      ~eventName="ddc_collection_failed",
      ~extra=[("reason", "empty iframe URL"->JSON.Encode.string)],
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
          LoggerUtils.handleLogging(
            ~optLogger,
            ~eventName=REDIRECTING_USER,
            ~value="Post DDC redirection",
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
            LoggerUtils.handleLogging(
              ~optLogger,
              ~eventName=DDC_FLOW,
              ~value="DDC completed successfully",
              ~paymentMethod,
            )
            emitCardDdcDemoEvent(
              ~eventName="ddc_collection_completed",
              ~extra=[("nextAction", dict->getJsonObjectFromDict("next_action"))],
            )
            handleRedirectToUrl(redirectUrl, redirectMode)
          } else {
            LoggerUtils.handleLogging(
              ~optLogger,
              ~eventName=DDC_FLOW,
              ~value=`DDC failed: invalid next action type - ${nextActionType}`,
              ~paymentMethod,
              ~logType=ERROR,
            )
            emitCardDdcDemoEvent(
              ~eventName="ddc_collection_failed",
              ~extra=[
                ("nextAction", dict->getJsonObjectFromDict("next_action")),
                ("reason", `invalid next action type - ${nextActionType}`->JSON.Encode.string),
              ],
            )
            handleFailure()
          }
        }
      } catch {
      | exn =>
        let err = exn->Identity.anyTypeToJson->JSON.stringify
        LoggerUtils.handleLogging(
          ~optLogger,
          ~eventName=DDC_FLOW,
          ~value=`DDC failed: message parse error - ${err}`,
          ~paymentMethod,
          ~logType=ERROR,
        )
        emitCardDdcDemoEvent(
          ~eventName="ddc_collection_failed",
          ~extra=[("reason", `message parse error - ${err}`->JSON.Encode.string)],
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
          LoggerUtils.handleLogging(
            ~optLogger,
            ~eventName=DDC_FLOW,
            ~value="DDC timed out",
            ~paymentMethod,
            ~logType=ERROR,
          )
          emitCardDdcDemoEvent(
            ~eventName="ddc_collection_failed",
            ~extra=[("reason", "timeout"->JSON.Encode.string)],
          )
          cleanup()
          handleFailure()
        }, timeoutMs))
  }
}
