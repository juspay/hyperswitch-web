open Utils

type vgsCollectGlobal = {create: (string, string, JSON.t => unit) => JSON.t}
@val @scope("window") external vgsCollect: Nullable.t<vgsCollectGlobal> = "VGSCollect"

@send external formField: (JSON.t, string, JSON.t) => JSON.t = "field"
// `submit` is deliberately not bound here — `VGSTypes.returnValue` already describes it.
@send external fieldOn: (JSON.t, string, JSON.t => unit) => unit = "on"
@send external fieldUpdate: (JSON.t, JSON.t) => unit = "update"
@send external fieldDelete: JSON.t => unit = "delete"
@get external fieldUpdateHandler: JSON.t => Nullable.t<JSON.t => unit> = "update"
@get external fieldDeleteHandler: JSON.t => Nullable.t<unit => unit> = "delete"

// `JSON.stringify` really returns `undefined` for `undefined`, functions and symbols.
@val @scope("JSON") external stringifyNullable: JSON.t => Nullable.t<string> = "stringify"

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

@get external exceptionCode: JsExn.t => Nullable.t<JSON.t> = "code"

let exceptionCodeOr = (exn: exn, ~fallback: string): string =>
  exn
  ->JsExn.fromException
  ->Option.flatMap(jsExn => jsExn->exceptionCode->Nullable.toOption)
  ->Option.flatMap(JSON.Decode.string)
  ->getNonEmptyOption
  ->Option.getOr(fallback)

let makeErrorEnvelope = (~code: string, ~message: string, ~errorType: string): JSON.t => {
  let errorDict = Dict.make()
  errorDict->Dict.set("code", code->JSON.Encode.string)
  errorDict->Dict.set("message", message->JSON.Encode.string)
  errorDict->Dict.set("type", errorType->JSON.Encode.string)
  let resultDict = Dict.make()
  resultDict->Dict.set("error", errorDict->JSON.Encode.object)
  resultDict->JSON.Encode.object
}

let vgsFieldErrorMessage = (fieldState: JSON.t): option<string> => {
  let stateDict = fieldState->getDictFromJson
  let firstNonEmpty = messages => messages->Array.find(message => message->String.length > 0)
  let fromErrorMessages =
    stateDict
    ->Dict.get("errorMessages")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.getOr([])
    ->Array.filterMap(JSON.Decode.string)
    ->firstNonEmpty
  switch fromErrorMessages {
  | Some(_) as found => found
  | None =>
    stateDict
    ->Dict.get("errors")
    ->Option.flatMap(JSON.Decode.array)
    ->Option.getOr([])
    ->Array.filterMap(error => error->getDictFromJson->getOptionString("message"))
    ->firstNonEmpty
  }
}

let describeVGSSubmitErrors = (errors: JSON.t): option<string> => {
  let described =
    errors
    ->getDictFromJson
    ->Dict.toArray
    ->Array.filterMap(((fieldName, fieldState)) =>
      fieldState->vgsFieldErrorMessage->Option.map(message => `${fieldName} ${message}`)
    )
  described->Array.length > 0 ? Some(described->Array.join(", ")) : None
}

let describeInvalidField = (~state: option<JSON.t>): option<string> =>
  switch state {
  | None => Some("is required")
  | Some(fieldState) =>
    let stateDict = fieldState->getDictFromJson
    if stateDict->getBool("isEmpty", true) {
      Some(fieldState->vgsFieldErrorMessage->Option.getOr("is required"))
    } else if !(stateDict->getBool("isValid", false)) {
      Some(fieldState->vgsFieldErrorMessage->Option.getOr("is invalid"))
    } else {
      None
    }
  }

let httpStatusCode = (status: JSON.t): option<float> =>
  switch status->JSON.Decode.float {
  | Some(_) as code => code
  | None => status->JSON.Decode.string->Option.flatMap(Float.fromString)
  }

let describeJson = (value: JSON.t): string =>
  switch value->JSON.Decode.string->getNonEmptyOption {
  | Some(text) => text
  | None => value->stringifyNullable->Nullable.toOption->getNonEmptyOption->Option.getOr("null")
  }

let emitBrokerError = (
  ~eventCallbacksRef: ref<Dict.t<JSON.t => unit>>,
  ~code: string,
  ~message: string,
): unit =>
  eventCallbacksRef.contents
  ->Dict.get("error")
  ->Option.forEach(cb =>
    try cb(makeErrorEnvelope(~code, ~message, ~errorType="api_error")) catch {
    | exn =>
      Console.error2(
        `[VGSVaultBroker] merchant on("error") handler threw`,
        exn->Identity.anyTypeToJson,
      )
    }
  )

type fieldEntry = {
  fieldType: string,
  vgsName: string,
  selector: string,
  fieldHandle: option<JSON.t>,
}

type vgsBrokerHandle = {
  formRef: ref<option<JSON.t>>,
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

// `computeVGSBaseOptions` hands back shared module constants, so copy before writing.
let applyMerchantOptionOverrides = (~basis: JSON.t, ~options: JSON.t): JSON.t => {
  let basisDict = basis->getDictFromJson->Dict.copy
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
    let mergedCss = basisDict->getDictFromDict("css")->Dict.copy
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
  let errorMessage = switch stateDict->getOptionString("error")->getNonEmptyOption {
  | Some(message) => message
  | None => state->vgsFieldErrorMessage->Option.getOr("")
  }
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

let fieldFingerprint = (payload: JSON.t): string =>
  payload->stringifyNullable->Nullable.toOption->Option.getOr("")

let dispatchFieldEvent = (
  ~eventCallbacksRef: ref<Dict.t<JSON.t => unit>>,
  ~fieldId: string,
  ~event: string,
  ~payload: JSON.t,
): unit => {
  eventCallbacksRef.contents
  ->Dict.get(eventKey(~fieldId, ~event))
  ->Option.forEach(cb =>
    try cb(payload) catch {
    | exn =>
      Console.error2(
        `[VGSVaultBroker] merchant on("${event}") handler threw`,
        exn->Identity.anyTypeToJson,
      )
    }
  )
}

let make = (
  ~vaultId: string,
  ~environment: string,
  ~eventCallbacksRef: ref<Dict.t<JSON.t => unit>>,
): vgsBrokerHandle => {
  let formRef: ref<option<JSON.t>> = ref(None)
  let fieldsRef: ref<Dict.t<fieldEntry>> = ref(Dict.make())
  let createFormInFlightRef: ref<option<promise<JSON.t>>> = ref(None)
  let formStateRef: ref<Dict.t<JSON.t>> = ref(Dict.make())
  let lastFieldPayloadRef: ref<Dict.t<string>> = ref(Dict.make())

  let fieldPayload = (~fieldType: string, ~vgsName: string): JSON.t =>
    buildFieldEventPayload(
      ~fieldType,
      ~state=formStateRef.contents
      ->Dict.get(vgsName)
      ->Option.getOr(JSON.Encode.object(Dict.make())),
    )

  let publishFieldStates = (): unit =>
    fieldsRef.contents
    ->Dict.toArray
    ->Array.forEach(((fieldId, {fieldType, vgsName, fieldHandle})) =>
      switch fieldHandle {
      | None => ()
      | Some(_) =>
        let payload = fieldPayload(~fieldType, ~vgsName)
        let fingerprint = payload->fieldFingerprint
        let changed = switch lastFieldPayloadRef.contents->Dict.get(fieldId) {
        | Some(previous) => previous !== fingerprint
        | None => true
        }
        if changed {
          lastFieldPayloadRef.contents->Dict.set(fieldId, fingerprint)
          dispatchFieldEvent(~eventCallbacksRef, ~fieldId, ~event="change", ~payload)
        }
      }
    )

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
            // VGS's 3rd `create` arg is the form-level state channel, not an error channel.
            let onFormStateChange: JSON.t => unit = state => {
              formStateRef := state->getDictFromJson
              publishFieldStates()
            }
            let form: JSON.t = switch vgsCollect->Nullable.toOption {
            | Some(collect) => collect.create(vaultId, environment, onFormStateChange)
            | None =>
              Error.raise(Error.make("VGSCollect script failed to register window.VGSCollect"))
            }
            formRef := Some(form)
            Promise.resolve(form)
          })
          ->Promise.catch(err => {
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
      Promise.resolve(
        makeErrorEnvelope(
          ~code="vgs_form_not_ready",
          ~message="VGS form not initialized",
          ~errorType="api_error",
        ),
      )
    | Some(form) =>
      let validationErrors = Dict.make()
      fieldsRef.contents
      ->Dict.valuesToArray
      ->Array.forEach(({fieldType, vgsName, fieldHandle}) =>
        switch fieldHandle {
        | None => ()
        | Some(_) =>
          describeInvalidField(~state=formStateRef.contents->Dict.get(vgsName))->Option.forEach(
            message => {
              let fieldErrors = Dict.make()
              fieldErrors->Dict.set(
                "errorMessages",
                [message->JSON.Encode.string]->JSON.Encode.array,
              )
              validationErrors->Dict.set(fieldType, fieldErrors->JSON.Encode.object)
            },
          )
        }
      )
      if validationErrors->Dict.keysToArray->Array.length > 0 {
        Promise.resolve(
          makeErrorEnvelope(
            ~code="validation_error",
            ~message=validationErrors
            ->JSON.Encode.object
            ->describeVGSSubmitErrors
            ->Option.getOr("Validation failed for one or more fields"),
            ~errorType="validation_error",
          ),
        )
      } else {
        Promise.make((resolve, _reject) => {
          let vgsForm = form->VGSTypes.formFromJson
          let settleWithFailure = (message: string) =>
            resolve(
              makeErrorEnvelope(~code="tokenization_failed", ~message, ~errorType="api_error"),
            )
          // VGS routes a transport failure through this SUCCESS callback as (status=null, data="Network Error").
          let onSuccess: (JSON.t, JSON.t) => unit = (status, data) => {
            switch (status->httpStatusCode, data->JSON.Decode.object) {
            | (Some(code), Some(vaultResponse)) if code >= 200. && code < 300. =>
              let resultDict = Dict.make()
              resultDict->Dict.set("status", "success"->JSON.Encode.string)
              resultDict->Dict.set("vaultResponse", vaultResponse->JSON.Encode.object)
              resolve(resultDict->JSON.Encode.object)
            | _ =>
              settleWithFailure(
                `VGS returned no tokenization response (status ${status->describeJson}): ${data->describeJson}`,
              )
            }
          }
          // VGS calls the submit error callback with ONE argument: the per-field error map.
          let onError: JSON.t => unit = errors => {
            let stringified = try errors->stringifyNullable->Nullable.toOption catch {
            | _ => None
            }
            settleWithFailure(
              switch errors->describeVGSSubmitErrors {
              | Some(readable) => readable
              | None => stringified->getNonEmptyOption->Option.getOr("VGS submit failed")
              },
            )
          }
          let emptyPayload = JSON.Encode.object(Dict.make())
          try {
            let submitReturn =
              vgsForm->VGSTypes.submitReturningValue("/post", emptyPayload, onSuccess, onError)
            // VGS *rejects* this when the fields aren't loaded yet; unadopted, this promise never settles.
            Promise.resolve(submitReturn)
            ->Promise.catch(exn => {
              settleWithFailure(`VGS submit rejected: ${exn->exceptionMessage}`)
              Promise.resolve(JSON.Encode.null)
            })
            ->ignore
          } catch {
          | exn => settleWithFailure(exn->exceptionMessage)
          }
        })
      }
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
        let vgsName = computedOptions->getDictFromJson->getString("name", "")

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
          {fieldType, vgsName, selector, fieldHandle: Some(fieldHandle)},
        )

        let wireEvent = (event: string): unit => {
          try {
            let handleFieldEvent: JSON.t => unit = _domEvent => {
              let payload = fieldPayload(~fieldType, ~vgsName)
              dispatchFieldEvent(~eventCallbacksRef, ~fieldId, ~event, ~payload)
            }
            fieldHandle->fieldOn(event, handleFieldEvent)
          } catch {
          | exn =>
            let message = `field.on("${event}") could not be wired for fieldId=${fieldId} — ${event} events will never fire: ${exn->exceptionMessage}`
            Console.error2(`[VGSVaultBroker] ${message}`, exn->Identity.anyTypeToJson)
            emitBrokerError(
              ~eventCallbacksRef,
              ~code="vgs_field_event_binding_failed",
              ~message,
            )
          }
        }
        wireEvent("focus")
        wireEvent("blur")

        let readyPayload = fieldPayload(~fieldType, ~vgsName)
        lastFieldPayloadRef.contents->Dict.set(fieldId, readyPayload->fieldFingerprint)
        dispatchFieldEvent(~eventCallbacksRef, ~fieldId, ~event="ready", ~payload=readyPayload)

        Promise.resolve()
      }
    })
    ->Promise.catch(err => {
      let message = `mountField(${fieldType}, ${selector}) failed: ${err->exceptionMessage}`
      Console.error2(`[VGSVaultBroker] ${message}`, err->Identity.anyTypeToJson)
      emitBrokerError(
        ~eventCallbacksRef,
        ~code=err->exceptionCodeOr(~fallback="vgs_mount_failed"),
        ~message,
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
        let message = `updateField(${fieldId}) threw — the requested options were not applied: ${exn->exceptionMessage}`
        Console.error2(`[VGSVaultBroker] ${message}`, exn->Identity.anyTypeToJson)
        emitBrokerError(~eventCallbacksRef, ~code="vgs_field_update_failed", ~message)
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
        let message = `unmountField(${fieldId}) threw — the secure field may still be in the DOM: ${exn->exceptionMessage}`
        Console.error2(`[VGSVaultBroker] ${message}`, exn->Identity.anyTypeToJson)
        emitBrokerError(~eventCallbacksRef, ~code="vgs_field_unmount_failed", ~message)
      }
      lastFieldPayloadRef.contents->Dict.delete(fieldId)
      fieldsRef.contents->Dict.set(
        fieldId,
        {
          fieldType: "",
          vgsName: "",
          selector: "",
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
    fieldsRef,
    ensureReady,
    submitForm,
    mountField,
    updateField,
    unmountField,
    unmountAll,
  }
}
