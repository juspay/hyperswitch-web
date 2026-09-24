// ---------------------------------------------------------------------------
// Playwright config for hyperswitch-web.
//
// Projects
//   hermetic      Chromium, router responses served from recordings/ via
//                 context.route(). No sandbox, no keys. Skips tests tagged @live.
//   live-setup    Provisions/loads sandbox credentials (the "global setup").
//                 Only runs as a dependency of live / live-webkit, so it is a
//                 no-op for --project=hermetic.
//   live          Chromium against TEST_ENV (sandbox|integ|local). Runs every
//                 test except @hermetic-only.
//   live-webkit   Same as live on WebKit (Safari), for nightly runs.
//
// Everything is configurable through env vars — see README.md.
// ---------------------------------------------------------------------------
import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import {
  defineConfig,
  devices,
  type PlaywrightTestConfig,
} from "@playwright/test";
import type { TestFixtures, WorkerFixtures } from "./fixtures";
import {
  CLIENT_BASE_URL,
  DEMO_APP_ROOT,
  DEMO_PORT,
  DEMO_SERVER_PORT,
  HYPERSWITCH_API_URL,
  IS_CI,
  LIVE_CHROMIUM_USER_AGENT,
  REPO_ROOT,
  SDK_PORT,
  SDK_URL,
} from "./fixtures/env";

// Specs import data-testids from the ReScript output (src/Utilities/TestUtils.bs.js,
// gitignored). Test files are collected before any webServer starts, so make
// sure it exists first. Cheap no-op when already built.
const TEST_UTILS = path.join(REPO_ROOT, "src/Utilities/TestUtils.bs.js");
if (!fs.existsSync(TEST_UTILS)) {
  console.log(
    "[playwright] src/Utilities/TestUtils.bs.js missing — running `npm run re:build` in the repo root",
  );
  execSync("npm run re:build", { cwd: REPO_ROOT, stdio: "inherit" });
}

const intFromEnv = (name: string): number | undefined => {
  const v = process.env[name];
  return v && /^\d+$/.test(v) ? Number(v) : undefined;
};

// Total worker cap. CI runs each tier as a single job on ubuntu-latest
// (4 vCPUs), so 4 there; locally Playwright's default (half the cores).
const workers = process.env.PW_WORKERS
  ? /^\d+$/.test(process.env.PW_WORKERS)
    ? Number(process.env.PW_WORKERS)
    : process.env.PW_WORKERS // e.g. "50%"
  : IS_CI
    ? 4
    : undefined;

// Live tests share one merchant, and each spec uses its own customer_id. Tests
// inside a file run serially, in order; files run concurrently up to this cap.
// Four concurrent files against one sandbox merchant is known to be safe, so
// CI uses the whole runner; locally 2 keeps sandbox load and flakiness low.
const liveWorkers = intFromEnv("PW_LIVE_WORKERS") ?? (IS_CI ? 4 : 2);

const reuseExistingServer = process.env.PW_REUSE_SERVERS
  ? process.env.PW_REUSE_SERVERS !== "0"
  : !IS_CI;

const webServer: PlaywrightTestConfig["webServer"] = process.env
  .PW_SKIP_WEBSERVER
  ? undefined
  : [
      {
        name: "sdk",
        // Fresh ReScript output, then the SDK dev server (serves HyperLoader.js + iframes).
        command:
          "npm run re:build && npx webpack serve --config webpack.dev.js",
        cwd: REPO_ROOT,
        url: `${SDK_URL}/HyperLoader.js`,
        env: {
          PORT: String(SDK_PORT),
          // Without this the SDK would load its iframes from localhost:9050.
          ENV_SDK_URL: SDK_URL,
          sdkEnv: process.env.SDK_ENV || "local",
        },
        reuseExistingServer,
        timeout: 300_000,
        stdout: "ignore",
        stderr: "pipe",
      },
      {
        // The demo shop. Its node server (server.js) is not started: the
        // harness answers /payments/config and /payments/urls (fixtures/demo-shop.ts).
        name: "demo-client",
        command: "npx webpack serve --config webpack.dev.js",
        cwd: DEMO_APP_ROOT,
        url: CLIENT_BASE_URL,
        env: {
          DEMO_PORT: String(DEMO_PORT),
          DEMO_SERVER_PORT: String(DEMO_SERVER_PORT),
          HYPERSWITCH_SERVER_URL: HYPERSWITCH_API_URL,
          HYPERSWITCH_CLIENT_URL: SDK_URL,
        },
        reuseExistingServer,
        timeout: 300_000,
        stdout: "ignore",
        stderr: "pipe",
      },
    ];

export default defineConfig<TestFixtures, WorkerFixtures>({
  testDir: "./e2e",
  // PW_OUTPUT_DIR / PW_HTML_REPORT_DIR: separate dirs for concurrent runs on one checkout.
  outputDir: process.env.PW_OUTPUT_DIR || "./test-results",
  forbidOnly: IS_CI,
  workers,
  // One job per tier on CI: list output in the log, the HTML report uploaded
  // as an artifact, and GitHub annotations on failing lines.
  reporter: [
    ["list"],
    [
      "html",
      {
        open: "never",
        outputFolder: process.env.PW_HTML_REPORT_DIR || "playwright-report",
      },
    ],
    ...(IS_CI ? ([["github"]] as const) : []),
  ],
  expect: { timeout: 10_000 },
  use: {
    baseURL: CLIENT_BASE_URL,
    testIdAttribute: "data-testid",
    viewport: { width: 1280, height: 720 },
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    screenshot: "only-on-failure",
  },
  webServer,
  projects: [
    {
      name: "hermetic",
      grepInvert: /@live\b/,
      fullyParallel: true,
      retries: 0,
      timeout: 60_000,
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1280, height: 720 },
        mode: "hermetic",
        trace: "retain-on-failure",
      },
    },
    {
      name: "live-setup",
      testDir: "./setup",
      testMatch: /.*\.setup\.ts/,
      retries: 0,
      use: { mode: "live" },
    },
    {
      name: "live",
      dependencies: ["live-setup"],
      grepInvert: /@hermetic-only\b/,
      fullyParallel: false,
      workers: liveWorkers,
      retries: 1,
      timeout: 120_000,
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1280, height: 720 },
        // Netcetera's 3DS ACS blocks the headless Chrome user agent.
        userAgent: LIVE_CHROMIUM_USER_AGENT,
        mode: "live",
        trace: "on-first-retry",
      },
    },
    {
      name: "live-webkit",
      dependencies: ["live-setup"],
      grepInvert: /@hermetic-only\b/,
      fullyParallel: false,
      workers: liveWorkers,
      retries: 1,
      timeout: 120_000,
      use: {
        ...devices["Desktop Safari"],
        viewport: { width: 1280, height: 720 },
        mode: "live",
        trace: "on-first-retry",
      },
    },
  ],
});
