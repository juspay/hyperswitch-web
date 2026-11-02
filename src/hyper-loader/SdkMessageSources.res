// Register frames at SDK creation sites, never from incoming messages or DOM IDs.
// Keep the configured origin: the same WindowProxy can later navigate elsewhere.
type frameSource = {frame: Dom.element, origin: string}

type registryKey
@scope("Symbol") @val external symbolFor: string => registryKey = "for"
@get_index
external readRegistry: (Dom.element, registryKey) => Nullable.t<ref<array<frameSource>>> = ""
@set_index external writeRegistry: (Dom.element, registryKey, ref<array<frameSource>>) => unit = ""
@val external currentWindow: Dom.element = "window"
@scope("window") @val external topWindow: Dom.element = "top"

// The loader and framework packages may contain separate copies of this module.
// Same-origin merchant descendants also share the top document's cleanup hook.
// Browser access checks prevent a foreign frame from registering itself here.
let registryKey = symbolFor("hyperswitch.sdkMessageSources")
let getRegistry = host =>
  switch readRegistry(host, registryKey)->Nullable.toOption {
  | Some(registry) => registry
  | None =>
    let registry = ref([])
    writeRegistry(host, registryKey, registry)
    registry
  }

let frames = try {
  getRegistry(topWindow)
} catch {
| _ => getRegistry(currentWindow)
}

let prune = () => {
  frames := frames.contents->Array.filter(entry => entry.frame->Window.Element.isConnected)
}

let register = (~frame, ~origin) => {
  prune()
  if PaymentMessageSecurity.isConcreteOrigin(origin) && frame->Window.Element.isConnected {
    frames := frames.contents->Array.filter(entry => entry.frame !== frame)
    frames.contents->Array.push({frame, origin})->ignore
  }
}

let isRegisteredSender = (event: Types.event) => {
  prune()
  frames.contents->Array.some(entry =>
    PaymentMessageSecurity.isExpectedSender(
      ~source=entry.frame->Window.contentWindow,
      ~origin=entry.origin,
      ~eventSource=event.source,
      ~eventOrigin=event.origin,
    )
  )
}
