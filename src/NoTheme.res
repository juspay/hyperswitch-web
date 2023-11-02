open CardThemeType

let nakedValues = {
  fontFamily: "",
  fontSizeBase: "1rem",
  colorPrimary: "",
  colorBackground: "",
  colorText: "",
  colorDanger: "",
  colorDangerText: "",
  borderRadius: "",
  fontVariantLigatures: "",
  fontVariationSettings: "",
  spacingUnit: "10px",
  fontWeightLight: "",
  fontWeightNormal: "",
  fontWeightMedium: "",
  fontWeightBold: "",
  fontLineHeight: "",
  fontSizeXl: "",
  fontSizeLg: "",
  fontSizeSm: "",
  fontSizeXs: "",
  fontSize2Xs: "",
  fontSize3Xs: "",
  colorSuccess: "",
  colorWarning: "",
  colorPrimaryText: "",
  colorBackgroundText: "",
  colorSuccessText: "",
  colorWarningText: "",
  colorTextSecondary: "",
  colorTextPlaceholder: "",
  spacingTab: "10px",
  borderColor: "",
  spacingAccordionItem: "10px",
  colorIconCardCvc: "#fd1717",
  colorIconCardCvcError: "",
  colorIconCardError: "#fd1717",
  spacingGridColumn: "20px",
  spacingGridRow: "20px",
}

let nakedValuesRules = _ => Js.Dict.empty()->Js.Json.object_

let default = nakedValues
let defaultRules = nakedValuesRules
