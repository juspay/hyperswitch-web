/* VGS Collect.js broker: runs ON the merchant's page and lets VGS inject its own secure
   field iframes at the merchant's DOM spots via `form.field(selector, options)`.
   The `<script>` is SRI-pinned so a compromised VGS CDN cannot inject JS into merchant
   pages — a hash mismatch makes the browser refuse to execute it (fail-closed).
   Confirms ride `submitForm`; aliases resolve in-page with no backend session-confirm. */

open Utils

type vgsCollectGlobal = {create: (string, string, JSON.t => unit) => JSON.t}
@val @scope("window") external vgsCollect: Nullable.t<vgsCollectGlobal> = "VGSCollect"

@send external formField: (JSON.t, string, JSON.t) => JSON.t = "field"
@send
external formSubmit: (
  JSON.t,
  string,
  JSON.t,
  (int, JSON.t) => unit,
  (int, JSON.t) => unit,
) => unit = "submit"
@send external fieldOn: (JSON.t, string, JSON.t => unit) => unit = "on"
@send external fieldUpdate: (JSON.t, JSON.t) => unit = "update"
@send external fieldDelete: JSON.t => unit = "delete"
/* presence probes only — the call itself still goes through the @send bindings above so
   `this` stays bound to the handle. */
@get external fieldUpdateHandler: JSON.t => Nullable.t<JSON.t => unit> = "update"
@get external fieldDeleteHandler: JSON.t => Nullable.t<unit => unit> = "delete"

/* `Window.addEventListener` is `@scope("window")` and takes no options record,
   so we need an element-scoped one that can pass `{once: true}`. */
type eventListenerOptions = {once: bool}
@send
external addElementEventListener: (Dom.element, string, 'ev => unit, eventListenerOptions) => unit =
  "addEventListener"
@send
external elementQuerySelector: (Dom.element, string) => Nullable.t<Dom.element> = "querySelector"
@send external setStyleProperty: (Window.style, string, string) => unit = "setProperty"
@send
external setStylePropertyImportant: (Window.style, string, string, string) => unit = "setProperty"

type mutationObserver
type mutationObserverInit = {childList: bool, subtree: bool}
@new
external makeMutationObserver: ((JSON.t, mutationObserver) => unit) => mutationObserver =
  "MutationObserver"
@send
external observeMutations: (mutationObserver, Dom.element, mutationObserverInit) => unit = "observe"
@send external disconnectObserver: mutationObserver => unit = "disconnect"

@set external setErrorCode: (Error.t, string) => unit = "code"
@set external setErrorEnvelope: (Error.t, JSON.t) => unit = "envelope"

let makeBrokerError = (~code: string, ~message: string): exn => {
  let envelope = Dict.make()
  envelope->Dict.set("code", code->JSON.Encode.string)
  envelope->Dict.set("message", message->JSON.Encode.string)
  let error = Error.make(message)
  error->setErrorCode(code)
  error->setErrorEnvelope(envelope->JSON.Encode.object)
  error->Error.toException
}

/* a JS `Error` does not expose `.message` through `JSON.stringify`, so read it off the
   exception directly. */
let exceptionMessage = (exn: exn): string =>
  exn
  ->JsExn.fromException
  ->Option.flatMap(JsExn.message)
  ->getNonEmptyOption
  ->Option.getOr("unknown")

type scriptState =
  | Loading
  | Ready
  | Failed

type fieldEntry = {
  fieldType: string,
  selector: string,
  options: JSON.t,
  fieldHandle: option<JSON.t>,
}

type vgsBrokerHandle = {
  formRef: ref<option<JSON.t>>,
  scriptStateRef: ref<scriptState>,
  fieldsRef: ref<Dict.t<fieldEntry>>,
  ensureReady: unit => promise<unit>,
  submitForm: unit => promise<JSON.t>,
  mountField: (
    ~fieldId: string,
    ~fieldType: string,
    ~selector: string,
    ~options: JSON.t,
  ) => promise<unit>,
  updateField: (~fieldId: string, ~options: JSON.t) => unit,
  unmountField: (~fieldId: string) => unit,
  unmountAll: unit => unit,
}

/* detects VGS by sniffing the credentials blob for the VGS-specific `vaultId` and
   `environment` keys, avoiding a second round-trip through the sessions JSON. */
let isVGSProvider = (vaultCredentials: JSON.t): bool => {
  if vaultCredentials === JSON.Encode.null {
    false
  } else {
    let dict = vaultCredentials->getDictFromJson
    dict->Dict.get("vaultId")->Option.isSome && dict->Dict.get("environment")->Option.isSome
  }
}

/* marker-attribute dedupe so concurrent mountField() calls collapse onto a single append.
   Deliberately a different marker from the React hook path's `data-status`. */
let scriptMarkerAttribute = "data-vgs-script-loaded"
let scriptSelector = `script[${scriptMarkerAttribute}]`

/* concurrent `mountField()` calls share ONE `loadVGSScript()` promise: each attaching its
   own `@set elementOnload` would race-overwrite the others (`@set` replaces, not chains) and
   strand every caller but the last. Stale once the script element leaves document.head. */
let inFlightScriptPromise: ref<option<Promise.t<unit>>> = ref(None)

let scriptElementStillPresent = (): bool =>
  Window.querySelector(scriptSelector)->Nullable.toOption->Option.isSome

let loadVGSScript = (): Promise.t<unit> => {
  /* drop a stale memoized promise when a previous deinit() removed the script element;
     checked against the DOM because the broker itself may have been recreated. */
  switch (inFlightScriptPromise.contents, scriptElementStillPresent()) {
  | (Some(_), false) => inFlightScriptPromise := None
  | _ => ()
  }
  switch inFlightScriptPromise.contents {
  | Some(scriptLoadPromise) => scriptLoadPromise
  | None =>
    let scriptLoadPromise = Promise.make((resolve, reject) => {
      switch Window.querySelector(scriptSelector)->Nullable.toOption {
      | Some(existing) =>
        switch existing->Window.getAttribute(scriptMarkerAttribute)->Nullable.toOption {
        | Some("loaded") => resolve()
        | Some("error") =>
          // Prior attempt errored; clean up the marker so a retry re-appends.
          existing->Window.remove
          inFlightScriptPromise := None
          reject(Error.make("vgs-collect previously failed to load")->Error.toException)
        | _ =>
          /* mid-flight: attach via addEventListener so we do not clobber another attacher's
             `@set elementOnload`; `{once: true}` removes it again. */
          existing->addElementEventListener(
            "load",
            _ => {
              existing->Window.setAttribute(scriptMarkerAttribute, "loaded")
              resolve()
            },
            {once: true},
          )
          existing->addElementEventListener(
            "error",
            (err: exn) => {
              existing->Window.setAttribute(scriptMarkerAttribute, "error")
              existing->Window.remove
              inFlightScriptPromise := None
              reject(err)
            },
            {once: true},
          )
        }
      | None =>
        let script = Window.createElement("script")
        script->Window.elementSrc(VGSConstants.vgsScriptURL)
        /* SRI: pin the fetched payload to the VGSConstants hash. `crossorigin="anonymous"` is
           required for SRI on a cross-origin script — without it the browser skips the check.
           A payload that does not match is refused outright: fail-closed. */
        script->Window.setAttribute("integrity", VGSConstants.vgsScriptIntegrity)
        script->Window.setAttribute("crossorigin", "anonymous")
        script->Window.setAttribute("async", "true")
        script->Window.setAttribute(scriptMarkerAttribute, "loading")
        script->Window.elementOnload(() => {
          script->Window.setAttribute(scriptMarkerAttribute, "loaded")
          resolve()
        })
        script->Window.elementOnerror(err => {
          script->Window.setAttribute(scriptMarkerAttribute, "error")
          inFlightScriptPromise := None
          reject(err)
        })
        let _ = Window.head->Window.appendChildElement(script)
      }
    })
    inFlightScriptPromise := Some(scriptLoadPromise)
    scriptLoadPromise
  }
}

/* maps the field-type string plus merchant options onto the canonical `VGSConstants`
   builders. Brokers carry no locale, so a localized expiry placeholder must be passed in. */
let computeVGSBaseOptions = (~fieldType: string, ~options: JSON.t): JSON.t => {
  let optionsDict = options->getDictFromJson
  switch fieldType {
  | "cardNumber" => VGSConstants.cardNumberOptions->Identity.anyTypeToJson
  | "cardExpiry" =>
    let placeholder = optionsDict->getString("placeholder", "MM / YY")
    VGSConstants.cardExpiryOptions(placeholder)->Identity.anyTypeToJson
  | "cardCvc" =>
    let savedCardDict = optionsDict->getDictFromDict("savedCard")
    let savedCardBrand = savedCardDict->getString("brand", "")
    if savedCardBrand->String.length > 0 {
      /* merchants supply the lowercase scheme ("amex") but getobjFromCardPattern keys on the
         display name ("AmericanExpress") — normalize through the same helper the React path uses. */
      let normalizedBrand = CardUtils.normalizeCardBrand(savedCardBrand)
      VGSConstants.savedCardCvcOptions(normalizedBrand)->Identity.anyTypeToJson
    } else {
      VGSConstants.cardCvcOptions->Identity.anyTypeToJson
    }
  | _ =>
    VGSConstants.cardNumberOptions->Identity.anyTypeToJson
  }
}

/* allowlist of VGS field-option keys a merchant may override per field; per-field values
   win over the VGSConstants defaults. Deliberately EXCLUDED:
   type / name — `name` IS the VGS alias key `VGSHelpers.getTokenizedData` reads, so
   renaming it silently breaks tokenization mapping.
   validations — replacing would drop "required" and the saved-card brand-length regexes.
   serializers — rewrites the submitted alias shape and breaks the "MM / YY" expiry split. */
let merchantOverridableStringKeys = [
  "placeholder",
  "successColor",
  "errorColor",
  "ariaLabel",
  "autoComplete",
  "inputMode",
  "defaultValue",
]
let merchantOverridableBoolKeys = ["showCardIcon", "disabled", "readOnly", "hideValue"]

let applyMerchantOptionOverrides = (~basis: JSON.t, ~options: JSON.t): JSON.t => {
  let basisDict = basis->getDictFromJson
  let optionsDict = options->getDictFromJson
  merchantOverridableStringKeys->Array.forEach(key => {
    switch optionsDict->getOptionString(key)->getNonEmptyOption {
    | Some(value) => basisDict->Dict.set(key, value->JSON.Encode.string)
    | None => ()
    }
  })
  merchantOverridableBoolKeys->Array.forEach(key => {
    switch optionsDict->getOptionBool(key) {
    | Some(value) => basisDict->Dict.set(key, value->JSON.Encode.bool)
    | None => ()
    }
  })
  // JSON numbers decode as float; VGS expects an int.
  switch optionsDict->Dict.get("yearLength")->Option.flatMap(JSON.Decode.float) {
  | Some(value) => basisDict->Dict.set("yearLength", value->Float.toInt->JSON.Encode.int)
  | None => ()
  }
  // keywise merge so merchant css keys win rather than replacing the default wholesale.
  let merchantCss = optionsDict->getDictFromDict("css")
  if merchantCss->Dict.keysToArray->Array.length > 0 {
    let mergedCss = basisDict->getDictFromDict("css")
    merchantCss->Dict.toArray->Array.forEach(((key, value)) => mergedCss->Dict.set(key, value))
    basisDict->Dict.set("css", mergedCss->JSON.Encode.object)
  }
  basisDict->JSON.Encode.object
}

let computeFieldOptions = (~fieldType: string, ~options: JSON.t): JSON.t => {
  let basis = computeVGSBaseOptions(~fieldType, ~options)
  applyMerchantOptionOverrides(~basis, ~options)
}

/* same frozen-option exclusions as the mount path: the intersection of VGSCollect's
   `field.update` keys and our mount-time allowlist. Mount-only keys (successColor,
   errorColor, inputMode, defaultValue, yearLength) are post-create no-ops to VGS. */
let vgsFieldUpdateAllowedKeys = [
  "placeholder",
  "ariaLabel",
  "autoComplete",
  "css",
  "hideValue",
  "disabled",
  "readOnly",
  "showCardIcon",
]
let filterFieldUpdateOptions = (~options: JSON.t): JSON.t => {
  let optionsDict = options->getDictFromJson
  let filtered = Dict.make()
  vgsFieldUpdateAllowedKeys->Array.forEach(key => {
    switch optionsDict->Dict.get(key) {
    | Some(value) => filtered->Dict.set(key, value)
    | None => ()
    }
  })
  filtered->JSON.Encode.object
}

/* normalizes VGS's per-event state into the merchant-facing envelope, the same shape the
   Hyperswitch `change` channel emits. `complete` is computed as (!empty && valid). */
let buildFieldEventPayload = (~fieldType: string, ~state: JSON.t): JSON.t => {
  let stateDict = state->getDictFromJson
  let empty = stateDict->getBool("isEmpty", true)
  let valid = stateDict->getBool("isValid", false)
  let errorMessage = stateDict->getString("error", "")
  let brand = stateDict->getString("cardBrand", "")
  let brand = if brand === "" {
    stateDict->getString("cardType", "")
  } else {
    brand
  }
  let payloadDict = Dict.make()
  payloadDict->Dict.set("empty", empty->JSON.Encode.bool)
  payloadDict->Dict.set("complete", (!empty && valid)->JSON.Encode.bool)
  payloadDict->Dict.set("valid", valid->JSON.Encode.bool)
  payloadDict->Dict.set("elementType", fieldType->JSON.Encode.string)
  if brand !== "" {
    payloadDict->Dict.set("brand", brand->JSON.Encode.string)
  }
  if errorMessage !== "" {
    payloadDict->Dict.set("error", errorMessage->JSON.Encode.string)
  }
  payloadDict->JSON.Encode.object
}

let eventKey = (~fieldId: string, ~event: string): string => `${fieldId}::${event}`

let dispatchFieldEvent = (
  ~eventCallbacksRef: ref<Dict.t<JSON.t => unit>>,
  ~fieldId: string,
  ~event: string,
  ~payload: JSON.t,
): unit => {
  eventCallbacksRef.contents
  ->Dict.get(eventKey(~fieldId, ~event))
  ->Option.forEach(cb => cb(payload))
}

let make = (
  ~pmSessionId: string,
  ~vaultId: string,
  ~environment: string,
  ~eventCallbacksRef: ref<Dict.t<JSON.t => unit>>,
): vgsBrokerHandle => {
  let formRef: ref<option<JSON.t>> = ref(None)
  let scriptStateRef: ref<scriptState> = ref(Loading)
  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  let createFormInFlightRef: ref<option<promise<JSON.t>>> = ref(None)

  let createForm = (): promise<JSON.t> =>
    switch formRef.contents {
    | Some(form) => Promise.resolve(form)
    | None =>
      /* without this memoization three parallel `create(...).mount(...)` calls enqueue three
         separate `VGSCollect.create(...)` invocations; only the last formRef survives while the
         earlier forms still own their iframes, giving triple-mounted fields. */
      switch createFormInFlightRef.contents {
      | Some(createFormPromise) => createFormPromise
      | None =>
        let createFormPromise =
          loadVGSScript()
          ->Promise.then(_ => {
            let onError: JSON.t => unit = errJson => {
              Console.error2("[VGSVaultBroker] VGSCollect form-level error", errJson)
            }
            let form: JSON.t = switch vgsCollect->Nullable.toOption {
            | Some(collect) => collect.create(vaultId, environment, onError)
            | None =>
              Error.raise(Error.make("VGSCollect script failed to register window.VGSCollect"))
            }
            formRef := Some(form)
            scriptStateRef := Ready
            Promise.resolve(form)
          })
          ->Promise.catch(err => {
            scriptStateRef := Failed
            createFormInFlightRef := None
            Promise.reject(err)
          })
        createFormInFlightRef := Some(createFormPromise)
        createFormPromise
      }
    }

  let ensureReady = (): promise<unit> => createForm()->Promise.then(_ => Promise.resolve())

  /* single network round-trip; never rejects — the group maps a resolved "error" envelope
     into the public Failure union. `card_exp_month` and `card_exp_year` come from splitting
     VGS's combined `card_exp` alias. `vgs_form_not_ready` is a broker preflight failure that
     downstream callers treat exactly like `tokenization_failed`. */
  let submitForm = (): promise<JSON.t> => {
    switch formRef.contents {
    | None =>
      let errorDict = Dict.make()
      errorDict->Dict.set("code", "vgs_form_not_ready"->JSON.Encode.string)
      errorDict->Dict.set("message", "VGS form not initialized"->JSON.Encode.string)
      let resultDict = Dict.make()
      resultDict->Dict.set("status", "error"->JSON.Encode.string)
      resultDict->Dict.set("error", errorDict->JSON.Encode.object)
      Promise.resolve(resultDict->JSON.Encode.object)
    | Some(form) =>
      Promise.make((resolve, _reject) => {
        let onSuccess: (int, JSON.t) => unit = (_status, data) => {
          let (cardNumber, expMonth, expYear, cardCvc) = VGSHelpers.getTokenizedData(data)
          let resultDict = Dict.make()
          resultDict->Dict.set("status", "success"->JSON.Encode.string)
          resultDict->Dict.set("card_number", cardNumber->JSON.Encode.string)
          resultDict->Dict.set("card_exp_month", expMonth->JSON.Encode.string)
          resultDict->Dict.set("card_exp_year", expYear->JSON.Encode.string)
          resultDict->Dict.set("card_cvc", cardCvc->JSON.Encode.string)
          resolve(resultDict->JSON.Encode.object)
        }
        let onError: (int, JSON.t) => unit = (_status, errors) => {
          /* VGS's onError payload is a per-field errors map squashed to one string; guard the
             stringify against a non-serializable payload rather than throwing back into VGS. */
          let messageStr: string = {
            let jsonStr = try errors->JSON.stringify catch {
            | _ => "unknown"
            }
            if jsonStr->String.length > 0 {
              jsonStr
            } else {
              "VGS submit failed"
            }
          }
          let errorDict = Dict.make()
          errorDict->Dict.set("code", "tokenization_failed"->JSON.Encode.string)
          errorDict->Dict.set("message", messageStr->JSON.Encode.string)
          errorDict->Dict.set("type", "api_error"->JSON.Encode.string)
          let resultDict = Dict.make()
          resultDict->Dict.set("status", "error"->JSON.Encode.string)
          resultDict->Dict.set("error", errorDict->JSON.Encode.object)
          resolve(resultDict->JSON.Encode.object)
        }
        let emptyPayload = JSON.Encode.object(Dict.make())
        try {
          form->formSubmit("/post", emptyPayload, onSuccess, onError)
        } catch {
        | exn =>
          // synchronous throw out of form.submit() (e.g. a blocking extension) — same envelope.
          let messageStr = exn->exceptionMessage
          let errorDict = Dict.make()
          errorDict->Dict.set("code", "tokenization_failed"->JSON.Encode.string)
          errorDict->Dict.set("message", messageStr->JSON.Encode.string)
          errorDict->Dict.set("type", "api_error"->JSON.Encode.string)
          let resultDict = Dict.make()
          resultDict->Dict.set("status", "error"->JSON.Encode.string)
          resultDict->Dict.set("error", errorDict->JSON.Encode.object)
          resolve(resultDict->JSON.Encode.object)
        }
      })
    }
  }

  /* injects the VGS secure iframe at the merchant selector, wires per-field events into
     `eventCallbacksRef`, and rejects with a `{code, message}` envelope — merchants never see
     a mount-time throw on the public API. */
  let mountField = (
    ~fieldId: string,
    ~fieldType: string,
    ~selector: string,
    ~options: JSON.t,
  ): promise<unit> => {
    ensureReady()
    ->Promise.then(_ => {
      switch formRef.contents {
      | None =>
        Promise.reject(
          makeBrokerError(
            ~code="vgs_form_not_ready",
            ~message="VGS form not initialized after ensureReady()",
          ),
        )
      | Some(form) =>
        let computedOptions = computeFieldOptions(~fieldType, ~options)

        /* cardFieldHeight sizing. VGS's injected iframe defaults to 150x300px and ignores both the
           container height and any css={} we pass (that styles the INNER input only). So: size the
           MERCHANT'S container inline (no !important, so merchant CSS still wins), then force the
           injected iframe to 100% !important once it appears. */
        let cardFieldHeight =
          options
          ->getDictFromJson
          ->getDictFromDict("appearance")
          ->getDictFromDict("variables")
          ->getString("cardFieldHeight", "48px")
          ->String.trim
        // refuse malformed values — a stray "null" string would be a confusing no-op.
        let cardFieldHeight = if cardFieldHeight == "" || cardFieldHeight == "null" {
          Console.warn2(
            `[VGSVaultBroker] appearance.variables.cardFieldHeight was empty/"null"; falling back to 48px`,
            options,
          )
          "48px"
        } else {
          cardFieldHeight
        }

        // inline height, no !important, so merchant CSS with higher specificity still wins.
        try {
          Window.querySelector(selector)
          ->Nullable.toOption
          ->Option.forEach(el => {
            let elementStyle = el->Window.style
            elementStyle->setStyleProperty("height", cardFieldHeight)
            elementStyle->setStyleProperty("width", "100%")
          })
        } catch {
        | _ => ()
        }

        let fieldHandle: JSON.t = try {
          form->formField(selector, computedOptions)
        } catch {
        | exn =>
          throw(
            makeBrokerError(
              ~code="vgs_mount_failed",
              ~message=`form.field("${selector}") threw: ${exn->exceptionMessage}`,
            ),
          )
        }

        /* force the injected iframe to fill its container: VGS's own sheet sets 150x300px inline,
           so !important is required. Injection may be sync or async, so do an immediate pass AND a
           MutationObserver; the observer disconnects on first success or after 5s. */
        try {
          switch Window.querySelector(selector)->Nullable.toOption {
          | None => ()
          | Some(container) =>
            let styleIframe = (): bool =>
              switch container->elementQuerySelector("iframe")->Nullable.toOption {
              | Some(iframe) =>
                let iframeStyle = iframe->Window.style
                iframeStyle->setStylePropertyImportant("width", "100%", "important")
                iframeStyle->setStylePropertyImportant("height", "100%", "important")
                iframeStyle->setStylePropertyImportant("display", "block", "important")
                true
              | None => false
              }

            if !styleIframe() {
              let observer = makeMutationObserver((_mutations, observer) =>
                if styleIframe() {
                  observer->disconnectObserver
                }
              )
              observer->observeMutations(container, {childList: true, subtree: false})
              let _ = setTimeout(() => observer->disconnectObserver, 5000)
            }
          }
        } catch {
        | _ => ()
        }

        fieldsRef.contents->Dict.set(
          fieldId,
          {fieldType, selector, options, fieldHandle: Some(fieldHandle)},
        )

        let wireEvent = (event: string): unit => {
          try {
            let handleFieldEvent: JSON.t => unit = state => {
              let payload = buildFieldEventPayload(~fieldType, ~state)
              dispatchFieldEvent(~eventCallbacksRef, ~fieldId, ~event, ~payload)
            }
            fieldHandle->fieldOn(event, handleFieldEvent)
          } catch {
          | exn =>
            Console.error2(
              `[VGSVaultBroker] failed to wire field.on("${event}") for fieldId=${fieldId}`,
              exn->Identity.anyTypeToJson,
            )
          }
        }
        wireEvent("change")
        wireEvent("focus")
        wireEvent("blur")
        wireEvent("ready")

        Promise.resolve()
      }
    })
    ->Promise.catch(err => {
      Console.error2(
        `[VGSVaultBroker] mountField(${fieldType}, ${selector}) failed`,
        err->Identity.anyTypeToJson,
      )
      Promise.reject(err)
    })
  }

  let updateField = (~fieldId: string, ~options: JSON.t): unit => {
    switch fieldsRef.contents->Dict.get(fieldId) {
    | Some({fieldHandle: Some(vgsFieldHandle)}) =>
      try {
        /* route through the intersection filter, not the raw bag: a raw type, name, validations
           or serializers key would reach VGSCollect and bypass the mount-path exclusions. */
        let filteredOptions = filterFieldUpdateOptions(~options)
        switch vgsFieldHandle->fieldUpdateHandler->Nullable.toOption {
        | Some(_) => vgsFieldHandle->fieldUpdate(filteredOptions)
        | None => ()
        }
      } catch {
      | exn =>
        Console.error2(
          `[VGSVaultBroker] updateField(${fieldId}) threw`,
          exn->Identity.anyTypeToJson,
        )
      }
    | _ => ()
    }
  }

  // prefer VGS's `field.delete()`; fall back to clearing the container's innerHTML.
  let unmountField = (~fieldId: string): unit => {
    switch fieldsRef.contents->Dict.get(fieldId) {
    | Some({fieldHandle: Some(vgsFieldHandle), selector}) =>
      try {
        let deleted = switch vgsFieldHandle->fieldDeleteHandler->Nullable.toOption {
        | Some(_) =>
          try {
            vgsFieldHandle->fieldDelete
            true
          } catch {
          | _ => false
          }
        | None => false
        }
        if !deleted {
          Window.querySelector(selector)
          ->Nullable.toOption
          ->Option.forEach(el => el->Window.innerHTML(""))
        }
      } catch {
      | exn =>
        Console.error2(
          `[VGSVaultBroker] unmountField(${fieldId}) threw`,
          exn->Identity.anyTypeToJson,
        )
      }
      fieldsRef.contents->Dict.set(
        fieldId,
        {
          fieldType: "",
          selector: "",
          options: JSON.Encode.null,
          fieldHandle: None,
        },
      )
    | _ => ()
    }
  }

  let unmountAll = (): unit => {
    fieldsRef.contents
    ->Dict.keysToArray
    ->Array.forEach(fieldId => {
      unmountField(~fieldId)
    })
    fieldsRef := Dict.make()
  }

  {
    formRef,
    scriptStateRef,
    fieldsRef,
    ensureReady,
    submitForm,
    mountField,
    updateField,
    unmountField,
    unmountAll,
  }
}
