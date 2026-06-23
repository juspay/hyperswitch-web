// @ts-check
"use strict";

/**
 * Credential orchestration module (Node.js / Cypress task context).
 *
 * Called once per test run via cy.task("setupCredentials") in the global
 * before() hook. Creates a fresh Hyperswitch merchant account, then for each
 * connector found in creds.json:
 *   1. Creates a dedicated business profile
 *   2. Creates a merchant connector account (MCA) on that profile
 *
 * Returns { publishableKey, secretKey, merchantId, connectorProfileIds } which
 * is injected into Cypress.env() so that every test can read it at runtime.
 *
 * creds.json format (mirrors juspay/hyperswitch backend test convention):
 * {
 *   "stripe": {
 *     "connector_account_details": { "auth_type": "HeaderKey", "api_key": "sk_test_..." }
 *   },
 *   "adyen": {
 *     "connector_1": {
 *       "connector_account_details": { "auth_type": "SignatureKey", "api_key": "...", ... }
 *     }
 *   }
 * }
 */

const fs = require("fs");
const path = require("path");

// ---------------------------------------------------------------------------
// Per-run cache — lives in the Node.js process for the entire Cypress run.
//
// The global before() hook in e2e.ts fires once per SPEC FILE, which means
// cy.task("setupCredentials") would be called 38 times (once per spec).
// Without this cache that would create 38 separate merchant accounts.
//
// Because Node.js caches modules, this variable survives for the whole run:
//   - Spec 1  → cache miss  → real API calls → merchant created → stored here
//   - Spec 2+ → cache hit   → returns instantly, zero API calls
// ---------------------------------------------------------------------------
/** @type {{ publishableKey: string, secretKey: string, merchantId: string, connectorProfileIds: Record<string, string> } | null} */
let _credentialsCache = null;

// ---------------------------------------------------------------------------
// Connector type overrides.
//
// Most connectors are "payment_processor", but some are not:
//   - netcetera: a 3DS authentication server (connector_type: "three_ds_server")
//
// Any connector not listed here defaults to "payment_processor".
// ---------------------------------------------------------------------------
const CONNECTOR_TYPE_MAP = {
  netcetera: "authentication_processor",
};

// ---------------------------------------------------------------------------
// Payment methods enabled per connector.
//
// "default" applies to every card-based processor not listed explicitly below.
//
// Connector-specific overrides are needed when:
//   - The payment method type is not "card" (wallets, crypto, voucher, redirect)
//   - A specific card network not in the default list must be enabled
//     (e.g. CartesBancaires for Cybersource cobadge tests)
//   - Both card AND non-card methods must be enabled (e.g. TrustPay)
//
// Test-file-level differences (currency, authentication_type,
// setup_future_usage, connector routing) are set on the payment body at
// runtime — they do NOT require a different MCA or merchant.
// ---------------------------------------------------------------------------
const CONNECTOR_PAYMENT_METHODS = {
  // ── Card processors (default) ───────────────────────────────────────────
  // Covers: stripe, adyen, netcetera, redsys, bankofamerica, juspay
  // recurring_enabled: true  → supports mandate / setup_future_usage flows
  default: [
    {
      payment_method: "card",
      payment_method_types: [
        {
          payment_method_type: "credit",
          card_networks: ["Visa", "Mastercard", "AmericanExpress", "UnionPay", "DinersClub"],
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: true,
          installment_payment_enabled: false,
        },
        {
          payment_method_type: "debit",
          card_networks: ["Visa", "Mastercard"],
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: true,
          installment_payment_enabled: false,
        },
      ],
    },
  ],

  // ── Cybersource ─────────────────────────────────────────────────────────
  // Needs CartesBancaires in card_networks for cobadge card tests
  // (cobadge-card-flow-cybersource.cy.ts uses Visa + CartesBancaires card).
  // recurring_enabled: true covers mandate-card-flow-cybersource.cy.ts
  // (setup_future_usage: "off_session" is a payment-body field, not MCA).
  cybersource: [
    {
      payment_method: "card",
      payment_method_types: [
        {
          payment_method_type: "credit",
          card_networks: ["Visa", "Mastercard", "AmericanExpress", "CartesBancaires", "UnionPay", "DinersClub"],
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: true,
          installment_payment_enabled: false,
        },
        {
          payment_method_type: "debit",
          card_networks: ["Visa", "Mastercard", "CartesBancaires"],
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: true,
          installment_payment_enabled: false,
        },
      ],
    },
  ],

  // ── TrustPay ─────────────────────────────────────────────────────────────
  // Tests cover both card flow (02-cards/05-card-trustpay.cy.ts) and
  // bank redirect (03-bank-transfers/01-trustpay-redirect.cy.ts).
  trustpay: [
    {
      payment_method: "card",
      payment_method_types: [
        {
          payment_method_type: "credit",
          card_networks: ["Visa", "Mastercard"],
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: true,
          installment_payment_enabled: false,
        },
        {
          payment_method_type: "debit",
          card_networks: ["Visa", "Mastercard"],
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: true,
          installment_payment_enabled: false,
        },
      ],
    },
    {
      payment_method: "bank_redirect",
      payment_method_types: [
        {
          payment_method_type: "eps",
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: false,
          installment_payment_enabled: false,
        },
        {
          payment_method_type: "sofort",
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: false,
          installment_payment_enabled: false,
        },
      ],
    },
  ],

  // ── PayPal ───────────────────────────────────────────────────────────────
  paypal: [
    {
      payment_method: "wallet",
      payment_method_types: [
        {
          payment_method_type: "paypal",
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: false,
          installment_payment_enabled: false,
        },
      ],
    },
  ],

  // ── Mifinity ─────────────────────────────────────────────────────────────
  // Redirect-based wallet (date-of-birth input, redirects to mifinity.com).
  mifinity: [
    {
      payment_method: "wallet",
      payment_method_types: [
        {
          payment_method_type: "mifinity",
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: false,
          installment_payment_enabled: false,
        },
      ],
    },
  ],

  // ── Cryptopay ────────────────────────────────────────────────────────────
  // Redirect to cryptopay.me/invoices.
  cryptopay: [
    {
      payment_method: "crypto",
      payment_method_types: [
        {
          payment_method_type: "crypto_currency",
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: false,
          installment_payment_enabled: false,
        },
      ],
    },
  ],

  // ── CashToCode ───────────────────────────────────────────────────────────
  // Two tests: voucher (EUR, cashtocode.com) and e-voucher (USD, evoucher.cashtocode.com).
  // Both use the same connector profile — currency is set per payment body.
  // The API accepts "classic" and "evoucher" as payment_method_type values
  // (not "cashtocode").
  cashtocode: [
    {
      payment_method: "voucher",
      payment_method_types: [
        {
          payment_method_type: "classic",
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: false,
          installment_payment_enabled: false,
        },
        {
          payment_method_type: "evoucher",
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: false,
          installment_payment_enabled: false,
        },
      ],
    },
  ],

  // ── Interac ──────────────────────────────────────────────────────────────
  // Uses CAD currency. Two sub-connectors: gigadat and loonio — chosen per
  // test via the `connector` field on the payment body (not the MCA).
  interac: [
    {
      payment_method: "bank_redirect",
      payment_method_types: [
        {
          payment_method_type: "interac",
          minimum_amount: 100,
          maximum_amount: 99999999,
          recurring_enabled: false,
          installment_payment_enabled: false,
        },
      ],
    },
  ],
};

// ---------------------------------------------------------------------------
// API helpers
// ---------------------------------------------------------------------------

/**
 * Creates a new Hyperswitch merchant account.
 * The response includes publishable_key but NOT the secret API key.
 * Use createApiKey() after this to obtain the merchant's secret key.
 *
 * @param {string} adminApiKey
 * @param {string} apiBaseUrl
 * @returns {Promise<{ merchantId: string, publishableKey: string }>}
 */
async function createMerchant(adminApiKey, apiBaseUrl) {
  const merchantId = `test_merchant_${Date.now()}`;

  const response = await fetch(`${apiBaseUrl}/accounts`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": adminApiKey,
    },
    body: JSON.stringify({
      merchant_id: merchantId,
      merchant_name: merchantId,
      locker_id: "m0010",
      merchant_details: {
        primary_contact_person: "Test User",
        primary_email: "test@hyperswitch.io",
      },
      primary_business_details: [
        {
          country: "US",
          business: "default",
        },
      ],
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `[setup] Failed to create merchant: HTTP ${response.status} ${response.statusText}\n${errorText}`
    );
  }

  const data = await response.json();
  return {
    merchantId: data.merchant_id,
    publishableKey: data.publishable_key,
  };
}

/**
 * Creates an API key for the merchant account.
 * The merchant creation response does NOT include the secret key —
 * it must be created separately via POST /api_keys/:merchant_id.
 *
 * @param {string} adminApiKey
 * @param {string} merchantId
 * @param {string} apiBaseUrl
 * @returns {Promise<string>} The plaintext API key (secret key).
 */
async function createApiKey(adminApiKey, merchantId, apiBaseUrl) {
  const response = await fetch(`${apiBaseUrl}/api_keys/${merchantId}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "api-key": adminApiKey,
    },
    body: JSON.stringify({
      name: `cypress_key_${Date.now()}`,
      description: "API key for cypress test run",
      expiration: "2027-12-31T23:59:59Z",
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `[setup] Failed to create API key: HTTP ${response.status} ${response.statusText}\n${errorText}`
    );
  }

  const data = await response.json();
  return data.api_key;
}

/**
 * Creates a dedicated business profile for one connector.
 * @param {string} secretKey
 * @param {string} merchantId
 * @param {string} apiBaseUrl
 * @param {string} connectorName  Used only to generate a meaningful profile name.
 * @returns {Promise<string>}     The new profile_id.
 */
async function createBusinessProfile(secretKey, merchantId, apiBaseUrl, connectorName) {
  // Append a timestamp to ensure the label is unique across parallel runs.
  const profileName = `${connectorName}_profile_${Date.now()}`;

  const response = await fetch(
    `${apiBaseUrl}/account/${merchantId}/business_profile`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "api-key": secretKey,
      },
      body: JSON.stringify({
        profile_name: profileName,
        return_url: "http://localhost:9060/completion",
      }),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `[setup] Failed to create business profile for "${connectorName}": HTTP ${response.status} ${response.statusText}\n${errorText}`
    );
  }

  const data = await response.json();
  return data.profile_id;
}

/**
 * Creates a merchant connector account (MCA) on the given profile.
 * @param {string} secretKey
 * @param {string} merchantId
 * @param {string} profileId
 * @param {string} connectorName
 * @param {Record<string, string>} connectorAccountDetails  From creds.json.
 * @param {Record<string, any> | undefined} metadata        From creds.json.
 * @param {string} apiBaseUrl
 */
async function createMerchantConnectorAccount(
  secretKey,
  merchantId,
  profileId,
  connectorName,
  connectorAccountDetails,
  metadata,
  apiBaseUrl
) {
  const paymentMethodsEnabled =
    CONNECTOR_PAYMENT_METHODS[connectorName] || CONNECTOR_PAYMENT_METHODS.default;
  const connectorType =
    CONNECTOR_TYPE_MAP[connectorName] || "payment_processor";

  const requestBody = {
    connector_type: connectorType,
    connector_name: connectorName,
    connector_label: `${connectorName}_${Date.now()}`,
    profile_id: profileId,
    connector_account_details: connectorAccountDetails,
    payment_methods_enabled: paymentMethodsEnabled,
    test_mode: true,
    disabled: false,
  };

  // Pass metadata from creds.json if present (e.g. cybersource needs
  // google_pay, apple_pay_combined, acquirer_bin, acquirer_merchant_id).
  if (metadata) {
    requestBody.metadata = metadata;
  }

  const response = await fetch(
    `${apiBaseUrl}/account/${merchantId}/connectors`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "api-key": secretKey,
      },
      body: JSON.stringify(requestBody),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `[setup] Failed to create MCA for "${connectorName}": HTTP ${response.status} ${response.statusText}\n${errorText}`
    );
  }
}

// ---------------------------------------------------------------------------
// creds.json parser
// ---------------------------------------------------------------------------

/**
 * Extracts connector_account_details from a creds.json entry.
 * Handles both direct and nested (connector_1 / connector_2) formats.
 *
 * Direct:   { "connector_account_details": { ... } }
 * Nested:   { "connector_1": { "connector_account_details": { ... } } }
 *
 * @param {Record<string, any>} connectorCreds
 * @returns {Record<string, string> | null}
 */
function extractConnectorAccountDetails(connectorCreds) {
  if (connectorCreds.connector_account_details) {
    return connectorCreds.connector_account_details;
  }
  if (
    connectorCreds.connector_1 &&
    connectorCreds.connector_1.connector_account_details
  ) {
    return connectorCreds.connector_1.connector_account_details;
  }
  return null;
}

/**
 * Extracts metadata from a creds.json entry.
 * Handles both direct and nested (connector_1 / connector_2) formats.
 *
 * @param {Record<string, any>} connectorCreds
 * @returns {Record<string, any> | undefined}
 */
function extractMetadata(connectorCreds) {
  if (connectorCreds.metadata) {
    return connectorCreds.metadata;
  }
  if (
    connectorCreds.connector_1 &&
    connectorCreds.connector_1.metadata
  ) {
    return connectorCreds.connector_1.metadata;
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// Main orchestrator
// ---------------------------------------------------------------------------

/**
 * Creates a fresh merchant + per-connector business profiles + MCAs.
 * Called via cy.task("setupCredentials") — runs in the Node.js process.
 *
 * @param {{ adminApiKey: string, apiBaseUrl: string, credsFilePath: string }} params
 * @returns {Promise<{
 *   publishableKey: string,
 *   secretKey: string,
 *   merchantId: string,
 *   connectorProfileIds: Record<string, string>
 * }>}
 */
async function setupAllCredentials({ adminApiKey, apiBaseUrl, credsFilePath }) {
  // ── Cache check ───────────────────────────────────────────────────────────
  // The Node.js module stays loaded for the entire Cypress run, so this cache
  // is shared across all spec files.  Only the first spec triggers real API
  // calls; every subsequent spec gets an instant cache hit.
  if (_credentialsCache) {
    console.log("[setup] Returning cached credentials (merchant already created for this run).");
    return _credentialsCache;
  }

  // ── 1. Read and parse creds.json ─────────────────────────────────────────
  const absoluteCredsPath = path.isAbsolute(credsFilePath)
    ? credsFilePath
    : path.resolve(process.cwd(), credsFilePath);

  if (!fs.existsSync(absoluteCredsPath)) {
    throw new Error(
      `[setup] creds.json not found at: ${absoluteCredsPath}\n` +
      `Set CONNECTOR_AUTH_FILE_PATH (or CYPRESS_CONNECTOR_AUTH_FILE_PATH) ` +
      `to the path of your creds.json file.`
    );
  }

  const credsJson = JSON.parse(fs.readFileSync(absoluteCredsPath, "utf-8"));
  console.log(
    `[setup] Loaded creds.json with connectors: ${Object.keys(credsJson).filter(k => k !== "Configs").join(", ")}`
  );

  // ── 2. Create merchant ───────────────────────────────────────────────────
  console.log(`[setup] Creating merchant on ${apiBaseUrl} ...`);
  const { merchantId, publishableKey } = await createMerchant(
    adminApiKey,
    apiBaseUrl
  );
  console.log(`[setup] Merchant created → merchant_id: ${merchantId}`);

  // ── 2b. Create API key for the merchant ─────────────────────────────────
  // The merchant creation response does not include the secret key.
  // It must be created separately via POST /api_keys/:merchant_id.
  const secretKey = await createApiKey(adminApiKey, merchantId, apiBaseUrl);
  console.log(`[setup] API key created for merchant`);

  // ── 3. For each connector: create profile + MCA ──────────────────────────
  const connectorProfileIds = {};

  for (const [connectorName, connectorCreds] of Object.entries(credsJson)) {
    // Skip top-level "Configs" key (dynamic config metadata, not a connector)
    if (connectorName === "Configs" || typeof connectorCreds !== "object") {
      continue;
    }

    const accountDetails = extractConnectorAccountDetails(connectorCreds);
    if (!accountDetails) {
      console.warn(
        `[setup] Skipping "${connectorName}": no connector_account_details found.`
      );
      continue;
    }

    const metadata = extractMetadata(connectorCreds);

    try {
      // a) Dedicated business profile for this connector
      const profileId = await createBusinessProfile(
        secretKey,
        merchantId,
        apiBaseUrl,
        connectorName
      );

      // b) MCA on that profile
      await createMerchantConnectorAccount(
        secretKey,
        merchantId,
        profileId,
        connectorName,
        accountDetails,
        metadata,
        apiBaseUrl
      );

      connectorProfileIds[connectorName] = profileId;
      console.log(
        `[setup] ${connectorName.padEnd(20)} → profile_id: ${profileId}`
      );
    } catch (err) {
      // Log the error but continue with remaining connectors.
      // Individual tests for the failed connector will fail at runtime
      // when they can't find a profile_id — which is the desired behavior.
      console.error(`[setup] Error setting up "${connectorName}":`, err.message);
    }
  }

  console.log(
    `[setup] Done. ${Object.keys(connectorProfileIds).length} connector(s) configured.`
  );

  _credentialsCache = { publishableKey, secretKey, merchantId, connectorProfileIds };
  return _credentialsCache;
}

module.exports = { setupAllCredentials };
