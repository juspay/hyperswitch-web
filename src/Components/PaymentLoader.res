@react.component
let make = () => {
  let (branding, setBranding) = React.useState(_ => "auto")

  React.useEffect0(() => {
    Utils.handlePostMessage([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      let json = ev.data->JSON.parseExn
      let dict = json->Utils.getDictFromJson
      setBranding(_ => dict->Utils.getDictFromDict("options")->Utils.getString("branding", "auto"))
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
