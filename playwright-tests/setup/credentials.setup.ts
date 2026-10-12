// ---------------------------------------------------------------------------
// "Global setup" for the live projects (runs as the `live-setup` project, which
// live / live-webkit depend on — so it never runs for --project=hermetic).
//
// 1. A valid credentials file already exists at credentialsOutputPath() (an
//    earlier local run, or `node setup/merchant-setup.js`) -> nothing to do.
// 2. Otherwise: needs ADMIN_API_KEY + CONNECTOR_AUTH_FILE_PATH, calls
//    ./merchant-setup.js#setupAllCredentials (fresh merchant, one business
//    profile + MCA per connector) and writes the result to
//    credentialsOutputPath() — CREDENTIALS_OUTPUT_PATH or
//    playwright-tests/test-credentials-<env>.json — which the `credentials`
//    fixture reads in every worker.
// ---------------------------------------------------------------------------
import fs from "node:fs";
import path from "node:path";
import { test as setup } from "@playwright/test";
import { HYPERSWITCH_API_URL, TEST_ENV } from "../fixtures/env";
import {
  credentialsOutputPath,
  loadPresetCredentials,
  type Credentials,
} from "../fixtures/credentials";

type SetupModule = {
  setupAllCredentials(args: {
    adminApiKey: string;
    apiBaseUrl: string;
    credsFilePath: string;
  }): Promise<Credentials>;
};

setup("provision live credentials", async () => {
  setup.setTimeout(180_000);

  const preset = loadPresetCredentials(true);
  if (preset) return;

  const adminApiKey = process.env.ADMIN_API_KEY;
  const credsFilePath = process.env.CONNECTOR_AUTH_FILE_PATH;
  if (!adminApiKey) {
    throw new Error(
      "Missing required env var: ADMIN_API_KEY (no pre-provisioned credentials found).\n" +
        `Either export ADMIN_API_KEY + CONNECTOR_AUTH_FILE_PATH, or point CREDENTIALS_OUTPUT_PATH at an existing test-credentials file.`,
    );
  }
  if (!credsFilePath) {
    throw new Error(
      "Missing required env var: CONNECTOR_AUTH_FILE_PATH (path to creds.json).\n" +
        "Example: CONNECTOR_AUTH_FILE_PATH=./creds.json (playwright-tests/creds.json is gitignored)",
    );
  }

  const outPath = credentialsOutputPath();
  // merchant-setup.js also caches to CREDENTIALS_OUTPUT_PATH; pin it to the
  // same file so credentials only ever land in one place.
  process.env.CREDENTIALS_OUTPUT_PATH = outPath;
  process.env.TEST_ENV = TEST_ENV;

  console.log(`[setup] Environment : ${TEST_ENV}`);
  console.log(`[setup] API base URL: ${HYPERSWITCH_API_URL}`);

  // Non-literal require keeps the plain-JS module out of the TypeScript program.
  const merchantSetup = path.join(__dirname, "merchant-setup.js");
  const { setupAllCredentials } = require(merchantSetup) as SetupModule; // eslint-disable-line @typescript-eslint/no-require-imports
  const creds = await setupAllCredentials({
    adminApiKey,
    apiBaseUrl: HYPERSWITCH_API_URL,
    credsFilePath: path.resolve(credsFilePath),
  });
  fs.writeFileSync(outPath, JSON.stringify(creds, null, 2));
  console.log(
    `[setup] Merchant ${creds.merchantId} — credentials written to ${outPath}`,
  );

  if (!loadPresetCredentials()) {
    throw new Error(
      `[setup] ${outPath} was written but is missing required connector profiles; check creds.json.`,
    );
  }
});
