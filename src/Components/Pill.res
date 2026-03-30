@react.component
let make = (~text, ~bgColor, ~textColor, ~fontSize, ~fontWeight) => {
  <span
    style={
      backgroundColor: bgColor,
      color: textColor,
      fontSize,
      fontWeight,
      padding: "1px 6px",
      borderRadius: "3px",
      width: "fit-content",
    }>
    {text->React.string}
  </span>
}
