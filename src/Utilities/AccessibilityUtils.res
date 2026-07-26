let visuallyHiddenClass = "!absolute !-m-px !h-px !w-px !overflow-hidden !whitespace-nowrap !border-0 !p-0 ![clip-path:inset(50%)]"

let hasText = value => value->String.length > 0

let hasOptionalText = value => value->Option.map(hasText)->Option.getOr(false)

let getAccessibleLabel = (~fieldName="", ~placeholder="", ~fallback) =>
  fieldName->hasText ? fieldName : placeholder->hasText ? placeholder : fallback

let getControlId = (~fieldId: option<string>, ~preferredId="", ~generatedId) =>
  fieldId->Option.getOr(preferredId->hasText ? preferredId : generatedId)

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

let getFieldAccessibility = (
  ~controlId,
  ~fieldName="",
  ~placeholder="",
  ~ariaLabel: option<string>,
  ~hasError,
  ~isValid,
) => {
  let accessibleLabel =
    ariaLabel->Option.getOr(getAccessibleLabel(~fieldName, ~placeholder, ~fallback=controlId))
  let errorId = controlId ++ "-error"
  let describedById = hasError ? Some(errorId) : None
  let invalid = ariaInvalid(~hasError, ~isValid)

  (accessibleLabel, errorId, describedById, invalid)
}
