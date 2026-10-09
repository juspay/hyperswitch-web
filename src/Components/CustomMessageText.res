// Renders a custom payment method message, replacing `{{key}}` placeholders
// with their configured elements. Link elements never navigate: activating one
// emits `customMessageElementClicked` so the merchant decides what to open.
//
// Style cascade for a link (each layer overrides per property):
//   1. SDK theme      -> zero-specificity `:where(.CustomMessageLink)` rule
//   2. appearance     -> merchant `appearance.rules[".CustomMessageLink"]`
//   3. elementStyles.link -> inline style
//   4. elements[key].style -> inline style (merged over 3)
open CustomMessageUtils

let linkClassName = "CustomMessageLink"

let themeLinkCss = (themeObj: CardThemeType.themeClass) =>
  `:where(.${linkClassName}) { color: ${themeObj.colorPrimary}; text-decoration: underline; cursor: pointer; }
:where(.${linkClassName}):focus-visible { outline: 2px solid ${themeObj.colorPrimary}; outline-offset: 2px; border-radius: 2px; }`

let useSegments = (~message: PaymentType.paymentMethodMessage) => {
  let isInteractive = SubscriptionEventHooks.useIsSubscribedTo(
    ~eventType=CustomMessageElementClicked,
  )
  React.useMemo(() => {
    toSegments(
      ~value=message.value->Option.getOr("")->String.trim,
      ~elements=message.elements,
      ~elementStyles=message.elementStyles,
      ~isInteractive,
    )
  }, (message, isInteractive))
}

let hasElementSegment = segments =>
  segments->Array.some(segment =>
    switch segment {
    | Element(_) => true
    | Text(_) => false
    }
  )

module Link = {
  @react.component
  let make = (~elementKey, ~elementType, ~label, ~style, ~onActivate) => {
    let activate = () => onActivate(~key=elementKey, ~elementType)

    let onClick = ev => {
      // Never let the click reach a wrapping <label> (save-details checkbox)
      // or any ancestor handler.
      ev->ReactEvent.Mouse.preventDefault
      ev->ReactEvent.Mouse.stopPropagation
      activate()
    }

    let onKeyDown = ev => {
      let key = ev->JsxEvent.Keyboard.key
      if key == "Enter" || key == " " || key == "Spacebar" {
        ev->JsxEvent.Keyboard.preventDefault
        ev->JsxEvent.Keyboard.stopPropagation
        activate()
      }
    }

    <span
      className={linkClassName}
      role="link"
      tabIndex=0
      style={style->styleToJsxStyle}
      onClick
      onKeyDown
      dataTestId={`custom-message-link-${elementKey}`}
    >
      {React.string(label)}
    </span>
  }
}

@react.component
let make = (
  ~message: PaymentType.paymentMethodMessage,
  ~paymentMethod: string,
  ~paymentMethodType: string,
  ~textClassName="",
) => {
  let {themeObj} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()
  let segments = useSegments(~message)

  let onActivate = (~key, ~elementType) =>
    emitter.emitCustomMessageElementClicked(
      ~key,
      ~elementType=elementType->elementTypeToString,
      ~paymentMethod,
      ~paymentMethodType,
    )

  <>
    <RenderIf condition={segments->hasElementSegment}>
      <style> {React.string(themeLinkCss(themeObj))} </style>
    </RenderIf>
    {segments
    ->Array.mapWithIndex((segment, index) =>
      switch segment {
      | Text(text) =>
        textClassName === ""
          ? <React.Fragment key={index->Int.toString}> {React.string(text)} </React.Fragment>
          : <span key={index->Int.toString} className=textClassName> {React.string(text)} </span>
      | Element({key, elementType, label, style}) =>
        <Link key={index->Int.toString} elementKey=key elementType label style onActivate />
      }
    )
    ->React.array}
  </>
}
