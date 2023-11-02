@react.component
let make = (
  ~name,
  ~size=20,
  ~width=size,
  ~className=?,
  ~iconType="orca",
  ~onClick=?,
  ~style=ReactDOMStyle.make(),
  ~shouldMirrorIcon=false,
) => {
  let otherClasses = switch className {
  | Some(str) => str
  | None => ""
  }

  <svg
    ?onClick
    style
    className={`fill-current ${otherClasses}`}
    width={string_of_int(width) ++ "px"}
    height={string_of_int(size) ++ "px"}
    transform={shouldMirrorIcon ? "scale(-1,1)" : ""}>
    <use xlinkHref={`${GlobalVars.repoPublicPath}/icons/${iconType}.svg#${name}`} />
  </svg>
}
