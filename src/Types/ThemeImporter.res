type themeDataModule = {
  default: CardThemeType.themeClass,
  defaultRules: CardThemeType.themeClass => JSON.t,
}

@val
external importTheme: string => Promise.t<themeDataModule> = "import"
