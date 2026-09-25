// Connector names — value is the creds.json top-level key for that connector,
// which setup/merchant-setup.js also uses as the connectorProfileIds key.
export const connectorEnum = {
  TRUSTPAY: "trustpay",
  ADYEN: "adyen",
  FIUU: "fiuu",
  VOLT: "volt",
  STRIPE: "stripe",
  NETCETERA: "netcetera",
  REDSYS: "redsys",
  MIFINITY: "mifinity",
  CRYPTOPAY: "cryptopay",
  BANK_OF_AMERICA: "bankofamerica",
  CYBERSOURCE: "cybersource",
  CASHTOCODE: "cashtocode",
  JUSPAY: "juspay",
  INTERAC: "interac",
  PAYPAL: "paypal",
  TRUSTLY: "trustly",
  /** In merchant-setup.js REQUIRED_CONNECTORS (Klarna MCA, redirect_to_url only today). */
  KLARNA: "klarna",
  /** Not provisioned by merchant-setup.js yet (no "plaid" in REQUIRED_CONNECTORS). */
  PLAID: "plaid",
} as const;

export type Connector = (typeof connectorEnum)[keyof typeof connectorEnum];
