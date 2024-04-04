open LocaleStringTypes
let mapLocalStringToTypeLocale = val => {
  switch val {
  | "en" => EN
  | "he" => HE
  | "fr" => FR
  | "en-GB" => EN_GB
  | "ar" => AR
  | "ja" => JA
  | "de" => DE
  | "fr-BE" => FR_BE
  | "es" => ES
  | "ca" => CA
  | "pt" => PT
  | "it" => IT
  | "pl" => PL
  | "nl" => NL
  | "sv" => SV
  | "ru" => RU
  | _ => EN
  }
}
