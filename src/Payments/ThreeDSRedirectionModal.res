open Utils
type customEvent = {openurl_if_required: string}

@react.component
let make = () => {
  let (popupUrl, setPopupUrl) = React.useState(_ => "")
  let (redirectResponseUrl, setRedirectResponseUrl) = React.useState(_ => "")
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (loader, setloader) = React.useState(_ => false)
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)

  let eventsToSendToParent = ["openurl_if_required"]
  eventsToSendToParent->UtilityHooks.useSendEventsToParent

  let handleOnClose = () =>
    if redirectResponseUrl == "" {
      messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
      postFailedSubmitResponse(~errortype="error", ~message="Something went wrong.")
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
        if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
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
      <iframe className="w-full h-full" src={popupUrl} />
    </div>
  </Modal>
}
