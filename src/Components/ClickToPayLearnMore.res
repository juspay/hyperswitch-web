open Utils

@react.component
let make = () => {
  let (openModal, setOpenModal) = React.useState(_ => false)
  let (cardBrand, setCardBrand) = React.useState(_ => "")

  let logger = HyperLogger.make(~source=Elements(Payment))

  let closeClickToPayModal = () => {
    setOpenModal(_ => false)
    messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
  }

  React.useEffect0(() => {
    ClickToPayHelpers.loadClickToPayScripts(logger)->ignore
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson
      if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
        let metadata = dict->getJsonObjectFromDict("metadata")->getDictFromJson
        let cardBrands =
          metadata
          ->Utils.getArray("cardBrands")
          ->Array.map(x => x->JSON.Decode.string->Option.getOr(""))
          ->Array.filter(x => x !== "")
          ->Array.join(",")

        if cardBrands === "" {
          closeClickToPayModal()
        }
        setCardBrand(_ => cardBrands)
      }
    }
    Window.addEventListener("message", handle)
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    Some(() => {Window.removeEventListener("message", handle)})
  })

  React.useEffect(() => {
    let handleClickToPayLearnMore = _ => {
      closeClickToPayModal()
    }
    Window.addEventListener("ok", handleClickToPayLearnMore)
    Some(
      () => {
        Window.removeEventListener("ok", handleClickToPayLearnMore)
      },
    )
  }, [])

  <RenderIf condition={cardBrand !== ""}>
    <div>
      <Modal showClose=false openModal setOpenModal>
        <ClickToPayHelpers.SrcLearnMore cardBrands=cardBrand />
      </Modal>
    </div>
  </RenderIf>
}
