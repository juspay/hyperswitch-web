open CardThemeType
let default = {
  fontFamily: "",
  fontSizeBase: "1rem",
  colorPrimary: "#006df9",
  colorBackground: "#ffffff",
  colorText: "#545454",
  colorDanger: "#fd1717",
  colorDangerText: "#fd1717",
  borderRadius: "4px",
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
  colorPrimaryText: "#5469d4",
  colorBackgroundText: "",
  colorSuccessText: "",
  colorWarningText: "",
  colorTextSecondary: "#6d6e78",
  colorTextPlaceholder: "",
  spacingTab: "12px",
  borderColor: "#e6e6e6",
  spacingAccordionItem: "10px",
  colorIconCardCvc: "",
  colorIconCardCvcError: "#fd1717",
  colorIconCardError: "#fd1717",
  spacingGridColumn: "20px",
  spacingGridRow: "20px",
  buttonBackgroundColor: "#006df9",
  buttonHeight: "48px",
  buttonWidth: "100%",
  buttonBorderRadius: "6px",
  buttonBorderColor: "#ffffff",
  buttonTextColor: "#ffffff",
  buttonTextFontSize: "16px",
  buttonTextFontWeight: "500",
}
let defaultRules = theme =>
  {
    ".Tab": {
      "border": `1px solid ${theme.borderColor}`,
      "borderRadius": theme.borderRadius,
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
      "alignItems": "start",
      "transition": "background .15s ease, border .15s ease, box-shadow .15s ease",
      "boxShadow": "0px 1px 1px rgb(0 0 0 / 3%), 0px 3px 6px rgb(0 0 0 / 2%)",
    },
    ".Tab:hover": {
      "color": theme.colorText,
    },
    ".Label": {
      "color": theme.colorText,
      "opacity": "10",
      "textAlign": "left",
    },
    ".Tab--selected": {
      "color": theme.colorPrimary,
      "boxShadow": `0px 1px 1px rgba(0, 0, 0, 0.03), 0px 3px 6px rgba(18, 42, 66, 0.02), 0 0 0 2px ${theme.colorPrimary}`,
    },
    ".Tab--selected:hover": {
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorPrimary,
      "boxShadow": `0px 1px 1px rgba(0, 0, 0, 0.03), 0px 3px 6px rgba(18, 42, 66, 0.02), 0 0 0 2px ${theme.colorPrimary}`,
    },
    ".Tab--selected:focus": {
      "border": `2px solid ${theme.colorPrimary}`,
      "borderColor": theme.colorPrimary,
      "boxShadow": `0 0 0 2px ${theme.colorPrimary}4c, 0 1px 1px 0 ${theme.colorBackground}, 0 0 0 1px ${theme.colorPrimary}4c`,
    },
    ".TabMore:focus": {
      "border": `1px solid ${theme.colorPrimary}`,
      "boxShadow": `${theme.colorPrimary}4c 0px 0px 0px 3px`,
    },
    ".TabMore": {
      "border": `1px solid ${theme.borderColor}`,
    },
    ".Input": {
      "border": `1px solid #e6e6e6`,
      "color": theme.colorText,
      "fontWeight": theme.fontWeightLight,
      "borderRadius": theme.borderRadius,
      "boxShadow": `0px 1px 1px rgb(0 0 0 / 3%), 0px 3px 6px rgb(0 0 0 / 2%)`,
      "transition": "background 0.15s ease, border 0.15s ease, box-shadow 0.15s ease, color 0.15s ease",
    },
    ".Input:-webkit-autofill": {
      "transition": "background-color 5000s ease-in-out 0s",
      "-webkitTextFillColor": `${theme.colorText} !important`,
    },
    ".Input:focus": {
      "border": `1px solid ${theme.colorPrimary}`,
      "boxShadow": `${theme.colorPrimary}4c 0px 0px 0px 3px`,
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
      "border": `1px solid ${theme.borderColor}`,
    },
    ".BlockDivider": {
      "border": `1px solid ${theme.borderColor}`,
    },
    ".AccordionItem": {
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
      "transition": "height 1s ease",
      "boxShadow": "0px 1px 1px rgb(0 0 0 / 3%), 0px 3px 6px rgb(0 0 0 / 2%)",
    },
    ".AccordionMore": {
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
      "border": `1px solid ${theme.borderColor}`,
    },
    ".AccordionMore:hover": {
      "color": theme.colorText,
    },
    ".AccordionItem:hover": {
      "color": theme.colorText,
    },
    ".AccordionItem--selected": {
      "color": theme.colorPrimary,
    },
    ".AccordionItem--selected:hover": {
      "color": theme.colorPrimary,
    },
    ".AccordionItemLabel": {
      "transition": "color .1s ease",
    },
    ".AccordionItemLabel--selected": {
      "color": theme.colorPrimary,
    },
    ".AccordionItemIcon--selected": {
      "color": theme.colorPrimary,
    },
    ".PickerItem": {
      "backgroundColor": theme.colorBackground,
      "borderRadius": theme.borderRadius,
      "border": `1px solid ${theme.borderColor}`,
      "color": theme.colorTextSecondary,
      "padding": theme.spacingUnit,
      "transition": "height 1s ease",
      "boxShadow": "0px 1px 1px rgb(0 0 0 / 3%), 0px 3px 6px rgb(0 0 0 / 2%)",
    },
    ".PickerItem:hover": {
      "color": theme.colorText,
    },
    ".PickerItem--selected": {
      "color": theme.colorPrimary,
      "border": `1px solid ${theme.colorPrimary}`,
      "boxShadow": `${theme.colorPrimary}4c 0px 0px 0px 3px`,
    },
    ".PickerItem--selected:hover": {
      "color": theme.colorPrimary,
      "border": `1px solid ${theme.colorPrimary}`,
      "boxShadow": `${theme.colorPrimary}4c 0px 0px 0px 3px`,
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

let default = default
let defaultRules = defaultRules
