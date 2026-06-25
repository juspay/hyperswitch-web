/*
 * Iframe focus delegation.
 *
 * The SDK renders payment fields inside an iframe embedded in the merchant's
 * page. Without help, tabbing past the iframe's last focusable element (or
 * shift-tabbing past its first) jumps focus to the top of the parent document
 * instead of the next/previous control around the iframe.
 *
 * This module lets the iframe detect those boundary cases and ask the parent
 * page (via `postMessage`) to move focus to the next/previous focusable element
 * just outside the iframe. The parent-side handler lives in the hyper-loader
 * (see `src/hyper-loader/Elements.res`).
 *
 * Protocol (flat JSON message): `[("focusDelegation", "next"|"previous"), ("iframeId", <id>)]`.
 */

// Notify the parent page to move focus to the next focusable element after the iframe.
let sendFocusNext = (~iframeId, ~targetOrigin="*") =>
  Utils.messageParentWindow(
    [("focusDelegation", "next"->JSON.Encode.string), ("iframeId", iframeId->JSON.Encode.string)],
    ~targetOrigin,
  )

// Notify the parent page to move focus to the previous focusable element before the iframe.
let sendFocusPrevious = (~iframeId, ~targetOrigin="*") =>
  Utils.messageParentWindow(
    [
      ("focusDelegation", "previous"->JSON.Encode.string),
      ("iframeId", iframeId->JSON.Encode.string),
    ],
    ~targetOrigin,
  )

// All focusable descendants of `container`, in DOM order.
let getFocusableElements = (container: Dom.element): array<Dom.element> =>
  container->AccessibilityUtils.querySelectorAllWithin(AccessibilityUtils.focusableSelector)

let parentFocusableSelector = "iframe, " ++ AccessibilityUtils.focusableSelector

// --- Parent-side handling -------------------------------------------------
//
// Runs in the merchant's page (outside the iframe). On receiving a
// `focusDelegation` message it locates the SDK iframe by `iframeId`, finds its
// position among the parent document's focusable elements, and moves focus to
// the next/previous one. Defensive: any missing element is a no-op.

// Index of `target` in `elements` via reference equality (no Array.indexOf for
// Dom.element in the stdlib).
let indexOfElement = (elements: array<Dom.element>, target: Dom.element): option<int> => {
  let found = ref(None)
  elements->Array.forEachWithIndex((el, idx) =>
    if found.contents === None && el === target {
      found := Some(idx)
    }
  )
  found.contents
}

// Resolve the SDK iframe DOM element in the parent document from the `iframeId`
// carried in the message. The iframe inside the SDK only knows its logical
// `iframeId` (the merchant's mount selector string); the actual element in the
// parent is mounted with an `orca-...-iframeRef-<iframeId>` id (see
// `LoaderPaymentElement.buildIframeHtmlString`). Try the known element-mount
// patterns first, then fall back to the bare id.
let resolveIframeElement = (~iframeId: string): Nullable.t<Dom.element> => {
  let candidates = [
    "#orca-payment-element-iframeRef-" ++ iframeId,
    "#orca-payment-methods-management-element-iframeRef-" ++ iframeId,
    "#" ++ iframeId,
  ]
  candidates->Array.reduce(Nullable.null, (acc, selector) =>
    switch acc->Nullable.toOption {
    | Some(_) => acc
    | None => Window.querySelector(selector)
    }
  )
}

// Move focus to the next ("next") or previous ("previous") focusable element in
// the parent document, relative to the SDK iframe identified by `iframeId`.
let handleParentFocusDelegation = (~direction: string, ~iframeId: string) => {
  try {
    switch resolveIframeElement(~iframeId)->Nullable.toOption {
    | Some(iframe) =>
      let focusable = Window.querySelectorAll(parentFocusableSelector)
      switch focusable->indexOfElement(iframe) {
      | Some(iframeIdx) =>
        let targetIdx = direction === "previous" ? iframeIdx - 1 : iframeIdx + 1
        switch focusable->Array.get(targetIdx) {
        | Some(target) => target->AccessibilityUtils.focus
        | None => () // boundary of the page — nothing to move focus to
        }
      | None => () // iframe not in the focusable list — no-op
      }
    | None => () // iframe not found in parent document — no-op
    }
  } catch {
  | _ => () // never let focus delegation break the merchant page
  }
}

// Boundary keydown handler for the form root. On `Tab` (no shift) while focus is
// on the LAST focusable element → ask the parent to move focus forward. On
// `Shift+Tab` while focus is on the FIRST focusable element → move focus back.
// In both cases we `preventDefault` so the browser does not first escape to the
// top of the parent document.
let handleBoundaryKeyDown = (
  event: JsxEvent.Keyboard.t,
  ~container: Nullable.t<Dom.element>,
  ~iframeId,
) => {
  if JsxEvent.Keyboard.key(event) === "Tab" {
    switch container->Nullable.toOption {
    | Some(container) =>
      let focusable = [container]->Array.concat(getFocusableElements(container))
      switch (focusable->Array.get(0), focusable->Array.get(focusable->Array.length - 1)) {
      | (Some(first), Some(last)) =>
        let current = AccessibilityUtils.activeElement->Nullable.toOption
        if JsxEvent.Keyboard.shiftKey(event) {
          // Shift+Tab on the first element → delegate focus to the previous
          // element in the parent.
          if current === Some(first) {
            event->JsxEvent.Keyboard.preventDefault
            sendFocusPrevious(~iframeId)
          }
        } else if current === Some(last) {
          // Tab on the last element → delegate focus to the next element in
          // the parent.
          event->JsxEvent.Keyboard.preventDefault
          sendFocusNext(~iframeId)
        }
      | _ => ()
      }
    | None => ()
    }
  }
}
