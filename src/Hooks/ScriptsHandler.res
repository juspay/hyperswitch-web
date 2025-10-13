open Promise
open Window

type scriptStatus = Idle | Loading | Ready | Error

type scriptAttrs = {
  async?: bool,
  defer?: bool,
  crossorigin?: string,
  integrity?: string,
  nomodule?: bool,
  referrerpolicy?: string,
  \"type"?: string,
}

type options = {
  checkForExisting?: bool,
  attrs?: Dict.t<scriptAttrs>,
  defaultAsync?: bool,
  unloadWhenNoSubscribers?: bool,
  ordered?: bool,
}

type entry = {
  mutable status: scriptStatus,
  mutable error: option<Dom.event>,
  mutable el: option<Dom.element>,
  mutable subscribers: array<scriptStatus => unit>,
  mutable promise: option<t<unit>>,
  mutable refCount: int,
  mutable onLoadHandler: option<Dom.event => unit>,
  mutable onErrorHandler: option<Dom.event => unit>,
}

type useScriptsResult<'a> = {
  statuses: Dict.t<scriptStatus>,
  errors: Dict.t<option<Dom.event>>,
  readyAll: bool,
  readyOf: string => bool,
  whenReady: 'a => t<unit>,
}

type useScriptResult = {
  status: scriptStatus,
  ready: bool,
  error: option<Dom.event>,
  whenReady: unit => t<unit>,
  readyOf: string => bool,
}

let store = Dict.make()

let getOrInitEntry = src => {
  switch store->Dict.get(src) {
  | Some(entry) => entry
  | None => {
      let entry = {
        status: Idle,
        error: None,
        el: None,
        subscribers: [],
        promise: None,
        refCount: 0,
        onLoadHandler: None,
        onErrorHandler: None,
      }
      store->Dict.set(src, entry)
      entry
    }
  }
}

let emit = (entry: entry, nextStatus) => {
  entry.status = nextStatus
  entry.subscribers->Array.forEach(subscriber => subscriber(nextStatus))
}

let markDataset = (script, status) => {
  try {
    let statusStr = switch status {
    | Idle => "idle"
    | Loading => "loading"
    | Ready => "ready"
    | Error => "error"
    }
    script->setAttribute("data-status", statusStr)
  } catch {
  | _ => ()
  }
}

let isLikelyAlreadyLoaded = (script, src) => {
  let readyState = script->elementReadyState->Nullable.toOption
  let datasetStatus = script->dataset->getDatasetStatus->Nullable.toOption

  if datasetStatus == Some("ready") {
    true
  } else {
    switch readyState {
    | Some("complete") | Some("loaded") => true
    | _ =>
      try {
        switch performance {
        | Some(_) => {
            let entries = getEntriesByName(src)
            let entriesLength = entries->Array.length
            let connected = script->isConnected
            let result = entriesLength > 0 && connected
            result
          }
        | None => false
        }
      } catch {
      | _ => false
      }
    }
  }
}

let applyScriptAttrs = (script, attrs) => {
  switch attrs {
  | None => ()
  | Some(attrs) => {
      attrs.async->Option.forEach(value => script->setAsync(value))
      attrs.defer->Option.forEach(value => script->setDefer(value))
      attrs.crossorigin->Option.forEach(value => script->setCrossorigin(value))
      attrs.integrity->Option.forEach(value => script->setIntegrity(value))
      attrs.nomodule->Option.forEach(value => script->setNomodule(value))
      attrs.referrerpolicy->Option.forEach(value => script->setReferrerpolicy(value))
      attrs.\"type"->Option.forEach(value => script->setType(value))
    }
  }
}

let loadOnce = (src, opts) => {
  let entry = getOrInitEntry(src)

  switch entry.status {
  | Ready => resolve()
  | _ =>
    switch entry.promise {
    | Some(existingPromise) => existingPromise
    | None => {
        let checkForExisting = opts->Option.flatMap(o => o.checkForExisting)->Option.getOr(true)
        let attrs = opts->Option.flatMap(o => o.attrs)->Option.getOr(Dict.make())
        let defaultAsync = opts->Option.flatMap(o => o.defaultAsync)->Option.getOr(true)

        let promise = make((resolve, reject) => {
          let scriptRef = ref(None)

          let existingScript = if checkForExisting {
            querySelector(`script[src="${cssEscape(src)}"]`)->Nullable.toOption
          } else {
            None
          }

          let onLoad = _ => {
            entry.error = None
            switch scriptRef.contents {
            | Some(script) => markDataset(script, Ready)
            | None => ()
            }
            emit(entry, Ready)
            resolve()
          }

          let onError = ev => {
            entry.error = Some(ev)
            switch scriptRef.contents {
            | Some(script) => markDataset(script, Error)
            | None => ()
            }
            emit(entry, Error)
            reject(ev)
          }

          entry.onLoadHandler = Some(onLoad)
          entry.onErrorHandler = Some(onError)

          switch existingScript {
          | Some(existing) =>
            if isLikelyAlreadyLoaded(existing, src) {
              entry.el = Some(existing)
              markDataset(existing, Ready)
              emit(entry, Ready)
              resolve()
            } else {
              scriptRef := Some(existing)
              entry.el = Some(existing)
              emit(entry, Loading)
              existing->addElementEventListener("load", onLoad)
              existing->addElementEventListener("error", onError)
            }
          | None => {
              let newScript = createElement("script")
              newScript->setSrc(src)

              let scriptAttrs = attrs->Dict.get(src)
              applyScriptAttrs(newScript, scriptAttrs)

              let userSpecifiedAsync = scriptAttrs->Option.flatMap(a => a.async)->Option.isSome
              if !userSpecifiedAsync && defaultAsync {
                newScript->setAsync(true)
              }

              markDataset(newScript, Loading)
              appendChildToHead(newScript)

              scriptRef := Some(newScript)
              entry.el = Some(newScript)
              emit(entry, Loading)

              newScript->addElementEventListener("load", onLoad)
              newScript->addElementEventListener("error", onError)
            }
          }
        })

        entry.promise = Some(promise)
        promise
      }
    }
  }
}

let unloadIfUnused = src => {
  switch store->Dict.get(src) {
  | Some(entry) if entry.refCount <= 0 => {
      switch entry.el {
      | Some(element) => {
          switch (entry.onLoadHandler, entry.onErrorHandler) {
          | (Some(onLoadHandler), Some(onErrorHandler)) => {
              element->removeElementEventListener("load", onLoadHandler)
              element->removeElementEventListener("error", onErrorHandler)
            }
          | (Some(onLoadHandler), None) =>
            element->removeElementEventListener("load", onLoadHandler)
          | (None, Some(onErrorHandler)) =>
            element->removeElementEventListener("error", onErrorHandler)
          | (None, None) => ()
          }

          switch element->parentElement->Nullable.toOption {
          | Some(parent) => parent->removeChild(element)
          | None => ()
          }
        }
      | None => ()
      }
      store->Dict.delete(src)
    }
  | _ => ()
  }
}

let useScripts = (srcs, ~opts=Some({ordered: false})) => {
  let list = React.useMemo(() => {
    srcs->Array.filter(src => src != "")
  }, [srcs])

  let whenReady = React.useCallback(srcArray => {
    let promises = srcArray->Array.map(src => {
      switch store->Dict.get(src) {
      | Some(entry) if entry.status == Ready => resolve()
      | _ => loadOnce(src, opts)
      }
    })
    all(promises)->then(_ => resolve())
  }, [])

  let (statuses, setStatuses) = React.useState(() => {
    let statusDict = Dict.make()
    list->Array.forEach(src => {
      let status = store->Dict.get(src)->Option.mapOr(Idle, entry => entry.status)
      statusDict->Dict.set(src, status)
    })
    statusDict
  })

  let (errors, setErrors) = React.useState(() => {
    let errorDict = Dict.make()
    list->Array.forEach(src => {
      let error = store->Dict.get(src)->Option.flatMap(entry => entry.error)
      errorDict->Dict.set(src, error)
    })
    errorDict
  })

  React.useEffect(() => {
    setStatuses(_ => {
      let next = Dict.make()
      list->Array.forEach(
        src => {
          let status = store->Dict.get(src)->Option.mapOr(Idle, entry => entry.status)
          next->Dict.set(src, status)
        },
      )
      next
    })
    setErrors(_ => {
      let next = Dict.make()
      list->Array.forEach(
        src => {
          let error = store->Dict.get(src)->Option.flatMap(entry => entry.error)
          next->Dict.set(src, error)
        },
      )
      next
    })
    None
  }, list)

  React.useEffect(
    () => {
      if list->Array.length == 0 {
        None
      } else {
        let subscriptions = ref([])

        let subscribe = src => {
          let entry = getOrInitEntry(src)
          entry.refCount = entry.refCount + 1

          let handler = status => {
            setStatuses(prev => {
              prev->Dict.get(src) == Some(status)
                ? prev
                : {
                    let newStatuses = Dict.fromArray(prev->Dict.toArray)
                    newStatuses->Dict.set(src, status)
                    newStatuses
                  }
            })
            setErrors(prev => {
              let newErrors = Dict.fromArray(prev->Dict.toArray)
              let error = if status == Error {
                store->Dict.get(src)->Option.flatMap(e => e.error)
              } else {
                None
              }
              newErrors->Dict.set(src, error)
              newErrors
            })
          }

          entry.subscribers = entry.subscribers->Array.concat([handler])
          subscriptions := subscriptions.contents->Array.concat([(src, handler)])

          handler(entry.status)

          if entry.status == Idle {
            loadOnce(src, opts)->catch(_ => resolve())->ignore
          }
        }

        switch opts->Option.flatMap(o => o.ordered)->Option.getOr(false) {
        | true => {
            let loadSequentially = async () => {
              for i in 0 to list->Array.length - 1 {
                let src = list->Array.getUnsafe(i)
                subscribe(src)
                switch store->Dict.get(src) {
                | Some(entry) if entry.status != Ready =>
                  try {
                    await loadOnce(src, opts)
                  } catch {
                  | _ => ()
                  }
                | _ => ()
                }
              }
            }
            loadSequentially()->ignore
          }
        | false => list->Array.forEach(subscribe)
        }

        Some(
          () => {
            subscriptions.contents->Array.forEach(((src, handler)) => {
              switch store->Dict.get(src) {
              | Some(entry) => {
                  entry.subscribers = entry.subscribers->Array.filter(sub => sub !== handler)
                  entry.refCount = max(0, entry.refCount - 1)

                  let shouldUnload =
                    opts->Option.flatMap(o => o.unloadWhenNoSubscribers)->Option.getOr(false)
                  if shouldUnload && entry.refCount == 0 {
                    unloadIfUnused(src)
                  }
                }
              | None => ()
              }
            })
          },
        )
      }
    },
    (
      list->Array.join("|"),
      opts->Option.flatMap(o => o.ordered)->Option.getOr(false),
      opts->Option.flatMap(o => o.checkForExisting)->Option.getOr(true),
      opts->Option.flatMap(o => o.defaultAsync)->Option.getOr(true),
      opts->Option.flatMap(o => o.unloadWhenNoSubscribers)->Option.getOr(false),
      opts
      ->Option.flatMap(o => o.attrs)
      ->Option.mapOr("", attrs =>
        attrs
        ->Dict.toArray
        ->Array.map(((k, v)) => `${k}:${JSON.stringify(v->Identity.anyTypeToJson)}`)
        ->Array.join(",")
      ),
    ),
  )

  let readyAll =
    list->Array.length > 0 &&
      list->Array.every(src => {
        statuses->Dict.get(src)->Option.getOr(Idle) == Ready
      })

  let readyOf = React.useCallback((src: string) => {
    statuses->Dict.get(src)->Option.getOr(Idle) == Ready
  }, [statuses])

  {
    statuses,
    errors,
    readyAll,
    readyOf,
    whenReady,
  }
}

let useScript = (src, opts) => {
  let srcArray = [src]
  let result = useScripts(srcArray, ~opts)
  let status = result.statuses->Dict.get(src)->Option.getOr(Idle)
  let ready = status == Ready
  let error = result.errors->Dict.get(src)->Option.getOr(None)
  let whenReady = React.useCallback1(() => result.whenReady([src]), [src])

  {
    status,
    ready,
    error,
    whenReady,
    readyOf: result.readyOf,
  }
}

let preloadScript = (src, opts) => loadOnce(src, opts)
