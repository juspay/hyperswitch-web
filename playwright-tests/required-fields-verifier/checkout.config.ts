import fs from "node:fs";
import path from "node:path";
import assert from "node:assert/strict";
import { defineConfig } from "@playwright/test";
import type { TestFixtures, WorkerFixtures } from "../fixtures";
import { target } from "../required-fields-sync/fixture.cjs";
const owned = target();
const registrationPath = fs.realpathSync(process.env.RF_RUN_REGISTRATION || "");
assert(registrationPath.startsWith(owned.root + path.sep));
const registration = JSON.parse(fs.readFileSync(registrationPath, "utf8"));
assert.equal(registration.owner, owned.owner);
assert.equal(registration.sdk_origin, process.env.SDK_URL);
assert.equal(registration.demo_origin, process.env.CLIENT_BASE_URL);
assert.equal(
  registration.artifact_sha256,
  process.env.RF_EXECUTED_BUNDLE_SHA256,
);
// Existing API fixtures must use their hermetic engine; any accidental Node
// fetch (including a live-mode regression) fails without network I/O.
globalThis.fetch = async () => {
  throw new Error("Node network forbidden in checkout fixture");
};
export default defineConfig<TestFixtures, WorkerFixtures>({
  testDir: ".",
  testMatch: "browser.spec.ts",
  workers: 1,
  retries: 0,
  timeout: 45000,
  globalTimeout: 180000,
  forbidOnly: true,
  outputDir: process.env.RF_OUTPUT_DIR,
  reporter: [["list"], ["./reporter.cjs"]],
  use: {
    mode: "hermetic",
    browserName: "chromium",
    baseURL: process.env.CLIENT_BASE_URL,
    serviceWorkers: "block",
    viewport: { width: 1280, height: 720 },
  },
});
