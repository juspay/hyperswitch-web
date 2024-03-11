type themeDataModule = {
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => Js.Json.t,
  defaultButtonRules: PaymentType.sdkHandleConfirmPayment,
}

@val
external importTheme: string => Promise.t<themeDataModule> = "import"
