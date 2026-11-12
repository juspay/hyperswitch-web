let entries = sdkAuthorization => sdkAuthorization->Window.atob->String.split(",")

let valueOfEntries = (entries, key) => {
  let prefix = key ++ "="
  entries->Array.findMap(entry =>
    entry->String.startsWith(prefix)
      ? switch entry->String.sliceToEnd(~start=prefix->String.length) {
        | "" => None
        | value => Some(value)
        }
      : None
  )
}

let value = (sdkAuthorization, key) =>
  try {
    sdkAuthorization->entries->valueOfEntries(key)
  } catch {
  | _ => None
  }
