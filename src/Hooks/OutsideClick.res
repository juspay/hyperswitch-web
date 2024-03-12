external ffToDomType: {..} => Dom.node_like<'a> = "%identity"
@send external contains: (Dom.element, {..}) => bool = "contains"

type ref =
  | ArrayOfRef(array<React.ref<Js.Nullable.t<Dom.element>>>)
  | RefArray(React.ref<array<Js.Nullable.t<Dom.element>>>)

let useOutsideClick = (
  ~refs: ref,
  ~containerRefs: option<React.ref<Js.Nullable.t<Dom.element>>>=?,
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
          refs->Js.Array2.reduce((acc, ref: React.ref<Js.Nullable.t<Dom.element>>) => {
            let isClickInsideRef = switch ref.current->Js.Nullable.toOption {
            | Some(element) => element->contains(targ)
            | None => false
            }
            acc || isClickInsideRef
          }, false)
        | RefArray(refs) =>
          refs.current
          ->Js.Array2.slice(~start=0, ~end_=-1)
          ->Js.Array2.reduce((acc, ref: Js.Nullable.t<Dom.element>) => {
            let isClickInsideRef = switch ref->Js.Nullable.toOption {
            | Some(element) => element->contains(targ)
            | None => false
            }
            acc || isClickInsideRef
          }, false)
        }

        let isClickInsideOfContainer = switch containerRefs {
        | Some(ref) =>
          switch ref.current->Js.Nullable.toOption {
          | Some(element) => element->contains(targ)
          | None => false
          }
        | None => true
        }

        if !isInsideClick && isClickInsideOfContainer {
          eventCallback()
        }
      }

      Js.Global.setTimeout(() => {
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
