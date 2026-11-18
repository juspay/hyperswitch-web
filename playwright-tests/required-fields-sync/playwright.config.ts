import { defineConfig } from "@playwright/test";
// No import of the normal config: no live setup, npx, dev proxy or auto-build.
const origin = new URL(process.env.RF_FIXTURE_ORIGIN || "about:blank");
if (
  origin.protocol !== "http:" ||
  origin.hostname !== "127.0.0.1" ||
  !origin.port
) {
  throw new Error("Use run-browser.cjs with an owned disposable fixture");
}
export default defineConfig({
  testDir: ".",
  testMatch: "browser.spec.ts",
  workers: 1,
  retries: 0,
  timeout: 30000,
  forbidOnly: true,
  outputDir: process.env.RF_OUTPUT_DIR,
  reporter: [["list"], ["./reporter.cjs", { stage: "browser-components" }]],
  use: {
    baseURL: origin.origin,
    browserName: "chromium",
    serviceWorkers: "block",
  },
});
