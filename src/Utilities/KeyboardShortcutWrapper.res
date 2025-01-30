type os = Windows | Mac | Linux | Unknown
@react.component
let make = (~children) => {
  let elementRef = React.useRef(Nullable.null)
  // Detect operating system
  let getOS = () => {
    switch Window.Navigator.platform {
    | p if Js.String.includes("Win", p) => Windows
    | p if Js.String.includes("Mac", p) => Mac
    | p if Js.String.includes("Linux", p) => Linux
    | _ => Unknown
    }
  }

  let handleKeyDown = (event: ReactEvent.Keyboard.t) =>
    {
      let os = getOS()
      let focusElement = (primaryId, fallbackId) => {
        let primaryElement = Window.window->Window.document->Window.getElementById(primaryId)

        let targetElement = switch primaryElement->Nullable.toOption {
        | Some(_) => primaryElement
        | None => Window.window->Window.document->Window.getElementById(fallbackId)
        }

        elementRef.current = targetElement
        CardUtils.focusRef(elementRef)
      }

      switch os {
      | Mac =>
        if ReactEvent.Keyboard.metaKey(event) && ReactEvent.Keyboard.shiftKey(event) {
          switch ReactEvent.Keyboard.key(event) {
          | "1" => focusElement("saved-methods", "payment-section")
          | "2" => focusElement("more-payment-methods", "use-existing-payment-methods")
          | _ => ()
          }
        }
      | Windows | Linux =>
        {
          if ReactEvent.Keyboard.ctrlKey(event) && ReactEvent.Keyboard.shiftKey(event) {
            switch ReactEvent.Keyboard.key(event) {
            | "1" => focusElement("saved-methods", "payment-section")
            | "2" => focusElement("more-payment-methods", "use-existing-payment-methods")
            | _ => ()
            }
          }
        }->ignore
      | Unknown =>
        {
          Js.log("Unknown OS")
        }->ignore
      }->ignore
    }->ignore

  React.useEffect(() => {
    Window.addEventListenerDom("keydown", handleKeyDown)
    Some(
      () => {
        Window.removeEventListenerDom("keydown", handleKeyDown)
      },
    )
  }, [])

  children
}
