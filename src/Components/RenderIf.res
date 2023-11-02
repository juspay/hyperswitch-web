@react.component
let make = (~condition: bool, ~children: React.element) => {
  if condition {
    children
  } else {
    React.null
  }
}
