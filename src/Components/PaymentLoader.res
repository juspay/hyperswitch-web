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
        let rules = dict->getDictFromDict("appearance")->getJsonObjectFromDict("rules")
        dict->loadTheme(theme => {
          generateStyleSheet(
            "",
            mergeJsons(theme.defaultRules(theme.default), rules)->getDictFromJson,
            "loaderstyle",
          )
          Promise.resolve()
        })
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  let className =
    branding === "auto"
      ? "h-screen w-screen backdrop-blur-md bg-black/80"
      : "Loader--fullscreen h-screen w-screen"

  <Loader branding className />
}
