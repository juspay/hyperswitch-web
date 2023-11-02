external ffToDomType: Dom.eventTarget => Dom.node_like<'a> = "%identity"
external ffToWebDom: Js.Nullable.t<Dom.element> => Js.Nullable.t<Webapi.Dom.Element.t> = "%identity"
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
      let handleClick = (e: Dom.event) => {
        let targ = Webapi.Dom.Event.target(e)

        let isInsideClick = switch refs {
        | ArrayOfRef(refs) =>
          refs->Js.Array2.reduce((acc, ref: React.ref<Js.Nullable.t<Dom.element>>) => {
            let isClickInsideRef = switch ffToWebDom(ref.current)->Js.Nullable.toOption {
            | Some(element) => Webapi.Dom.Element.contains(ffToDomType(targ), element)
            | None => false
            }
            acc || isClickInsideRef
          }, false)
        | RefArray(refs) =>
          refs.current
          ->Js.Array2.slice(~start=0, ~end_=-1)
          ->Js.Array2.reduce((acc, ref: Js.Nullable.t<Dom.element>) => {
            let isClickInsideRef = switch ffToWebDom(ref)->Js.Nullable.toOption {
            | Some(element) => Webapi.Dom.Element.contains(ffToDomType(targ), element)
            | None => false
            }
            acc || isClickInsideRef
          }, false)
        }

        let isClickInsideOfContainer = switch containerRefs {
        | Some(ref) =>
          switch ffToWebDom(ref.current)->Js.Nullable.toOption {
          | Some(element) => Webapi.Dom.Element.contains(ffToDomType(targ), element)
          | None => false
          }
        | None => true
        }

        if !isInsideClick && isClickInsideOfContainer {
          eventCallback()
        }
      }

      Js.Global.setTimeout(() => {
        events->Js.Array2.forEach(event => {
          Webapi.Dom.Window.addEventListener(event, handleClick, Webapi.Dom.window)
        })
      }, 50)->ignore

      Some(
        () => {
          events->Js.Array2.forEach(event =>
            Webapi.Dom.Window.removeEventListener(event, handleClick, Webapi.Dom.window)
          )
        },
      )
    } else {
      None
    }
  }, [isActive])
}
