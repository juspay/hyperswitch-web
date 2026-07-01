// ***********************************************************
// Global Cypress support file — loaded automatically before every test file.
//
// Responsibilities:
//   1. Validate that required bootstrap env vars are present (fail-fast).
//   2. Call cy.task("setupCredentials") once per run to:
//        a. Create a fresh Hyperswitch merchant account (admin API key auth).
//        b. Create a dedicated business profile per connector.
//        c. Create a merchant connector account (MCA) on each profile using
//           the connector credentials from creds.json.
//   3. Inject the returned publishable key, secret key, and per-connector
//      profile IDs into Cypress.env() for use by all test files.
//   4. Clean up browser state after each test (cookies + localStorage).
// ***********************************************************

import "./commands";
import { createPaymentBody } from "./utils";

before(() => {
  // ── Pre-existing credentials (CI parallel jobs) ──────────────────────────
  // When the CI "setup" job runs first, it writes test-credentials.json which
  // cypress.config.js reads and injects into Cypress.env() with
  // PRESETUP_CREDENTIALS=true.  In that case we skip the dynamic setup task
  // and use the shared merchant account.
  if (Cypress.env("PRESETUP_CREDENTIALS")) {
    const profileIds = Cypress.env("CONNECTOR_PROFILE_IDS") as
      | Record<string, string>
      | undefined;
    createPaymentBody.profile_id = profileIds?.stripe ?? "";

    cy.log(`[setup] Using pre-existing credentials (shared merchant).`);
    cy.task("log", `[setup] Using pre-existing credentials (shared merchant).`);
    cy.task(
      "log",
      `[setup] Publishable key: ${Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY")}`,
    );
    cy.task(
      "log",
      `[setup] Default profile: ${createPaymentBody.profile_id} (stripe)`,
    );
    cy.task(
      "log",
      `[setup] Connector profile IDs: ${JSON.stringify(profileIds)}`,
    );
    return;
  }

  // ── Bootstrap validation (local dev — no pre-existing credentials) ────────
  const adminApiKey = Cypress.env("ADMIN_API_KEY") as string | undefined;
  const credsFilePath = Cypress.env("CONNECTOR_AUTH_FILE_PATH") as
    | string
    | undefined;

  if (!adminApiKey) {
    throw new Error(
      "Missing required env var: ADMIN_API_KEY\n" +
        "Set it in cypress.env.json or export CYPRESS_ADMIN_API_KEY before running tests.",
    );
  }
  if (!credsFilePath) {
    throw new Error(
      "Missing required env var: CONNECTOR_AUTH_FILE_PATH\n" +
        "Set it in cypress.env.json or export CYPRESS_CONNECTOR_AUTH_FILE_PATH before running tests.\n" +
        'Example: { "CONNECTOR_AUTH_FILE_PATH": "./creds.json" }',
    );
  }

  const apiBaseUrl = Cypress.env("HYPERSWITCH_API_URL") as string;
  const targetEnv = Cypress.env("TEST_ENV") || "sandbox";

  cy.log(`[setup] Environment : ${targetEnv}`);
  cy.log(`[setup] API base URL: ${apiBaseUrl}`);

  // ── Credential generation (Node.js task) ─────────────────────────────────
  // Creates a fresh merchant + per-connector profiles + MCAs.
  // Allow up to 2 minutes — 11 connectors × 2 API calls each = ~22 calls.
  cy.task(
    "setupCredentials",
    { adminApiKey, apiBaseUrl, credsFilePath },
    { timeout: 120_000 },
  ).then((creds: any) => {
    // Inject into Cypress.env() so every test can read these at runtime.
    Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY", creds.publishableKey);
    Cypress.env("HYPERSWITCH_SECRET_KEY", creds.secretKey);
    // connectorProfileIds: { stripe: "pro_...", cybersource: "pro_...", ... }
    Cypress.env("CONNECTOR_PROFILE_IDS", creds.connectorProfileIds);

    // Set the default profile_id (Stripe) on the shared payment body so that
    // tests which don't override it explicitly still hit a valid connector.
    createPaymentBody.profile_id = creds.connectorProfileIds?.stripe ?? "";

    cy.log(`[setup] Merchant ID     : ${creds.merchantId}`);
    cy.log(`[setup] Publishable key : ${creds.publishableKey}`);
    cy.log(
      `[setup] Default profile : ${createPaymentBody.profile_id} (stripe)`,
    );
  });
});

// ── Global test cleanup ───────────────────────────────────────────────────────
afterEach(() => {
  cy.clearCookies();
  cy.clearLocalStorage();
});
