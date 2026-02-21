open Utils

@react.component
let make = () => {
  let logger = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let (iframeUrl, setIframeUrl) = React.useState(_ => "")
  let (timeoutMs, setTimeoutMs) = React.useState(_ => 30000)

  let timeoutIdRef = React.useRef(None)
  let messageHandlerRef = React.useRef(None)

  let eventsToSendToParent = ["next_action"]
  eventsToSendToParent->UtilityHooks.useSendEventsToParent

  let cleanup = () => {
    timeoutIdRef.current->Option.forEach(clearTimeout)
    messageHandlerRef.current->Option.forEach(h => Window.removeEventListener("message", h))
    timeoutIdRef.current = None
    messageHandlerRef.current = None
  }

  let handleFailure = () =>
    postFailedSubmitResponse(~errortype="error", ~message="Something went wrong")

  let handleRedirectToUrl = (redirectUrl, redirectMode) =>
    switch redirectMode {
    | "if_required" =>
      messageParentWindow([("openurl_if_required", redirectUrl->JSON.Encode.string)])
    | _ => {
        LoggerUtils.handleLogging(
          ~optLogger=Some(logger),
          ~eventName=REDIRECTING_USER,
          ~value=redirectUrl,
          ~paymentMethod="CARD",
          ~logType=INFO,
        )
        openUrl(redirectUrl)
      }
    }

  React.useEffect0(() => {
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      try {
        let json = switch ev.data->JSON.Classify.classify {
        | String(str) => str->safeParse
        | Object(obj) => obj->JSON.Encode.object
        | _ => JSON.Encode.null
        }
        let dict = json->getDictFromJson
        if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
          let metaDataDict = dict->getDictFromDict("metadata")

          setIframeUrl(_ => metaDataDict->getString("iframeUrl", ""))
          setTimeoutMs(_ => metaDataDict->getFloat("timeoutMs", 30000.0)->Float.toInt)
        } else if dict->Dict.get("next_action")->Option.isSome {
          let nextAction = PaymentConfirmTypes.getNextAction(dict, "next_action")
          let nextActionType = nextAction.type_
          let redirectUrl = nextAction.url
          let redirectMode = nextAction.redirectMode
          if nextActionType === "redirect_to_url" && redirectUrl !== "" {
            handleRedirectToUrl(redirectUrl, redirectMode)
          } else {
            handleFailure()
          }
        }
      } catch {
      | _ => handleFailure()
      }
    }

    Window.addEventListener("message", handle)

    timeoutIdRef.current = Some(setTimeout(() => {
        cleanup()
        handleFailure()
      }, timeoutMs))

    Some(
      () => {
        Window.removeEventListener("message", handle)
        cleanup()
      },
    )
  })

  <iframe
    id="orca-ddc-iframe"
    src={iframeUrl}
    className="absolute w-[1px] h-[1px] border-0 overflow-hidden -left-[9999px] -top-[9999px]"
  />
}
