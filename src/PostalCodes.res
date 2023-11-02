open PostalCodeType
let postalCode = [
  {
    iso: "AF",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "AX",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "AL",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "DZ",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "AS",
    format: "NNNNN (optionally NNNNN-NNNN or NNNNN-NNNNNN)",
    regex: "^\\d{5}(-{1}\\d{4,6})$",
  },
  {
    iso: "AD",
    format: "CCNNN",
    regex: "^[Aa][Dd]\\d{3}$",
  },
  {
    iso: "AO",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "AI",
    format: "AI-2640",
    regex: "^[Aa][I][-][2][6][4][0]$",
  },
  {
    iso: "AG",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "AR",
    format: "1974-1998 NNNN; From 1999 ANNNNAAA",
    regex: "^\\d{4}|[A-Za-z]\\d{4}[a-zA-Z]{3}$",
  },
  {
    iso: "AM",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "AW",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "AC",
    format: "AAAANAA one code: ASCN 1ZZ",
    regex: "^[Aa][Ss][Cc][Nn]\\s{0,1}[1][Zz][Zz]$",
  },
  {
    iso: "AU",
    format: "NNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "AT",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "AZ",
    format: "CCNNNN",
    regex: "^[Aa][Zz]\\d{4}$",
  },
  {
    iso: "BS",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "BH",
    format: "NNN or NNNN",
    regex: "^\\d{3,4}$",
  },
  {
    iso: "BD",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "BB",
    format: "CCNNNNN",
    regex: "^[Aa][Zz]\\d{5}$",
  },
  {
    iso: "BY",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "BE",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "BZ",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "BJ",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "BM",
    format: "AA NN or AA AA",
    regex: "^[A-Za-z]{2}\\s([A-Za-z]{2}|\\d{2})$",
  },
  {
    iso: "BT",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "BO",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "BQ",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "BA",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "BW",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "BR",
    format: "NNNNN-NNN (NNNNN from 1971 to 1992)",
    regex: "^\\d{5}-\\d{3}$",
  },
  {
    iso: "",
    format: "BIQQ 1ZZ",
    regex: "^[Bb][Ii][Qq]{2}\\s{0,1}[1][Zz]{2}$",
  },
  {
    iso: "IO",
    format: "AAAANAA one code: BBND 1ZZ",
    regex: "^[Bb]{2}[Nn][Dd]\\s{0,1}[1][Zz]{2}$",
  },
  {
    iso: "VG",
    format: "CCNNNN",
    regex: "^[Vv][Gg]\\d{4}$",
  },
  {
    iso: "BN",
    format: "AANNNN",
    regex: "^[A-Za-z]{2}\\d{4}$",
  },
  {
    iso: "BG",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "BF",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "BI",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "KH",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "CM",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "CA",
    format: "ANA NAN",
    regex: "^(?=[^DdFfIiOoQqUu\\d\\s])[A-Za-z]\\d(?=[^DdFfIiOoQqUu\\d\\s])[A-Za-z]\\s{0,1}\\d(?=[^DdFfIiOoQqUu\\d\\s])[A-Za-z]\\d$",
  },
  {
    iso: "CV",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "KY",
    format: "CCN-NNNN",
    regex: "^[Kk][Yy]\\d[-\\s]{0,1}\\d{4}$",
  },
  {
    iso: "CF",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "TD",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "CL",
    format: "NNNNNNN (NNN-NNNN)",
    regex: "^\\d{7}\\s\\(\\d{3}-\\d{4}\\)$",
  },
  {
    iso: "CN",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "CX",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "CC",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "CO",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "KM",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "CG",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "CD",
    format: "- no codes -",
    regex: "^[Cc][Dd]$",
  },
  {
    iso: "CK",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "CR",
    format: "NNNNN (NNNN until 2007)",
    regex: "^\\d{4,5}$",
  },
  {
    iso: "CI",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "HR",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "CU",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "CW",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "CY",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "CZ",
    format: "NNNNN (NNN NN)",
    regex: "^\\d{5}\\s\\(\\d{3}\\s\\d{2}\\)$",
  },
  {
    iso: "DK",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "DJ",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "DM",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "DO",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "TL",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "EC",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "SV",
    format: "1101",
    regex: "^1101$",
  },
  {
    iso: "EG",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "GQ",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "ER",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "EE",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "ET",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "FK",
    format: "AAAANAA one code: FIQQ 1ZZ",
    regex: "^[Ff][Ii][Qq]{2}\\s{0,1}[1][Zz]{2}$",
  },
  {
    iso: "FO",
    format: "NNN",
    regex: "^\\d{3}$",
  },
  {
    iso: "FJ",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "FI",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "FR",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "GF",
    format: "973NN",
    regex: "^973\\d{2}$",
  },
  {
    iso: "PF",
    format: "987NN",
    regex: "^987\\d{2}$",
  },
  {
    iso: "TF",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "GA",
    format: "NN [city name] NN",
    regex: "^\\d{2}\\s[a-zA-Z-_ ]\\s\\d{2}$",
  },
  {
    iso: "GM",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "GE",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "DE",
    format: "NN",
    regex: "^\\d{2}$",
  },
  {
    iso: "DE",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "DE",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "GH",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "GI",
    format: "GX11 1AA",
    regex: "^[Gg][Xx][1]{2}\\s{0,1}[1][Aa]{2}$",
  },
  {
    iso: "GR",
    format: "NNN NN",
    regex: "^\\d{3}\\s{0,1}\\d{2}$",
  },
  {
    iso: "GL",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "GD",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "GP",
    format: "971NN",
    regex: "^971\\d{2}$",
  },
  {
    iso: "GU",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "GT",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "GG",
    format: "AAN NAA, AANN NAA",
    regex: "^[A-Za-z]{2}\\d\\s{0,1}\\d[A-Za-z]{2}$",
  },
  {
    iso: "GN",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "GW",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "GY",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "HT",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "HM",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "HN",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "HK",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "HU",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "IS",
    format: "NNN",
    regex: "^\\d{3}$",
  },
  {
    iso: "IN",
    format: "NNNNNN,&#10;NNN NNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "ID",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "IR",
    format: "NNNNN-NNNNN",
    regex: "^\\d{5}-\\d{5}$",
  },
  {
    iso: "IQ",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "IE",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "IM",
    format: "CCN NAA, CCNN NAA",
    regex: "^[Ii[Mm]\\d{1,2}\\s\\d\\[A-Z]{2}$",
  },
  {
    iso: "IL",
    format: "NNNNNNN, NNNNN",
    regex: "^\\b\\d{5}(\\d{2})?$",
  },
  {
    iso: "IT",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "JM",
    format: "Before suspension: CCAAANN &#10;After suspension: NN",
    regex: "^\\d{2}$",
  },
  {
    iso: "JP",
    format: "NNNNNNN (NNN-NNNN)",
    regex: "^\\d{7}\\s\\(\\d{3}-\\d{4}\\)$",
  },
  {
    iso: "JE",
    format: "CCN NAA",
    regex: "^[Jj][Ee]\\d\\s{0,1}\\d[A-Za-z]{2}$",
  },
  {
    iso: "JO",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "KZ",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "KE",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "KI",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "KP",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "KR",
    format: "NNNNNN (NNN-NNN)(1988~2015)",
    regex: "^\\d{6}\\s\\(\\d{3}-\\d{3}\\)$",
  },
  {
    iso: "XK",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "KW",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "KG",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "LV",
    format: "LV-NNNN",
    regex: "^[Ll][Vv][- ]{0,1}\\d{4}$",
  },
  {
    iso: "LA",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "LB",
    format: "NNNN NNNN",
    regex: "^\\d{4}\\s{0,1}\\d{4}$",
  },
  {
    iso: "LS",
    format: "NNN",
    regex: "^\\d{3}$",
  },
  {
    iso: "LR",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "LY",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "LI",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "LT",
    format: "LT-NNNNN",
    regex: "^[Ll][Tt][- ]{0,1}\\d{5}$",
  },
  {
    iso: "LU",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "MO",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "MK",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "MG",
    format: "NNN",
    regex: "^\\d{3}$",
  },
  {
    iso: "MW",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "MV",
    format: "NNNN, NNNNN",
    regex: "^\\d{4,5}$",
  },
  {
    iso: "MY",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "ML",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "MT",
    format: "AAANNNN (AAA NNNN)",
    regex: "^[A-Za-z]{3}\\s{0,1}\\d{4}$",
  },
  {
    iso: "MH",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "MR",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "MU",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "MQ",
    format: "972NN",
    regex: "^972\\d{2}$",
  },
  {
    iso: "YT",
    format: "976NN",
    regex: "^976\\d{2}$",
  },
  {
    iso: "FM",
    format: "NNNNN or NNNNN-NNNN",
    regex: "^\\d{5}(-{1}\\d{4})$",
  },
  {
    iso: "MX",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "FM",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "MD",
    format: "CCNNNN (CC-NNNN)",
    regex: "^[Mm][Dd][- ]{0,1}\\d{4}$",
  },
  {
    iso: "MC",
    format: "980NN",
    regex: "^980\\d{2}$",
  },
  {
    iso: "MN",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "ME",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "MS",
    format: "MSR 1110-1350",
    regex: "^[Mm][Ss][Rr]\\s{0,1}\\d{4}$",
  },
  {
    iso: "MA",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "MZ",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "MM",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "NA",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "NR",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "NP",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "NL",
    format: "NNNN AA",
    regex: "^\\d{4}\\s{0,1}[A-Za-z]{2}$",
  },
  {
    iso: "NC",
    format: "988NN",
    regex: "^988\\d{2}$",
  },
  {
    iso: "NZ",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "NI",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "NE",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "NG",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "NU",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "NF",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "MP",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "NO",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "OM",
    format: "NNN",
    regex: "^\\d{3}$",
  },
  {
    iso: "PK",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "PW",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "PA",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "PG",
    format: "NNN",
    regex: "^\\d{3}$",
  },
  {
    iso: "PY",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "PE",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "PH",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "PN",
    format: "AAAANAA one code: PCRN 1ZZ",
    regex: "^[Pp][Cc][Rr][Nn]\\s{0,1}[1][Zz]{2}$",
  },
  {
    iso: "PL",
    format: "NNNNN (NN-NNN)",
    regex: "^\\d{2}[- ]{0,1}\\d{3}$",
  },
  {
    iso: "PT",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "PT",
    format: "NNNN-NNN (NNNN NNN)",
    regex: "^\\d{4}[- ]{0,1}\\d{3}$",
  },
  {
    iso: "PR",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "QA",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "RE",
    format: "974NN",
    regex: "^974\\d{2}$",
  },
  {
    iso: "RO",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "RU",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "BL",
    format: "97133",
    regex: "^97133$",
  },
  {
    iso: "SH",
    format: "STHL 1ZZ",
    regex: "^[Ss][Tt][Hh][Ll]\\s{0,1}[1][Zz]{2}$",
  },
  {
    iso: "KN",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "LC",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "MF",
    format: "97150",
    regex: "^97150$",
  },
  {
    iso: "PM",
    format: "97500",
    regex: "^97500$",
  },
  {
    iso: "VC",
    format: "CCNNNN",
    regex: "^[Vv][Cc]\\d{4}$",
  },
  {
    iso: "SM",
    format: "4789N",
    regex: "^4789\\d$",
  },
  {
    iso: "ST",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "SA",
    format: "NNNNN for PO Boxes. NNNNN-NNNN for home delivery.",
    regex: "^\\d{5}(-{1}\\d{4})?$",
  },
  {
    iso: "SN",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "RS",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "RS",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "SC",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "SX",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "SL",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "SG",
    format: "NN",
    regex: "^\\d{2}$",
  },
  {
    iso: "SG",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "SG",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "SK",
    format: "NNNNN (NNN NN)",
    regex: "^\\d{5}\\s\\(\\d{3}\\s\\d{2}\\)$",
  },
  {
    iso: "SI",
    format: "NNNN (CC-NNNN)",
    regex: "^([Ss][Ii][- ]{0,1}){0,1}\\d{4}$",
  },
  {
    iso: "SB",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "SO",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "ZA",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "GS",
    format: "SIQQ 1ZZ",
    regex: "^[Ss][Ii][Qq]{2}\\s{0,1}[1][Zz]{2}$",
  },
  {
    iso: "KR",
    format: "NNNNNN (NNN-NNN)",
    regex: "^\\d{6}\\s\\(\\d{3}-\\d{3}\\)$",
  },
  {
    iso: "ES",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "LK",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "SD",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "SR",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "SZ",
    format: "ANNN",
    regex: "^[A-Za-z]\\d{3}$",
  },
  {
    iso: "SE",
    format: "NNNNN (NNN NN)",
    regex: "^\\d{3}\\s*\\d{2}$",
  },
  {
    iso: "CH",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "SJ",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "SY",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "TW",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "TJ",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "TZ",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "TH",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "TG",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "TK",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "TO",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "TT",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "SH",
    format: "TDCU 1ZZ",
    regex: "^[Tt][Dd][Cc][Uu]\\s{0,1}[1][Zz]{2}$",
  },
  {
    iso: "TN",
    format: "NNNN",
    regex: "^\\d{4}$",
  },
  {
    iso: "TR",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "TM",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "TC",
    format: "TKCA 1ZZ",
    regex: "^[Tt][Kk][Cc][Aa]\\s{0,1}[1][Zz]{2}$",
  },
  {
    iso: "TV",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "UG",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "UA",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "AE",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "GB",
    format: "A(A)N(A/N)NAA (A[A]N[A/N] NAA)",
    regex: "([Gg][Ii][Rr] 0[Aa]{2})|((([A-Za-z][0-9]{1,2})|(([A-Za-z][A-Ha-hJ-Yj-y][0-9]{1,2})|(([A-Za-z][0-9][A-Za-z])|([A-Za-z][A-Ha-hJ-Yj-y][0-9][A-Za-z]?))))\s?[0-9][A-Za-z]{2})",
  },
  {
    iso: "US",
    format: "NNNNN (optionally NNNNN-NNNN)",
    regex: "^\\b\\d{5}\\b(?:[- ]{1}\\d{4})?$",
  },
  {
    iso: "UY",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "VI",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "UZ",
    format: "NNN NNN",
    regex: "^\\d{3} \\d{3}$",
  },
  {
    iso: "VU",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "VA",
    format: "120",
    regex: "^120$",
  },
  {
    iso: "VE",
    format: "NNNN or NNNN A",
    regex: "^\\d{4}(\\s[a-zA-Z]{1})?$",
  },
  {
    iso: "VN",
    format: "NNNNNN",
    regex: "^\\d{6}$",
  },
  {
    iso: "WF",
    format: "986NN",
    regex: "^986\\d{2}$",
  },
  {
    iso: "YE",
    format: "- no codes -",
    regex: "",
  },
  {
    iso: "ZM",
    format: "NNNNN",
    regex: "^\\d{5}$",
  },
  {
    iso: "ZW",
    format: "- no codes -",
    regex: "",
  },
]

let default = postalCode
