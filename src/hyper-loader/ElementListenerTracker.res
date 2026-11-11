type logger = {track: string => unit, logOnMount: unit => unit}

type t = {
  logger: logger,
  register: ref<string> => unit,
  onMount: string => unit,
  destroy: unit => unit,
}

type scope = {logger: logger, mutable mountedSelector: option<string>, mutable isDestroyed: bool}

type handle = {
  scope: ref<scope>,
  listeners: array<string>,
  mutable selectorRef: ref<string>,
  mutable hasRegistration: bool,
  mutable mountSelector: option<string>,
  mutable isPaired: bool,
}

let ignoreErrors = (fn, arg) => try fn(arg) catch {
| _ => ()
}

let deferPairing = fn =>
  Promise.resolve()
  ->Promise.thenResolve(() => ignoreErrors(fn, ()))
  ->Promise.catch(_ => Promise.resolve())
  ->ignore

let makeFactory = () => {
  let handlesByType: Dict.t<array<handle>> = Dict.make()
  (componentType, ~context=?) => {
    let makeScope = () => {
      let eventListeners = []
      let hasMounted = ref(false)
      let log = () => HyperLoaderLogger.logEventListeners(~componentType, ~events=eventListeners, ~context?)
      let logger = {
        track: name =>
          if !(eventListeners->Array.includes(name)) {
            eventListeners->Array.push(name)->ignore
            if hasMounted.contents {
              log()
            }
          },
        logOnMount: () =>
          if !hasMounted.contents {
            hasMounted := true
            log()
          },
      }
      {logger, mountedSelector: None, isDestroyed: false}
    }
    let handle = {
      scope: ref(makeScope()),
      listeners: [],
      selectorRef: ref(""),
      hasRegistration: false,
      mountSelector: None,
      isPaired: false,
    }
    let handles = () => handlesByType->Dict.get(componentType)->Option.getOr([])
    let prune = () =>
      handlesByType->Dict.set(
        componentType,
        handles()->Array.filter(h =>
          !h.scope.contents.isDestroyed && (!h.isPaired || h.mountSelector->Option.isSome)
        ),
      )
    let enqueue = () => {
      prune()
      if !handle.isPaired || handle.mountSelector->Option.isSome {
        let handles = handles()
        if !(handles->Array.includes(handle)) {
          handles->Array.push(handle)->ignore
          handlesByType->Dict.set(componentType, handles)
        }
      }
    }
    let connect = (registration, mounting) => {
      if registration.scope.contents.mountedSelector->Option.isSome {
        mounting.listeners->Array.forEach(registration.scope.contents.logger.track)
        mounting.scope := registration.scope.contents
      } else {
        registration.listeners->Array.forEach(mounting.scope.contents.logger.track)
        registration.scope := mounting.scope.contents
      }
      registration.scope.contents.mountedSelector = mounting.mountSelector
      registration.isPaired = true
      mounting.isPaired = true
      prune()
    }
    let pairRegistration = () => {
      if !handle.scope.contents.isDestroyed && handle.mountSelector->Option.isNone {
        let sibling = handles()->Array.find(h =>
          !h.scope.contents.isDestroyed &&
          handle.selectorRef.contents !== "" &&
          h.mountSelector === Some(handle.selectorRef.contents)
        )
        sibling->Option.forEach(mounting => connect(handle, mounting))
      }
    }
    let pairMount = () => {
      handles()
      ->Array.filter(h =>
        !h.scope.contents.isDestroyed &&
        h.hasRegistration &&
        h.mountSelector->Option.isNone &&
        h.selectorRef.contents !== "" &&
        handle.mountSelector === Some(h.selectorRef.contents)
      )
      ->Array.forEach(registration => connect(registration, handle))
    }
    let register = selectorRef => {
      if !handle.scope.contents.isDestroyed {
        handle.selectorRef = selectorRef
        handle.hasRegistration = true
        enqueue()
        deferPairing(pairRegistration)
      }
    }
    let track = name => {
      if !(handle.listeners->Array.includes(name)) {
        handle.listeners->Array.push(name)->ignore
      }
      if !handle.scope.contents.isDestroyed {
        handle.scope.contents.logger.track(name)
      }
    }
    let logOnMount = () => {
      if !handle.scope.contents.isDestroyed {
        pairMount()
        handle.scope.contents.mountedSelector = handle.mountSelector
        handle.scope.contents.logger.logOnMount()
      }
    }
    let onMount = selector => {
      if (
        handle.isPaired &&
        handle.mountSelector->Option.isNone &&
        (handle.scope.contents.isDestroyed || handle.scope.contents.mountedSelector !== Some(selector))
      ) {
        handle.scope := makeScope()
        handle.listeners->Array.forEach(handle.scope.contents.logger.track)
        handle.isPaired = false
      }
      handle.mountSelector = Some(selector)
      handlesByType->Dict.set(
        componentType,
        handles()->Array.filter(h => h === handle || h.mountSelector !== Some(selector)),
      )
      enqueue()
    }
    let destroy = () => {
      if handle.mountSelector->Option.isSome {
        pairMount()
      } else if handle.hasRegistration {
        pairRegistration()
      }
      handle.scope.contents.isDestroyed = true
      prune()
    }
    {
      register: selectorRef => ignoreErrors(register, selectorRef),
      logger: {
        track: name => ignoreErrors(track, name),
        logOnMount: () => ignoreErrors(logOnMount, ()),
      },
      onMount: selector => ignoreErrors(onMount, selector),
      destroy: () => ignoreErrors(destroy, ()),
    }
  }
}

let make = (~componentType, ~context=?) => makeFactory()(componentType, ~context?)
