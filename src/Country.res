type windowsTimeZones = {
  id: string,
  name: string,
}
type timezoneType = {
  isoAlpha3?: string,
  timeZones: array<string>,
  countryName: string,
  isoAlpha2: string,
}

type state = {
  name: string,
  code: string,
}

type countryStateData = {
  countries: array<timezoneType>,
  states: JSON.t,
}

let defaultTimeZone = {
  isoAlpha3: "",
  timeZones: [],
  countryName: "-",
  isoAlpha2: "",
}

let country = [
  {
    isoAlpha2: "AF",
    countryName: "Afghanistan",
    timeZones: ["Asia/Kabul"],
  },
  {
    isoAlpha2: "AX",
    countryName: "Aland Islands",
    timeZones: ["Europe/Mariehamn"],
  },
  {
    isoAlpha2: "AL",
    countryName: "Albania",
    timeZones: ["Europe/Tirane"],
  },
  {
    isoAlpha2: "DZ",
    countryName: "Algeria",
    timeZones: ["Africa/Algiers"],
  },
  {
    isoAlpha2: "AS",
    countryName: "American Samoa",
    timeZones: ["Pacific/Pago_Pago"],
  },
  {
    isoAlpha2: "AD",
    countryName: "Andorra",
    timeZones: ["Europe/Andorra"],
  },
  {
    isoAlpha2: "AO",
    countryName: "Angola",
    timeZones: ["Africa/Luanda"],
  },
  {
    isoAlpha2: "AI",
    countryName: "Anguilla",
    timeZones: ["America/Anguilla"],
  },
  {
    isoAlpha2: "AQ",
    countryName: "Antarctica",
    timeZones: [
      "Antarctica/Casey",
      "Antarctica/Davis",
      "Antarctica/DumontDUrville",
      "Antarctica/Mawson",
      "Antarctica/McMurdo",
      "Antarctica/Palmer",
      "Antarctica/Rothera",
      "Antarctica/Syowa",
      "Antarctica/Troll",
      "Antarctica/Vostok",
    ],
  },
  {
    isoAlpha2: "AG",
    countryName: "Antigua and Barbuda",
    timeZones: ["America/Antigua"],
  },
  {
    isoAlpha2: "AR",
    countryName: "Argentina",
    timeZones: [
      "America/Argentina/Buenos_Aires",
      "America/Argentina/Catamarca",
      "America/Argentina/Cordoba",
      "America/Argentina/Jujuy",
      "America/Argentina/La_Rioja",
      "America/Argentina/Mendoza",
      "America/Argentina/Rio_Gallegos",
      "America/Argentina/Salta",
      "America/Argentina/San_Juan",
      "America/Argentina/San_Luis",
      "America/Argentina/Tucuman",
      "America/Argentina/Ushuaia",
    ],
  },
  {
    isoAlpha2: "AM",
    countryName: "Armenia",
    timeZones: ["Asia/Yerevan"],
  },
  {
    isoAlpha2: "AW",
    countryName: "Aruba",
    timeZones: ["America/Aruba"],
  },
  {
    isoAlpha2: "AU",
    countryName: "Australia",
    timeZones: [
      "Antarctica/Macquarie",
      "Australia/Adelaide",
      "Australia/Brisbane",
      "Australia/Broken_Hill",
      "Australia/Currie",
      "Australia/Darwin",
      "Australia/Eucla",
      "Australia/Hobart",
      "Australia/Lindeman",
      "Australia/Lord_Howe",
      "Australia/Melbourne",
      "Australia/Perth",
      "Australia/Sydney",
    ],
  },
  {
    isoAlpha2: "AT",
    countryName: "Austria",
    timeZones: ["Europe/Vienna"],
  },
  {
    isoAlpha2: "AZ",
    countryName: "Azerbaijan",
    timeZones: ["Asia/Baku"],
  },
  {
    isoAlpha2: "BH",
    countryName: "Bahrain",
    timeZones: ["Asia/Bahrain"],
  },
  {
    isoAlpha2: "BD",
    countryName: "Bangladesh",
    timeZones: ["Asia/Dhaka"],
  },
  {
    isoAlpha2: "BB",
    countryName: "Barbados",
    timeZones: ["America/Barbados"],
  },
  {
    isoAlpha2: "BY",
    countryName: "Belarus",
    timeZones: ["Europe/Minsk"],
  },
  {
    isoAlpha2: "BE",
    countryName: "Belgium",
    timeZones: ["Europe/Brussels"],
  },
  {
    isoAlpha2: "BZ",
    countryName: "Belize",
    timeZones: ["America/Belize"],
  },
  {
    isoAlpha2: "BJ",
    countryName: "Benin",
    timeZones: ["Africa/Porto-Novo"],
  },
  {
    isoAlpha2: "BM",
    countryName: "Bermuda",
    timeZones: ["Atlantic/Bermuda"],
  },
  {
    isoAlpha2: "BT",
    countryName: "Bhutan",
    timeZones: ["Asia/Thimphu"],
  },
  {
    isoAlpha2: "BO",
    countryName: "Bolivia",
    timeZones: ["America/La_Paz"],
  },
  {
    isoAlpha2: "BQ",
    countryName: "Bonaire, Sint Eustatius and Saba",
    timeZones: ["America/Anguilla"],
  },
  {
    isoAlpha2: "BA",
    countryName: "Bosnia and Herzegovina",
    timeZones: ["Europe/Sarajevo"],
  },
  {
    isoAlpha2: "BW",
    countryName: "Botswana",
    timeZones: ["Africa/Gaborone"],
  },
  {
    isoAlpha2: "BV",
    countryName: "Bouvet Island",
    timeZones: ["Europe/Oslo"],
  },
  {
    isoAlpha2: "BR",
    countryName: "Brazil",
    timeZones: [
      "America/Araguaina",
      "America/Bahia",
      "America/Belem",
      "America/Boa_Vista",
      "America/Campo_Grande",
      "America/Cuiaba",
      "America/Eirunepe",
      "America/Fortaleza",
      "America/Maceio",
      "America/Manaus",
      "America/Noronha",
      "America/Porto_Velho",
      "America/Recife",
      "America/Rio_Branco",
      "America/Santarem",
      "America/Sao_Paulo",
    ],
  },
  {
    isoAlpha2: "IO",
    countryName: "British Indian Ocean Territory",
    timeZones: ["Indian/Chagos"],
  },
  {
    isoAlpha2: "BN",
    countryName: "Brunei",
    timeZones: ["Asia/Brunei"],
  },
  {
    isoAlpha2: "BG",
    countryName: "Bulgaria",
    timeZones: ["Europe/Sofia"],
  },
  {
    isoAlpha2: "BF",
    countryName: "Burkina Faso",
    timeZones: ["Africa/Ouagadougou"],
  },
  {
    isoAlpha2: "BI",
    countryName: "Burundi",
    timeZones: ["Africa/Bujumbura"],
  },
  {
    isoAlpha2: "KH",
    countryName: "Cambodia",
    timeZones: ["Asia/Phnom_Penh"],
  },
  {
    isoAlpha2: "CM",
    countryName: "Cameroon",
    timeZones: ["Africa/Douala"],
  },
  {
    isoAlpha2: "CA",
    countryName: "Canada",
    timeZones: [
      "America/Atikokan",
      "America/Blanc-Sablon",
      "America/Cambridge_Bay",
      "America/Creston",
      "America/Dawson",
      "America/Dawson_Creek",
      "America/Edmonton",
      "America/Fort_Nelson",
      "America/Glace_Bay",
      "America/Goose_Bay",
      "America/Halifax",
      "America/Inuvik",
      "America/Iqaluit",
      "America/Moncton",
      "America/Nipigon",
      "America/Pangnirtung",
      "America/Rainy_River",
      "America/Rankin_Inlet",
      "America/Regina",
      "America/Resolute",
      "America/St_Johns",
      "America/Swift_Current",
      "America/Thunder_Bay",
      "America/Toronto",
      "America/Vancouver",
      "America/Whitehorse",
      "America/Winnipeg",
      "America/Yellowknife",
    ],
  },
  {
    isoAlpha2: "CV",
    countryName: "Cape Verde",
    timeZones: ["Atlantic/Cape_Verde"],
  },
  {
    isoAlpha2: "KY",
    countryName: "Cayman Islands",
    timeZones: ["America/Cayman"],
  },
  {
    isoAlpha2: "CF",
    countryName: "Central African Republic",
    timeZones: ["Africa/Bangui"],
  },
  {
    isoAlpha2: "TD",
    countryName: "Chad",
    timeZones: ["Africa/Ndjamena"],
  },
  {
    isoAlpha2: "CL",
    countryName: "Chile",
    timeZones: ["America/Punta_Arenas", "America/Santiago", "Pacific/Easter"],
  },
  {
    isoAlpha2: "CN",
    countryName: "China",
    timeZones: ["Asia/Shanghai", "Asia/Urumqi"],
  },
  {
    isoAlpha2: "CX",
    countryName: "Christmas Island",
    timeZones: ["Indian/Christmas"],
  },
  {
    isoAlpha2: "CC",
    countryName: "Cocos (Keeling) Islands",
    timeZones: ["Indian/Cocos"],
  },
  {
    isoAlpha2: "CO",
    countryName: "Colombia",
    timeZones: ["America/Bogota"],
  },
  {
    isoAlpha2: "KM",
    countryName: "Comoros",
    timeZones: ["Indian/Comoro"],
  },
  {
    isoAlpha2: "CG",
    countryName: "Congo",
    timeZones: ["Africa/Brazzaville"],
  },
  {
    isoAlpha2: "CK",
    countryName: "Cook Islands",
    timeZones: ["Pacific/Rarotonga"],
  },
  {
    isoAlpha2: "CR",
    countryName: "Costa Rica",
    timeZones: ["America/Costa_Rica"],
  },
  {
    isoAlpha2: "CI",
    countryName: "Cote D'Ivoire (Ivory Coast)",
    timeZones: ["Africa/Abidjan"],
  },
  {
    isoAlpha2: "HR",
    countryName: "Croatia",
    timeZones: ["Europe/Zagreb"],
  },
  {
    isoAlpha2: "CU",
    countryName: "Cuba",
    timeZones: ["America/Havana"],
  },
  {
    isoAlpha2: "CW",
    countryName: "Curaçao",
    timeZones: ["America/Curacao"],
  },
  {
    isoAlpha2: "CY",
    countryName: "Cyprus",
    timeZones: ["Asia/Famagusta", "Asia/Nicosia"],
  },
  {
    isoAlpha2: "CZ",
    countryName: "Czech Republic",
    timeZones: ["Europe/Prague"],
  },
  {
    isoAlpha2: "CD",
    countryName: "Democratic Republic of the Congo",
    timeZones: ["Africa/Kinshasa", "Africa/Lubumbashi"],
  },
  {
    isoAlpha2: "DK",
    countryName: "Denmark",
    timeZones: ["Europe/Copenhagen"],
  },
  {
    isoAlpha2: "DJ",
    countryName: "Djibouti",
    timeZones: ["Africa/Djibouti"],
  },
  {
    isoAlpha2: "DM",
    countryName: "Dominica",
    timeZones: ["America/Dominica"],
  },
  {
    isoAlpha2: "DO",
    countryName: "Dominican Republic",
    timeZones: ["America/Santo_Domingo"],
  },
  {
    isoAlpha2: "EC",
    countryName: "Ecuador",
    timeZones: ["America/Guayaquil", "Pacific/Galapagos"],
  },
  {
    isoAlpha2: "EG",
    countryName: "Egypt",
    timeZones: ["Africa/Cairo"],
  },
  {
    isoAlpha2: "SV",
    countryName: "El Salvador",
    timeZones: ["America/El_Salvador"],
  },
  {
    isoAlpha2: "GQ",
    countryName: "Equatorial Guinea",
    timeZones: ["Africa/Malabo"],
  },
  {
    isoAlpha2: "ER",
    countryName: "Eritrea",
    timeZones: ["Africa/Asmara"],
  },
  {
    isoAlpha2: "EE",
    countryName: "Estonia",
    timeZones: ["Europe/Tallinn"],
  },
  {
    isoAlpha2: "SZ",
    countryName: "Eswatini",
    timeZones: ["Africa/Mbabane"],
  },
  {
    isoAlpha2: "ET",
    countryName: "Ethiopia",
    timeZones: ["Africa/Addis_Ababa"],
  },
  {
    isoAlpha2: "FK",
    countryName: "Falkland Islands",
    timeZones: ["Atlantic/Stanley"],
  },
  {
    isoAlpha2: "FO",
    countryName: "Faroe Islands",
    timeZones: ["Atlantic/Faroe"],
  },
  {
    isoAlpha2: "FJ",
    countryName: "Fiji Islands",
    timeZones: ["Pacific/Fiji"],
  },
  {
    isoAlpha2: "FI",
    countryName: "Finland",
    timeZones: ["Europe/Helsinki"],
  },
  {
    isoAlpha2: "FR",
    countryName: "France",
    timeZones: ["Europe/Paris"],
  },
  {
    isoAlpha2: "GF",
    countryName: "French Guiana",
    timeZones: ["America/Cayenne"],
  },
  {
    isoAlpha2: "PF",
    countryName: "French Polynesia",
    timeZones: ["Pacific/Gambier", "Pacific/Marquesas", "Pacific/Tahiti"],
  },
  {
    isoAlpha2: "TF",
    countryName: "French Southern Territories",
    timeZones: ["Indian/Kerguelen"],
  },
  {
    isoAlpha2: "GA",
    countryName: "Gabon",
    timeZones: ["Africa/Libreville"],
  },
  {
    isoAlpha2: "GE",
    countryName: "Georgia",
    timeZones: ["Asia/Tbilisi"],
  },
  {
    isoAlpha2: "DE",
    countryName: "Germany",
    timeZones: ["Europe/Berlin", "Europe/Busingen"],
  },
  {
    isoAlpha2: "GH",
    countryName: "Ghana",
    timeZones: ["Africa/Accra"],
  },
  {
    isoAlpha2: "GI",
    countryName: "Gibraltar",
    timeZones: ["Europe/Gibraltar"],
  },
  {
    isoAlpha2: "GR",
    countryName: "Greece",
    timeZones: ["Europe/Athens"],
  },
  {
    isoAlpha2: "GL",
    countryName: "Greenland",
    timeZones: ["America/Danmarkshavn", "America/Nuuk", "America/Scoresbysund", "America/Thule"],
  },
  {
    isoAlpha2: "GD",
    countryName: "Grenada",
    timeZones: ["America/Grenada"],
  },
  {
    isoAlpha2: "GP",
    countryName: "Guadeloupe",
    timeZones: ["America/Guadeloupe"],
  },
  {
    isoAlpha2: "GU",
    countryName: "Guam",
    timeZones: ["Pacific/Guam"],
  },
  {
    isoAlpha2: "GT",
    countryName: "Guatemala",
    timeZones: ["America/Guatemala"],
  },
  {
    isoAlpha2: "GG",
    countryName: "Guernsey and Alderney",
    timeZones: ["Europe/Guernsey"],
  },
  {
    isoAlpha2: "GN",
    countryName: "Guinea",
    timeZones: ["Africa/Conakry"],
  },
  {
    isoAlpha2: "GW",
    countryName: "Guinea-Bissau",
    timeZones: ["Africa/Bissau"],
  },
  {
    isoAlpha2: "GY",
    countryName: "Guyana",
    timeZones: ["America/Guyana"],
  },
  {
    isoAlpha2: "HT",
    countryName: "Haiti",
    timeZones: ["America/Port-au-Prince"],
  },
  {
    isoAlpha2: "HM",
    countryName: "Heard Island and McDonald Islands",
    timeZones: ["Indian/Kerguelen"],
  },
  {
    isoAlpha2: "HN",
    countryName: "Honduras",
    timeZones: ["America/Tegucigalpa"],
  },
  {
    isoAlpha2: "HK",
    countryName: "Hong Kong S.A.R.",
    timeZones: ["Asia/Hong_Kong"],
  },
  {
    isoAlpha2: "HU",
    countryName: "Hungary",
    timeZones: ["Europe/Budapest"],
  },
  {
    isoAlpha2: "IS",
    countryName: "Iceland",
    timeZones: ["Atlantic/Reykjavik"],
  },
  {
    isoAlpha2: "IN",
    countryName: "India",
    timeZones: ["Asia/Kolkata", "Asia/Calcutta"],
  },
  {
    isoAlpha2: "ID",
    countryName: "Indonesia",
    timeZones: ["Asia/Jakarta", "Asia/Jayapura", "Asia/Makassar", "Asia/Pontianak"],
  },
  {
    isoAlpha2: "IR",
    countryName: "Iran",
    timeZones: ["Asia/Tehran"],
  },
  {
    isoAlpha2: "IQ",
    countryName: "Iraq",
    timeZones: ["Asia/Baghdad"],
  },
  {
    isoAlpha2: "IE",
    countryName: "Ireland",
    timeZones: ["Europe/Dublin"],
  },
  {
    isoAlpha2: "IL",
    countryName: "Israel",
    timeZones: ["Asia/Jerusalem"],
  },
  {
    isoAlpha2: "IT",
    countryName: "Italy",
    timeZones: ["Europe/Rome"],
  },
  {
    isoAlpha2: "JM",
    countryName: "Jamaica",
    timeZones: ["America/Jamaica"],
  },
  {
    isoAlpha2: "JP",
    countryName: "Japan",
    timeZones: ["Asia/Tokyo"],
  },
  {
    isoAlpha2: "JE",
    countryName: "Jersey",
    timeZones: ["Europe/Jersey"],
  },
  {
    isoAlpha2: "JO",
    countryName: "Jordan",
    timeZones: ["Asia/Amman"],
  },
  {
    isoAlpha2: "KZ",
    countryName: "Kazakhstan",
    timeZones: [
      "Asia/Almaty",
      "Asia/Aqtau",
      "Asia/Aqtobe",
      "Asia/Atyrau",
      "Asia/Oral",
      "Asia/Qostanay",
      "Asia/Qyzylorda",
    ],
  },
  {
    isoAlpha2: "KE",
    countryName: "Kenya",
    timeZones: ["Africa/Nairobi"],
  },
  {
    isoAlpha2: "KI",
    countryName: "Kiribati",
    timeZones: ["Pacific/Enderbury", "Pacific/Kiritimati", "Pacific/Tarawa"],
  },
  {
    isoAlpha2: "XK",
    countryName: "Kosovo",
    timeZones: ["Europe/Belgrade"],
  },
  {
    isoAlpha2: "KW",
    countryName: "Kuwait",
    timeZones: ["Asia/Kuwait"],
  },
  {
    isoAlpha2: "KG",
    countryName: "Kyrgyzstan",
    timeZones: ["Asia/Bishkek"],
  },
  {
    isoAlpha2: "LA",
    countryName: "Laos",
    timeZones: ["Asia/Vientiane"],
  },
  {
    isoAlpha2: "LV",
    countryName: "Latvia",
    timeZones: ["Europe/Riga"],
  },
  {
    isoAlpha2: "LB",
    countryName: "Lebanon",
    timeZones: ["Asia/Beirut"],
  },
  {
    isoAlpha2: "LS",
    countryName: "Lesotho",
    timeZones: ["Africa/Maseru"],
  },
  {
    isoAlpha2: "LR",
    countryName: "Liberia",
    timeZones: ["Africa/Monrovia"],
  },
  {
    isoAlpha2: "LY",
    countryName: "Libya",
    timeZones: ["Africa/Tripoli"],
  },
  {
    isoAlpha2: "LI",
    countryName: "Liechtenstein",
    timeZones: ["Europe/Vaduz"],
  },
  {
    isoAlpha2: "LT",
    countryName: "Lithuania",
    timeZones: ["Europe/Vilnius"],
  },
  {
    isoAlpha2: "LU",
    countryName: "Luxembourg",
    timeZones: ["Europe/Luxembourg"],
  },
  {
    isoAlpha2: "MO",
    countryName: "Macau S.A.R.",
    timeZones: ["Asia/Macau"],
  },
  {
    isoAlpha2: "MG",
    countryName: "Madagascar",
    timeZones: ["Indian/Antananarivo"],
  },
  {
    isoAlpha2: "MW",
    countryName: "Malawi",
    timeZones: ["Africa/Blantyre"],
  },
  {
    isoAlpha2: "MY",
    countryName: "Malaysia",
    timeZones: ["Asia/Kuala_Lumpur", "Asia/Kuching"],
  },
  {
    isoAlpha2: "MV",
    countryName: "Maldives",
    timeZones: ["Indian/Maldives"],
  },
  {
    isoAlpha2: "ML",
    countryName: "Mali",
    timeZones: ["Africa/Bamako"],
  },
  {
    isoAlpha2: "MT",
    countryName: "Malta",
    timeZones: ["Europe/Malta"],
  },
  {
    isoAlpha2: "IM",
    countryName: "Man (Isle of)",
    timeZones: ["Europe/Isle_of_Man"],
  },
  {
    isoAlpha2: "MH",
    countryName: "Marshall Islands",
    timeZones: ["Pacific/Kwajalein", "Pacific/Majuro"],
  },
  {
    isoAlpha2: "MQ",
    countryName: "Martinique",
    timeZones: ["America/Martinique"],
  },
  {
    isoAlpha2: "MR",
    countryName: "Mauritania",
    timeZones: ["Africa/Nouakchott"],
  },
  {
    isoAlpha2: "MU",
    countryName: "Mauritius",
    timeZones: ["Indian/Mauritius"],
  },
  {
    isoAlpha2: "YT",
    countryName: "Mayotte",
    timeZones: ["Indian/Mayotte"],
  },
  {
    isoAlpha2: "MX",
    countryName: "Mexico",
    timeZones: [
      "America/Bahia_Banderas",
      "America/Cancun",
      "America/Chihuahua",
      "America/Hermosillo",
      "America/Matamoros",
      "America/Mazatlan",
      "America/Merida",
      "America/Mexico_City",
      "America/Monterrey",
      "America/Ojinaga",
      "America/Tijuana",
    ],
  },
  {
    isoAlpha2: "FM",
    countryName: "Micronesia",
    timeZones: ["Pacific/Chuuk", "Pacific/Kosrae", "Pacific/Pohnpei"],
  },
  {
    isoAlpha2: "MD",
    countryName: "Moldova",
    timeZones: ["Europe/Chisinau"],
  },
  {
    isoAlpha2: "MC",
    countryName: "Monaco",
    timeZones: ["Europe/Monaco"],
  },
  {
    isoAlpha2: "MN",
    countryName: "Mongolia",
    timeZones: ["Asia/Choibalsan", "Asia/Hovd", "Asia/Ulaanbaatar"],
  },
  {
    isoAlpha2: "ME",
    countryName: "Montenegro",
    timeZones: ["Europe/Podgorica"],
  },
  {
    isoAlpha2: "MS",
    countryName: "Montserrat",
    timeZones: ["America/Montserrat"],
  },
  {
    isoAlpha2: "MA",
    countryName: "Morocco",
    timeZones: ["Africa/Casablanca"],
  },
  {
    isoAlpha2: "MZ",
    countryName: "Mozambique",
    timeZones: ["Africa/Maputo"],
  },
  {
    isoAlpha2: "MM",
    countryName: "Myanmar",
    timeZones: ["Asia/Yangon"],
  },
  {
    isoAlpha2: "NA",
    countryName: "Namibia",
    timeZones: ["Africa/Windhoek"],
  },
  {
    isoAlpha2: "NR",
    countryName: "Nauru",
    timeZones: ["Pacific/Nauru"],
  },
  {
    isoAlpha2: "NP",
    countryName: "Nepal",
    timeZones: ["Asia/Kathmandu"],
  },
  {
    isoAlpha2: "NL",
    countryName: "Netherlands",
    timeZones: ["Europe/Amsterdam"],
  },
  {
    isoAlpha2: "NC",
    countryName: "New Caledonia",
    timeZones: ["Pacific/Noumea"],
  },
  {
    isoAlpha2: "NZ",
    countryName: "New Zealand",
    timeZones: ["Pacific/Auckland", "Pacific/Chatham"],
  },
  {
    isoAlpha2: "NI",
    countryName: "Nicaragua",
    timeZones: ["America/Managua"],
  },
  {
    isoAlpha2: "NE",
    countryName: "Niger",
    timeZones: ["Africa/Niamey"],
  },
  {
    isoAlpha2: "NG",
    countryName: "Nigeria",
    timeZones: ["Africa/Lagos"],
  },
  {
    isoAlpha2: "NU",
    countryName: "Niue",
    timeZones: ["Pacific/Niue"],
  },
  {
    isoAlpha2: "NF",
    countryName: "Norfolk Island",
    timeZones: ["Pacific/Norfolk"],
  },
  {
    isoAlpha2: "KP",
    countryName: "North Korea",
    timeZones: ["Asia/Pyongyang"],
  },
  {
    isoAlpha2: "MK",
    countryName: "North Macedonia",
    timeZones: ["Europe/Skopje"],
  },
  {
    isoAlpha2: "MP",
    countryName: "Northern Mariana Islands",
    timeZones: ["Pacific/Saipan"],
  },
  {
    isoAlpha2: "NO",
    countryName: "Norway",
    timeZones: ["Europe/Oslo"],
  },
  {
    isoAlpha2: "OM",
    countryName: "Oman",
    timeZones: ["Asia/Muscat"],
  },
  {
    isoAlpha2: "PK",
    countryName: "Pakistan",
    timeZones: ["Asia/Karachi"],
  },
  {
    isoAlpha2: "PW",
    countryName: "Palau",
    timeZones: ["Pacific/Palau"],
  },
  {
    isoAlpha2: "PS",
    countryName: "Palestinian Territory Occupied",
    timeZones: ["Asia/Gaza", "Asia/Hebron"],
  },
  {
    isoAlpha2: "PA",
    countryName: "Panama",
    timeZones: ["America/Panama"],
  },
  {
    isoAlpha2: "PG",
    countryName: "Papua New Guinea",
    timeZones: ["Pacific/Bougainville", "Pacific/Port_Moresby"],
  },
  {
    isoAlpha2: "PY",
    countryName: "Paraguay",
    timeZones: ["America/Asuncion"],
  },
  {
    isoAlpha2: "PE",
    countryName: "Peru",
    timeZones: ["America/Lima"],
  },
  {
    isoAlpha2: "PH",
    countryName: "Philippines",
    timeZones: ["Asia/Manila"],
  },
  {
    isoAlpha2: "PN",
    countryName: "Pitcairn Island",
    timeZones: ["Pacific/Pitcairn"],
  },
  {
    isoAlpha2: "PL",
    countryName: "Poland",
    timeZones: ["Europe/Warsaw"],
  },
  {
    isoAlpha2: "PT",
    countryName: "Portugal",
    timeZones: ["Atlantic/Azores", "Atlantic/Madeira", "Europe/Lisbon"],
  },
  {
    isoAlpha2: "PR",
    countryName: "Puerto Rico",
    timeZones: ["America/Puerto_Rico"],
  },
  {
    isoAlpha2: "QA",
    countryName: "Qatar",
    timeZones: ["Asia/Qatar"],
  },
  {
    isoAlpha2: "RE",
    countryName: "Reunion",
    timeZones: ["Indian/Reunion"],
  },
  {
    isoAlpha2: "RO",
    countryName: "Romania",
    timeZones: ["Europe/Bucharest"],
  },
  {
    isoAlpha2: "RU",
    countryName: "Russia",
    timeZones: [
      "Asia/Anadyr",
      "Asia/Barnaul",
      "Asia/Chita",
      "Asia/Irkutsk",
      "Asia/Kamchatka",
      "Asia/Khandyga",
      "Asia/Krasnoyarsk",
      "Asia/Magadan",
      "Asia/Novokuznetsk",
      "Asia/Novosibirsk",
      "Asia/Omsk",
      "Asia/Sakhalin",
      "Asia/Srednekolymsk",
      "Asia/Tomsk",
      "Asia/Ust-Nera",
      "Asia/Vladivostok",
      "Asia/Yakutsk",
      "Asia/Yekaterinburg",
      "Europe/Astrakhan",
      "Europe/Kaliningrad",
      "Europe/Kirov",
      "Europe/Moscow",
      "Europe/Samara",
      "Europe/Saratov",
      "Europe/Ulyanovsk",
      "Europe/Volgograd",
    ],
  },
  {
    isoAlpha2: "RW",
    countryName: "Rwanda",
    timeZones: ["Africa/Kigali"],
  },
  {
    isoAlpha2: "SH",
    countryName: "Saint Helena",
    timeZones: ["Atlantic/St_Helena"],
  },
  {
    isoAlpha2: "KN",
    countryName: "Saint Kitts and Nevis",
    timeZones: ["America/St_Kitts"],
  },
  {
    isoAlpha2: "LC",
    countryName: "Saint Lucia",
    timeZones: ["America/St_Lucia"],
  },
  {
    isoAlpha2: "PM",
    countryName: "Saint Pierre and Miquelon",
    timeZones: ["America/Miquelon"],
  },
  {
    isoAlpha2: "VC",
    countryName: "Saint Vincent and the Grenadines",
    timeZones: ["America/St_Vincent"],
  },
  {
    isoAlpha2: "BL",
    countryName: "Saint-Barthelemy",
    timeZones: ["America/St_Barthelemy"],
  },
  {
    isoAlpha2: "MF",
    countryName: "Saint-Martin (French part)",
    timeZones: ["America/Marigot"],
  },
  {
    isoAlpha2: "WS",
    countryName: "Samoa",
    timeZones: ["Pacific/Apia"],
  },
  {
    isoAlpha2: "SM",
    countryName: "San Marino",
    timeZones: ["Europe/San_Marino"],
  },
  {
    isoAlpha2: "ST",
    countryName: "Sao Tome and Principe",
    timeZones: ["Africa/Sao_Tome"],
  },
  {
    isoAlpha2: "SA",
    countryName: "Saudi Arabia",
    timeZones: ["Asia/Riyadh"],
  },
  {
    isoAlpha2: "SN",
    countryName: "Senegal",
    timeZones: ["Africa/Dakar"],
  },
  {
    isoAlpha2: "RS",
    countryName: "Serbia",
    timeZones: ["Europe/Belgrade"],
  },
  {
    isoAlpha2: "SC",
    countryName: "Seychelles",
    timeZones: ["Indian/Mahe"],
  },
  {
    isoAlpha2: "SL",
    countryName: "Sierra Leone",
    timeZones: ["Africa/Freetown"],
  },
  {
    isoAlpha2: "SG",
    countryName: "Singapore",
    timeZones: ["Asia/Singapore"],
  },
  {
    isoAlpha2: "SX",
    countryName: "Sint Maarten (Dutch part)",
    timeZones: ["America/Anguilla"],
  },
  {
    isoAlpha2: "SK",
    countryName: "Slovakia",
    timeZones: ["Europe/Bratislava"],
  },
  {
    isoAlpha2: "SI",
    countryName: "Slovenia",
    timeZones: ["Europe/Ljubljana"],
  },
  {
    isoAlpha2: "SB",
    countryName: "Solomon Islands",
    timeZones: ["Pacific/Guadalcanal"],
  },
  {
    isoAlpha2: "SO",
    countryName: "Somalia",
    timeZones: ["Africa/Mogadishu"],
  },
  {
    isoAlpha2: "ZA",
    countryName: "South Africa",
    timeZones: ["Africa/Johannesburg"],
  },
  {
    isoAlpha2: "GS",
    countryName: "South Georgia",
    timeZones: ["Atlantic/South_Georgia"],
  },
  {
    isoAlpha2: "KR",
    countryName: "South Korea",
    timeZones: ["Asia/Seoul"],
  },
  {
    isoAlpha2: "SS",
    countryName: "South Sudan",
    timeZones: ["Africa/Juba"],
  },
  {
    isoAlpha2: "ES",
    countryName: "Spain",
    timeZones: ["Africa/Ceuta", "Atlantic/Canary", "Europe/Madrid"],
  },
  {
    isoAlpha2: "LK",
    countryName: "Sri Lanka",
    timeZones: ["Asia/Colombo"],
  },
  {
    isoAlpha2: "SD",
    countryName: "Sudan",
    timeZones: ["Africa/Khartoum"],
  },
  {
    isoAlpha2: "SR",
    countryName: "Suriname",
    timeZones: ["America/Paramaribo"],
  },
  {
    isoAlpha2: "SJ",
    countryName: "Svalbard and Jan Mayen Islands",
    timeZones: ["Arctic/Longyearbyen"],
  },
  {
    isoAlpha2: "SE",
    countryName: "Sweden",
    timeZones: ["Europe/Stockholm"],
  },
  {
    isoAlpha2: "CH",
    countryName: "Switzerland",
    timeZones: ["Europe/Zurich"],
  },
  {
    isoAlpha2: "SY",
    countryName: "Syria",
    timeZones: ["Asia/Damascus"],
  },
  {
    isoAlpha2: "TW",
    countryName: "Taiwan",
    timeZones: ["Asia/Taipei"],
  },
  {
    isoAlpha2: "TJ",
    countryName: "Tajikistan",
    timeZones: ["Asia/Dushanbe"],
  },
  {
    isoAlpha2: "TZ",
    countryName: "Tanzania",
    timeZones: ["Africa/Dar_es_Salaam"],
  },
  {
    isoAlpha2: "TH",
    countryName: "Thailand",
    timeZones: ["Asia/Bangkok"],
  },
  {
    isoAlpha2: "BS",
    countryName: "The Bahamas",
    timeZones: ["America/Nassau"],
  },
  {
    isoAlpha2: "GM",
    countryName: "The Gambia ",
    timeZones: ["Africa/Banjul"],
  },
  {
    isoAlpha2: "TL",
    countryName: "Timor-Leste",
    timeZones: ["Asia/Dili"],
  },
  {
    isoAlpha2: "TG",
    countryName: "Togo",
    timeZones: ["Africa/Lome"],
  },
  {
    isoAlpha2: "TK",
    countryName: "Tokelau",
    timeZones: ["Pacific/Fakaofo"],
  },
  {
    isoAlpha2: "TO",
    countryName: "Tonga",
    timeZones: ["Pacific/Tongatapu"],
  },
  {
    isoAlpha2: "TT",
    countryName: "Trinidad and Tobago",
    timeZones: ["America/Port_of_Spain"],
  },
  {
    isoAlpha2: "TN",
    countryName: "Tunisia",
    timeZones: ["Africa/Tunis"],
  },
  {
    isoAlpha2: "TR",
    countryName: "Turkey",
    timeZones: ["Europe/Istanbul"],
  },
  {
    isoAlpha2: "TM",
    countryName: "Turkmenistan",
    timeZones: ["Asia/Ashgabat"],
  },
  {
    isoAlpha2: "TC",
    countryName: "Turks and Caicos Islands",
    timeZones: ["America/Grand_Turk"],
  },
  {
    isoAlpha2: "TV",
    countryName: "Tuvalu",
    timeZones: ["Pacific/Funafuti"],
  },
  {
    isoAlpha2: "UG",
    countryName: "Uganda",
    timeZones: ["Africa/Kampala"],
  },
  {
    isoAlpha2: "UA",
    countryName: "Ukraine",
    timeZones: ["Europe/Kiev", "Europe/Simferopol", "Europe/Uzhgorod", "Europe/Zaporozhye"],
  },
  {
    isoAlpha2: "AE",
    countryName: "United Arab Emirates",
    timeZones: ["Asia/Dubai"],
  },
  {
    isoAlpha2: "GB",
    countryName: "United Kingdom",
    timeZones: ["Europe/London"],
  },
  {
    isoAlpha2: "US",
    countryName: "United States of America",
    timeZones: [
      "America/Adak",
      "America/Anchorage",
      "America/Boise",
      "America/Chicago",
      "America/Denver",
      "America/Detroit",
      "America/Indiana/Indianapolis",
      "America/Indiana/Knox",
      "America/Indiana/Marengo",
      "America/Indiana/Petersburg",
      "America/Indiana/Tell_City",
      "America/Indiana/Vevay",
      "America/Indiana/Vincennes",
      "America/Indiana/Winamac",
      "America/Juneau",
      "America/Kentucky/Louisville",
      "America/Kentucky/Monticello",
      "America/Los_Angeles",
      "America/Menominee",
      "America/Metlakatla",
      "America/New_York",
      "America/Nome",
      "America/North_Dakota/Beulah",
      "America/North_Dakota/Center",
      "America/North_Dakota/New_Salem",
      "America/Phoenix",
      "America/Sitka",
      "America/Yakutat",
      "Pacific/Honolulu",
    ],
  },
  {
    isoAlpha2: "UM",
    countryName: "United States Minor Outlying Islands",
    timeZones: ["Pacific/Midway", "Pacific/Wake"],
  },
  {
    isoAlpha2: "UY",
    countryName: "Uruguay",
    timeZones: ["America/Montevideo"],
  },
  {
    isoAlpha2: "UZ",
    countryName: "Uzbekistan",
    timeZones: ["Asia/Samarkand", "Asia/Tashkent"],
  },
  {
    isoAlpha2: "VU",
    countryName: "Vanuatu",
    timeZones: ["Pacific/Efate"],
  },
  {
    isoAlpha2: "VA",
    countryName: "Vatican City State (Holy See)",
    timeZones: ["Europe/Vatican"],
  },
  {
    isoAlpha2: "VE",
    countryName: "Venezuela",
    timeZones: ["America/Caracas"],
  },
  {
    isoAlpha2: "VN",
    countryName: "Vietnam",
    timeZones: ["Asia/Ho_Chi_Minh"],
  },
  {
    isoAlpha2: "VG",
    countryName: "Virgin Islands (British)",
    timeZones: ["America/Tortola"],
  },
  {
    isoAlpha2: "VI",
    countryName: "Virgin Islands (US)",
    timeZones: ["America/St_Thomas"],
  },
  {
    isoAlpha2: "WF",
    countryName: "Wallis and Futuna Islands",
    timeZones: ["Pacific/Wallis"],
  },
  {
    isoAlpha2: "EH",
    countryName: "Western Sahara",
    timeZones: ["Africa/El_Aaiun"],
  },
  {
    isoAlpha2: "YE",
    countryName: "Yemen",
    timeZones: ["Asia/Aden"],
  },
  {
    isoAlpha2: "ZM",
    countryName: "Zambia",
    timeZones: ["Africa/Lusaka"],
  },
  {
    isoAlpha2: "ZW",
    countryName: "Zimbabwe",
    timeZones: ["Africa/Harare"],
  },
]
let sofortCountries = [
  {
    isoAlpha3: "AUT",
    timeZones: ["Europe/Vienna"],
    countryName: "Austria",
    isoAlpha2: "AT",
  },
  {
    isoAlpha3: "BEL",
    timeZones: ["Europe/Brussels"],
    countryName: "Belgium",
    isoAlpha2: "BE",
  },
  {
    isoAlpha3: "DEU",
    timeZones: ["Europe/Berlin", "Europe/Busingen"],
    countryName: "Germany",
    isoAlpha2: "DE",
  },
  {
    isoAlpha3: "ITA",
    timeZones: ["Europe/Rome"],
    countryName: "Italy",
    isoAlpha2: "IT",
  },
  {
    isoAlpha3: "NLD",
    timeZones: ["Europe/Amsterdam"],
    countryName: "Netherlands",
    isoAlpha2: "NL",
  },
  {
    isoAlpha3: "ESP",
    timeZones: ["Europe/Madrid", "Africa/Ceuta", "Atlantic/Canary"],
    countryName: "Spain",
    isoAlpha2: "ES",
  },
]

let getCountry = (paymentMethodName, countryList: array<timezoneType>) => {
  switch paymentMethodName {
  | "sofort" => sofortCountries
  | _ => countryList
  }
}

let getCountryNameFromAlpha2Robust = (alpha2Code: string) => {
  let normalizedCode = alpha2Code->String.toUpperCase
  country
  ->Array.find(item => item.isoAlpha2->String.toUpperCase === normalizedCode)
  ->Option.map(item => item.countryName)
  ->Option.getOr(alpha2Code) // fallback to original code if not found
}

let getCountryNameFromAlpha2 = (alpha2Code: string) => {
  // Use robust version by default for better error handling
  getCountryNameFromAlpha2Robust(alpha2Code)
}

let getAlpha2FromCountryNameRobust = (countryName: string) => {
  let normalizedName = countryName->String.trim
  // First try exact match
  switch country->Array.find(item => item.countryName === normalizedName) {
  | Some(item) => item.isoAlpha2
  | None =>
    // Fallback to case-insensitive match
    switch country->Array.find(item =>
      item.countryName->String.toUpperCase === normalizedName->String.toUpperCase
    ) {
    | Some(item) => item.isoAlpha2
    | None => countryName // final fallback to original name
    }
  }
}

let getAlpha2FromCountryName = (countryName: string) => {
  // Use robust version by default for better error handling
  getAlpha2FromCountryNameRobust(countryName)
}

// Utility function to get all countries with both alpha2 codes and human-readable names
let getAllCountriesWithMapping = () => {
  country->Array.map(item => {
    isoAlpha2: item.isoAlpha2,
    countryName: item.countryName,
    timeZones: item.timeZones,
  })
}
