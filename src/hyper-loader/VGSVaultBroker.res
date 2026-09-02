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
@get external fieldUpdateHandler: JSON.t => Nullable.t<JSON.t => unit> = "update"
@get external fieldDeleteHandler: JSON.t => Nullable.t<unit => unit> = "delete"

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

let isVGSProvider = (vaultCredentials: JSON.t): bool => {
  if vaultCredentials === JSON.Encode.null {
    false
  } else {
    let dict = vaultCredentials->getDictFromJson
    dict->Dict.get("vaultId")->Option.isSome && dict->Dict.get("environment")->Option.isSome
  }
}

let scriptMarkerAttribute = "data-vgs-script-loaded"
let scriptSelector = `script[${scriptMarkerAttribute}]`

let inFlightScriptPromise: ref<option<Promise.t<unit>>> = ref(None)

let scriptElementStillPresent = (): bool =>
  Window.querySelector(scriptSelector)->Nullable.toOption->Option.isSome

let loadVGSScript = (): Promise.t<unit> => {
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
          existing->Window.remove
          inFlightScriptPromise := None
          reject(Error.make("vgs-collect previously failed to load")->Error.toException)
        | _ =>
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
      let normalizedBrand = CardUtils.normalizeCardBrand(savedCardBrand)
      VGSConstants.savedCardCvcOptions(normalizedBrand)->Identity.anyTypeToJson
    } else {
      VGSConstants.cardCvcOptions->Identity.anyTypeToJson
    }
  | _ =>
    VGSConstants.cardNumberOptions->Identity.anyTypeToJson
  }
}

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
  switch optionsDict->Dict.get("yearLength")->Option.flatMap(JSON.Decode.float) {
  | Some(value) => basisDict->Dict.set("yearLength", value->Float.toInt->JSON.Encode.int)
  | None => ()
  }
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
      switch createFormInFlightRef.contents {
      | Some(createFormPromise) => createFormPromise
      | None =>
        let createFormPromise =
          loadVGSScript()
          ->Promise.then(_ => {
            let onError: JSON.t => unit = errJson => {
              let reportingFields =
                errJson->getDictFromJson->Dict.keysToArray->Array.join(", ")
              Console.error(
                `[VGSVaultBroker] VGSCollect form-level error for field(s): ${reportingFields}`,
              )
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

        let cardFieldHeight =
          options
          ->getDictFromJson
          ->getDictFromDict("appearance")
          ->getDictFromDict("variables")
          ->getString("cardFieldHeight", "48px")
          ->String.trim
        let cardFieldHeight = if cardFieldHeight == "" || cardFieldHeight == "null" {
          Console.warn2(
            `[VGSVaultBroker] appearance.variables.cardFieldHeight was empty/"null"; falling back to 48px. Received:`,
            cardFieldHeight,
          )
          "48px"
        } else {
          cardFieldHeight
        }

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
