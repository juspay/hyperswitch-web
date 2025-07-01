open LocaleStringTypes
let mapLocalStringToTypeLocale = val => {
  // First try the exact match
  let exactMatch = switch val->String.toLowerCase {
  | "he" => Some(HE)
  | "fr" => Some(FR)
  | "ar" => Some(AR)
  | "ja" => Some(JA)
  | "de" => Some(DE)
  | "es" => Some(ES)
  | "ca" => Some(CA)
  | "pt" => Some(PT)
  | "it" => Some(IT)
  | "pl" => Some(PL)
  | "nl" => Some(NL)
  | "sv" => Some(SV)
  | "ru" => Some(RU)
  | "zh" => Some(ZH)
  | "en-gb" => Some(EN_GB)
  | "fr-be" => Some(FR_BE)
  | "zh-hant" => Some(ZH_HANT)
  | "en" => Some(EN)
  | _ => None
  }

  // If exact match found, return it
  switch exactMatch {
  | Some(locale) => locale
  // If no exact match is found, try to match based on the first part of the language code (before the "-")
  | None => {
      let baseLanguage = val->String.toLowerCase->String.split("-")->Array.get(0)->Option.getOr("")
      switch baseLanguage {
      | "he" => HE
      | "fr" => FR
      | "ar" => AR
      | "ja" => JA
      | "de" => DE
      | "es" => ES
      | "ca" => CA
      | "pt" => PT
      | "it" => IT
      | "pl" => PL
      | "nl" => NL
      | "sv" => SV
      | "ru" => RU
      | "zh" => ZH
      | "en" => EN
      | _ => EN // Default fallback
      }
    }
  }
}
