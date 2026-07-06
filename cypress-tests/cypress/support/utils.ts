
// ---------------------------------------------------------------------------
// Demo-app base URL
// ---------------------------------------------------------------------------

/** Default demo-app port when running locally. Overridable via Cypress.env. */
export const CLIENT_BASE_URL = "http://localhost:9060";

/**
 * Returns the actual demo-app base URL at runtime.
 * Reads CLIENT_BASE_URL from Cypress.env() so that CI / different
 * environments can override it without code changes.
 */
const getClientBaseUrl = (): string =>
  (Cypress.env("CLIENT_BASE_URL") as string | undefined) || CLIENT_BASE_URL;

// ---------------------------------------------------------------------------
// URL builder
// ---------------------------------------------------------------------------

export const getClientURL = (
  clientSecret: string,
  publishableKey: string,
  locale?: string,
  theme?: string,
  layout?: string | Record<string, unknown>,
  options?: Record<string, unknown>,
) => {
  const baseUrl = getClientBaseUrl();
  let url = `${baseUrl}?isCypressTestMode=true&clientSecret=${clientSecret}&publishableKey=${publishableKey}`;
  if (createPaymentBody.profile_id) {
    url += `&profileId=${encodeURIComponent(createPaymentBody.profile_id)}`;
  }
  if (locale) {
    url += `&locale=${locale}`;
  }
  if (theme) {
    url += `&theme=${theme}`;
  }
  if (layout) {
    const layoutValue =
      typeof layout === "string" ? layout : JSON.stringify(layout);
    url += `&layout=${encodeURIComponent(layoutValue)}`;
  }
  if (options) {
    url += `&options=${encodeURIComponent(JSON.stringify(options))}`;
  }
  return url;
};

// ---------------------------------------------------------------------------
// Connector enum — value is the creds.json top-level key for that connector.
// ---------------------------------------------------------------------------

export enum connectorEnum {
  TRUSTPAY = "trustpay",
  ADYEN = "adyen",
  STRIPE = "stripe",
  NETCETERA = "netcetera",
  REDSYS = "redsys",
  MIFINITY = "mifinity",
  CRYPTOPAY = "cryptopay",
  BANK_OF_AMERICA = "bankofamerica",
  CYBERSOURCE = "cybersource",
  CASHTOCODE = "cashtocode",
  JUSPAY = "juspay",
  INTERAC = "interac",
  PAYPAL = "paypal",
}

// ---------------------------------------------------------------------------
// Profile ID lookup — reads from Cypress.env("CONNECTOR_PROFILE_IDS")
//
// CONNECTOR_PROFILE_IDS is populated by the global before() hook in e2e.ts
// after cy.task("setupCredentials") resolves.  It has the shape:
//   { stripe: "pro_...", adyen: "pro_...", ... }
// ---------------------------------------------------------------------------

/**
 * Env-aware profile ID lookup.
 * Preserves the same `.get()` API used across all test files so no caller
 * changes are required when switching from static maps to dynamic lookup.
 */
export const connectorProfileIdMapping = {
  get: (connector: connectorEnum): string | undefined => {
    const ids = Cypress.env("CONNECTOR_PROFILE_IDS") as Record<string, string> | undefined;
    return ids?.[connector];
  },
};

/**
 * Returns the Stripe profile ID for the current run.
 * Used to initialise createPaymentBody.profile_id in the global before() hook.
 */
export const getDefaultProfileId = (): string => {
  const ids = Cypress.env("CONNECTOR_PROFILE_IDS") as Record<string, string> | undefined;
  return ids?.[connectorEnum.STRIPE] ?? "";
};

// ---------------------------------------------------------------------------
// Shared payment body (mutated per-test via changeObjectKeyValue)
// ---------------------------------------------------------------------------

export const createPaymentBody = {
  currency: "USD",
  amount: 2999,
  order_details: [
    {
      product_name: "Apple iPhone 15",
      quantity: 1,
      amount: 2999,
    },
  ],
  confirm: false,
  capture_method: "automatic",
  authentication_type: "no_three_ds",
  customer_id: "hyperswitch_sdk_demo_id",
  email: "hyperswitch_sdk_demo_id@gmail.com",
  request_external_three_ds_authentication: false,
  description: "Hello this is description",
  shipping: {
    address: {
      line1: "1467",
      line2: "Harrison Street",
      line3: "Harrison Street",
      city: "San Francisco",
      state: "California",
      zip: "94122",
      country: "US",
      first_name: "joseph",
      last_name: "Doe",
    },
    phone: {
      number: "8056594427",
      country_code: "+91",
    },
  },
  metadata: {
    udf1: "value1",
    new_customer: "true",
    login_date: "2019-09-10T10:11:12Z",
  },
  // Resolved at runtime in e2e.ts before() hook after setupCredentials resolves.
  profile_id: "",
  billing: {
    email: "hyperswitch_sdk_demo_id@gmail.com",
    address: {
      line1: "1467",
      line2: "Harrison Street",
      line3: "Harrison Street",
      city: "San Francisco",
      state: "California",
      zip: "94122",
      country: "US",
      first_name: "joseph",
      last_name: "Doe",
    },
    phone: {
      number: "8056594427",
      country_code: "+91",
    },
  },
};

export const defaultBillingAddress = {
  line1: "1467",
  line2: "Harrison Street",
  line3: "Harrison Street",
  city: "San Francisco",
  state: "California",
  zip: "94122",
  country: "US",
  first_name: "joseph",
  last_name: "Doe",
};

export const changeObjectKeyValue = (
  object: Record<string, any>,
  key: string,
  value: boolean | string | object,
) => {
  object[key] = value;
};

export const removeObjectKey = (
  object: Record<string, any>,
  key: string,
) => {
  delete object[key];
};

export const confirmBody = {
  client_secret: "",
  return_url: "http://localhost:9060/completion",
  payment_method: "card",
  payment_method_data: {
    card: {
      card_number: "4000000000001091",
      card_exp_month: "01",
      card_exp_year: "28",
      card_holder_name: "",
      card_cvc: "424",
      card_issuer: "",
      card_network: "Visa",
    },
  },
  billing: {
    address: {
      state: "New York",
      city: "New York",
      country: "US",
      first_name: "John",
      last_name: "Doe",
      zip: "10001",
      line1: "123 Main Street Apt 4B",
    },
  },
  email: "hyperswitch_sdk_demo_id@gmail.com",
  browser_info: {
    user_agent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    accept_header:
      "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
    language: "en-US",
    color_depth: 30,
    screen_height: 1117,
    screen_width: 1728,
    time_zone: -330,
    java_enabled: true,
    java_script_enabled: true,
  },
};

export const stripeTestCard = "4000000000003220";
export const adyenTestCard = "4917610000000000";
export const bluesnapTestCard = "4000000000001091";
export const amexTestCard = "378282246310005";
export const visaTestCard = "4242424242424242";
export const netceteraChallengeTestCard = "348638267931507";
export const netceteraFrictionlessTestCard = "4929251897047956";
export const juspayChallengeTestCard = "5306889942833340";
export const juspayFrictionlessTestCard = "4929251897047956";
