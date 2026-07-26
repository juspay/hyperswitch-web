// A field/validation error that is both visually rendered and announced to
// screen readers (role="alert" + assertive, atomic live region).
//
// Renders only the inner alert <div>: callers keep their own conditional-render
// wrapper (the render condition is not always text-based), and pass the matching
// `id` (for aria-describedby linkage from the input), `className`, and `style`.
// `id` defaults to "" → the id attribute is omitted (byte-identical to a div with
// no id); `style` is optional and omitted when not provided.
@react.component
let make = (~text: string, ~className: string, ~style: option<JsxDOM.style>=?, ~id: string="") => {
  let elementId = id == "" ? None : Some(id)
  <div id=?elementId role="alert" ariaLive={#assertive} ariaAtomic=true className ?style>
    {React.string(text)}
  </div>
}
