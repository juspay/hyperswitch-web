// ConsoleSuppress.res

@module("./ClickToPayConsoleSuppressHelpers.js")
external setupConsoleSuppress: (array<string>, array<'a> => bool) => unit = "setupConsoleSuppress"

let suppressPatterns = [
  ">>>>",
  "<<<<<<<<",
  "loadPartnerNetworks ::",
  "queryParam? >>",
  "----------------",
  "!!!!!!!!!!!",
  "Requested CardNetworks >>",
  "MASTERCARD SDK loaded successfully",
  "VISA SDK loaded successfully",
  "::>>",
  "apiResponseCache",
  "All sdks are loaded successfully",
  "getCardsInput",
  ">>,",
]

let shouldSuppress = (args: array<'a>): bool => {
  let message = args->Obj.magic->Array.join(" ")
  suppressPatterns->Array.some(pattern => message->String.includes(pattern))
}

let initialize = () => {
  setupConsoleSuppress(suppressPatterns, shouldSuppress)
}
