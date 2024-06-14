open CardThemeType
let charcoal = {
  fontFamily: "Quicksand",
  fontSizeBase: "1rem",
  colorPrimary: "#000000",
  colorBackground: "#f0f3f5",
  colorText: "#000000",
  colorDanger: "#df1b41",
  colorDangerText: "#df1b41",
  borderRadius: "10px",
  fontVariantLigatures: "",
  fontVariationSettings: "",
  spacingUnit: "11px",
  fontWeightLight: "400",
  fontWeightNormal: "500",
  fontWeightMedium: "600",
  fontWeightBold: "700",
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
  colorPrimaryText: "#707070",
  colorBackgroundText: "#ffffff",
  colorSuccessText: "",
  colorWarningText: "",
  colorTextSecondary: "#6d6e78",
  colorTextPlaceholder: "",
  spacingTab: "12px",
  borderColor: "#000000",
  spacingAccordionItem: "10px",
  colorIconCardCvc: "",
  colorIconCardCvcError: "#fd1717",
  colorIconCardError: "#fd1717",
  spacingGridColumn: "20px",
  spacingGridRow: "20px",
  buttonBackgroundColor: "#000000",
  buttonHeight: "48px",
  buttonWidth: "100%",
  buttonBorderRadius: "6px",
  buttonBorderColor: "#000000",
  buttonTextColor: "#ffffff",
  buttonTextFontSize: "16px",
  buttonTextFontWeight: "500",
  buttonBorderWidth: "0px",
}

let charcoalRules = theme =>
  {
    ".Tab": {
      "border": `1px solid ${theme.colorBackground}`,
      "alignItems": "start",
      "borderRadius": theme.borderRadius,
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
    },
    ".Tab--selected": {
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorBackgroundText,
      "backgroundColor": theme.colorPrimary,
    },
    ".Tab:hover": {
      "border": `1px solid ${theme.colorBackground}`,
      "color": theme.colorText,
    },
    ".Tab--selected:hover": {
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorBackgroundText,
      "backgroundColor": theme.colorPrimary,
    },
    ".TabMore:focus": {
      "border": `1px solid ${theme.colorPrimary}`,
      "boxShadow": `${theme.colorPrimary}4c 0px 0px 0px 3px`,
    },
    ".TabMore": {
      "border": `1px solid ${theme.colorBackground}`,
    },
    ".Label": {
      "color": theme.colorText,
      "textAlign": "left",
    },
    ".Input": {
      "border": `1px solid ${theme.colorBackground}`,
      "fontWeight": theme.fontWeightLight,
      "color": theme.colorText,
      "borderRadius": theme.borderRadius,
    },
    ".Input-Compressed": {
      "border": `1px solid ${theme.colorBackground}`,
      "fontWeight": theme.fontWeightLight,
      "color": theme.colorText,
    },
    ".Input:-webkit-autofill": {
      "transition": "background-color 5000s ease-in-out 0s",
      "-webkitTextFillColor": `${theme.colorText} !important`,
    },
    ".Input:focus": {
      "border": `1px solid ${theme.colorPrimary}`,
      "boxShadow": `${theme.colorPrimary}4c 0px 0px 0px 3px`,
    },
    ".Input-Compressed:focus": {
      "border": `2px solid ${theme.colorPrimary}`,
      "boxShadow": `${theme.colorPrimary}4c 0px 0px 0px 2px`,
      "position": "relative",
      "zIndex": "2",
    },
    ".Input--invalid": {
      "color": theme.colorDanger,
      "border": `2px solid ${theme.colorDanger}`,
      "transition": "border 0.15s ease, box-shadow 0.15s ease, color 0.15s ease",
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
    },
    ".BlockDivider": {
      "border": `1px solid ${theme.borderColor}`,
    },
    ".AccordionItem": {
      "border": "1px solid #ffffff !important",
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
      "transition": "height 1s ease",
    },
    ".AccordionMore": {
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
    },
    ".AccordionMore:hover": {
      "color": theme.colorText,
    },
    ".AccordionItem:hover": {
      "color": theme.colorText,
    },
    ".AccordionItem--selected": {
      "color": theme.colorText,
      "transition": "height 1s ease",
    },
    ".AccordionItemLabel": {
      "transition": "color .1s ease",
    },
    ".AccordionItemLabel--selected": {
      "color": theme.colorText,
    },
    ".AccordionItemIcon--selected": {
      "color": theme.colorText,
    },
    ".PickerItem": {
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
      "transition": "height 1s ease",
      "padding": theme.spacingUnit,
      "borderRadius": theme.borderRadius,
      "borderColor": "#00000040 !important",
    },
    ".PickerItem:hover": {
      "color": theme.colorText,
    },
    ".PickerItem--selected": {
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorBackgroundText,
      "backgroundColor": theme.colorPrimary,
    },
    ".PickerItem--selected:hover": {
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorBackgroundText,
      "backgroundColor": theme.colorPrimary,
    },
    ".Checkbox": {
      "fontWeight": theme.fontWeightLight,
      "fontSize": theme.fontSizeLg,
    },
    ".PaymentMethodsHeaderLabel": {
      "color": theme.colorText,
      "fontSize": theme.fontSize2Xl,
      "fontWeight": theme.fontWeightMedium,
      "marginBottom": "1.5rem",
    },
  }->Identity.anyTypeToJson

let default = charcoal
let defaultRules = charcoalRules
