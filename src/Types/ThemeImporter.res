type themeDataModule = {
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => Js.Json.t,
}
open Promise

@val
external importTheme: string => t<themeDataModule> = "import"
