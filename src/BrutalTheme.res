open CardThemeType
let brutal = {
  fontFamily: "Quicksand",
  fontSizeBase: "1rem",
  colorPrimary: "#f5fb1f",
  colorBackground: "#ffffff",
  colorText: "#000000",
  colorDanger: "#ff1a1a",
  colorDangerText: "#ff1a1a",
  borderRadius: "6px",
  fontVariantLigatures: "",
  fontVariationSettings: "",
  spacingUnit: "11px",
  fontWeightLight: "500",
  fontWeightNormal: "600",
  fontWeightMedium: "700",
  fontWeightBold: "800",
  fontLineHeight: "",
  fontSize2Xl: "24px",
  fontSizeXl: "16px",
  fontSizeLg: "14px",
  fontSizeSm: "12px",
  fontSizeXs: "10px",
  fontSize2Xs: "8px",
  fontSize3Xs: "6px",
  colorSuccess: "",
  colorWarning: "",
  colorPrimaryText: "#000000",
  colorBackgroundText: "#000000",
  colorSuccessText: "",
  colorWarningText: "",
  colorTextSecondary: "#e0e0e0",
  colorTextPlaceholder: "",
  spacingTab: "12px",
  borderColor: "#566186",
  spacingAccordionItem: "10px",
  colorIconCardCvc: "",
  colorIconCardCvcError: "#ff1a1a",
  colorIconCardError: "#ff1a1a",
  spacingGridColumn: "20px",
  spacingGridRow: "20px",
  buttonBackgroundColor: "#f5fb1f",
  buttonHeight: "48px",
  buttonWidth: "100%",
  buttonBorderRadius: "6px",
  buttonBorderColor: "#566186",
  buttonTextColor: "#000000",
  buttonTextFontSize: "16px",
  buttonTextFontWeight: "500",
  buttonBorderWidth: "0px",
}
let brutalRules = (theme: CardThemeType.themeClass) =>
  {
    ".Tab": {
      "border": `0.17em solid #000000`,
      "borderRadius": theme.borderRadius,
      "backgroundColor": theme.colorBackground,
      "color": theme.colorBackgroundText,
      "boxShadow": "0.15em 0.15em",
      "alignItems": "start",
      "transition": "background-color 50ms linear",
    },
    ".Tab:active": {
      "transform": "translate(0.05em, 0.05em)",
      "boxShadow": "0.02em 0.02em",
    },
    ".Tab--selected": {
      "border": `0.17em solid #000000`,
      "color": theme.colorBackgroundText,
      "backgroundColor": theme.colorPrimary,
    },
    ".Tab:hover": {
      "border": `0.17em solid #000000`,
    },
    ".TabMore:active": {
      "transform": "translate(0.05em, 0.05em)",
      "boxShadow": "0.02em 0.02em",
    },
    ".TabMore": {
      "border": `0.17em solid #000000`,
      "boxShadow": "0.15em 0.15em",
    },
    ".Label": {
      "color": `${theme.colorBackgroundText} !important`,
      "fontWeight": "500 !important",
      "textAlign": "left",
    },
    ".Input": {
      "border": `0.1em solid #000000`,
      "boxShadow": "0.12em 0.12em",
      "color": theme.colorText,
      "borderRadius": theme.borderRadius,
    },
    ".Input-Compressed": {
      "border": `0.1em solid #000000`,
      "boxShadow": "0.12em 0.12em",
      "color": theme.colorText,
    },
    ".Input:-webkit-autofill": {
      "transition": "background-color 5000s ease-in-out 0s",
      "-webkitTextFillColor": `${theme.colorText} !important`,
    },
    ".Input:focus": {
      "transform": "translate(0.05em, 0.05em)",
      "boxShadow": "0.02em 0.02em",
    },
    ".Input-Compressed:focus": {
      "transform": "translate(0.02em, 0.02em)",
      "boxShadow": "0.01em 0.01em",
    },
    ".Input--invalid": {
      "border": `0.1em solid ${theme.colorDangerText}`,
      "color": theme.colorDanger,
    },
    ".Input::placeholder": {
      "fontWeight": theme.fontWeightLight,
      "color": theme.colorTextPlaceholder,
    },
    ".TabLabel": {
      "transition": "color .1s ease",
      "textAlign": "start",
    },
    ".TabIcon": {
      "transition": "color .1s ease",
    },
    ".Block": {
      "backgroundColor": theme.colorBackground,
      "borderRadius": theme.borderRadius,
      "border": `0.17em solid #000000`,
      "boxShadow": "0.15em 0.15em",
    },
    ".BlockDivider": {
      "border": `1px solid ${theme.borderColor}`,
    },
    ".AccordionItem": {
      "borderWidth": "2px !important",
      "backgroundColor": theme.colorBackground,
      "color": theme.colorBackgroundText,
      "transition": "height 1s ease",
      "borderColor": `#000000 !important`,
    },
    ".AccordionMore": {
      "backgroundColor": theme.colorBackground,
      "color": theme.colorBackgroundText,
      "border": `2px solid #000000`,
    },
    ".AccordionMore:active": {
      "transform": "translate(0.05em, 0.05em)",
      "boxShadow": "0.02em 0.02em",
    },
    ".AccordionItem--selected": {
      "color": theme.colorBackgroundText,
      "transition": "height 1s ease",
    },
    ".AccordionItemLabel": {
      "transition": "color .1s ease",
    },
    ".AccordionItemLabel--selected": {
      "color": theme.colorText,
    },
    ".PickerItem": {
      "border": `0.17em solid #000000`,
      "boxShadow": "0.15em 0.15em",
      "backgroundColor": theme.colorBackground,
      "color": `${theme.colorText} !important`,
      "padding": theme.spacingUnit,
      "borderRadius": theme.borderRadius,
    },
    ".PickerItem--selected": {
      "border": `0.17em solid #000000`,
      "boxShadow": "0.15em 0.15em",
      "color": `${theme.colorText} !important`,
      "backgroundColor": theme.colorPrimary,
    },
    ".Checkbox": {
      "fontWeight": theme.fontWeightLight,
      "fontSize": theme.fontSizeLg,
    },
    ".CheckboxInput": {
      "borderColor": "black !important",
    },
    ".CheckboxInput--checked": {
      "borderColor": "black !important",
      "borderTopColor": "transparent !important",
      "borderLeftColor": "transparent !important",
    },
    ".PaymentMethodsHeaderLabel": {
      "color": theme.colorText,
      "fontSize": theme.fontSize2Xl,
      "fontWeight": theme.fontWeightMedium,
      "marginBottom": "1.5rem",
    },
  }->Identity.anyTypeToJson

let default = brutal
let defaultRules = brutalRules
