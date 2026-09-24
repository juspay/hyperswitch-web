// ---------------------------------------------------------------------------
// The one import for specs:
//
//   import { test, expect, testIds, paymentBody, stripeCards } from "../../fixtures";
//
//   test.describe("Card Number Validation", () => {
//     test.beforeEach(async ({ checkout }) => {
//       await checkout.open({ body: paymentBody({ customer_id: "card_validation_test_user" }) });
//     });
//     test("formats a Visa", async ({ sdk }) => {
//       await sdk.type(testIds.cardNoInputTestId, "4242424242424242");
//       await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue("4242 4242 4242 4242");
//     });
//   });
//
// Fixtures: mode, credentials (worker) · hermetic, api, checkout, sdk (test).
// `context` is extended: any test that uses page/context/sdk/checkout gets the
// hermetic routes installed; tests that don't never create a browser context.
// See playwright-tests/README.md for the full fixture API.
// ---------------------------------------------------------------------------
import path from "node:path";
import { test as base, expect } from "@playwright/test";
import {
  E2E_DIR,
  HYPERSWITCH_API_URL,
  CLIENT_BASE_URL,
  DEMO_SERVER_URL,
  RECORD,
  SDK_URL,
} from "./env";
import {
  HERMETIC_CREDENTIALS,
  TestCredentials,
  credentialsOutputPath,
  loadPresetCredentials,
} from "./credentials";
import { HermeticEngine } from "./hermetic/engine";
import { Hermetic } from "./hermetic";
import { Recorder } from "./hermetic/recorder";
import { HyperswitchApi } from "./api";
import { Checkout } from "./checkout";
import { Sdk } from "./sdk";
import { installDemoShopConfig } from "./demo-shop";

export type Mode = "hermetic" | "live";

export interface WorkerFixtures {
  /** "hermetic" on the hermetic project, "live" on live / live-webkit. */
  mode: Mode;
  /** Merchant keys + connector profile IDs (fake ones in hermetic mode). */
  credentials: TestCredentials;
}

export interface TestFixtures {
  /** Extra fixture files (relative to recordings/) layered on top of base + per-spec files. */
  hermeticFixtures: string[];
  /** Hermetic routing controller. Mutators are no-ops on live projects. Installed on every browser context. */
  hermetic: Hermetic;
  /** Node-side router calls: createPaymentIntent, retrievePayment, pollPaymentStatus, ... */
  api: HyperswitchApi;
  /** Creates a payment and opens the demo shop on it. */
  checkout: Checkout;
  /** Payment-element frame helpers. */
  sdk: Sdk;
}

/** recordings/<group>/<spec> for a spec file e2e/<group>/<spec>.spec.ts */
export function specFixtureBase(testFile: string): {
  group: string;
  spec: string;
} {
  const rel = path.relative(E2E_DIR, testFile).split(path.sep);
  const group = rel.length > 1 ? rel[0] : "";
  const spec = path.basename(testFile).replace(/\.spec\.ts$/, "");
  return { group, spec };
}

export const test = base.extend<TestFixtures, WorkerFixtures>({
  mode: ["live", { scope: "worker", option: true }],

  credentials: [
    async ({ mode }, use) => {
      if (mode === "hermetic") {
        await use(new TestCredentials(HERMETIC_CREDENTIALS));
        return;
      }
      const loaded = loadPresetCredentials(true);
      if (!loaded) {
        throw new Error(
          `[playwright] No usable live credentials. The live-setup project should have written ` +
            `${credentialsOutputPath()} — run with --project=live (not only live-setup skipped), set ` +
            `CREDENTIALS_OUTPUT_PATH, or provide ADMIN_API_KEY + CONNECTOR_AUTH_FILE_PATH.`,
        );
      }
      await use(new TestCredentials(loaded.credentials));
    },
    { scope: "worker" },
  ],

  hermeticFixtures: [[], { option: true }],

  hermetic: async ({ mode, credentials, hermeticFixtures }, use, testInfo) => {
    if (mode !== "hermetic") {
      await use(new Hermetic(undefined));
      return;
    }

    const engine = new HermeticEngine({
      credentials,
      localOrigins: [SDK_URL, CLIENT_BASE_URL, DEMO_SERVER_URL],
      apiUrl: HYPERSWITCH_API_URL,
    });
    const { group, spec } = specFixtureBase(testInfo.file);
    engine.loadDir("base");
    if (group) {
      engine.loadFile(path.join(group, "_group.json"), { optional: true });
      engine.loadFile(path.join(group, `${spec}.json`), { optional: true });
    }
    for (const f of hermeticFixtures) engine.loadFile(f);

    await use(new Hermetic(engine));

    if (engine.unmatched.length > 0) {
      const list = [...new Set(engine.unmatched)].join("\n");
      console.warn(
        `[hermetic] ${testInfo.title}: unmatched router requests (answered 404):\n${list}`,
      );
      await testInfo.attach("hermetic-unmatched.txt", {
        body: list,
        contentType: "text/plain",
      });
    }
    if (testInfo.status !== testInfo.expectedStatus) {
      await testInfo.attach("hermetic-calls.json", {
        body: JSON.stringify(
          {
            layers: engine.sources,
            intent: engine.intent,
            calls: engine.calls,
          },
          null,
          2,
        ),
        contentType: "application/json",
      });
    }
  },

  // Every browser context (so page, popups, sdk, checkout) gets the demo-shop
  // config routes and, in hermetic mode, the engine's context.route(); on live
  // with RECORD=1 the recorder. Tests that never touch a page (api-only, data
  // tables) therefore never launch a browser context.
  context: async ({ context, mode, hermetic, credentials }, use, testInfo) => {
    // Demo shop /payments/config + /payments/urls, answered by the harness in every project.
    await installDemoShopConfig(context);
    if (hermetic.engine) await hermetic.engine.install(context);

    const recorder =
      mode === "live" && RECORD ? new Recorder(HYPERSWITCH_API_URL) : undefined;
    recorder?.attach(context);

    await use(context);

    if (recorder) {
      const file = await recorder.save(
        testInfo,
        hermetic.liveIntentIds,
        credentials,
      );
      if (file)
        console.log(
          `[record] ${testInfo.title} -> ${path.relative(process.cwd(), file)}`,
        );
    }
  },

  api: async ({ credentials, hermetic }, use, testInfo) => {
    const api = new HyperswitchApi(credentials, hermetic);
    await use(api);
    // Redacted (no keys, no client secrets): the fetch calls themselves are not in the trace.
    if (api.callLog.length > 0 && testInfo.status !== testInfo.expectedStatus) {
      await testInfo.attach("api-calls.json", {
        body: JSON.stringify(api.callLog, null, 2),
        contentType: "application/json",
      });
    }
  },

  sdk: async ({ page, api, hermetic }, use) => {
    const describe = async () => {
      const ids = hermetic.enabled
        ? {
            paymentId: hermetic.intent?.payment_id,
            clientSecret: hermetic.intent?.client_secret,
          }
        : hermetic.liveIntentIds;
      if (!ids.paymentId || !ids.clientSecret)
        return "(no payment created yet)";
      return api.describePaymentMethods(ids.paymentId, ids.clientSecret);
    };
    await use(new Sdk(page, describe));
  },

  checkout: async ({ page, api, credentials, sdk }, use) => {
    await use(new Checkout(page, api, credentials, sdk));
  },
});

export { expect };

// Re-exports so specs need a single import.
export { testIds } from "./test-ids";
export * from "./cards";
export * from "./types";
export * from "./test-data";
export * from "./payment-body";
export { connectorEnum, type Connector } from "./connectors";
export {
  getClientURL,
  type OpenCheckoutOptions,
  type ClientUrlOptions,
} from "./checkout";
export type { PaymentIntent } from "./api";
export {
  PAYMENT_ELEMENT_IFRAME,
  CARD_FIELDS_IFRAME,
  FULLSCREEN_IFRAME,
  PAYMENT_METHOD_SELECT_VALUES,
} from "./sdk";
export type {
  Hermetic,
  HermeticRoute,
  HermeticCall,
  HermeticIntent,
} from "./hermetic";
export type { Sdk } from "./sdk";
export type { Checkout, OpenedCheckout } from "./checkout";
export type { HyperswitchApi } from "./api";
export type { TestCredentials } from "./credentials";
export * from "./helpers";
export { HYPERSWITCH_API_URL, CLIENT_BASE_URL, SDK_URL, TEST_ENV } from "./env";
