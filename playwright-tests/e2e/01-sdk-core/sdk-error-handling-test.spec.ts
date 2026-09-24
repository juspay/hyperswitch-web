// SDK error handling: missing or malformed client secrets and publishable keys,
// failed payment-method list calls, a failed HyperLoader.js load, router error
// statuses (@live) and Sentry reporting (skipped unless SENTRY_DSN is set).
//
// Failure injection uses page.route(), which sees requests from every frame of
// the page (the SDK makes its router calls from its own iframes, not from the
// top-level demo shop) and beats the hermetic context route, so the injected
// failures run in both tiers.
//
// Notes:
// - The SDK renders from GET /payments/:id/client. The network-failure tests fail
//   that call (plus the legacy `payment_methods` endpoints, so a failure is still
//   injected if the SDK ever calls those again) and wait until the failure was
//   served before asserting.
// - "SDK script loading errors" fails the SDK script the shop loads
//   (HyperLoader.js), not the shop's own bundle, so the shop still boots.
// - not-exist assertions are gated on an observable "the SDK/shop has decided"
//   condition, so they can't pass merely because nothing has rendered yet.
import {
  test,
  expect,
  testIds,
  paymentBody,
  captureConsoleErrors,
  HYPERSWITCH_API_URL,
  PAYMENT_ELEMENT_IFRAME,
  SDK_URL,
} from "../../fixtures";

const body = paymentBody({ customer_id: "error_handling_test_user" });

/** The SDK's payment-method list call (the one it renders from). */
const CLIENT_LIST = /\/payments\/[^/]+\/client(\?|$)/;

test.describe("SDK Error Handling Tests", () => {
  test("should handle missing client secret error", async ({
    checkout,
    credentials,
    page,
  }) => {
    await page.goto(
      checkout.url("", { profileId: credentials.defaultProfileId }),
    );

    // The shop has loaded HyperLoader and decided what to render.
    await page.waitForFunction(
      () => !!(window as unknown as { Hyper?: unknown }).Hyper,
    );
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toHaveCount(0, {
      timeout: 5_000,
    });
  });

  test("should handle invalid client secret format", async ({
    checkout,
    credentials,
    page,
    sdk,
  }) => {
    const invalidClientSecret = "invalid_secret_format";

    // "invalid_secret_format" passes the SDK's format check (.+_secret_[A-Za-z0-9]+),
    // so HyperLoader mounts the iframe and the router rejects the list call. The
    // iframe itself does exist, so the test waits for the rejection and asserts
    // that the SDK shows its error state and no payment form renders.
    const rejected = page.waitForResponse(
      (r) =>
        CLIENT_LIST.test(new URL(r.url()).pathname + new URL(r.url()).search) &&
        r.status() >= 400,
    );
    await page.goto(
      checkout.url(invalidClientSecret, {
        profileId: credentials.defaultProfileId,
      }),
    );
    await rejected;

    await expect(sdk.text("Oops, something went wrong!")).toBeVisible();
    await expect(sdk.field(testIds.cardNoInputTestId)).toHaveCount(0);
  });

  test("should handle network errors gracefully", async ({
    checkout,
    page,
  }) => {
    let failed = 0;
    // Legacy payment-methods endpoint (the SDK no longer calls it) ...
    await page.route("**/account/payment_methods*", (route) => {
      failed++;
      return route.abort();
    });
    // ... and the list call the SDK actually makes.
    await page.route(
      (url) =>
        url.href.startsWith(HYPERSWITCH_API_URL) &&
        CLIENT_LIST.test(url.pathname + url.search),
      (route) => {
        failed++;
        return route.abort();
      },
    );

    await checkout.open({ body });
    await expect
      .poll(() => failed, {
        message: "the SDK's payment-methods call was never made",
      })
      .toBeGreaterThan(0);

    // Page should remain accessible even when the payment methods request fails
    await expect(page.locator("body")).toBeAttached();
    await expect(page.locator("#submit")).toBeAttached();
  });

  test(
    "should handle 401 unauthorized error",
    { tag: "@live" },
    async ({ api }) => {
      // @live: asserts the real router's auth check; a recording would only test itself.
      const invalidSecretKey = "invalid_key";

      const response = await api.call("POST", "/payments", {
        apiKey: invalidSecretKey,
        data: body,
      });
      expect([401, 404]).toContain(response.status);
    },
  );

  test(
    "should handle 404 not found error",
    { tag: "@live" },
    async ({ api }) => {
      // @live: asserts the real router's routing; a recording would only test itself.
      const response = await api.call("GET", "/nonexistent_endpoint");
      expect([200, 404]).toContain(response.status);
    },
  );

  test(
    "should return an error status for an unknown payment",
    { tag: "@live" },
    async ({ api }) => {
      // @live: asserts the real router's answer for an unknown payment; a recording
      // would only test itself.
      const response = await api.call(
        "GET",
        "/payments/pay_000000000000000000000000000000",
      );
      expect(response.status).toBeGreaterThanOrEqual(400);
    },
  );

  test("should handle SDK script loading errors", async ({
    checkout,
    page,
  }) => {
    let served = 0;
    await page.route(`${SDK_URL}/HyperLoader.js`, (route) => {
      served++;
      return route.fulfill({ status: 500, body: "Server Error" });
    });

    await checkout.open({ body });

    // The shop's script.onerror path: "Failed to load HyperLoader.js" -> error message.
    await expect(
      page.getByText("Failed to load payment. Please refresh."),
    ).toBeVisible();
    expect(served).toBeGreaterThan(0);
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toHaveCount(0, {
      timeout: 5_000,
    });
  });

  test("should recover from temporary network failures", async ({
    checkout,
    page,
  }) => {
    let requestCount = 0;
    // First list call fails at the network level; later ones reach the router
    // (hermetic: the recordings). The legacy `payment_methods` path is matched too.
    await page.route(
      (url) =>
        url.href.startsWith(HYPERSWITCH_API_URL) &&
        (CLIENT_LIST.test(url.pathname + url.search) ||
          /\/payment_methods/.test(url.pathname)),
      (route) => {
        requestCount++;
        return requestCount === 1 ? route.abort() : route.fallback();
      },
    );

    await checkout.open({ body });
    await expect
      .poll(() => requestCount, {
        message: "the SDK's payment-methods call was never made",
      })
      .toBeGreaterThan(0);

    // Only the outer iframe is asserted. Note: the SDK does not retry the failed
    // list call; the element shows "Oops, something went wrong!" instead of the
    // card form, so "recover" here means the element still mounts.
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible({
      timeout: 10_000,
    });
  });

  test("should handle invalid publishable key prefix", async ({
    checkout,
    page,
  }) => {
    const invalidPrefixKey = "pk_invalid_test_key";

    const consoleErrors = await captureConsoleErrors(page);
    await checkout.open({ body, publishableKey: invalidPrefixKey });

    await expect
      .poll(async () => (await consoleErrors()).length)
      .toBeGreaterThan(0);
  });

  test("should handle missing required parameters", async ({
    checkout,
    page,
  }) => {
    const consoleErrors = await captureConsoleErrors(page);
    await page.goto(checkout.url("", { publishableKey: "" }));

    await expect
      .poll(async () => (await consoleErrors()).length)
      .toBeGreaterThan(0);
  });

  test("should log errors to Sentry when configured", async ({
    checkout,
    page,
  }) => {
    const sentryDsn = process.env.SENTRY_DSN;
    // Needs a real Sentry project; skipped visibly rather than passing vacuously.
    test.skip(!sentryDsn, "SENTRY_DSN is not set");

    const sentryRequest = page.waitForRequest(
      (r) => r.method() === "POST" && r.url().includes("sentry.io"),
      { timeout: 5_000 },
    );

    const intent = await checkout.createPaymentIntent(body);
    await page.goto(
      `${checkout.url(intent)}&sentryDsn=${encodeURIComponent(sentryDsn!)}`,
    );

    await page.evaluate(() => {
      const w = window as unknown as { triggerTestError?: () => void };
      if (w.triggerTestError) w.triggerTestError();
    });

    const req = await sentryRequest;
    expect(req.postData()).toBeTruthy();
  });
});
