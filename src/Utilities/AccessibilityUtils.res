let generateElementId = (~baseId, ~suffix) => baseId === "" ? "" : `${baseId}-${suffix}`

let getErrorId = id => generateElementId(~baseId=id, ~suffix="error")

let getAriaInvalidState = isValid => isValid === Some(false) ? #"true" : #"false"
