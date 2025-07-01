type vgsFieldCss

type fieldOptions = {
  \"type": string,
  name: string,
  placeholder: string,
  validations: array<string>,
  showCardIcon?: bool,
  successColor?: string,
  errorColor?: string,
  css?: vgsFieldCss,
}

type field = {on: (string, JSON.t => unit) => unit}

type returnValue = {
  field: (string, fieldOptions) => field,
  submit: (string, JSON.t, (JSON.t, JSON.t) => unit, JSON.t => unit) => unit,
}

@send
external field: (string, fieldOptions) => unit = "field"

@val
external create: (string, string, JSON.t => unit) => returnValue = "VGSCollect.create"
