open CardThemeType
open Utils
open ErrorUtils

let getTheme = val => {
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
  ephemeralKey: "",
  pmClientSecret: "",
  pmSessionId: "",
  loader: Auto,
  sdkAuthorization: "",
}
type recoilConfig = {
  config: configClass,
  themeObj: themeClass,
  localeString: LocaleDataType.localeStrings,
  constantString: LocaleDataType.constantStrings,
  showLoader: bool,
}

@val external importJSON: string => promise<LocaleDataType.localeStrings> = "import"

let getLocaleObject = async string => {
  try {
    let locale = if string == "auto" {
      Window.Navigator.language
    } else {
      string
    }

    let promiseLocale = switch locale->LocaleDataType.localeStringToType {
      | Some(En) => importJSON("../shared-code/assets/v2/jsons/locales/en.json")
      | Some(He) => importJSON("../shared-code/assets/v2/jsons/locales/he.json")
      | Some(Fr) => importJSON("../shared-code/assets/v2/jsons/locales/fr.json")
      | Some(En_GB) => importJSON("../shared-code/assets/v2/jsons/locales/en-GB.json")
      | Some(Ar) => importJSON("../shared-code/assets/v2/jsons/locales/ar.json")
      | Some(Ja) => importJSON("../shared-code/assets/v2/jsons/locales/ja.json")
      | Some(De) => importJSON("../shared-code/assets/v2/jsons/locales/de.json")
      | Some(Fr_BE) => importJSON("../shared-code/assets/v2/jsons/locales/fr-BE.json")
      | Some(Es) => importJSON("../shared-code/assets/v2/jsons/locales/es.json")
      | Some(Ca) => importJSON("../shared-code/assets/v2/jsons/locales/ca.json")
      // | Some(Zh) => importJSON("../shared-code/assets/v2/jsons/locales/zh.json") // Pending support
      | Some(Pt) => importJSON("../shared-code/assets/v2/jsons/locales/pt.json")
      | Some(It) => importJSON("../shared-code/assets/v2/jsons/locales/it.json")
      | Some(Pl) => importJSON("../shared-code/assets/v2/jsons/locales/pl.json")
      | Some(Nl) => importJSON("../shared-code/assets/v2/jsons/locales/nl.json")
      | Some(NI_BE) => importJSON("../shared-code/assets/v2/jsons/locales/nl-BE.json") // to check
      | Some(Sv) => importJSON("../shared-code/assets/v2/jsons/locales/sv.json")
      | Some(Ru) => importJSON("../shared-code/assets/v2/jsons/locales/ru.json")
      // | Some(Zh_HANT) => importJSON("../shared-code/assets/v2/jsons/locales/zh-Hant.json") // Pending support
      | Some(Lt) => importJSON("../shared-code/assets/v2/jsons/locales/lt.json")
      | Some(Cs) => importJSON("../shared-code/assets/v2/jsons/locales/cs.json")
      | Some(Sk) => importJSON("../shared-code/assets/v2/jsons/locales/sk.json")
      | Some(Ls) => importJSON("../shared-code/assets/v2/jsons/locales/is.json") // to check
      | Some(Cy) => importJSON("../shared-code/assets/v2/jsons/locales/cy.json")
      | Some(El) => importJSON("../shared-code/assets/v2/jsons/locales/el.json")
      | Some(Et) => importJSON("../shared-code/assets/v2/jsons/locales/et.json")
      | Some(Fi) => importJSON("../shared-code/assets/v2/jsons/locales/fi.json")
      | Some(Nb) => importJSON("../shared-code/assets/v2/jsons/locales/no.json") // to check
      | Some(Bs) => importJSON("../shared-code/assets/v2/jsons/locales/bs.json")
      | Some(Da) => importJSON("../shared-code/assets/v2/jsons/locales/da.json")
      | Some(Ms) => importJSON("../shared-code/assets/v2/jsons/locales/ms.json")
      | Some(Tr_CY) => importJSON("../shared-code/assets/v2/jsons/locales/tr-CY.json")
      | None => importJSON("../shared-code/assets/v2/jsons/locales/en.json")
     }
    let awaitedLocaleValue = await promiseLocale
    awaitedLocaleValue
  } catch {
  | _ => LocaleDataType.defaultLocale
  }
}

let getConstantStringsObject = async () => {
  try {
    let promiseConstantStrings = Js.import(LocaleDataType.defaultConstantStrings)
    await promiseConstantStrings
  } catch {
  | _ => LocaleDataType.defaultConstantStrings
  }
}

let defaultRecoilConfig: recoilConfig = {
  config: defaultConfig,
  themeObj: defaultConfig.appearance.variables,
  localeString: LocaleDataType.defaultLocale,
  constantString: LocaleDataType.defaultConstantStrings,
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
      "buttonBorderWidth",
    ]
    unknownKeysWarning(validKeys, json, "appearance.variables")
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
      fontSize2Xl: getWarningString(json, "fontSize2Xl", default.fontSize2Xl, ~logger),
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
      buttonBorderWidth: getWarningString(
        json,
        "buttonBorderWidth",
        default.buttonBorderWidth,
        ~logger,
      ),
      disabledFieldColor: getWarningString(
        json,
        "disabledFieldColor",
        default.disabledFieldColor,
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
    unknownKeysWarning(["theme", "variables", "rules", "labels", "innerLayout"], json, "appearance")

    let rulesJson = defaultRules(getVariables("variables", json, default, logger))

    {
      theme: getWarningString(json, "theme", "default", ~logger)->getTheme,
      componentType: getWarningString(json, "componentType", "", ~logger),
      variables: getVariables("variables", json, default, logger),
      rules: mergeJsons(rulesJson, getJsonObjectFromDict(json, "rules")),
      innerLayout: getWarningString(json, "innerLayout", "spaced", ~logger)->getInnerLayout,
      labels: switch getWarningString(json, "labels", "above", ~logger)->String.toLowerCase {
      | "above" => Above
      | "floating" => Floating
      | "none" => Never
      | str => {
          str->unknownPropValueWarning(["above", "floating", "never"], "appearance.labels")
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
    unknownKeysWarning(["cssSrc", "family", "src", "weight"], json, "fonts")
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
    [
      "appearance",
      "fonts",
      "locale",
      "clientSecret",
      "loader",
      "ephemeralKey",
      "pmClientSecret",
      "pmSessionId",
      "sdkAuthorization",
    ],
    dict,
    "elements",
  )
  {
    appearance: getAppearance("appearance", dict, default, defaultRules, logger),
    locale: getWarningString(dict, "locale", "auto", ~logger),
    fonts: getFonts("fonts", dict, logger),
    clientSecret: getWarningString(dict, "clientSecret", "", ~logger),
    ephemeralKey: getWarningString(dict, "ephemeralKey", "", ~logger),
    pmSessionId: getWarningString(dict, "pmSessionId", "", ~logger),
    pmClientSecret: getWarningString(dict, "pmClientSecret", "", ~logger),
    loader: getWarningString(dict, "loader", "auto", ~logger)->getShowLoader,
    sdkAuthorization: getString(dict, "sdkAuthorization", ""),
  }
}
