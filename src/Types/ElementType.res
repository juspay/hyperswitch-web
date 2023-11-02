open ErrorUtils
type classes = {
  base: string,
  complete: string,
  empty: string,
  focus: string,
  invalid: string,
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
  base: Js.Json.t,
  complete: Js.Json.t,
  empty: Js.Json.t,
  invalid: Js.Json.t,
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
}
let getIconStyle = (str, logger) => {
  switch str {
  | "default" => Default
  | "solid" => Solid
  | str => {
      str->unknownPropValueWarning(["default", "solid"], "options.iconStyle", ~logger)
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
  base: Js.Dict.empty()->Js.Json.object_,
  complete: Js.Dict.empty()->Js.Json.object_,
  empty: Js.Dict.empty()->Js.Json.object_,
  invalid: Js.Dict.empty()->Js.Json.object_,
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
}
let getClasses = (str, dict, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      base: getWarningString(json, "base", "OrcaElement", ~logger),
      complete: getWarningString(json, "complete", "OrcaElement--complete", ~logger),
      empty: getWarningString(json, "empty", "OrcaElement--empty", ~logger),
      focus: getWarningString(json, "focus", "OrcaElement--focus", ~logger),
      invalid: getWarningString(json, "invalid", "OrcaElement--invalid", ~logger),
      webkitAutofill: getWarningString(
        json,
        "webkitAutofill",
        "OrcaElement--webkit-autofill",
        ~logger,
      ),
    }
  })
  ->Belt.Option.getWithDefault(defaultClasses)
}

let rec getStyleObj = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      backgroundColor: getWarningString(json, "backgroundColor", "", ~logger),
      color: getWarningString(json, "color", "", ~logger),
      fontFamily: getWarningString(json, "fontFamily", "", ~logger),
      fontSize: getWarningString(json, "fontSize", "", ~logger),
      fontSmoothing: getWarningString(json, "fontSmoothing", "", ~logger),
      fontStyle: getWarningString(json, "fontStyle", "", ~logger),
      fontVariant: getWarningString(json, "fontVariant", "", ~logger),
      fontWeight: getWarningString(json, "fontWeight", "", ~logger),
      iconColor: getWarningString(json, "iconColor", "", ~logger),
      lineHeight: getWarningString(json, "lineHeight", "", ~logger),
      letterSpacing: getWarningString(json, "letterSpacing", "", ~logger),
      textAlign: getWarningString(json, "textAlign", "", ~logger),
      padding: getWarningString(json, "padding", "", ~logger),
      textDecoration: getWarningString(json, "textDecoration", "", ~logger),
      textShadow: getWarningString(json, "textShadow", "", ~logger),
      textTransform: getWarningString(json, "textTransform", "", ~logger),
      placeholder: Some(getStyleObj(json, "::placeholder", logger)),
      hover: Some(getStyleObj(json, ":hover", logger)),
      focus: Some(getStyleObj(json, ":focus", logger)),
      selection: Some(getStyleObj(json, "::selection", logger)),
      webkitAutofill: Some(getStyleObj(json, ":-webkit-autofill", logger)),
      disabled: Some(getStyleObj(json, ":disabled", logger)),
      msClear: Some(getStyleObj(json, "::-ms-clear", logger)),
    }
  })
  ->Belt.Option.getWithDefault(defaultStyleClass)
}
let getTheme = (str, key, logger) => {
  switch str {
  | "dark" => Dark
  | "light" => Light
  | "light-outline" => LightOutline
  | str => {
      str->unknownPropValueWarning(["dark", "light", "light-outline"], key, ~logger)
      Dark
    }
  }
}
let getPaymentRequestButton = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      type_: getWarningString(json, "type", "", ~logger),
      theme: getWarningString(json, "theme", "dark", ~logger)->getTheme(
        "elements.options.style.paymentRequestButton.theme",
        logger,
      ),
      height: getWarningString(json, "height", "", ~logger),
    }
  })
  ->Belt.Option.getWithDefault(defaultPaymentRequestButton)
}

let getStyle = (dict, str, logger) => {
  dict
  ->Js.Dict.get(str)
  ->Belt.Option.flatMap(Js.Json.decodeObject)
  ->Belt.Option.map(json => {
    {
      base: getJsonObjectFromDict(json, "base"),
      complete: getJsonObjectFromDict(json, "complete"),
      empty: getJsonObjectFromDict(json, "empty"),
      invalid: getJsonObjectFromDict(json, "invalid"),
      paymentRequestButton: getPaymentRequestButton(json, "paymentRequestButton", logger),
    }
  })
  ->Belt.Option.getWithDefault(defaultStyle)
}
let itemToObjMapper = (dict, logger) => {
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
    ],
    dict,
    "options",
    ~logger,
  )

  {
    classes: getClasses("classes", dict, logger),
    style: getStyle(dict, "style", logger),
    value: getWarningString(dict, "value", "", ~logger),
    hidePostalCode: getBoolWithWarning(dict, "hidePostalCode", false, ~logger),
    iconStyle: getWarningString(dict, "iconStyle", "default", ~logger)->getIconStyle(logger),
    hideIcon: getBoolWithWarning(dict, "hideIcon", false, ~logger),
    showIcon: getBoolWithWarning(dict, "showIcon", false, ~logger),
    disabled: getBoolWithWarning(dict, "disabled", false, ~logger),
  }
}
