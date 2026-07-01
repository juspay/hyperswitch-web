const { defineConfig } = require("cypress");
const { setupAllCredentials } = require("./setup");
const fs = require("fs");
const path = require("path");

// Determine the target environment from the TEST_ENV env var.
// Supported values: "sandbox" (default) | "integ" | "local"
const testEnv = process.env.TEST_ENV || "sandbox";

const apiUrlMap = {
  sandbox: "https://sandbox.hyperswitch.io",
  integ: "https://integ-api.hyperswitch.io",
  // For local: set LOCAL_API_URL env var (e.g. http://localhost:8080)
  local: process.env.LOCAL_API_URL || "http://localhost:8080",
};

const apiUrl = apiUrlMap[testEnv] || apiUrlMap.sandbox;

// ── Pre-existing credentials check ──────────────────────────────────────────
// In CI, the "setup" job creates a merchant + MCAs once and writes the result
// to test-credentials.json.  The parallel Cypress jobs download that file and
// pass the path via CREDENTIALS_OUTPUT_PATH.  When found, the credentials are
// injected here so e2e.ts can skip the cy.task("setupCredentials") call.
//
// Locally (no test-credentials.json), e2e.ts falls back to the dynamic setup
// task as before.
let presetupCredentials = null;
const presetupPath =
  process.env.CREDENTIALS_OUTPUT_PATH ||
  path.join(__dirname, "test-credentials.json");

if (fs.existsSync(presetupPath)) {
  try {
    presetupCredentials = JSON.parse(fs.readFileSync(presetupPath, "utf-8"));
    console.log(
      `[cypress.config] Found pre-existing credentials at ${presetupPath}`,
    );
    console.log(`[cypress.config] Merchant: ${presetupCredentials.merchantId}`);
  } catch (err) {
    console.warn(
      `[cypress.config] Failed to parse ${presetupPath}: ${err.message}`,
    );
  }
}

module.exports = defineConfig({
  projectId: "6r9ayw",
  chromeWebSecurity: false,

  e2e: {
    baseUrl: "http://localhost:9050",
    supportFile: "cypress/support/e2e.ts",
    experimentalModifyObstructiveThirdPartyCode: true,
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    responseTimeout: 10000,
    pageLoadTimeout: 30000,
    viewportWidth: 1280,
    viewportHeight: 720,
    video: false,
    screenshotOnRunFailure: true,
    trashAssetsBeforeRuns: true,

    setupNodeEvents(on) {
      // ── Credential generation task ───────────────────────────────────────
      // Runs in the Node.js process (not the browser).
      // Called once from the global before() hook in cypress/support/e2e.ts.
      // Creates a fresh merchant, per-connector business profiles, and MCAs
      // using the admin API key + the creds.json connector credential file.
      //
      // Skipped when pre-existing credentials are found (CI parallel jobs).
      on("task", {
        setupCredentials(params) {
          return setupAllCredentials(params);
        },

        // ── Logging task ──────────────────────────────────────────────────
        // cy.log output does NOT appear in CI stdout (Cypress suppresses it
        // in run mode).  This task bridges the gap by writing to console.log
        // in the Node process, which IS forwarded to CI logs.
        //
        // Usage in tests:
        //   cy.task("log", `[debug] SDK rendered text: ${text}`);
        log(message) {
          console.log(message);
          return null;
        },
      });
    },
  },

  retries: {
    runMode: 2, // Retry twice in CI for flaky tests
    openMode: 0, // No retry in interactive mode
  },

  env: {
    // TEST_ENV is forwarded so Cypress.env("TEST_ENV") works inside tests.
    TEST_ENV: testEnv,

    // Resolved Hyperswitch API base URL for the selected environment.
    HYPERSWITCH_API_URL: apiUrl,

    // Admin API key — used to create a fresh merchant per test run.
    // Set via CYPRESS_ADMIN_API_KEY env var or directly in cypress.env.json.
    ADMIN_API_KEY: process.env.ADMIN_API_KEY || "",

    // Path to the connector credentials file (creds.json).
    // Set via CYPRESS_CONNECTOR_AUTH_FILE_PATH env var or cypress.env.json.
    CONNECTOR_AUTH_FILE_PATH: process.env.CONNECTOR_AUTH_FILE_PATH || "",

    // Local backend URL override (only used when TEST_ENV=local).
    LOCAL_API_URL: process.env.LOCAL_API_URL || "",

    // Demo app base URL (where the webpack-dev-server for the React app runs).
    // Override via CYPRESS_CLIENT_BASE_URL if the port differs.
    CLIENT_BASE_URL: process.env.CLIENT_BASE_URL || "http://localhost:9060",

    // ── Pre-existing credentials (CI parallel jobs) ───────────────────────
    // When the "setup" job runs first, it writes test-credentials.json with
    // { publishableKey, secretKey, merchantId, connectorProfileIds }.
    // We inject those here and set PRESETUP_CREDENTIALS=true so e2e.ts knows
    // to skip cy.task("setupCredentials").
    ...(presetupCredentials
      ? {
          PRESETUP_CREDENTIALS: true,
          HYPERSWITCH_PUBLISHABLE_KEY: presetupCredentials.publishableKey,
          HYPERSWITCH_SECRET_KEY: presetupCredentials.secretKey,
          CONNECTOR_PROFILE_IDS: presetupCredentials.connectorProfileIds,
        }
      : {}),
  },
});
