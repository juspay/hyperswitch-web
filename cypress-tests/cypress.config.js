const { defineConfig } = require("cypress");
const { setupAllCredentials } = require("./setup");

// Determine the target environment from the TEST_ENV env var.
// Supported values: "sandbox" (default) | "integ" | "local"
const testEnv = process.env.TEST_ENV || "sandbox";

const apiUrlMap = {
  sandbox: "https://sandbox.hyperswitch.io",
  integ:   "https://integ.hyperswitch.io/api",
  // For local: set LOCAL_API_URL env var (e.g. http://localhost:8080)
  local:   process.env.LOCAL_API_URL || "http://localhost:8080",
};

const apiUrl = apiUrlMap[testEnv] || apiUrlMap.sandbox;

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
      on("task", {
        setupCredentials(params) {
          return setupAllCredentials(params);
        },
      });
    },
  },

  retries: {
    runMode: 2,   // Retry twice in CI for flaky tests
    openMode: 0,  // No retry in interactive mode
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
  },
});
