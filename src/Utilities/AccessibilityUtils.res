let visuallyHiddenClass = "!absolute !-m-px !h-px !w-px !overflow-hidden !whitespace-nowrap !border-0 !p-0 ![clip:rect(0,0,0,0)]"

let hasText = value => value->String.length > 0

let hasOptionalText = value => value->Option.map(hasText)->Option.getOr(false)

let getAccessibleLabel = (~fieldName="", ~placeholder="", ~fallback) =>
  fieldName->hasText ? fieldName : placeholder->hasText ? placeholder : fallback

let ariaInvalid = (~hasError, ~isValid) =>
  if (
    hasError ||
    switch isValid {
    | Some(false) => true
    | _ => false
    }
  ) {
    #"true"
  } else {
    #"false"
  }
