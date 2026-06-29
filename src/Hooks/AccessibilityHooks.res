/*
 * Reusable keyboard / focus-management hooks for accessibility.
 *
 * - useEscapeKey   : invoke a callback when the Escape key is pressed.
 * - useFocusTrap   : keep keyboard focus within a container while it is active.
 * - useReturnFocus : restore focus to the previously-focused element on close.
 *
 * These hooks are dependency-light and have no external deps. Each effect that
 * registers a listener returns a cleanup that removes it.
 */

// Minimal typed view over a raw DOM keyboard event delivered to a window/document
// "keydown" listener. `Window.addEventListener` binds the handler as `_ => unit`,
// so we describe just the fields we read here.
type keyboardEvent = {
  key: string,
  shiftKey: bool,
}
@send external preventDefault: keyboardEvent => unit = "preventDefault"
type eventTarget
type document
@val external globalWindow: eventTarget = "window"
@get external ownerDocument: Dom.element => Nullable.t<document> = "ownerDocument"
@get external defaultView: document => Nullable.t<eventTarget> = "defaultView"
@get external documentActiveElement: document => Nullable.t<Dom.element> = "activeElement"
@send
external addKeyDownListener: (eventTarget, @as("keydown") _, keyboardEvent => unit) => unit =
  "addEventListener"
@send
external removeKeyDownListener: (eventTarget, @as("keydown") _, keyboardEvent => unit) => unit =
  "removeEventListener"

let getOwnerDocument = (containerRef: React.ref<Nullable.t<Dom.element>>) =>
  containerRef.current
  ->Nullable.toOption
  ->Option.flatMap(el => el->ownerDocument->Nullable.toOption)

let getEventTarget = (containerRef: React.ref<Nullable.t<Dom.element>>) =>
  getOwnerDocument(containerRef)
  ->Option.flatMap(doc => doc->defaultView->Nullable.toOption)
  ->Option.getOr(globalWindow)

let getActiveElement = (containerRef: React.ref<Nullable.t<Dom.element>>) =>
  switch getOwnerDocument(containerRef) {
  | Some(doc) => doc->documentActiveElement
  | None => AccessibilityUtils.activeElement
  }

let getFocusableElements = (containerRef: React.ref<Nullable.t<Dom.element>>) =>
  switch containerRef.current->Nullable.toOption {
  | Some(container) =>
    container->AccessibilityUtils.querySelectorAllWithin(AccessibilityUtils.focusableSelector)
  | None => []
  }

let useEscapeKey = (
  ~enabled: bool,
  ~onEscape: unit => unit,
  ~containerRef: React.ref<Nullable.t<Dom.element>>,
) => {
  React.useEffect(() => {
    if enabled {
      let handle = (ev: keyboardEvent) =>
        if ev.key === "Escape" {
          onEscape()
        }
      let target = getEventTarget(containerRef)
      target->addKeyDownListener(handle)
      Some(() => target->removeKeyDownListener(handle))
    } else {
      None
    }
  }, [enabled])
}

let useFocusTrap = (~active: bool, ~containerRef: React.ref<Nullable.t<Dom.element>>) => {
  React.useEffect(() => {
    if active {
      let handle = (ev: keyboardEvent) =>
        if ev.key === "Tab" {
          let focusable = getFocusableElements(containerRef)
          switch (focusable->Array.get(0), focusable->Array.get(focusable->Array.length - 1)) {
          | (Some(first), Some(last)) =>
            let current = getActiveElement(containerRef)->Nullable.toOption
            if ev.shiftKey {
              // Shift+Tab on the first element wraps to the last.
              if current === Some(first) {
                ev->preventDefault
                last->AccessibilityUtils.focus
              }
            } // Tab on the last element wraps back to the first.
            else if current === Some(last) {
              ev->preventDefault
              first->AccessibilityUtils.focus
            }
          | _ => ()
          }
        }
      let target = getEventTarget(containerRef)
      target->addKeyDownListener(handle)
      Some(() => target->removeKeyDownListener(handle))
    } else {
      None
    }
  }, [active])
}

let useReturnFocus = (~active: bool, ~containerRef: React.ref<Nullable.t<Dom.element>>) => {
  // Holds the element that had focus when `active` last became true.
  let previouslyFocused = React.useRef(Nullable.null)

  React.useEffect(() => {
    if active {
      // Capture the currently-focused element when the trap becomes active.
      previouslyFocused.current = getActiveElement(containerRef)
      None
    } else {
      // On deactivation, restore focus to the captured element (if any).
      previouslyFocused.current
      ->Nullable.toOption
      ->Option.forEach(el => el->AccessibilityUtils.focus)
      previouslyFocused.current = Nullable.null
      None
    }
  }, [active])
}
