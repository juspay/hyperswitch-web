open MessageChannelBinding

type portHandle = {
  port: port,
  epoch: int,
}

let registry: Dict.t<portHandle> = Dict.make()

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
