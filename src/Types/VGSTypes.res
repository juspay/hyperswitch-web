// VGSTypes
// Type bindings for the VGS Collect.js SDK (https://js.verygoodvault.com).
// VGS renders each card field inside its own secure iframe; `create` returns a
// form handle exposing `field` (mount a secure field) and `submit` (tokenise).

// CSS-in-JS style object applied to the input inside a VGS secure field iframe.
// VGS expects standard (kebab-case) CSS property names, so this is a JSON object.
type vgsFieldCss = JSON.t

type fieldOptions = {
  \"type": string,
  name: string,
  placeholder: string,
  validations: array<string>,
  showCardIcon?: bool,
  successColor?: string,
  errorColor?: string,
  yearLength?: int,
  css?: vgsFieldCss,
}

// A mounted secure field. `on` subscribes to field events (focus/blur/update).
type field = {on: (string, JSON.t => unit) => unit}

// The form handle returned by VGSCollect.create.
type returnValue = {
  field: (string, fieldOptions) => field,
  submit: (string, JSON.t, (JSON.t, JSON.t) => unit, JSON.t => unit) => unit,
}

// VGSCollect.create(vaultId, environment, stateChangeCallback)
@val
external create: (string, string, JSON.t => unit) => returnValue = "VGSCollect.create"
