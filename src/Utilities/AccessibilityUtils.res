let generateElementId = (~baseId, ~suffix) => {
  baseId === "" ? "" : `${baseId}-${suffix}`
}

let getErrorId = id => generateElementId(~baseId=id, ~suffix="error")

let getAriaInvalidState = isValid =>
  switch isValid {
  | Some(false) => #"true"
  | _ => #"false"
  }
