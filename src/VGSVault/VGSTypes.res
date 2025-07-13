type vgsFieldCss = {
  // Add your CSS properties here
  // Example:
  // fontSize?: string,
  // color?: string,
  // etc.
}

module VGS = {
  type serializer
  type separateOptions = {
    monthName: string,
    yearName: string,
  }

  @val @scope("vault.SERIALIZERS")
  external separate: separateOptions => serializer = "separate"
}

type fieldOptions = {
  @as("type") type_: string,
  name: string,
  placeholder: string,
  validations: array<string>,
  showCardIcon?: bool,
  successColor?: string,
  errorColor?: string,
  css?: vgsFieldCss,
  yearLength?: int,
  serializers?: array<VGS.serializer>,
}

type field = {on: (string, JSON.t => unit) => unit}

type vgsCollect = {
  field: (string, fieldOptions) => field,
  submit: (string, JSON.t, (JSON.t, JSON.t) => unit, JSON.t => unit) => unit,
}

type expiryFields = {
  month: string,
  year: string,
}

@val
external create: (string, string, JSON.t => unit) => vgsCollect = "VGSCollect.create"
