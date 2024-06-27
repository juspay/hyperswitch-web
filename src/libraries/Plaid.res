// * For Documentation - https://plaid.com/docs/link/web/

type createArgs = {
  token: string,
  onSuccess: (string, JSON.t) => unit,
  onLoad?: unit => unit,
  onExit?: JSON.t => unit,
  onEvent?: JSON.t => unit,
}

type createReturn = {
  @as("open") open_: unit => unit,
  exit: unit => unit,
  destroy: unit => unit,
  submit: unit => unit,
}

@val @scope(("window", "Plaid"))
external create: createArgs => createReturn = "create"

@val @scope(("window", "Plaid"))
external version: string = "version"
