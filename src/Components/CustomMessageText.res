open CustomMessageUtils

let linkClassName = "CustomMessageLink"

let linkCssStyle = (themeObj: CardThemeType.themeClass) =>
  `:where(.${linkClassName}) { color: ${themeObj.colorPrimary}; text-decoration: underline; cursor: pointer; }
:where(.${linkClassName}):focus-visible { outline: 2px solid ${themeObj.colorPrimary}; outline-offset: 2px; border-radius: 2px; }`

let useMessageSegments = (~message: PaymentType.paymentMethodMessage) => React.useMemo(() => {
    messageToSegments(
      ~value=message.value->Option.getOr("")->String.trim,
      ~elements=message.elements,
      ~elementStyles=message.elementStyles,
    )
  }, [message])

module LinkSegment = {
  @react.component
  let make = (~elementKey, ~label, ~style, ~onActivate) => {
    let activate = () => onActivate(~key=elementKey)

    let onClick = ev => {
      ev->ReactEvent.Mouse.preventDefault
      ev->ReactEvent.Mouse.stopPropagation
      activate()
    }

    let onKeyDown = ev => {
      let key = ev->JsxEvent.Keyboard.key
      let keyCode = ev->JsxEvent.Keyboard.keyCode
      if key == "Enter" || key == " " || key == "Spacebar" || keyCode == 13 || keyCode == 32 {
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
      dataTestId={TestUtils.customMessageLinkTestId(elementKey)}
    >
      {React.string(label)}
    </span>
  }
}

@react.component
let make = (~segments: array<segment>, ~paymentMethod: string, ~paymentMethodType: string) => {
  let {themeObj} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let emitter = SubscriptionEventHooks.useSubscriptionEventEmitter()

  let onActivate = (~key) =>
    emitter.emitCustomMessageElementClicked(~key, ~paymentMethod, ~paymentMethodType)

  <>
    <style> {React.string(linkCssStyle(themeObj))} </style>
    {segments
    ->Array.mapWithIndex((segment, index) =>
      switch segment {
      | Text(text) =>
        <React.Fragment key={index->Int.toString}> {React.string(text)} </React.Fragment>
      | Link({key, label, style}) =>
        <LinkSegment key={index->Int.toString} elementKey=key label style onActivate />
      }
    )
    ->React.array}
  </>
}
