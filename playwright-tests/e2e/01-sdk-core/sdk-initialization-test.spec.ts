// SDK initialization: valid and invalid publishable keys and the extra
// initialization query params.
//
// Hermetic-capable: initialization only needs HyperLoader, the SDK iframes and
// the list calls (served from recordings/base in the hermetic tier).
//
// Note: the demo shop ignores the `customBackendUrl`
// and `isForceInit` query params (Hyperswitch-React-Demo-App/src/Payment.js
// only reads isTestMode, clientSecret, publishableKey, profileId,
// locale, theme, layout, options), so those two tests only prove the SDK still
// initialises with the extra params present.
import {
  test,
  expect,
  paymentBody,
  captureConsoleErrors,
  HYPERSWITCH_API_URL,
} from "../../fixtures";

const body = paymentBody({ customer_id: "sdk_init_test_user" });

test.describe("SDK Initialization Tests", () => {
  test("should initialize SDK with valid publishable key", async ({
    checkout,
    sdk,
  }) => {
    await checkout.open({ body });

    await sdk.waitForReady();
  });

  test("should fail initialization with invalid publishable key format", async ({
    checkout,
    page,
  }) => {
    const invalidKey = "invalid_key_format";

    // Registered before the SDK's JS runs, so early errors are captured.
    const consoleErrors = await captureConsoleErrors(page);
    await checkout.open({ body, publishableKey: invalidKey });

    await expect
      .poll(async () => (await consoleErrors()).length)
      .toBeGreaterThan(0);
  });

  test("should initialize with custom backend URL", async ({
    checkout,
    page,
    sdk,
  }) => {
    const customBackendUrl =
      process.env.HYPERSWITCH_CUSTOM_BACKEND_URL || HYPERSWITCH_API_URL;

    const intent = await checkout.createPaymentIntent(body);
    await page.goto(
      `${checkout.url(intent)}&customBackendUrl=${encodeURIComponent(customBackendUrl)}`,
    );

    await sdk.waitForReady();
  });

  test("should reinitialize SDK when isForceInit is true", async ({
    checkout,
    page,
    sdk,
  }) => {
    const intent = await checkout.createPaymentIntent(body);
    await page.goto(`${checkout.url(intent)}&isForceInit=true`);

    await sdk.waitForReady();

    expect(
      await page.evaluate(
        () => !!(window as unknown as { Hyper?: unknown }).Hyper,
      ),
    ).toBe(true);
  });

  test("should initialize SDK with profile ID", async ({ checkout, sdk }) => {
    // checkout.url() puts the intent's profile_id in the URL.
    await checkout.open({ body });

    await sdk.waitForReady();
  });
});
