type theme = Default | Brutal | Midnight | Soft | Charcoal | NONE

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
  | KlarnaElement
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
  clientSecret: string,
  fonts: array<fonts>,
  loader: showLoader,
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
  | "klarna" => KlarnaElement
  | "expressCheckout" => ExpressCheckoutElement
  | "paymentMethodsManagement" => PaymentMethodsManagement
  | _ => NONE
  }
}

let getPaymentModeToStrMapper = val => {
  switch val {
  | Card => "Card"
  | Payment => "Payment"
  | CardNumberElement => "CardNumberElement"
  | CardExpiryElement => "CardExpiryElement"
  | CardCVCElement => "CardCVCElement"
  | GooglePayElement => "GooglePayElement"
  | PayPalElement => "PayPalElement"
  | ApplePayElement => "ApplePayElement"
  | PaymentMethodCollectElement => "PaymentMethodCollectElement"
  | KlarnaElement => "KlarnaElement"
  | ExpressCheckoutElement => "ExpressCheckoutElement"
  | PaymentMethodsManagement => "PaymentMethodsManagement"
  | NONE => "None"
  }
}
