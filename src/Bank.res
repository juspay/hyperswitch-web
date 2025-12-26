type bank = {
  displayName: string,
  value: string,
}
type bankList = array<bank>
let defaultEpsBank = {
  displayName: "Ärzte- und Apothekerbank",
  value: "arzte_und_apotheker_bank",
}
let defaultIdealBank = {
  displayName: "ABN AMRO",
  value: "abn_amro",
}
let defaultBank = {
  displayName: "",
  value: "",
}

let polandBanks = [
  {
    displayName: "Alior Bank",
    value: "pay_with_alior_bank",
  },
  {
    displayName: "Bank Nowy S.A.",
    value: "bank_nowy_s_a",
  },
  {
    displayName: "Citi Handlowy",
    value: "pay_with_citi_handlowy",
  },
  {
    displayName: "Santander Przelew24",
    value: "santander_przelew24",
  },
  {
    displayName: "Bank Ochrony Środowiska",
    value: "pay_with_b_o_s",
  },
  {
    displayName: "Bank Millennium",
    value: "bank_millennium",
  },
  {
    displayName: "e-transfer Pocztowy24",
    value: "e_transfer_pocztowy24",
  },
  {
    displayName: "Velo Bank",
    value: "velo_bank",
  },
  {
    displayName: "Bank Pekao S.A.",
    value: "bank_p_e_k_a_o_s_a",
  },
  {
    displayName: "Inteligo",
    value: "pay_with_inteligo",
  },
  {
    displayName: "Plus Bank",
    value: "pay_with_plus_bank",
  },
  {
    displayName: "Banki Spółdzielcze",
    value: "banki_spoldzielcze",
  },
  {
    displayName: "ING",
    value: "pay_with_i_n_g",
  },
  {
    displayName: "mBank",
    value: "m_bank",
  },
  {
    displayName: "Credit Agricole",
    value: "credit_agricole",
  },
  {
    displayName: "Toyota Bank",
    value: "toyota_bank",
  },
  {
    displayName: "BLIK PSP",
    value: "blik_p_s_p",
  },
  {
    displayName: "BNP Paribas Poland",
    value: "b_n_p_paribas_poland",
  },
  {
    displayName: "Place Z Ipką",
    value: "place_z_i_p_k_o",
  },
]

let czechBanks = [
  {
    displayName: "Česká spořitelna",
    value: "ceska_sporitelna",
  },
  {
    displayName: "Komerční banka",
    value: "komercni_banka",
  },
  {
    displayName: "Platność Online - Karta płatnicza",
    value: "platnosc_online_karta_platnicza",
  },
]
let p24Banks = [
  {
    displayName: "Alior Bank",
    value: "alior_bank",
  },
  {
    displayName: "Inteligo",
    value: "inteligo",
  },
  {
    displayName: "BLIK",
    value: "blik",
  },
  {
    displayName: "Nest Przelew",
    value: "nest_przelew",
  },
  {
    displayName: "Noble Pay",
    value: "noble_pay",
  },
  {
    displayName: "Plus Bank",
    value: "plus_bank",
  },
  {
    displayName: "PBAc z iPKO",
    value: "pbac_z_ipko",
  },
  {
    displayName: "Volkswagen Bank",
    value: "volkswagen_bank",
  },
  {
    displayName: "Citi",
    value: "citi",
  },
  {
    displayName: "Bank Nowy BFG SA",
    value: "bank_nowy_bfg_sa",
  },
  {
    displayName: "eTransfer Pocztowy24",
    value: "e_transfer_pocztowy24",
  },
  {
    displayName: "Toyota Bank",
    value: "toyota_bank",
  },
  {
    displayName: "BOŚ",
    value: "boz",
  },
  {
    displayName: "Getin Bank",
    value: "getin_bank",
  },
  {
    displayName: "Idea Bank",
    value: "idea_bank",
  },
  {
    displayName: "Bank Pekao SA",
    value: "bank_pekao_sa",
  },
  {
    displayName: "BNP Paribas",
    value: "bnp_paribas",
  },
  {
    displayName: "Santander Przelew24",
    value: "santander_przelew24",
  },
  {
    displayName: "mBank mTransfer",
    value: "mbank_mtransfer",
  },
  {
    displayName: "Banki Spółdzielcze",
    value: "banki_spbdzielcze",
  },
  {
    displayName: "Credit Agricole",
    value: "credit_agricole",
  },
  {
    displayName: "Bank Millennium",
    value: "bank_millennium",
  },
]

let idealBanks = [
  {
    displayName: "ABN AMRO",
    value: "abn_amro",
  },
  {
    displayName: "ASN Bank",
    value: "asn_bank",
  },
  {
    displayName: "ASN Bank",
    value: "asn",
  },
  {
    displayName: "Bunq",
    value: "bunq",
  },
  {
    displayName: "Handelsbanken",
    value: "handelsbanken",
  },
  {
    displayName: "ING",
    value: "ing",
  },
  {
    displayName: "Knab",
    value: "knab",
  },
  {
    displayName: "Moneyou",
    value: "moneyou",
  },
  {
    displayName: "N26",
    value: "n26",
  },
  {
    displayName: "Nationale-Nederlanden (NN Group)",
    value: "nationale_nederlanden",
  },
  {
    displayName: "Rabobank",
    value: "rabobank",
  },
  {
    displayName: "RegioBank",
    value: "regiobank",
  },
  {
    displayName: "Revolut",
    value: "revolut",
  },
  {
    displayName: "SNS Bank (De Volksbank)",
    value: "sns_bank",
  },
  {
    displayName: "SNS Bank",
    value: "sns",
  },
  {
    displayName: "Triodos Bank",
    value: "triodos_bank",
  },
  {
    displayName: "Triodos Bank",
    value: "triodos",
  },
  {
    displayName: "Van Lanschot",
    value: "van_lanschot",
  },
  {
    displayName: "Van Lanschot Kempen",
    value: "van_lanschot_kempen",
  },
  {
    displayName: "Yoursafe",
    value: "yoursafe",
  },
]

let epsBanks = [
  {
    displayName: "Ärzte- und Apothekerbank",
    value: "arzte_und_apotheker_bank",
  },
  {
    displayName: "Austrian Anadi Bank AG",
    value: "austrian_anadi_bank_ag",
  },
  {
    displayName: "Bank Austria",
    value: "bank_austria",
  },
  {
    displayName: "bank99 AG",
    value: "bank99_AG",
  },
  {
    displayName: "Bankhaus Carl Spängler & Co.AG",
    value: "bankhaus_carl_spangler",
  },
  {
    displayName: "Bankhaus Schelhammer & Schattera AG",
    value: "bankhaus_schelhammer_und_schattera_ag",
  },
  {
    displayName: "BAWAG P.S.K. AG",
    value: "bawag_psk_ag",
  },
  {
    displayName: "BKS Bank AG",
    value: "bks_bank_ag",
  },
  {
    displayName: "Brüll Kallmus Bank AG",
    value: "brull_kallmus_bank_ag",
  },
  {
    displayName: "BTV VIER LÄNDER BANK",
    value: "btv_vier_lander_bank",
  },
  {
    displayName: "Capital Bank Grawe Gruppe AG",
    value: "capital_bank_grawe_gruppe_ag",
  },
  {
    displayName: "Dolomitenbank",
    value: "dolomitenbank",
  },
  {
    displayName: "Easybank AG",
    value: "easybank_ag",
  },
  {
    displayName: "Erste Bank und Sparkassen",
    value: "erste_bank_und_sparkassen",
  },
  {
    displayName: "Hypo Alpe-Adria-Bank International AG",
    value: "hypo_alpeadriabank_international_ag",
  },
  {
    displayName: "HYPO NOE LB für Niederösterreich u. Wien",
    value: "hypo_noe_lb_fur_niederosterreich_u_wien",
  },
  {
    displayName: "HYPO Oberösterreich, Salzburg, Steiermark",
    value: "hypo_oberosterreich_salzburg_steiermark",
  },
  {
    displayName: "Hypo Tirol Bank AG",
    value: "hypo_tirol_bank_ag",
  },
  {
    displayName: "Hypo Vorarlberg Bank AG",
    value: "hypo_vorarlberg_bank_ag",
  },
  {
    displayName: "HYPO-BANK BURGENLAND Aktiengesellschaft",
    value: "hypo_bank_burgenland_aktiengesellschaft",
  },
  {
    displayName: "Marchfelder Bank",
    value: "marchfelder_bank",
  },
  {
    displayName: "Oberbank AG",
    value: "oberbank_ag",
  },
  {
    displayName: "Österreichische Ärzte- und Apothekerbank",
    value: "osterreichische_arzte_und_apothekerbank",
  },
  {
    displayName: "Posojilnica Bank eGen",
    value: "posojilnica_bank_e_gen",
  },
  {
    displayName: "Raiffeisen Bankengruppe Österreich",
    value: "raiffeisen_bankengruppe_osterreich",
  },
  {
    displayName: "Schelhammer Capital Bank AG",
    value: "schelhammer_capital_bank_ag",
  },
  {
    displayName: "Schoellerbank AG",
    value: "schoellerbank_ag",
  },
  {
    displayName: "Sparda-Bank Wien",
    value: "sparda_bank_wien",
  },
  {
    displayName: "Volksbank Gruppe",
    value: "volksbank_gruppe",
  },
  {
    displayName: "Volkskreditbank AG",
    value: "volkskreditbank_ag",
  },
  {
    displayName: "VR-Bank Braunau",
    value: "vr_bank_braunau",
  },
]
let slovakiaBanks = [
  {
    displayName: "ePlatby VUB",
    value: "e_platby_v_u_b",
  },
  {
    displayName: `Poštová banka`,
    value: "postova_banka",
  },
  {
    displayName: "Tatra Pay",
    value: "tatra_pay",
  },
  {
    displayName: "Viamo",
    value: "viamo",
  },
  {
    displayName: "Sporo Pay",
    value: "sporo_pay",
  },
]
let fpxBanks = [
  {
    displayName: "Affin Bank",
    value: "affin_bank",
  },
  {
    displayName: "Agro Bank",
    value: "agro_bank",
  },
  {
    displayName: "Alliance Bank",
    value: "alliance_bank",
  },
  {
    displayName: "Am Bank",
    value: "am_bank",
  },
  {
    displayName: "Bank Islam",
    value: "bank_islam",
  },
  {
    displayName: "Bank Of China",
    value: "bank_of_china",
  },
  {
    displayName: "Bank Rakyat",
    value: "bank_rakyat",
  },
  {
    displayName: "Bank Simpanan Nasional",
    value: "bank_simpanan_nasional",
  },
  {
    displayName: "CIMB Bank",
    value: "cimb_bank",
  },
  {
    displayName: "Hong Leong Bank",
    value: "hong_leong_bank",
  },
  {
    displayName: "Bank Muamalat",
    value: "bank_muamalat",
  },
  {
    displayName: "HSBC Bank",
    value: "hsbc_bank",
  },
  {
    displayName: "Kuwait Finance House",
    value: "kuwait_finance_house",
  },
  {
    displayName: "Maybank",
    value: "maybank",
  },
  {
    displayName: "Citibank",
    value: "citi",
  },
  {
    displayName: "OCBC Bank",
    value: "ocbc_bank",
  },
  {
    displayName: "Public Bank",
    value: "public_bank",
  },
  {
    displayName: "RHB Bank",
    value: "rhb_bank",
  },
  {
    displayName: "Standard Chartered Bank",
    value: "standard_chartered_bank",
  },
  {
    displayName: "UOB Bank",
    value: "uob_bank",
  },
]
let thailandBanks = [
  {
    displayName: "Bangkok Bank",
    value: "bangkok_bank",
  },
  {
    displayName: "Krungsri Bank",
    value: "krungsri_bank",
  },
  {
    displayName: "Krung Thai Bank",
    value: "krung_thai_bank",
  },
  {
    displayName: "The Siam Commercial Bank",
    value: "the_siam_commercial_bank",
  },
  {
    displayName: "Kasikorn Bank",
    value: "kasikorn_bank",
  },
]

let getBanks = paymentMethodName => {
  switch paymentMethodName {
  | "ideal" => idealBanks
  | "eps" => epsBanks
  | "online_banking_czech_republic" => czechBanks
  | "online_banking_poland" => polandBanks
  | "online_banking_slovakia" => slovakiaBanks
  | "online_banking_fpx" => fpxBanks
  | "online_banking_thailand" => thailandBanks
  | "przelewy24" => p24Banks
  | _ => []
  }
}
