external ffToDomType: {..} => Dom.node_like<'a> = "%identity"
@send external contains: (Dom.element, {..}) => bool = "contains"

type ref =
  | ArrayOfRef(array<React.ref<Nullable.t<Dom.element>>>)
  | RefArray(React.ref<array<Nullable.t<Dom.element>>>)

let useOutsideClick = (
  ~refs: ref,
  ~containerRefs: option<React.ref<Nullable.t<Dom.element>>>=?,
  ~isActive,
  ~events=["click"],
  ~callback,
  (),
) => {
  let useEvent0 = callback => {
    let callbackRef = React.useRef(callback)
    React.useEffect1(() => {
      callbackRef.current = callback

      None
    }, [callback])

    React.useCallback0(() => {
      callbackRef.current()
    })
  }
  let eventCallback = useEvent0(callback)
  React.useEffect1(() => {
    if isActive {
      let handleClick = (e: ReactEvent.Mouse.t) => {
        let targ = e->ReactEvent.Mouse.target

        let isInsideClick = switch refs {
        | ArrayOfRef(refs) =>
          refs->Array.reduce(false, (acc, ref: React.ref<Nullable.t<Dom.element>>) => {
            let isClickInsideRef = switch ref.current->Nullable.toOption {
            | Some(element) => element->contains(targ)
            | None => false
            }
            acc || isClickInsideRef
          })
        | RefArray(refs) =>
          refs.current
          ->Array.slice(~start=0, ~end=-1)
          ->Array.reduce(false, (acc, ref: Nullable.t<Dom.element>) => {
            let isClickInsideRef = switch ref->Nullable.toOption {
            | Some(element) => element->contains(targ)
            | None => false
            }
            acc || isClickInsideRef
          })
        }

        let isClickInsideOfContainer = switch containerRefs {
        | Some(ref) =>
          switch ref.current->Nullable.toOption {
          | Some(element) => element->contains(targ)
          | None => false
          }
        | None => true
        }

        if !isInsideClick && isClickInsideOfContainer {
          eventCallback()
        }
      }

      setTimeout(() => {
        events->Array.forEach(
          event => {
            Window.addEventListener(event, handleClick)
          },
        )
      }, 50)->ignore

      Some(
        () => {
          events->Array.forEach(event => {
            Window.removeEventListener(event, handleClick)
          })
        },
      )
    } else {
      None
    }
  }, [isActive])
}
