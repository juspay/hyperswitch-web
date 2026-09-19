open CardThemeType
open Utils
open ErrorUtils

let getTheme = (val): theme => {
  switch val->String.toLowerCase {
  | "default" => Default
  | "brutal" => Brutal
  | "midnight" => Midnight
  | "charcoal" => Charcoal
  | "soft" => Soft
  | "bubblegum" => Bubblegum
  | "none" => NONE
  | str => {
      str->unknownPropValueWarning(
        ["default", "midnight", "brutal", "charcoal", "soft", "bubblegum", "none"],
        "appearance.theme",
      )
      Default
    }
  }
}

let getInnerLayout = str => {
  switch str {
  | "compressed" => Compressed
  | _ => Spaced
  }
}

let getColorScheme = (str): colorScheme => {
  switch str->String.toLowerCase {
  | "auto" => Auto
  | "dark" => Dark
  | "light" => Light
  | str =>
    str->unknownPropValueWarning(["light", "dark", "auto"], "appearance.colorScheme")
    Light
  }
}

let setColorSchemeMeta = (colorScheme: colorScheme) => {
  open Window
  let meta = switch querySelector(`meta[name="color-scheme"]`)->Nullable.toOption {
  | Some(el) => el
  | None =>
    let el = createElement("meta")
    el->setAttribute("name", "color-scheme")
    head->appendChildElement(el)
    el
  }
  let colorSchemeVal = switch colorScheme {
  | Auto => "light dark"
  | Dark => "dark"
  | Light => "light"
  }
  meta->setAttribute("content", colorSchemeVal)
}

let getShowLoader = str => {
  switch str {
  | "auto" => Auto
  | "always" => Always
  | "never" => Never
  | str => {
      str->unknownPropValueWarning(["auto", "always", "never"], "loader")
      Auto
    }
  }
}

let defaultAppearance = {
  theme: Default,
  variables: DefaultTheme.default,
  componentType: "payment",
  labels: Above,
  rules: Dict.make()->JSON.Encode.object,
  innerLayout: Spaced,
  colorScheme: Light,
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
  pmSessionId: "",
  loader: Auto,
  sdkAuthorization: "",
}
type jotaiConfig = {
  config: configClass,
  themeObj: themeClass,
  localeString: LocaleStringTypes.localeStrings,
  constantString: LocaleStringTypes.constantStrings,
  showLoader: bool,
}

let getLocaleObject = async string => {
  try {
    let locale = if string == "auto" {
      Window.Navigator.language
    } else {
      string
    }

    let promiseLocale = switch locale->LocaleStringHelper.mapLocalStringToTypeLocale {
    | EN => import(EnglishLocale.localeStrings)
    | HE => import(HebrewLocale.localeStrings)
    | FR => import(FrenchLocale.localeStrings)
    | EN_GB => import(EnglishGBLocale.localeStrings)
    | AR => import(ArabicLocale.localeStrings)
    | JA => import(JapaneseLocale.localeStrings)
    | DE => import(DeutschLocale.localeStrings)
    | FR_BE => import(FrenchBelgiumLocale.localeStrings)
    | FR_CA => import(FrenchCanadianLocale.localeStrings)
    | ES => import(SpanishLocale.localeStrings)
    | CA => import(CatalanLocale.localeStrings)
    | ZH => import(ChineseLocale.localeStrings)
    | PT => import(PortugueseLocale.localeStrings)
    | IT => import(ItalianLocale.localeStrings)
    | PL => import(PolishLocale.localeStrings)
    | NL => import(DutchLocale.localeStrings)
    | SV => import(SwedishLocale.localeStrings)
    | RU => import(RussianLocale.localeStrings)
    | ZH_HANT => import(TraditionalChineseLocale.localeStrings)
    | DA => import(DanishLocale.localeStrings)
    | LT => import(LithuanianLocale.localeStrings)
    | CS => import(CzechLocale.localeStrings)
    | SK => import(SlovakLocale.localeStrings)
    | IS => import(IcelandicLocale.localeStrings)
    | CY => import(WelshLocale.localeStrings)
    | EL => import(GreekLocale.localeStrings)
    | ET => import(EstonianLocale.localeStrings)
    | FI => import(FinnishLocale.localeStrings)
    | NB => import(NorwegianLocale.localeStrings)
    | BS => import(BosnianLocale.localeStrings)
    | MS => import(MalayLocale.localeStrings)
    | TR_CY => import(TurkishLocale.localeStrings)
    }

    let awaitedLocaleValue = await promiseLocale
    awaitedLocaleValue
  } catch {
  | _ => EnglishLocale.localeStrings
  }
}

let getConstantStringsObject = async () => {
  try {
    let promiseConstantStrings = import(ConstantStrings.constantStrings)
    await promiseConstantStrings
  } catch {
  | _ => ConstantStrings.constantStrings
  }
}

let defaultJotaiConfig: jotaiConfig = {
  config: defaultConfig,
  themeObj: defaultConfig.appearance.variables,
  localeString: EnglishLocale.localeStrings,
  constantString: ConstantStrings.constantStrings,
  showLoader: false,
}

let getVariables = (str, dict, default) => {
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
      "buttonBorderWidth",
      "inputFieldHeight",
    ]
    unknownKeysWarning(validKeys, json, "appearance.variables")
    {
      fontFamily: getWarningString(json, "fontFamily", default.fontFamily),
      fontSizeBase: getWarningString(json, "fontSizeBase", default.fontSizeBase),
      colorPrimary: getWarningString(json, "colorPrimary", default.colorPrimary),
      colorBackground: getWarningString(json, "colorBackground", default.colorBackground),
      colorText: getWarningString(json, "colorText", default.colorText),
      colorDanger: getWarningString(json, "colorDanger", default.colorDanger),
      colorDangerText: getWarningString(json, "colorDangerText", default.colorDangerText),
      borderRadius: getWarningString(json, "borderRadius", default.borderRadius),
      fontVariantLigatures: getWarningString(
        json,
        "fontVariantLigatures",
        default.fontVariantLigatures,
      ),
      fontVariationSettings: getWarningString(
        json,
        "fontVariationSettings",
        default.fontVariationSettings,
      ),
      spacingUnit: getWarningString(json, "spacingUnit", default.spacingUnit),
      fontWeightLight: getWarningString(json, "fontWeightLight", default.fontWeightLight),
      fontWeightNormal: getWarningString(json, "fontWeightNormal", default.fontWeightNormal),
      fontWeightMedium: getWarningString(json, "fontWeightMedium", default.fontWeightMedium),
      fontWeightBold: getWarningString(json, "fontWeightBold", default.fontWeightBold),
      fontLineHeight: getWarningString(json, "fontLineHeight", default.fontLineHeight),
      fontSize2Xl: getWarningString(json, "fontSize2Xl", default.fontSize2Xl),
      fontSizeXl: getWarningString(json, "fontSizeXl", default.fontSizeXl),
      fontSizeLg: getWarningString(json, "fontSizeLg", default.fontSizeLg),
      fontSizeSm: getWarningString(json, "fontSizeSm", default.fontSizeSm),
      fontSizeXs: getWarningString(json, "fontSizeXs", default.fontSizeXs),
      fontSize2Xs: getWarningString(json, "fontSize2Xs", default.fontSize2Xs),
      fontSize3Xs: getWarningString(json, "fontSize3Xs", default.fontSize3Xs),
      colorSuccess: getWarningString(json, "colorSuccess", default.colorSuccess),
      colorWarning: getWarningString(json, "colorWarning", default.colorWarning),
      colorPrimaryText: getWarningString(json, "colorPrimaryText", default.colorPrimaryText),
      colorBackgroundText: getWarningString(
        json,
        "colorBackgroundText",
        default.colorBackgroundText,
      ),
      colorSuccessText: getWarningString(json, "colorSuccessText", default.colorSuccessText),
      colorWarningText: getWarningString(json, "colorWarningText", default.colorWarningText),
      colorTextSecondary: getWarningString(json, "colorTextSecondary", default.colorTextSecondary),
      colorTextPlaceholder: getWarningString(
        json,
        "colorTextPlaceholder",
        default.colorTextPlaceholder,
      ),
      spacingTab: getWarningString(json, "spacingTab", default.spacingTab),
      borderColor: getWarningString(json, "borderColor", default.borderColor),
      colorIconCardCvc: getWarningString(json, "colorIconCardCvc", default.colorIconCardCvc),
      colorIconCardCvcError: getWarningString(
        json,
        "colorIconCardCvcError",
        default.colorIconCardCvcError,
      ),
      colorIconCardError: getWarningString(json, "colorIconCardError", default.colorIconCardError),
      spacingAccordionItem: getWarningString(
        json,
        "spacingAccordionItem",
        default.spacingAccordionItem,
      ),
      spacingGridColumn: getWarningString(json, "spacingGridColumn", default.spacingGridColumn),
      spacingGridRow: getWarningString(json, "spacingGridRow", default.spacingGridRow),
      buttonBackgroundColor: getWarningString(
        json,
        "buttonBackgroundColor",
        default.buttonBackgroundColor,
      ),
      buttonHeight: getWarningString(json, "buttonHeight", default.buttonHeight),
      buttonWidth: getWarningString(json, "buttonWidth", default.buttonWidth),
      buttonBorderRadius: getWarningString(json, "buttonBorderRadius", default.buttonBorderRadius),
      buttonBorderColor: getWarningString(json, "buttonBorderColor", default.buttonBorderColor),
      buttonTextColor: getWarningString(json, "buttonTextColor", default.buttonTextColor),
      buttonTextFontSize: getWarningString(json, "buttonTextFontSize", default.buttonTextFontSize),
      buttonTextFontWeight: getWarningString(
        json,
        "buttonTextFontWeight",
        default.buttonTextFontWeight,
      ),
      inputFieldHeight: getWarningString(json, "inputFieldHeight", default.inputFieldHeight),
      buttonBorderWidth: getWarningString(json, "buttonBorderWidth", default.buttonBorderWidth),
      disabledFieldColor: getWarningString(json, "disabledFieldColor", default.disabledFieldColor),
    }
  })
  ->Option.getOr(default)
}

let getAppearance = (
  str,
  dict,
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => JSON.t,
) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.object)
  ->Option.map(json => {
    unknownKeysWarning(
      ["theme", "variables", "rules", "labels", "innerLayout", "colorScheme"],
      json,
      "appearance",
    )

    let rulesJson = defaultRules(getVariables("variables", json, default))

    {
      theme: getWarningString(json, "theme", "default")->getTheme,
      componentType: getWarningString(json, "componentType", ""),
      variables: getVariables("variables", json, default),
      rules: mergeJsons(rulesJson, getJsonObjectFromDict(json, "rules")),
      innerLayout: getWarningString(json, "innerLayout", "spaced")->getInnerLayout,
      labels: switch getWarningString(json, "labels", "above")->String.toLowerCase {
      | "above" => Above
      | "floating" => Floating
      | "none" => Never
      | str => {
          str->unknownPropValueWarning(["above", "floating", "never"], "appearance.labels")
          Above
        }
      },
      colorScheme: getWarningString(json, "colorScheme", "light")->getColorScheme,
    }
  })
  ->Option.getOr(defaultAppearance)
}
let getFonts = (str, dict) => {
  dict
  ->Dict.get(str)
  ->Option.flatMap(JSON.Decode.array)
  ->Option.getOr([])
  ->Array.filterMap(JSON.Decode.object)
  ->Array.map(json => {
    unknownKeysWarning(["cssSrc", "family", "src", "weight"], json, "fonts")
    {
      cssSrc: getWarningString(json, "cssSrc", ""),
      family: getWarningString(json, "family", ""),
      src: getWarningString(json, "src", ""),
      weight: getWarningString(json, "weight", ""),
    }
  })
}
let itemToObjMapper = (
  dict,
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => JSON.t,
) => {
  unknownKeysWarning(
    ["appearance", "fonts", "locale", "clientSecret", "loader", "pmSessionId", "sdkAuthorization"],
    dict,
    "elements",
  )
  {
    appearance: getAppearance("appearance", dict, default, defaultRules),
    locale: getWarningString(dict, "locale", "auto"),
    fonts: getFonts("fonts", dict),
    clientSecret: getWarningString(dict, "clientSecret", ""),
    pmSessionId: getWarningString(dict, "pmSessionId", ""),
    loader: getWarningString(dict, "loader", "auto")->getShowLoader,
    sdkAuthorization: getString(dict, "sdkAuthorization", ""),
  }
}
