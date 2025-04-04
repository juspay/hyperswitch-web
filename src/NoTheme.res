open CardThemeType

let noThemeValues = {
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
  fontSize2Xl: "",
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
  buttonBackgroundColor: "",
  buttonHeight: "48px",
  buttonWidth: "100%",
  buttonBorderRadius: "6px",
  buttonBorderColor: "",
  buttonTextColor: "",
  buttonTextFontSize: "16px",
  buttonTextFontWeight: "500",
  buttonBorderWidth: "0px",
  disabledFieldColor: "",
}

let noThemeValuesRules = _ => Dict.make()->JSON.Encode.object

let default = noThemeValues
let defaultRules = noThemeValuesRules
