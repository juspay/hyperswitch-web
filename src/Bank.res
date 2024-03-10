type bank = {
  displayName: string,
  hyperSwitch: string,
}
type bankList = array<bank>
let defaultEpsBank = {
  displayName: "Ärzte- und Apothekerbank",
  hyperSwitch: "arzte_und_apotheker_bank",
}
let defaultIdealBank = {
  displayName: "ABN AMRO",
  hyperSwitch: "abn_amro",
}
let defaultBank = {
  displayName: "",
  hyperSwitch: "",
}

let polandBanks = [
  {displayName: "Alior Bank", hyperSwitch: "pay_with_alior_bank"},
  {displayName: "Bank Nowy S.A.", hyperSwitch: "bank_nowy_s_a"},
  {displayName: "Citi Handlowy", hyperSwitch: "pay_with_citi_handlowy"},
  {displayName: "Santander Przelew24", hyperSwitch: "santander_przelew24"},
  {displayName: "Bank Ochrony Środowiska", hyperSwitch: "pay_with_b_o_s"},
  {displayName: "Bank Millennium", hyperSwitch: "bank_millennium"},
  {displayName: "e-transfer Pocztowy24", hyperSwitch: "e_transfer_pocztowy24"},
  {displayName: "Velo Bank", hyperSwitch: "velo_bank"},
  {displayName: "Bank Pekao S.A.", hyperSwitch: "bank_p_e_k_a_o_s_a"},
  {displayName: "Inteligo", hyperSwitch: "pay_with_inteligo"},
  {displayName: "Plus Bank", hyperSwitch: "pay_with_plus_bank"},
  {displayName: "Banki Spółdzielcze", hyperSwitch: "banki_spoldzielcze"},
  {displayName: "ING", hyperSwitch: "pay_with_i_n_g"},
  {displayName: "mBank", hyperSwitch: "m_bank"},
  {displayName: "Credit Agricole", hyperSwitch: "credit_agricole"},
  {displayName: "Toyota Bank", hyperSwitch: "toyota_bank"},
  {displayName: "BLIK PSP", hyperSwitch: "blik_p_s_p"},
  {displayName: "BNP Paribas Poland", hyperSwitch: "b_n_p_paribas_poland"},
  {displayName: "Place Z Ipką", hyperSwitch: "place_z_i_p_k_o"},
]

let czechBanks = [
  {displayName: "Česká spořitelna", hyperSwitch: "ceska_sporitelna"},
  {displayName: "Komerční banka", hyperSwitch: "komercni_banka"},
  {
    displayName: "Platność Online - Karta płatnicza",
    hyperSwitch: "platnosc_online_karta_platnicza",
  },
]
let p24Banks = [
  {displayName: "Alior Bank", hyperSwitch: "alior_bank"},
  {displayName: "Inteligo", hyperSwitch: "inteligo"},
  {displayName: "BLIK", hyperSwitch: "blik"},
  {displayName: "Nest Przelew", hyperSwitch: "nest_przelew"},
  {displayName: "Noble Pay", hyperSwitch: "noble_pay"},
  {displayName: "Plus Bank", hyperSwitch: "plus_bank"},
  {displayName: "PBAc z iPKO", hyperSwitch: "pbac_z_ipko"},
  {displayName: "Volkswagen Bank", hyperSwitch: "volkswagen_bank"},
  {displayName: "Citi", hyperSwitch: "citi"},
  {displayName: "Bank Nowy BFG SA", hyperSwitch: "bank_nowy_bfg_sa"},
  {displayName: "eTransfer Pocztowy24", hyperSwitch: "e_transfer_pocztowy24"},
  {displayName: "Toyota Bank", hyperSwitch: "toyota_bank"},
  {displayName: "BOŚ", hyperSwitch: "boz"},
  {displayName: "Getin Bank", hyperSwitch: "getin_bank"},
  {displayName: "Idea Bank", hyperSwitch: "idea_bank"},
  {displayName: "Bank Pekao SA", hyperSwitch: "bank_pekao_sa"},
  {displayName: "BNP Paribas", hyperSwitch: "bnp_paribas"},
  {displayName: "Santander Przelew24", hyperSwitch: "santander_przelew24"},
  {displayName: "mBank mTransfer", hyperSwitch: "mbank_mtransfer"},
  {displayName: "Banki Spółdzielcze", hyperSwitch: "banki_spbdzielcze"},
  {displayName: "Credit Agricole", hyperSwitch: "credit_agricole"},
  {displayName: "Bank Millennium", hyperSwitch: "bank_millennium"},
]

let idealBanks = [
  {
    displayName: "ABN AMRO",
    hyperSwitch: "abn_amro",
  },
  {
    displayName: "ASN Bank",
    hyperSwitch: "asn_bank",
  },
  {
    displayName: "Bunq",
    hyperSwitch: "bunq",
  },
  {
    displayName: "Handelsbanken",
    hyperSwitch: "handelsbanken",
  },
  {
    displayName: "ING",
    hyperSwitch: "ing",
  },
  {
    displayName: "Knab",
    hyperSwitch: "knab",
  },
  {
    displayName: "Moneyou",
    hyperSwitch: "moneyou",
  },
  {
    displayName: "N26",
    hyperSwitch: "n26",
  },
  {
    displayName: "Nationale-Nederlanden (NN Group)",
    hyperSwitch: "nationale_nederlanden",
  },
  {
    displayName: "Rabobank",
    hyperSwitch: "rabobank",
  },
  {
    displayName: "RegioBank",
    hyperSwitch: "regiobank",
  },
  {
    displayName: "Revolut",
    hyperSwitch: "revolut",
  },
  {
    displayName: "SNS Bank (De Volksbank)",
    hyperSwitch: "sns_bank",
  },
  {
    displayName: "Triodos Bank",
    hyperSwitch: "triodos_bank",
  },
  {
    displayName: "Van Lanschot",
    hyperSwitch: "van_lanschot",
  },
  {
    displayName: "Yoursafe",
    hyperSwitch: "yoursafe",
  },
]

let epsBanks = [
  {
    displayName: "Ärzte- und Apothekerbank",
    hyperSwitch: "arzte_und_apotheker_bank",
  },
  {
    displayName: "Austrian Anadi Bank AG",
    hyperSwitch: "austrian_anadi_bank_ag",
  },
  {
    displayName: "Bank Austria",
    hyperSwitch: "bank_austria",
  },
  {
    displayName: "bank99 AG",
    hyperSwitch: "bank99_AG",
  },
  {
    displayName: "Bankhaus Carl Spängler & Co.AG",
    hyperSwitch: "bankhaus_carl_spangler",
  },
  {
    displayName: "Bankhaus Schelhammer & Schattera AG",
    hyperSwitch: "bankhaus_schelhammer_und_schattera_ag",
  },
  {
    displayName: "BAWAG P.S.K. AG",
    hyperSwitch: "bawag_psk_ag",
  },
  {
    displayName: "BKS Bank AG",
    hyperSwitch: "bks_bank_ag",
  },
  {
    displayName: "Brüll Kallmus Bank AG",
    hyperSwitch: "brull_kallmus_bank_ag",
  },
  {
    displayName: "BTV VIER LÄNDER BANK",
    hyperSwitch: "btv_vier_lander_bank",
  },
  {
    displayName: "Capital Bank Grawe Gruppe AG",
    hyperSwitch: "capital_bank_grawe_gruppe_ag",
  },
  {
    displayName: "Dolomitenbank",
    hyperSwitch: "dolomitenbank",
  },
  {
    displayName: "Easybank AG",
    hyperSwitch: "easybank_ag",
  },
  {
    displayName: "Erste Bank und Sparkassen",
    hyperSwitch: "erste_bank_und_sparkassen",
  },
  {
    displayName: "Hypo Alpe-Adria-Bank International AG",
    hyperSwitch: "hypo_alpeadriabank_international_ag",
  },
  {
    displayName: "HYPO NOE LB für Niederösterreich u. Wien",
    hyperSwitch: "hypo_noe_lb_fur_niederosterreich_u_wien",
  },
  {
    displayName: "HYPO Oberösterreich, Salzburg, Steiermark",
    hyperSwitch: "hypo_oberosterreich_salzburg_steiermark",
  },
  {
    displayName: "Hypo Tirol Bank AG",
    hyperSwitch: "hypo_tirol_bank_ag",
  },
  {
    displayName: "Hypo Vorarlberg Bank AG",
    hyperSwitch: "hypo_vorarlberg_bank_ag",
  },
  {
    displayName: "HYPO-BANK BURGENLAND Aktiengesellschaft",
    hyperSwitch: "hypo_bank_burgenland_aktiengesellschaft",
  },
  {
    displayName: "Marchfelder Bank",
    hyperSwitch: "marchfelder_bank",
  },
  {
    displayName: "Oberbank AG",
    hyperSwitch: "oberbank_ag",
  },
  {
    displayName: "Österreichische Ärzte- und Apothekerbank",
    hyperSwitch: "osterreichische_arzte_und_apothekerbank",
  },
  {
    displayName: "Posojilnica Bank eGen",
    hyperSwitch: "posojilnica_bank_e_gen",
  },
  {
    displayName: "Raiffeisen Bankengruppe Österreich",
    hyperSwitch: "raiffeisen_bankengruppe_osterreich",
  },
  {
    displayName: "Schelhammer Capital Bank AG",
    hyperSwitch: "schelhammer_capital_bank_ag",
  },
  {
    displayName: "Schoellerbank AG",
    hyperSwitch: "schoellerbank_ag",
  },
  {
    displayName: "Sparda-Bank Wien",
    hyperSwitch: "sparda_bank_wien",
  },
  {
    displayName: "Volksbank Gruppe",
    hyperSwitch: "volksbank_gruppe",
  },
  {
    displayName: "Volkskreditbank AG",
    hyperSwitch: "volkskreditbank_ag",
  },
  {
    displayName: "VR-Bank Braunau",
    hyperSwitch: "vr_bank_braunau",
  },
]
let slovakiaBanks = [
  {displayName: "ePlatby VUB", hyperSwitch: "e_platby_v_u_b"},
  {displayName: `Poštová banka`, hyperSwitch: "postova_banka"},
  {displayName: "Tatra Pay", hyperSwitch: "tatra_pay"},
  {displayName: "Viamo", hyperSwitch: "viamo"},
  {displayName: "Sporo Pay", hyperSwitch: "sporo_pay"},
]
let fpxBanks = [
  {displayName: "Affin Bank", hyperSwitch: "affin_bank"},
  {displayName: "Agro Bank", hyperSwitch: "agro_bank"},
  {displayName: "Alliance Bank", hyperSwitch: "alliance_bank"},
  {displayName: "Am Bank", hyperSwitch: "am_bank"},
  {displayName: "Bank Rakyat", hyperSwitch: "bank_rakyat"},
  {displayName: "Bank Simpanan Nasional", hyperSwitch: "bank_simpanan_nasional"},
  {displayName: "CIMB Bank", hyperSwitch: "cimb_bank"},
  {displayName: "Hong Leong Bank", hyperSwitch: "hong_leong_bank"},
  {displayName: "Bank Muamalat", hyperSwitch: "bank_muamalat"},
  {displayName: "HSBC Bank", hyperSwitch: "hsbc_bank"},
  {displayName: "Kuwait Finance House", hyperSwitch: "kuwait_finance_house"},
  {displayName: "Maybank", hyperSwitch: "may_bank"},
  {displayName: "OCBC Bank", hyperSwitch: "ocbc_bank"},
  {displayName: "Public Bank", hyperSwitch: "public_bank"},
  {displayName: "RHB Bank", hyperSwitch: "rhb_bank"},
  {displayName: "Standard Chartered Bank", hyperSwitch: "standard_chartered_bank"},
  {displayName: "UOB Bank", hyperSwitch: "uob_bank"},
]
let thailandBanks = [
  {displayName: "Bangkok Bank", hyperSwitch: "bangkok_bank"},
  {displayName: "Krungsri Bank", hyperSwitch: "krungsri_bank"},
  {displayName: "Krung Thai Bank", hyperSwitch: "krung_thai_bank"},
  {displayName: "The Siam Commercial Bank", hyperSwitch: "the_siam_commercial_bank"},
  {displayName: "Kasikorn Bank", hyperSwitch: "kasikorn_bank"},
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
