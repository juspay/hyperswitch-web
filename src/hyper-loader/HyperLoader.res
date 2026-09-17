/*
 Every async chunk this loader pulls in arrives as a `<script>` webpack injects at runtime, so
 a merchant whose CSP is `script-src 'nonce-…'` without `'strict-dynamic'` allows their own
 `<script nonce=…>` for HyperLoader.js and then blocks every chunk it asks for - which is now
 every public API surface. `__webpack_nonce__` is webpack's hook: it must be raw JS for
 webpack's parser to see, and must run during initial script evaluation, while this file's own
 `<script>` is still `document.currentScript` - exactly when a top-level statement here runs.
 `getAttribute("nonce")` is the fallback: browsers with CSP nonce hiding blank the content
 attribute and answer only on the IDL property.
 */
%%raw(`
try {
  var hyperLoaderScript = document.currentScript;
  if (!hyperLoaderScript) {
    var noncedScripts = document.querySelectorAll("script[nonce]");
    hyperLoaderScript = noncedScripts.length > 0 ? noncedScripts[noncedScripts.length - 1] : null;
  }
  var hyperLoaderNonce = hyperLoaderScript
    ? hyperLoaderScript.nonce || hyperLoaderScript.getAttribute("nonce")
    : null;
  if (hyperLoaderNonce) {
    __webpack_nonce__ = hyperLoaderNonce;
  }
} catch (hyperLoaderNonceError) {
  /* A CSP that never needed a nonce must not be worse off than one that did */
}
`)

let loadHyper = (str, option) => {
  Promise.resolve(Hyper.make(str, option, None))
}

let loadStripe = (str, option) => {
  ErrorUtils.manageErrorWarning(DEPRECATED_LOADSTRIPE, ~logger=LoggerUtils.defaultLoggerConfig)
  loadHyper(str, option)
}

let removeBeforeUnloadEventListeners: array<'ev => unit> => unit = handlers => {
  let iframeMessageHandler = (ev: Types.event) => {
    let dict = ev.data->Identity.anyTypeToJson->Utils.getDictFromJson
    dict
    ->Dict.get("disableBeforeUnloadEventListener")
    ->Option.map(shouldRemove => {
      if shouldRemove->JSON.Decode.bool->Option.getOr(false) {
        try {
          handlers
          ->Array.map(handler => {
            Window.removeEventListener("beforeunload", handler)
          })
          ->ignore
        } catch {
        | err => Js.Console.error2("Incorrect usage of removeBeforeUnloadEventListeners hook", err)
        }
      }
    })
    ->ignore
  }

  // Subscribe to postMessage event
  Window.addEventListener("message", iframeMessageHandler)
}

Types.window["Hyper"] = Hyper.make
Types.window["Hyper"]["init"] = Hyper.make
Types.window["removeBeforeUnloadEventListeners"] = removeBeforeUnloadEventListeners

let isWordpress = Types.window["wp"] !== JSON.Encode.null
if !isWordpress {
  Types.window["Stripe"] = Hyper.make
}
