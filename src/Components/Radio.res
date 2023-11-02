@react.component
let make = (
  ~checked,
  ~height="15px",
  ~padding="36%",
  ~className="default",
  ~marginTop="0",
  ~opacity="100%",
  ~border="2px solid currentColor",
) => {
  let class = checked ? "active" : "inactive"
  let nonActiveOpacity = checked ? "100%" : opacity
  let css = `
  input[type="radio"] {
    -webkit-appearance: none;
    appearance: none;
    -moz-appearance: initial;
  }

  .${className}${class} input[type="radio"] {
    visibility: hidden;
}

.${className}${class} input[type="radio"]::before {
    border: ${border};
    height: ${height};
    width: ${height};
    border-radius: 50%;
    display: block;
    content: " ";
    opacity: ${nonActiveOpacity};
    cursor: pointer;
    visibility: visible;
    margin-top: ${marginTop};
}

.${className}${class} input[type="radio"]:checked::before {
    background: radial-gradient(currentColor ${padding}, transparent 32%);
}`
  <>
    <style> {React.string(css)} </style>
    <div className={`${className}${class} flex self-center`}>
      <input type_="radio" className="Radio" checked readOnly=true />
    </div>
  </>
}
