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

@set external setTextContent: (Dom.element, string) => unit = "textContent"

let focusableSelector = "button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])"

let announceFailedSubmit = message => {
  switch Window.querySelector("#hyperswitch-sdk-live-alert")->Nullable.toOption {
  | Some(alert) =>
    alert->setTextContent("")
    setTimeout(() => alert->setTextContent(message), 0)->ignore
    setTimeout(() => alert->setTextContent(""), 5000)->ignore
  | None => ()
  }
}

let ensureKnownIframeTitles = () => {
  Window.querySelectorAll("iframe")->Array.forEach(iframe => {
    let currentTitle = iframe->Window.getAttribute("title")->Nullable.toOption->Option.getOr("")
    if currentTitle === "" {
      let src = iframe->Window.getAttribute("src")->Nullable.toOption->Option.getOr("")
      if src->String.includes("pay.google.com") {
        iframe->Window.setAttribute("title", "Google Pay processing frame")
      } else if src === "" || src === "about:blank" {
        iframe->Window.setAttribute("title", "Secure payment processing frame")
      }
    }
  })
}

let scheduleKnownIframeTitleRepair = () => {
  ensureKnownIframeTitles()
  setTimeout(ensureKnownIframeTitles, 1000)->ignore
  setTimeout(ensureKnownIframeTitles, 3000)->ignore
}

let onActivateKeyDown = (~onActivate: unit => unit) => (event: JsxEvent.Keyboard.t) => {
  let key = JsxEvent.Keyboard.key(event)
  if key == "Enter" || JsxEvent.Keyboard.keyCode(event) == 13 || key == " " {
    event->JsxEvent.Keyboard.preventDefault
    onActivate()
  }
}
