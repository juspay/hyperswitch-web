let getLocaleWeb = async locale => {
  try {
    let promiseLocale = switch locale->LocaleStringHelper.mapLocalStringToTypeLocale {
    | En => Js.import(EnglishLocale.localeStrings)
    | He => Js.import(HebrewLocale.localeStrings)
    | Fr => Js.import(FrenchLocale.localeStrings)
    | En_GB => Js.import(EnglishGBLocale.localeStrings)
    | Ar => Js.import(ArabicLocale.localeStrings)
    | Ja => Js.import(JapaneseLocale.localeStrings)
    | De => Js.import(DeutschLocale.localeStrings)
    | Fr_BE => Js.import(FrenchBelgiumLocale.localeStrings)
    | Es => Js.import(SpanishLocale.localeStrings)
    | Ca => Js.import(CatalanLocale.localeStrings)
    | Zh => Js.import(ChineseLocale.localeStrings)
    | Pt => Js.import(PortugueseLocale.localeStrings)
    | It => Js.import(ItalianLocale.localeStrings)
    | Pl => Js.import(PolishLocale.localeStrings)
    | Nl => Js.import(DutchLocale.localeStrings)
    | Sv => Js.import(SwedishLocale.localeStrings)
    | Ru => Js.import(RussianLocale.localeStrings)
    | Ni_BE => Js.import(DutchBelgiumLocale.localeStrings)
    | Lt => Js.import(LithuanianLocale.localeStrings)
    | Cs => Js.import(CzechLocale.localeStrings)
    | Sk => Js.import(SlovakLocale.localeStrings)
    | Ls => Js.import(IcelandicLocale.localeStrings)
    | Cy => Js.import(WelshLocale.localeStrings)
    | El => Js.import(GreekLocale.localeStrings)
    | Et => Js.import(EstonianLocale.localeStrings)
    | Fi => Js.import(FinnishLocale.localeStrings)
    | Nb => Js.import(NorwegianLocale.localeStrings)
    | Bs => Js.import(BosnianLocale.localeStrings)
    | Da => Js.import(DanishLocale.localeStrings)
    | Ms => Js.import(MalayLocale.localeStrings)
    | Tr_C => Js.import(TurkishLocale.localeStrings)
    }

    let awaitedLocaleValue = await promiseLocale
    awaitedLocaleValue
  } catch {
  | _ => EnglishLocale.localeStrings
  }
}
