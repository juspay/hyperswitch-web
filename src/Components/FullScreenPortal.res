open Utils
@val @scope(("window", "parent", "frames", `"fullscreen"`, "document"))
external getElementById: string => Dom.element = "getElementById"

/*
 * Accessibility note (Task 12 — keyboard-navigation gap closure):
 *
 * This component is a thin portal: it renders `children` into the REMOTE
 * `#fullscreen` iframe document via `ReactDOM.createPortal`. The only consumers
 * (ACHBankDebit / BecsBankDebit) portal a `<BankDebitModal>`, whose content is
 * the shared `Modal` component. `Modal` already provides the full dialog
 * contract: `role="dialog"` + `ariaModal=true` + an accessible name, plus
 * `AccessibilityHooks.useReturnFocus` / `useFocusTrap` / `useEscapeKey`
 * (Escape -> close path that posts `("fullscreen", false)` to the parent).
 *
 * Therefore NO dialog semantics, focus-into-dialog, or Escape handling are added
 * here: wrapping the portalled `Modal` in a second `role="dialog"`/`ariaModal`
 * container would create a nested/duplicate dialog (a screen-reader regression),
 * not an additive landmark. The genuine dismissal path lives on `Modal` and must
 * stay the single source of truth so the bank-debit flow is not corrupted.
 *
 * Cross-document note: `AccessibilityHooks` derive their keydown target and
 * active element from the rendered modal container's owner document, so the same
 * modal contract applies when content is portalled into the fullscreen iframe.
 */
@react.component
let make = (~children) => {
  let (fullScreenIframeNode, setFullScreenIframeNode) = React.useState(() => Nullable.null)

  React.useEffectOnEveryRender(() => {
    let handle = (ev: Window.event) => {
      try {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson

        if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
          if dict->getBool("fullScreenIframeMounted", false) {
            setFullScreenIframeNode(_ =>
              switch Window.windowParent->Window.fullscreen {
              | Some(doc) => doc->Window.document->Window.getElementById("fullscreen")
              | None => Nullable.null
              }
            )
          }
        }
      } catch {
      | _err => ()
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  switch fullScreenIframeNode->Nullable.toOption {
  | Some(domNode) => ReactDOM.createPortal(children, domNode)
  | None => React.null
  }
}
