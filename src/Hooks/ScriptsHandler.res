open Promise
open Window

type scriptStatus = Idle | Loading | Ready | Error

type options = {
  \"type"?: string,
  async?: bool,
  defer?: bool,
  validateGlobal?: Dict.t<string>,
}

type entry = {
  mutable status: scriptStatus,
  mutable el: option<Dom.element>,
  mutable subscribers: array<scriptStatus => unit>,
  mutable promise: option<t<unit>>,
  mutable onLoadHandler: option<Dom.event => unit>,
  mutable onErrorHandler: option<Dom.event => unit>,
}

type useScriptsResult = {
  statuses: Dict.t<scriptStatus>,
  readyAll: bool,
}

type useScriptResult = {
  status: scriptStatus,
  ready: bool,
}

let isGlobalExists = globalVarName => {
  let rec checkNestedProperty = (obj, keys, index) => {
    switch obj->Nullable.toOption {
    | Some(_) if index <= 15 =>
      if index >= Array.length(keys) {
        true
      } else {
        let key = keys->Array.get(index)
        switch key {
        | Some(_) => {
            let nextValue = %raw(`obj[key]`)
            checkNestedProperty(nextValue->Nullable.make, keys, index + 1)
          }
        | None => false
        }
      }
    | _ => false
    }
  }
  try {
    let keys = globalVarName->String.split(".")
    checkNestedProperty(window->Nullable.make, keys, 0)
  } catch {
  | _ => false
  }
}

let store = Dict.make()

let getOrInitEntry = src =>
  switch store->Dict.get(src) {
  | Some(entry) => entry
  | None => {
      let entry = {
        status: Idle,
        el: None,
        subscribers: [],
        promise: None,
        onLoadHandler: None,
        onErrorHandler: None,
      }
      store->Dict.set(src, entry)
      entry
    }
  }

let emitAndMarkDataset = (entry: entry, nextStatus) => {
  entry.status = nextStatus
  entry.subscribers->Array.forEach(subscriber => subscriber(nextStatus))
  switch entry.el {
  | Some(script) =>
    try {
      let statusStr = switch nextStatus {
      | Idle => "idle"
      | Loading => "loading"
      | Ready => "ready"
      | Error => "error"
      }
      script->setAttribute("data-status", statusStr)
    } catch {
    | _ => ()
    }
  | None => ()
  }
}

let isLikelyAlreadyLoaded = (script, ~globalVarName=?) =>
  switch script->dataset->getDatasetStatus->Nullable.toOption {
  | Some("ready") => true
  | _ =>
    switch globalVarName {
    | Some(varName) if isGlobalExists(varName) => true
    | _ =>
      switch script->elementReadyState->Nullable.toOption {
      | Some("complete") | Some("loaded") => true
      | _ => false
      }
    }
  }

let applyScriptAttrs = (script, opts) =>
  switch opts {
  | None => script->setAsync(true)
  | Some(opts) => {
      let async = opts.async->Option.getOr(true)
      script->setAsync(async)
      opts.defer->Option.forEach(value => script->setDefer(value))
      opts.\"type"->Option.forEach(value => script->setType(value))
    }
  }

let cleanupDomListeners = entry =>
  switch entry.el {
  | Some(el) => {
      entry.onLoadHandler->Option.forEach(h => el->removeElementEventListener("load", h))
      entry.onErrorHandler->Option.forEach(h => el->removeElementEventListener("error", h))
      entry.onLoadHandler = None
      entry.onErrorHandler = None
    }
  | None => ()
  }

let loadOnce = (src, opts: option<options>) => {
  let entry = getOrInitEntry(src)
  switch entry.status {
  | Ready => resolve()
  | _ =>
    switch entry.promise {
    | Some(existingPromise) => existingPromise
    | None => {
        let promise = make((resolve, reject) => {
          let existingScript = querySelector(`script[src="${src}"]`)->Nullable.toOption
          let globalVarName = switch opts {
          | Some(o) => o.validateGlobal->Option.getOr(Dict.make())->Dict.get(src)
          | None => None
          }

          let shouldCreateNewScript = switch existingScript {
          | Some(existing) if existing->isLikelyAlreadyLoaded(~globalVarName?) => {
              entry.el = Some(existing)
              emitAndMarkDataset(entry, Ready)
              resolve()
              false
            }
          | _ => true
          }

          let onLoad = _ => {
            cleanupDomListeners(entry)
            emitAndMarkDataset(entry, Ready)
            if shouldCreateNewScript {
              existingScript->Option.forEach(script => script->remove)
            }
            resolve()
          }

          let onError = ev => {
            cleanupDomListeners(entry)
            entry.promise = None
            emitAndMarkDataset(entry, Error)
            reject(ev)
          }

          entry.onLoadHandler = Some(onLoad)
          entry.onErrorHandler = Some(onError)

          if shouldCreateNewScript {
            let newScript = createElement("script")
            applyScriptAttrs(newScript, opts)
            newScript->setSrc(src)
            appendChildToHead(newScript)
            entry.el = Some(newScript)
            emitAndMarkDataset(entry, Loading)
            newScript->addElementEventListener("load", onLoad)
            newScript->addElementEventListener("error", onError)
          }
        })
        entry.promise = Some(promise)
        promise
      }
    }
  }
}

let useScripts = (srcs, ~opts=None) => {
  let list = React.useMemo(() => {
    srcs->Array.filter(src => src != "")
  }, [srcs])

  let (statuses, setStatuses) = React.useState(() => {
    list->Array.reduce(Dict.make(), (acc, src) => {
      let status = store->Dict.get(src)->Option.mapOr(Idle, entry => entry.status)
      acc->Dict.set(src, status)
      acc
    })
  })

  React.useEffect(() => {
    if list->Array.length == 0 {
      None
    } else {
      let subscriptions = ref([])

      let subscribe = src => {
        let entry = getOrInitEntry(src)
        let handler = status =>
          setStatuses(prev =>
            prev->Dict.get(src) == Some(status)
              ? prev
              : {
                  let newStatuses = Dict.fromArray(prev->Dict.toArray)
                  newStatuses->Dict.set(src, status)
                  newStatuses
                }
          )

        entry.subscribers = entry.subscribers->Array.concat([handler])
        subscriptions := subscriptions.contents->Array.concat([(src, handler)])
        handler(entry.status)

        if entry.status == Idle {
          loadOnce(src, opts)->catch(_ => resolve())->ignore
        }
      }

      list->Array.forEach(subscribe)

      Some(
        () =>
          subscriptions.contents->Array.forEach(((src, handler)) =>
            switch store->Dict.get(src) {
            | Some(entry) => entry.subscribers = entry.subscribers->Array.filter(s => s !== handler)
            | None => ()
            }
          ),
      )
    }
  }, list)

  let readyAll = list->Array.every(src => statuses->Dict.get(src)->Option.getOr(Idle) == Ready)

  {
    statuses,
    readyAll,
  }
}

let useScript = (src, opts) => {
  let srcArray = [src]
  let result = useScripts(srcArray, ~opts)
  let status = result.statuses->Dict.get(src)->Option.getOr(Idle)
  let ready = status == Ready

  {
    status,
    ready,
  }
}

let preloadScript = loadOnce
