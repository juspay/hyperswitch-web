open CardThemeType

let soft = {
  fontFamily: "Quicksand",
  fontSizeBase: "1rem",
  colorPrimary: "#7d8fff",
  colorBackground: "#3c3d3e",
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
  colorTextSecondary: "",
  colorTextPlaceholder: "",
  spacingTab: "15px",
  borderColor: "#566186",
  spacingAccordionItem: "10px",
  colorIconCardCvc: "",
  colorIconCardCvcError: "#fe87a1",
  colorIconCardError: "#fe87a1",
  spacingGridColumn: "20px",
  spacingGridRow: "20px",
  buttonBackgroundColor: "#3c3d3e",
  buttonHeight: "48px",
  buttonWidth: "100%",
  buttonBorderRadius: "6px",
  buttonBorderColor: "#7d8fff",
  buttonTextColor: "#7d8fff",
  buttonTextFontSize: "16px",
  buttonTextFontWeight: "500",
}

let softRules = theme =>
  {
    ".Tab": {
      "borderRadius": theme.borderRadius,
      "alignItems": "start",
      "padding": "12px 10px 9px 14px !important",
      "color": theme.colorTextSecondary,
      "transition": "background .15s ease, border .15s ease, box-shadow .15s ease",
      "boxShadow": `4px 4px 5px #353637, -4px -4px 5px #434445`,
    },
    ".Tab--selected": {
      "color": theme.colorPrimary,
      "background": "linear-gradient(340deg, #3d3d3d, #383838)",
      "boxShadow": "inset 7px 8px 7px #353637, inset -5px -4px 7px #434445",
    },
    ".TabMore": {
      "boxShadow": `4px 4px 5px #353637, -4px -4px 5px #434445`,
    },
    ".Tab--selected:hover": {
      "boxShadow": "inset 7px 8px 7px #353637, inset -5px -4px 7px #434445",
    },
    ".Tab--selected:focus": {
      "borderColor": theme.colorPrimary,
      "boxShadow": "inset 7px 8px 7px #353637, inset -5px -4px 7px #434445",
    },
    ".Label": {
      "color": theme.colorText,
      "textAlign": "left",
    },
    ".Input": {
      "borderRadius": theme.borderRadius,
      "color": theme.colorText,
      "boxShadow": `inset 4px 4px 5px #353637, inset -4px -3px 7px #434445`,
      "transition": "background 0.15s ease, border 0.15s ease, box-shadow 0.15s ease, color 0.15s ease",
    },
    ".Input-Compressed": {
      "color": theme.colorText,
      "boxShadow": `inset 4px 4px 5px #353637, inset -4px -3px 7px #434445`,
      "transition": "background 0.15s ease, border 0.15s ease, box-shadow 0.15s ease, color 0.15s ease",
    },
    ".Input:-webkit-autofill": {
      "transition": "background-color 5000s ease-in-out 0s",
      "-webkitTextFillColor": `${theme.colorText} !important`,
    },
    ".Input:focus": {
      "boxShadow": `inset 8px 7px 7px #353637, inset -8px -6px 7px #434445`,
    },
    ".Input-Compressed:focus": {
      "boxShadow": `inset 8px 7px 7px #353637, inset -8px -6px 7px #434445`,
    },
    ".Input--invalid": {
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
      "borderRadius": theme.borderRadius,
      "color": theme.colorTextSecondary,
      "transition": "background .15s ease, border .15s ease, box-shadow .15s ease",
      "boxShadow": "inset 7px 8px 7px #353637, inset -5px -4px 7px #434445",
    },
    ".BlockDivider": {
      "borderRadius": theme.borderRadius,
      "padding": "2px !important",
      "color": theme.colorTextSecondary,
      "transition": "background .15s ease, border .15s ease, box-shadow .15s ease",
      "background": "#3d3d3d",
      "boxShadow": `2px 2px 1px #353637, -2px -2px 1px #434445`,
      "opacity": "80%",
    },
    ".AccordionItem": {
      "border": "1px solid transparent !important",
      "margin": "3px",
      "color": theme.colorTextSecondary,
      "transition": "background .15s ease, border .15s ease, box-shadow .15s ease",
      "boxShadow": `4px 4px 5px #353637, -4px -4px 5px #434445`,
    },
    ".AccordionItem--selected": {
      "color": theme.colorPrimary,
      "transition": "height 1s ease",
    },
    ".AccordionItem--selected:hover": {
      "boxShadow": "inset 7px 8px 7px #353637, inset -5px -4px 7px #434445",
    },
    ".AccordionMore": {
      "color": theme.colorTextSecondary,
      "transition": "background .15s ease, border .15s ease, box-shadow .15s ease",
      "boxShadow": `4px 4px 5px #353637, -4px -4px 5px #434445`,
      "borderRadius": theme.borderRadius,
      "color": theme.colorTextSecondary,
    },
    ".AccordionMore:hover": {
      "color": "#ffffff",
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
      "borderRadius": theme.borderRadius,
      "color": theme.colorTextSecondary,
      "margin": "5px",
      "padding": theme.spacingUnit,
      "transition": "background .15s ease, border .15s ease, box-shadow .15s ease",
      "boxShadow": `4px 4px 5px #353637, -4px -4px 5px #434445`,
    },
    ".PickerItem:hover": {
      "color": "#ffffff",
    },
    ".PickerItem--selected": {
      "color": theme.colorPrimary,
      "background": "linear-gradient(340deg, #3d3d3d, #383838)",
      "boxShadow": "inset 7px 8px 7px #353637, inset -5px -4px 7px #434445",
    },
    ".PickerItem--selected:hover": {
      "color": theme.colorPrimary,
      "boxShadow": "inset 7px 8px 7px #353637, inset -5px -4px 7px #434445",
    },
    ".SavedItemLabel": {
      "color": "white",
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

let default = soft
let defaultRules = softRules
