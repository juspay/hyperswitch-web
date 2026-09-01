// SadPortRegistry — per-document registry of MessagePort endpoints for the
// MessageChannel Card Relay.
//
// Each document that participates in the port plane owns one registry:
//
//   * Per-field iframe — a single port (keyed by its groupId:fieldName
//     portKey) installed by LoaderController when the mount-config message
//     arrives with a transfer list.
//   * Hidden coordinator iframe — one port PER FIELD of its group, installed
//     the same way from the `cardFieldPort` frames the group forwards.
//
// Epoch discipline: ports are keyed AND epoch-tagged. Re-installing under the
// same key with a NEW epoch closes the stale port before replacing it (a
// remount must never leave a live listener on a dead channel). A same-epoch
// duplicate install is a no-op.
open Utils
open MessageChannelBinding

type portHandle = {
  port: port,
  epoch: int,
}

let registry: Dict.t<portHandle> = Dict.make()

// React-consumable change notification: consumers (the coordinator) subscribe
// once and re-scan the per-document registry on every structural mutation.
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

// Post a versioned relay frame on a registered port. Returns false when the
// key isn't registered — DROP semantics: the caller does NOT fall back to the
// window plane for raws (the dual-plane emitters post their masked window
// half regardless), so `false` means the snapshot is lost for this cycle and
// the caller should `Console.warn` as a dev-time integration-drift signal.
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
