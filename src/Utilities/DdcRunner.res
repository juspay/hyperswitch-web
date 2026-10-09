open Utils

type result =
  | Redirect(string, string)
  | Failed

let run = (~ddcData: option<PaymentConfirmTypes.ddcData>, ~optLogger, ~paymentMethod) =>
  Promise.make((resolve, _) => {
    let {iframeUrl, timeoutMs} = ddcData->Option.getOr(PaymentConfirmTypes.defaultDdcData)
    let log = (~logType=HyperLoggerTypes.INFO, value) =>
      LoggerUtils.handleLogging(~optLogger, ~eventName=DDC_FLOW, ~value, ~paymentMethod, ~logType)

    log("DDC initiated")

    if iframeUrl === "" {
      log(~logType=ERROR, "DDC failed: empty iframe URL")
      resolve(Failed)
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

      let handleMessage = (ev: Window.event) =>
        try {
          let dict = ev.data->Identity.anyTypeToJson->getDictFromJson
          if dict->Dict.get("next_action")->Option.isSome {
            let nextAction = PaymentConfirmTypes.getNextAction(dict, "next_action")
            cleanup()
            if nextAction.type_ === "redirect_to_url" && nextAction.postDdcRedirectUrl !== "" {
              log("DDC completed successfully")
              resolve(Redirect(nextAction.postDdcRedirectUrl, nextAction.redirectMode))
            } else {
              log(~logType=ERROR, `DDC failed: invalid next action type - ${nextAction.type_}`)
              resolve(Failed)
            }
          }
        } catch {
        | exn =>
          log(
            ~logType=ERROR,
            `DDC failed: message parse error - ${exn->Identity.anyTypeToJson->JSON.stringify}`,
          )
          cleanup()
          resolve(Failed)
        }

      messageHandlerRef := Some(handleMessage)
      Window.addEventListener("message", handleMessage)
      iframeRef := Some(Window.body->makeHiddenIframe(~src=iframeUrl, ~id="ddc-iframe"))
      timeoutIdRef := Some(setTimeout(() => {
            log(~logType=ERROR, "DDC timed out")
            cleanup()
            resolve(Failed)
          }, timeoutMs))
    }
  })
