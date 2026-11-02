open Utils
type customEvent = {openurl_if_required: string}

@react.component
let make = () => {
  let isTrustedParent = PaymentMessageHooks.useFullscreenParentCheck()
  let (popupUrl, setPopupUrl) = React.useState(_ => "")
  let (redirectResponseUrl, setRedirectResponseUrl) = React.useState(_ => "")
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (loader, setloader) = React.useState(_ => false)
  let loggerState = Jotai.useAtomValue(JotaiAtoms.loggerAtom)

  let eventsToSendToParent = ["openurl_if_required"]
  let isTrustedChild = (ev: Window.event) =>
    [popupUrl, redirectResponseUrl]
    ->Array.filterMap(PaymentMessageSecurity.originOf)
    ->Array.includes(ev.origin) &&
      Window.querySelector("#threeDsRedirectFrame")
      ->Nullable.toOption
      ->Option.map(iframe => ev.source === iframe->Window.contentWindow)
      ->Option.getOr(false)
  eventsToSendToParent->UtilityHooks.useSendEventsToParent(~isTrustedChild)

  let handleOnClose = () =>
    if redirectResponseUrl == "" {
      postFailedSubmitResponse(~errortype="error", ~message="Something went wrong.")
      closePaymentLoaderIfAny()
    } else {
      let customEvent =
        {
          openurl_if_required: redirectResponseUrl,
        }
        ->Identity.anyTypeToJson
        ->getDictFromJson
      messageParentWindow(customEvent->Dict.toArray)
    }

  React.useEffect0(() => {
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    setloader(_ => true)
    let handle = (ev: Window.event) => {
      try {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        if isTrustedParent(ev) && dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
          let metadata = dict->getJsonObjectFromDict("metadata")
          let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
          let popupUrl = metaDataDict->getString("popupUrl", "")
          let redirectResponseUrl = metaDataDict->getString("redirectResponseUrl", "")
          setPopupUrl(_ => popupUrl)
          setRedirectResponseUrl(_ => redirectResponseUrl)
          setloader(_ => false)
        }
      } catch {
      | err => {
          let exceptionMessage = err->formatException->JSON.stringify
          loggerState.setLogError(~value=exceptionMessage, ~eventName=THREE_DS_POPUP_REDIRECTION)
          postFailedSubmitResponse(~errortype="error", ~message="Something went wrong.")
        }
      }
    }
    Window.addEventListener("message", handle)
    Some(() => Window.removeEventListener("message", handle))
  })
  <Modal loader openModal setOpenModal closeCallback=handleOnClose>
    <div className="w-full h-[500px] bg-white">
      <iframe id="threeDsRedirectFrame" className="w-full h-full" src={popupUrl} />
    </div>
  </Modal>
}
