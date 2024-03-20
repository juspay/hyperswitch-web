open CardThemeType
open Utils
open ErrorUtils

let getTheme = (val, logger) => {
  switch val {
  | "default" => Default
  | "brutal" => Brutal
  | "midnight" => Midnight
  | "charcoal" => Charcoal
  | "soft" => Soft
  | "none" => NONE
  | str => {
      str->unknownPropValueWarning(
        ["default", "midnight", "brutal", "charcoal", "soft", "none"],
        "appearance.theme",
        ~logger,
      )
      Default
    }
  }
}
let getShowLoader = (str, logger) => {
  switch str {
  | "auto" => Auto
  | "always" => Always
  | "never" => Never
  | str => {
      str->unknownPropValueWarning(["auto", "always", "never"], "loader", ~logger)
      Auto
    }
  }
}

let getPaymentMode = val => {
  switch val {
  | "card" => Card
  | "payment" => Payment
  | "cardNumber" => CardNumberElement
  | "cardExpiry" => CardExpiryElement
  | "cardCvc" => CardCVCElement
  | _ => NONE
  }
}

let defaultAppearance = {
  theme: Default,
  variables: DefaultTheme.default,
  componentType: "payment",
  labels: Above,
  rules: Dict.make()->JSON.Encode.object,
}
let defaultFonts = {
  cssSrc: "",
  family: "",
  src: "",
  weight: "",
}
let defaultConfig = {
  appearance: defaultAppearance,
  locale: "auto",
  fonts: [],
  clientSecret: "",
  loader: Auto,
}
type recoilConfig = {
  config: configClass,
  themeObj: themeClass,
  localeString: LocaleString.localeStrings,
  showLoader: bool,
}
let getLocaleObject = string => {
  let val = if string == "auto" {
    navigator["language"]
  } else {
    string
  }
  LocaleString.localeStrings
  ->Array.filter(item => item.locale == val)
  ->Array.get(0)
  ->Option.getOr(LocaleString.defaultLocale)
}
let defaultRecoilConfig: recoilConfig = {
  config: defaultConfig,
  themeObj: defaultConfig.appearance.variables,
  localeString: getLocaleObject(defaultConfig.locale),
  showLoader: false,
}

let getVariables = (str, dict, default, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    let validKeys = [
      "fontFamily",
      "fontSizeBase",
      "colorPrimary",
      "colorBackground",
      "colorText",
      "colorDanger",
      "colorDangerText",
      "borderRadius",
      "fontVariantLigatures",
      "fontVariationSettings",
      "spacingUnit",
      "fontWeightLight",
      "fontWeightNormal",
      "fontWeightMedium",
      "fontWeightBold",
      "fontLineHeight",
      "fontSizeXl",
      "fontSizeLg",
      "fontSizeSm",
      "fontSizeXs",
      "fontSize2Xs",
      "fontSize3Xs",
      "colorSuccess",
      "colorWarning",
      "colorPrimaryText",
      "colorBackgroundText",
      "colorSuccessText",
      "colorWarningText",
      "colorTextSecondary",
      "colorTextPlaceholder",
      "spacingTab",
      "borderColor",
      "spacingGridColumn",
      "spacingGridRow",
      "spacingAccordionItem",
      "buttonBackgroundColor",
      "buttonHeight",
      "buttonWidth",
      "buttonBorderRadius",
      "buttonBorderColor",
      "buttonTextColor",
      "buttonTextFontSize",
      "buttonTextFontWeight",
    ]
    unknownKeysWarning(validKeys, json, "appearance.variables", ~logger)
    {
      fontFamily: getWarningString(json, "fontFamily", default.fontFamily, ~logger),
      fontSizeBase: getWarningString(json, "fontSizeBase", default.fontSizeBase, ~logger),
      colorPrimary: getWarningString(json, "colorPrimary", default.colorPrimary, ~logger),
      colorBackground: getWarningString(json, "colorBackground", default.colorBackground, ~logger),
      colorText: getWarningString(json, "colorText", default.colorText, ~logger),
      colorDanger: getWarningString(json, "colorDanger", default.colorDanger, ~logger),
      colorDangerText: getWarningString(json, "colorDangerText", default.colorDangerText, ~logger),
      borderRadius: getWarningString(json, "borderRadius", default.borderRadius, ~logger),
      fontVariantLigatures: getWarningString(
        json,
        "fontVariantLigatures",
        default.fontVariantLigatures,
        ~logger,
      ),
      fontVariationSettings: getWarningString(
        json,
        "fontVariationSettings",
        default.fontVariationSettings,
        ~logger,
      ),
      spacingUnit: getWarningString(json, "spacingUnit", default.spacingUnit, ~logger),
      fontWeightLight: getWarningString(json, "fontWeightLight", default.fontWeightLight, ~logger),
      fontWeightNormal: getWarningString(
        json,
        "fontWeightNormal",
        default.fontWeightNormal,
        ~logger,
      ),
      fontWeightMedium: getWarningString(
        json,
        "fontWeightMedium",
        default.fontWeightMedium,
        ~logger,
      ),
      fontWeightBold: getWarningString(json, "fontWeightBold", default.fontWeightBold, ~logger),
      fontLineHeight: getWarningString(json, "fontLineHeight", default.fontLineHeight, ~logger),
      fontSizeXl: getWarningString(json, "fontSizeXl", default.fontSizeXl, ~logger),
      fontSizeLg: getWarningString(json, "fontSizeLg", default.fontSizeLg, ~logger),
      fontSizeSm: getWarningString(json, "fontSizeSm", default.fontSizeSm, ~logger),
      fontSizeXs: getWarningString(json, "fontSizeXs", default.fontSizeXs, ~logger),
      fontSize2Xs: getWarningString(json, "fontSize2Xs", default.fontSize2Xs, ~logger),
      fontSize3Xs: getWarningString(json, "fontSize3Xs", default.fontSize3Xs, ~logger),
      colorSuccess: getWarningString(json, "colorSuccess", default.colorSuccess, ~logger),
      colorWarning: getWarningString(json, "colorWarning", default.colorWarning, ~logger),
      colorPrimaryText: getWarningString(
        json,
        "colorPrimaryText",
        default.colorPrimaryText,
        ~logger,
      ),
      colorBackgroundText: getWarningString(
        json,
        "colorBackgroundText",
        default.colorBackgroundText,
        ~logger,
      ),
      colorSuccessText: getWarningString(
        json,
        "colorSuccessText",
        default.colorSuccessText,
        ~logger,
      ),
      colorWarningText: getWarningString(
        json,
        "colorWarningText",
        default.colorWarningText,
        ~logger,
      ),
      colorTextSecondary: getWarningString(
        json,
        "colorTextSecondary",
        default.colorTextSecondary,
        ~logger,
      ),
      colorTextPlaceholder: getWarningString(
        json,
        "colorTextPlaceholder",
        default.colorTextPlaceholder,
        ~logger,
      ),
      spacingTab: getWarningString(json, "spacingTab", default.spacingTab, ~logger),
      borderColor: getWarningString(json, "borderColor", default.borderColor, ~logger),
      colorIconCardCvc: getWarningString(
        json,
        "colorIconCardCvc",
        default.colorIconCardCvc,
        ~logger,
      ),
      colorIconCardCvcError: getWarningString(
        json,
        "colorIconCardCvcError",
        default.colorIconCardCvcError,
        ~logger,
      ),
      colorIconCardError: getWarningString(
        json,
        "colorIconCardError",
        default.colorIconCardError,
        ~logger,
      ),
      spacingAccordionItem: getWarningString(
        json,
        "spacingAccordionItem",
        default.spacingAccordionItem,
        ~logger,
      ),
      spacingGridColumn: getWarningString(
        json,
        "spacingGridColumn",
        default.spacingGridColumn,
        ~logger,
      ),
      spacingGridRow: getWarningString(json, "spacingGridRow", default.spacingGridRow, ~logger),
      buttonBackgroundColor: getWarningString(
        json,
        "buttonBackgroundColor",
        default.buttonBackgroundColor,
        ~logger,
      ),
      buttonHeight: getWarningString(json, "buttonHeight", default.buttonHeight, ~logger),
      buttonWidth: getWarningString(json, "buttonWidth", default.buttonWidth, ~logger),
      buttonBorderRadius: getWarningString(
        json,
        "buttonBorderRadius",
        default.buttonBorderRadius,
        ~logger,
      ),
      buttonBorderColor: getWarningString(
        json,
        "buttonBorderColor",
        default.buttonBorderColor,
        ~logger,
      ),
      buttonTextColor: getWarningString(json, "buttonTextColor", default.buttonTextColor, ~logger),
      buttonTextFontSize: getWarningString(
        json,
        "buttonTextFontSize",
        default.buttonTextFontSize,
        ~logger,
      ),
      buttonTextFontWeight: getWarningString(
        json,
        "buttonTextFontWeight",
        default.buttonTextFontWeight,
        ~logger,
      ),
    }
  })
  ->Option.getOr(default)
}

let getAppearance = (
  str,
  dict,
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => JSON.t,
  logger,
) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(["theme", "variables", "rules", "labels"], json, "appearance", ~logger)

    let rulesJson = defaultRules(getVariables("variables", json, default, logger))

    {
      theme: getWarningString(json, "theme", "default", ~logger)->getTheme(logger),
      componentType: getWarningString(json, "componentType", "", ~logger),
      variables: getVariables("variables", json, default, logger),
      rules: mergeJsons(rulesJson, getJsonObjectFromDict(json, "rules")),
      labels: switch getWarningString(json, "labels", "above", ~logger) {
      | "above" => Above
      | "floating" => Floating
      | "none" => Never
      | str => {
          str->unknownPropValueWarning(["above", "floating", "never"], "appearance.labels", ~logger)
          Above
        }
      },
    }
  })
  ->Option.getOr(defaultAppearance)
}
let getFonts = (str, dict, logger) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Belt.Array.keepMap(JSON.Decode.object)
  ->Array.map(json => {
    unknownKeysWarning(["cssSrc", "family", "src", "weight"], json, "fonts", ~logger)
    {
      cssSrc: getWarningString(json, "cssSrc", "", ~logger),
      family: getWarningString(json, "family", "", ~logger),
      src: getWarningString(json, "src", "", ~logger),
      weight: getWarningString(json, "weight", "", ~logger),
    }
  })
}
let itemToObjMapper = (
  dict,
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => JSON.t,
  logger,
) => {
  unknownKeysWarning(
    ["appearance", "fonts", "locale", "clientSecret", "loader"],
    dict,
    "elements",
    ~logger,
  )
  {
    appearance: getAppearance("appearance", dict, default, defaultRules, logger),
    locale: getWarningString(dict, "locale", "auto", ~logger),
    fonts: getFonts("fonts", dict, logger),
    clientSecret: getWarningString(dict, "clientSecret", "", ~logger),
    loader: getWarningString(dict, "loader", "auto", ~logger)->getShowLoader(logger),
  }
}
