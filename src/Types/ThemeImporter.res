type themeDataModule = {
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => JSON.t,
}

@val
external importTheme: string => promise<themeDataModule> = "import"
