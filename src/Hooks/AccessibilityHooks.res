type fieldAccessibility = {
  inputId: string,
  errorId: string,
  hasError: bool,
}

let useFieldAccessibility = (~id="", ~errorString="") => {
  let reactId = React.useId()
  {
    inputId: id->String.length > 0 ? id : `input${reactId}`,
    errorId: `error${reactId}`,
    hasError: errorString->String.length > 0,
  }
}
