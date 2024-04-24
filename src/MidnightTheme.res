open CardThemeType
let midnight = {
  fontFamily: "Quicksand",
  fontSizeBase: "1rem",
  colorPrimary: "#85d996",
  colorBackground: "#30313d",
  colorText: "#e0e0e0",
  colorDanger: "#fe87a1",
  colorDangerText: "#fe87a1",
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
  colorPrimaryText: "#000000",
  colorBackgroundText: "#ffffffe0",
  colorSuccessText: "",
  colorWarningText: "",
  colorTextSecondary: "#ffffff",
  colorTextPlaceholder: "",
  spacingTab: "12px",
  borderColor: "#424353",
  spacingAccordionItem: "10px",
  colorIconCardCvc: "",
  colorIconCardCvcError: "#fe87a1",
  colorIconCardError: "#fd1717",
  spacingGridColumn: "20px",
  spacingGridRow: "20px",
  buttonBackgroundColor: "#85d996",
  buttonHeight: "48px",
  buttonWidth: "100%",
  buttonBorderRadius: "6px",
  buttonBorderColor: "#85d996",
  buttonTextColor: "#000000",
  buttonTextFontSize: "16px",
  buttonTextFontWeight: "500",
}

let midnightRules = theme =>
  {
    ".Tab": {
      "border": `1px solid ${theme.borderColor}`,
      "borderRadius": theme.borderRadius,
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
      "alignItems": "start",
      "transition": "background .15s ease, border .15s ease, box-shadow .15s ease",
      "boxShadow": "0px 2px 4px rgb(0 0 0 / 2%), 0px 1px 6px rgb(0 0 0 / 3%)",
    },
    ".Tab--selected": {
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorPrimaryText,
      "backgroundColor": theme.colorPrimary,
      "boxShadow": `0px 1px 1px rgba(0, 0, 0, 0.03), 0px 3px 6px rgba(18, 42, 66, 0.02), 0 0 0 2px ${theme.colorPrimary}`,
    },
    ".Tab--selected:hover": {
      "border": `1px solid ${theme.colorPrimary}`,
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
      "boxShadow": "0px 2px 4px rgb(0 0 0 / 50%), 0px 1px 6px rgb(0 0 0 / 25%)",
    },
    ".Label": {
      "color": "#ffffff",
      "textAlign": "left",
    },
    ".Button": {
      "marginTop": theme.spacingUnit,
      "marginBottom": theme.spacingUnit,
      "padding": "3px",
      "width": "fit-content",
      "height": "30px",
      "borderRadius": theme.borderRadius,
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorPrimary,
    },
    ".Input": {
      "border": `1px solid #424353`,
      "borderRadius": theme.borderRadius,
      "color": "#ffffff",
      "boxShadow": `0px 2px 4px rgb(0 0 0 / 50%), 0px 1px 6px rgb(0 0 0 / 25%)`,
      "transition": "background 0.15s ease, border 0.15s ease, box-shadow 0.15s ease, color 0.15s ease",
    },
    ".Input-Compressed": {
      "border": `1px solid #424353`,
      "color": "#ffffff",
      "boxShadow": `0px 2px 4px rgb(0 0 0 / 50%), 0px 1px 6px rgb(0 0 0 / 25%)`,
      "transition": "background 0.15s ease, border 0.15s ease, box-shadow 0.15s ease, color 0.15s ease",
    },
    ".Input:-webkit-autofill": {
      "transition": "background-color 5000s ease-in-out 0s",
      "-webkitTextFillColor": "#ffffff !important",
    },
    ".Input:focus": {
      "border": `1px solid ${theme.colorPrimary}`,
      "boxShadow": `${theme.colorPrimary}4c 0px 0px 0px 3px`,
    },
    ".Input-Compressed:focus": {
      "border": `1px solid ${theme.colorPrimary}`,
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
      "border": `1px solid ${theme.borderColor}`,
    },
    ".BlockDivider": {
      "border": `1px solid ${theme.borderColor}`,
    },
    ".AccordionItem": {
      "backgroundColor": theme.colorBackground,
      "transition": "height 1s ease",
      "color": "#e0e0e0",
      "boxShadow": "0px 2px 4px rgb(0 0 0 / 50%), 0px 1px 6px rgb(0 0 0 / 25%)",
    },
    ".AccordionItem:hover": {
      "color": theme.colorTextSecondary,
    },
    ".AccordionMore": {
      "backgroundColor": theme.colorBackground,
      "color": theme.colorTextSecondary,
      "border": `1px solid ${theme.borderColor}`,
    },
    ".AccordionMore:hover": {
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
      "transition": "height 1s ease",
      "color": "#e0e0e0",
      "padding": theme.spacingUnit,
      "borderRadius": theme.borderRadius,
      "border": `1px solid ${theme.borderColor}`,
    },
    ".PickerItem:hover": {
      "color": theme.colorTextSecondary,
    },
    ".PickerItem--selected": {
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorPrimaryText,
      "backgroundColor": theme.colorPrimary,
      "boxShadow": `0px 1px 1px rgba(0, 0, 0, 0.03), 0px 3px 6px rgba(18, 42, 66, 0.02), 0 0 0 2px ${theme.colorPrimary}`,
    },
    ".PickerItem--selected:hover": {
      "border": `1px solid ${theme.colorPrimary}`,
      "color": theme.colorPrimaryText,
      "backgroundColor": theme.colorPrimary,
      "boxShadow": `0px 1px 1px rgba(0, 0, 0, 0.03), 0px 3px 6px rgba(18, 42, 66, 0.02), 0 0 0 2px ${theme.colorPrimary}`,
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

let default = midnight
let defaultRules = midnightRules
