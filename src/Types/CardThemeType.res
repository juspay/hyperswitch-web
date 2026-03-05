type theme = Default | Brutal | Midnight | Soft | Charcoal | Bubblegum | NONE

type innerLayout = Spaced | Compressed

type showLoader = Auto | Always | Never

type mode =
  | Card
  | Payment
  | CardNumberElement
  | CardExpiryElement
  | CardCVCElement
  | PaymentMethodCollectElement
  | GooglePayElement
  | PayPalElement
  | ApplePayElement
  | SamsungPayElement
  | KlarnaElement
  | PazeElement
  | ExpressCheckoutElement
  | PaymentMethodsManagement
  | NONE
type label = Above | Floating | Never
type themeClass = {
  fontFamily: string,
  fontSizeBase: string,
  colorPrimary: string,
  colorBackground: string,
  colorText: string,
  colorDanger: string,
  borderRadius: string,
  fontVariantLigatures: string,
  fontVariationSettings: string,
  spacingUnit: string,
  fontWeightLight: string,
  fontWeightNormal: string,
  fontWeightMedium: string,
  fontWeightBold: string,
  fontLineHeight: string,
  fontSize2Xl: string,
  fontSizeXl: string,
  fontSizeLg: string,
  fontSizeSm: string,
  fontSizeXs: string,
  fontSize2Xs: string,
  fontSize3Xs: string,
  colorSuccess: string,
  colorWarning: string,
  colorPrimaryText: string,
  colorBackgroundText: string,
  colorSuccessText: string,
  colorDangerText: string,
  colorWarningText: string,
  colorTextSecondary: string,
  colorTextPlaceholder: string,
  spacingTab: string,
  borderColor: string,
  spacingAccordionItem: string,
  colorIconCardCvc: string,
  colorIconCardCvcError: string,
  colorIconCardError: string,
  spacingGridColumn: string,
  spacingGridRow: string,
  buttonBackgroundColor: string,
  buttonHeight: string,
  buttonWidth: string,
  buttonBorderRadius: string,
  buttonBorderColor: string,
  buttonTextColor: string,
  buttonTextFontSize: string,
  buttonTextFontWeight: string,
  buttonBorderWidth: string,
  disabledFieldColor: string,
}
type appearance = {
  theme: theme,
  componentType: string,
  variables: themeClass,
  rules: JSON.t,
  labels: label,
  innerLayout: innerLayout,
}
type fonts = {
  cssSrc: string,
  family: string,
  src: string,
  weight: string,
}
type configClass = {
  appearance: appearance,
  locale: string,
  ephemeralKey: string,
  pmClientSecret: string,
  pmSessionId: string,
  clientSecret: string,
  fonts: array<fonts>,
  loader: showLoader,
  sdkAuthorization: string,
}

let getPaymentMode = val => {
  switch val {
  | "card" => Card
  | "payment" => Payment
  | "cardNumber" => CardNumberElement
  | "cardExpiry" => CardExpiryElement
  | "cardCvc" => CardCVCElement
  | "googlePay" => GooglePayElement
  | "payPal" => PayPalElement
  | "applePay" => ApplePayElement
  | "paymentMethodCollect" => PaymentMethodCollectElement
  | "samsungPay" => SamsungPayElement
  | "klarna" => KlarnaElement
  | "expressCheckout" => ExpressCheckoutElement
  | "paze" => PazeElement
  | "paymentMethodsManagement" => PaymentMethodsManagement
  | _ => NONE
  }
}

let getPaymentModeToStrMapper = (val: mode) => (val :> string)
