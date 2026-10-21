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

  <>
    <RenderIf condition={branding === "auto"}>
      <div className="h-screen w-screen flex m-auto items-center backdrop-blur-md bg-black/80">
        <div className={`flex flex-col justify-center m-auto visible`}>
          <HyperswitchLoader branding />
        </div>
      </div>
    </RenderIf>
    <RenderIf condition={branding !== "auto"}>
      <Loader className="Loader--fullscreen h-screen w-screen" />
    </RenderIf>
  </>
}
