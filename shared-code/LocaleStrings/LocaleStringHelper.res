open LocaleStringTypes
let mapLocalStringToTypeLocale = val => {
  switch val {
  | "he" => He
  | "fr" => Fr
  | "en-GB" => En_GB
  | "ar" => Ar
  | "ja" => Ja
  | "de" => De
  | "fr-BE" => Fr_BE
  | "es" => Es
  | "ca" => Ca
  | "zh" => Zh
  | "pt" => Pt
  | "it" => It
  | "pl" => Pl
  | "nl" => Nl
  | "sv" => Sv
  | "ru" => Ru
  | "ni-be" => Ni_BE
  | "lt" => Lt
  | "cs" => Cs
  | "sk" => Sk
  | "ls" => Ls
  | "cy" => Cy
  | "el" => El
  | "et" => Et
  | "fi" => Fi
  | "nb" => Nb
  | "bs" => Bs
  | "da" => Da
  | "ms" => Ms
  | "tr-c" => Tr_C
  | "en"
  | _ =>
    En
  }
}

let getLocale = locale => {
  try {
    switch locale->Option.getOr(En) {
    | En => EnglishLocale.localeStrings
    | He => HebrewLocale.localeStrings
    | Fr => FrenchLocale.localeStrings
    | En_GB => EnglishGBLocale.localeStrings
    | Ar => ArabicLocale.localeStrings
    | Ja => JapaneseLocale.localeStrings
    | De => DeutschLocale.localeStrings
    | Fr_BE => FrenchBelgiumLocale.localeStrings
    | Es => SpanishLocale.localeStrings
    | Ca => CatalanLocale.localeStrings
    | Zh => ChineseLocale.localeStrings
    | Pt => PortugueseLocale.localeStrings
    | It => ItalianLocale.localeStrings
    | Pl => PolishLocale.localeStrings
    | Nl => DutchLocale.localeStrings
    | Sv => SwedishLocale.localeStrings
    | Ru => RussianLocale.localeStrings
    | Ni_BE => DutchBelgiumLocale.localeStrings
    | Lt => LithuanianLocale.localeStrings
    | Cs => CzechLocale.localeStrings
    | Sk => SlovakLocale.localeStrings
    | Ls => IcelandicLocale.localeStrings
    | Cy => WelshLocale.localeStrings
    | El => GreekLocale.localeStrings
    | Et => EstonianLocale.localeStrings
    | Fi => FinnishLocale.localeStrings
    | Nb => NorwegianLocale.localeStrings
    | Bs => BosnianLocale.localeStrings
    | Da => DanishLocale.localeStrings
    | Ms => MalayLocale.localeStrings
    | Tr_C => TurkishLocale.localeStrings
    }
  } catch {
  | _ => EnglishLocale.localeStrings
  }
}
