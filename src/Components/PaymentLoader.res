@react.component
let make = () => {
  open Utils
  let (branding, setBranding) = React.useState(_ => "auto")
  let (paymentMethod, setPaymentMethod) = React.useState(_ => "")
  let setConfig = Recoil.useSetRecoilState(RecoilAtoms.configAtom)

  React.useEffect0(() => {
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let handleAsync = async () => {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        if dict->Utils.getBool("fullScreenIframeMounted", false) {
          let optionsDict = dict->getDictFromDict("options")
          if optionsDict->getOptionString("branding")->Option.isSome {
            setBranding(_ => optionsDict->getString("branding", "auto"))
          }
          let locale = optionsDict->getString("locale", "auto")
          let localeString = await CardTheme.getLocaleObject(locale)
          setConfig(prev => {...prev, localeString})
          let metadata = dict->getJsonObjectFromDict("metadata")
          let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
          let paymentMethodStr = metaDataDict->getString("paymentMethod", "")
          setPaymentMethod(_ => paymentMethodStr)
        }
      }
      handleAsync()->ignore
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  let styles =
    branding === "auto"
      ? "backdrop-blur-md bg-black/80"
      : "backdrop-contrast-125 backdrop-blur-2xl opacity-70 bg-black/80"

  <div className={`h-screen w-screen flex m-auto items-center ${styles}`}>
    <div className={`flex flex-col justify-center m-auto visible`}>
      <Loader branding paymentMethod />
    </div>
  </div>
}
