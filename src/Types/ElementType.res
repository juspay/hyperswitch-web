open ErrorUtils
type classes = {
  base: string,
  complete: string,
  empty: string,
  focus: string,
  invalid: string,
  valid: string,
  webkitAutofill: string,
}
type rec styleClass = {
  backgroundColor: string,
  color: string,
  fontFamily: string,
  fontSize: string,
  fontSmoothing: string,
  fontStyle: string,
  fontVariant: string,
  fontWeight: string,
  iconColor: string,
  lineHeight: string,
  letterSpacing: string,
  textAlign: string,
  padding: string,
  textDecoration: string,
  textShadow: string,
  textTransform: string,
  hover: option<styleClass>,
  focus: option<styleClass>,
  selection: option<styleClass>,
  webkitAutofill: option<styleClass>,
  disabled: option<styleClass>,
  msClear: option<styleClass>,
  placeholder: option<styleClass>,
}
type theme = Dark | Light | LightOutline
type iconStyle = Default | Solid
type paymentRequestButtonStyle = {
  type_: string,
  theme: theme,
  height: string,
}
type style = {
  base: JSON.t,
  complete: JSON.t,
  empty: JSON.t,
  invalid: JSON.t,
  paymentRequestButton: paymentRequestButtonStyle,
}
type options = {
  classes: classes,
  style: style,
  value: string,
  hidePostalCode: bool,
  iconStyle: iconStyle,
  hideIcon: bool,
  showIcon: bool,
  disabled: bool,
  placeholder: string,
  showError: bool,
}
let getIconStyle = str => {
  switch str {
  | "default" => Default
  | "solid" => Solid
  | str => {
      str->unknownPropValueWarning(["default", "solid"], "options.iconStyle")
      Default
    }
  }
}
open Utils
let defaultClasses = {
  base: "OrcaElement",
  complete: "OrcaElement--complete",
  empty: "OrcaElement--empty",
  focus: "OrcaElement--focus",
  invalid: "OrcaElement--invalid",
  valid: "OrcaElement--valid",
  webkitAutofill: "OrcaElement--webkit-autofill",
}
let defaultStyleClass = {
  backgroundColor: "",
  color: "",
  fontFamily: "",
  fontSize: "",
  fontSmoothing: "",
  fontStyle: "",
  fontVariant: "",
  fontWeight: "",
  iconColor: "",
  lineHeight: "",
  letterSpacing: "",
  textAlign: "",
  padding: "",
  textDecoration: "",
  textShadow: "",
  textTransform: "",
  hover: None,
  focus: None,
  placeholder: None,
  selection: None,
  webkitAutofill: None,
  disabled: None,
  msClear: None,
}
let defaultPaymentRequestButton = {
  type_: "default",
  theme: Dark,
  height: "",
}
let defaultStyle = {
  base: Dict.make()->JSON.Encode.object,
  complete: Dict.make()->JSON.Encode.object,
  empty: Dict.make()->JSON.Encode.object,
  invalid: Dict.make()->JSON.Encode.object,
  paymentRequestButton: defaultPaymentRequestButton,
}
let defaultOptions = {
  classes: defaultClasses,
  style: defaultStyle,
  value: "",
  hidePostalCode: false,
  iconStyle: Default,
  hideIcon: false,
  showIcon: false,
  disabled: false,
  placeholder: "",
  showError: true,
}
let getClasses = (str, dict) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      base: getWarningString(json, "base", "OrcaElement"),
      complete: getWarningString(json, "complete", "OrcaElement--complete"),
      empty: getWarningString(json, "empty", "OrcaElement--empty"),
      focus: getWarningString(json, "focus", "OrcaElement--focus"),
      invalid: getWarningString(json, "invalid", "OrcaElement--invalid"),
      valid: getWarningString(json, "valid", "OrcaElement--valid"),
      webkitAutofill: getWarningString(json, "webkitAutofill", "OrcaElement--webkit-autofill"),
    }
  })
  ->Option.getOr(defaultClasses)
}

let rec getStyleObj = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      backgroundColor: getWarningString(json, "backgroundColor", ""),
      color: getWarningString(json, "color", ""),
      fontFamily: getWarningString(json, "fontFamily", ""),
      fontSize: getWarningString(json, "fontSize", ""),
      fontSmoothing: getWarningString(json, "fontSmoothing", ""),
      fontStyle: getWarningString(json, "fontStyle", ""),
      fontVariant: getWarningString(json, "fontVariant", ""),
      fontWeight: getWarningString(json, "fontWeight", ""),
      iconColor: getWarningString(json, "iconColor", ""),
      lineHeight: getWarningString(json, "lineHeight", ""),
      letterSpacing: getWarningString(json, "letterSpacing", ""),
      textAlign: getWarningString(json, "textAlign", ""),
      padding: getWarningString(json, "padding", ""),
      textDecoration: getWarningString(json, "textDecoration", ""),
      textShadow: getWarningString(json, "textShadow", ""),
      textTransform: getWarningString(json, "textTransform", ""),
      placeholder: Some(getStyleObj(json, "::placeholder")),
      hover: Some(getStyleObj(json, ":hover")),
      focus: Some(getStyleObj(json, ":focus")),
      selection: Some(getStyleObj(json, "::selection")),
      webkitAutofill: Some(getStyleObj(json, ":-webkit-autofill")),
      disabled: Some(getStyleObj(json, ":disabled")),
      msClear: Some(getStyleObj(json, "::-ms-clear")),
    }
  })
  ->Option.getOr(defaultStyleClass)
}
let getTheme = (str, key) => {
  switch str {
  | "dark" => Dark
  | "light" => Light
  | "light-outline" => LightOutline
  | str => {
      str->unknownPropValueWarning(["dark", "light", "light-outline"], key)
      Dark
    }
  }
}
let getPaymentRequestButton = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      type_: getWarningString(json, "type", ""),
      theme: getWarningString(json, "theme", "dark")->getTheme(
        "elements.options.style.paymentRequestButton.theme",
      ),
      height: getWarningString(json, "height", ""),
    }
  })
  ->Option.getOr(defaultPaymentRequestButton)
}

let getStyle = (dict, str) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    {
      base: getJsonObjectFromDict(json, "base"),
      complete: getJsonObjectFromDict(json, "complete"),
      empty: getJsonObjectFromDict(json, "empty"),
      invalid: getJsonObjectFromDict(json, "invalid"),
      paymentRequestButton: getPaymentRequestButton(json, "paymentRequestButton"),
    }
  })
  ->Option.getOr(defaultStyle)
}
let itemToObjMapper = dict => {
  unknownKeysWarning(
    [
      "classes",
      "style",
      "value",
      "hidePostalCode",
      "iconStyle",
      "hideIcon",
      "showIcon",
      "disabled",
      "placeholder",
      "showError",
    ],
    dict,
    "options",
  )

  {
    classes: getClasses("classes", dict),
    style: getStyle(dict, "style"),
    value: getWarningString(dict, "value", ""),
    hidePostalCode: getBoolWithWarning(dict, "hidePostalCode", false),
    iconStyle: getWarningString(dict, "iconStyle", "default")->getIconStyle,
    hideIcon: getBoolWithWarning(dict, "hideIcon", false),
    showIcon: getBoolWithWarning(dict, "showIcon", false),
    disabled: getBoolWithWarning(dict, "disabled", false),
    placeholder: getWarningString(dict, "placeholder", ""),
    showError: getBoolWithWarning(dict, "showError", true),
  }
}
