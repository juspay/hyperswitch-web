// ---------------------------------------------------------------------------
// The demo shop asks its node server (Hyperswitch-React-Demo-App/server.js,
// proxied under /payments) for two things before loading the SDK:
//   GET /payments/config -> { publishableKey, profileId }   (ignored with isTestMode=true)
//   GET /payments/urls   -> { serverUrl, clientUrl }        (router URL, HyperLoader origin)
// The harness answers both itself, in every project. That makes server.js
// unnecessary for tests and sidesteps its rate limiter (300 req/min on these
// routes), which parallel workers would otherwise hit. The values are what the
// demo app's .env would provide (HYPERSWITCH_SERVER_URL / HYPERSWITCH_CLIENT_URL).
// ---------------------------------------------------------------------------
import type { BrowserContext } from "@playwright/test";
import {
  CLIENT_BASE_URL,
  HYPERSWITCH_API_URL,
  RETURN_ORIGIN,
  RETURNS_TO_DEMO_SHOP,
  SDK_URL,
} from "./env";

export async function installDemoShopConfig(
  context: BrowserContext,
  { serverUrl = HYPERSWITCH_API_URL, clientUrl = SDK_URL } = {},
): Promise<void> {
  const base = new URL(CLIENT_BASE_URL).origin;
  await context.route(`${base}/payments/urls`, (route) =>
    route.fulfill({ json: { serverUrl, clientUrl } }),
  );
  await context.route(`${base}/payments/config`, (route) =>
    route.fulfill({ json: { publishableKey: "", profileId: "" } }),
  );
}

/**
 * When payments return to PUBLIC_RETURN_URL (demo shop on localhost), answer
 * that page with a blank document so a redirect flow's landing never depends
 * on the real site; specs read the outcome from the URL's query. Install after
 * the hermetic engine so this route wins over its catch-all.
 */
export async function installReturnPage(
  context: BrowserContext,
): Promise<void> {
  if (RETURNS_TO_DEMO_SHOP) return;
  await context.route(
    (url) => url.origin === RETURN_ORIGIN,
    (route) =>
      route.fulfill({
        contentType: "text/html",
        body: "<!doctype html><title>Payment return (test stand-in)</title>",
      }),
  );
}
