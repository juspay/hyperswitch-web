// ---------------------------------------------------------------------------
// Environment resolution shared by playwright.config.ts, the setup project and
// the fixtures. Everything is overridable through environment variables so the
// suite can run next to other dev servers on the same machine.
// ---------------------------------------------------------------------------
import path from "node:path";

export type TestEnv = "sandbox" | "integ" | "local";

/** playwright-tests/ */
export const PW_ROOT = path.resolve(__dirname, "..");
/** hyperswitch-web/ (repo root) */
export const REPO_ROOT = path.resolve(PW_ROOT, "..");
export const DEMO_APP_ROOT = path.join(REPO_ROOT, "Hyperswitch-React-Demo-App");
export const RECORDINGS_DIR = path.join(PW_ROOT, "recordings");
export const E2E_DIR = path.join(PW_ROOT, "e2e");

/** Router environment the live tier runs against. */
export const TEST_ENV = (process.env.TEST_ENV || "sandbox") as TestEnv;

export const apiUrlMap: Record<TestEnv, string> = {
  sandbox: "https://sandbox.hyperswitch.io",
  integ: "https://integ.hyperswitch.io/api",
  // For local: set LOCAL_API_URL (e.g. http://localhost:8080)
  local: process.env.LOCAL_API_URL || "http://localhost:8080",
};

/** Hyperswitch router base URL for the selected TEST_ENV. */
export const HYPERSWITCH_API_URL = apiUrlMap[TEST_ENV] || apiUrlMap.sandbox;

/** Profiles a credentials file must contain to be accepted; anything less is treated as stale. */
export const requiredPresetProfileIds = ["stripe", "adyen", "fiuu", "trustpay"];

const portOf = (url: string | undefined): number | undefined => {
  if (!url) return undefined;
  try {
    const u = new URL(url);
    return u.port ? Number(u.port) : undefined;
  } catch {
    return undefined;
  }
};

const num = (v: string | undefined): number | undefined =>
  v && v.trim() !== "" ? Number(v) : undefined;

// Default ports are deliberately NOT the dev defaults (9050/9060/5252) so a
// test run never collides with (or silently reuses) a developer's long-running
// dev servers on the same machine.
export const SDK_PORT =
  num(process.env.SDK_PORT) ?? portOf(process.env.SDK_URL) ?? 9150;
export const DEMO_PORT =
  num(process.env.DEMO_PORT) ?? portOf(process.env.CLIENT_BASE_URL) ?? 9160;
export const DEMO_SERVER_PORT =
  num(process.env.DEMO_SERVER_PORT) ??
  portOf(process.env.DEMO_SERVER_URL) ??
  5352;

/** Where HyperLoader.js and the SDK iframes are served from. */
export const SDK_URL = process.env.SDK_URL || `http://localhost:${SDK_PORT}`;
/** Demo shop (Hyperswitch-React-Demo-App webpack dev server). */
export const CLIENT_BASE_URL =
  process.env.CLIENT_BASE_URL || `http://localhost:${DEMO_PORT}`;
/** Demo shop's node server (/config, /urls, /create-intent). */
export const DEMO_SERVER_URL =
  process.env.DEMO_SERVER_URL || `http://localhost:${DEMO_SERVER_PORT}`;

/** RECORD=1 on the live project saves router responses under recordings/_recorded/. */
export const RECORD = ["1", "true", "yes"].includes(
  (process.env.RECORD || "").toLowerCase(),
);

export const IS_CI = !!process.env.CI;

/** Chromium user agent used on live projects (Netcetera ACS blocks headless Chrome). */
export const LIVE_CHROMIUM_USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";
