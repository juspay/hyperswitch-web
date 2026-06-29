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

@send external focus: Dom.element => unit = "focus"

@send
external querySelectorAllWithin: (Dom.element, string) => array<Dom.element> = "querySelectorAll"

@val @scope("document") external activeElement: Nullable.t<Dom.element> = "activeElement"

let focusableSelector = "button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])"

let onActivateKeyDown = (~onActivate: unit => unit) => (event: JsxEvent.Keyboard.t) => {
  let key = JsxEvent.Keyboard.key(event)
  if key == "Enter" || JsxEvent.Keyboard.keyCode(event) == 13 || key == " " {
    event->JsxEvent.Keyboard.preventDefault
    onActivate()
  }
}
