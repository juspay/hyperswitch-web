open Utils

let handleDDC = (
  ~ddcData: option<PaymentConfirmTypes.ddcData>,
  ~iframeId,
  ~isPaymentSession,
  ~resolve,
  ~data,
  ~loggedPaymentMethod,
) => {
  let {iframeUrl, timeoutMs} = ddcData->Option.getOr(PaymentConfirmTypes.defaultDdcData)

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
      ~event=DdcFailed({reason: MissingUrl}),
      ~paymentMethod=?loggedPaymentMethod,
    )
    handleFailure()
  } else {
    SdkLogger.logLifecycle(~event=DdcStarted, ~paymentMethod=?loggedPaymentMethod)

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
          let redirectOrigin = try {
            URLModule.makeUrl(redirectUrl).origin
          } catch {
          | _ => ""
          }
          SdkLogger.logLifecycle(
            ~event=CustomerRedirectStarted({
              nextAction: "redirect_to_url",
              redirectMode,
              redirectOrigin,
            }),
            ~paymentMethod=?loggedPaymentMethod,
          )
          openUrl(redirectUrl)
        }
      }
    }

    let handleMessage = (ev: Window.event) => {
      let parsed = try {
        let json = ev.data->Identity.anyTypeToJson
        let dict = json->getDictFromJson
        dict->Dict.get("next_action")->Option.isSome
          ? Ok(Some(PaymentConfirmTypes.getNextAction(dict, "next_action")))
          : Ok(None)
      } catch {
      | exn => Error(exn)
      }

      switch parsed {
      | Error(exn) =>
        SdkLogger.logLifecycle(
          ~event=DdcFailed({reason: UnreadableResponse}),
          ~exn,
          ~paymentMethod=?loggedPaymentMethod,
        )
        cleanup()
        handleFailure()
      | Ok(None) => ()
      | Ok(Some(nextAction)) =>
        let nextActionType = nextAction.type_
        let redirectUrl = nextAction.postDdcRedirectUrl
        let redirectMode = nextAction.redirectMode
        cleanup()
        if nextActionType === "redirect_to_url" && redirectUrl !== "" {
          SdkLogger.logLifecycle(~event=DdcCompleted, ~paymentMethod=?loggedPaymentMethod)
          handleRedirectToUrl(redirectUrl, redirectMode)
        } else {
          let reason: SdkLogger.ddcFailure =
            nextActionType === "redirect_to_url" ? MissingRedirectUrl : InvalidNextAction
          SdkLogger.logLifecycle(
            ~event=DdcFailed({reason: reason}),
            ~details=[("next_action", nextActionType->JSON.Encode.string)],
            ~paymentMethod=?loggedPaymentMethod,
          )
          handleFailure()
        }
      }
    }

    messageHandlerRef := Some(handleMessage)
    Window.addEventListener("message", handleMessage)

    let iframe = Window.body->makeHiddenIframe(~src=iframeUrl, ~id="ddc-iframe")
    iframeRef := Some(iframe)

    timeoutIdRef := Some(setTimeout(() => {
          SdkLogger.logLifecycle(~event=DdcTimedOut, ~paymentMethod=?loggedPaymentMethod)
          cleanup()
          handleFailure()
        }, timeoutMs))
  }
}
