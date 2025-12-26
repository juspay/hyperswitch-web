@react.component
let make = () => {
  open Utils
  let (branding, setBranding) = React.useState(_ => "auto")

  React.useEffect0(() => {
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson
      if dict->Utils.getBool("fullScreenIframeMounted", false) {
        if dict->getDictFromDict("options")->getOptionString("branding")->Option.isSome {
          setBranding(_ => dict->getDictFromDict("options")->getString("branding", "auto"))
        }
      }
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
      <Loader branding />
    </div>
  </div>
}
