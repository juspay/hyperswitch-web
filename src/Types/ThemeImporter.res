type themeDataModule = {
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => Js.Json.t,
}

@val
external importTheme: string => Promise.t<themeDataModule> = "import"
