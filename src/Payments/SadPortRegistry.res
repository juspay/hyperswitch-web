/* SadPortRegistry — per-document registry of MessagePort endpoints for the Card Relay.
   A field iframe owns one port (keyed groupId:fieldName); the hidden coordinator owns one
   per field of its group, installed from the `cardFieldPort` frames the group forwards.
   Epoch discipline: ports are keyed AND epoch-tagged. Re-installing under the same key with
   a NEW epoch closes the stale port first — a remount must never leave a live listener on a
   dead channel. A same-epoch duplicate install is a no-op. */

open Utils
open MessageChannelBinding

type portHandle = {
  port: port,
  epoch: int,
}

let registry: Dict.t<portHandle> = Dict.make()

// consumers subscribe once and re-scan the registry on every structural mutation.
let changeListeners: ref<array<unit => unit>> = ref([])

let addChangeListener = (cb: unit => unit): unit => {
  changeListeners := changeListeners.contents->Array.concat([cb])
}
let removeChangeListener = (cb: unit => unit): unit => {
  changeListeners := changeListeners.contents->Array.filter(l => l !== cb)
}
let notify = () => changeListeners.contents->Array.forEach(cb => cb())

let installPort = (~key: string, ~epoch: int, ~port) => {
  switch registry->Dict.get(key) {
  | Some(existing) =>
    if existing.epoch != epoch {
      try {
        existing.port->portClose
      } catch {
      | _ => ()
      }
      registry->Dict.set(key, {port, epoch})
      notify()
    }
  | None => {
      registry->Dict.set(key, {port, epoch})
      notify()
    }
  }
}

let getPort = (~key: string) => registry->Dict.get(key)->Option.map(h => h.port)

let closePort = (~key: string) => {
  switch registry->Dict.get(key) {
  | Some(handle) =>
    try {
      handle.port->portClose
    } catch {
    | _ => ()
    }
    Dict.delete(registry, key)
    notify()
  | None => ()
  }
}

let closeAllPorts = () => {
  registry
  ->Dict.keysToArray
  ->Array.forEach(key => closePort(~key))
}

/* returns false when the key is not registered. DROP semantics: the caller does NOT fall
   back to the window plane for raws, so false means the snapshot is lost for this cycle and
   the caller should warn as a dev-time drift signal. */
let postFrame = (~key: string, frame: JSON.t) =>
  switch registry->Dict.get(key) {
  | Some(handle) =>
    try {
      handle.port->portPostMessage(frame)
      true
    } catch {
    | _ => false
    }
  | None => false
  }
