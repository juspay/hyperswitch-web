// Stripe 3DS card flow end to end: the checkout page and payment element load,
// a 3DS card payment redirects to the Stripe 3DS page, and completing or
// failing Stripe's test challenge returns to the shop with that outcome.
//
// The challenge buttons sit two iframes deep in Stripe's hosted page:
// hooks.stripe.com/3d_secure_2/hosted > iframe __privateStripeFrame* >
// iframe #challengeFrame (testmode-acs.stripe.com) > #test-source-authorize-3ds
// (COMPLETE) / #test-source-fail-3ds (FAIL). The router then sends the browser
// to return_url?status=succeeded|failed.
//
// Hermetic-capable: the spec fixture (recordings/02-cards/stripe-3DS-card-flow-e2e-test.json)
// answers confirm with requires_customer_action + next_action.redirect_to_url on
// the router's /payments/redirect endpoint, whose page forwards to a stand-in
// Stripe page with the same frames and buttons; each button goes through a
// stand-in router redirect-response that sets the payment status. The live tier
// gets the real router, Stripe page and challenge.
import type { Page } from "@playwright/test";
import type { PaymentIntent, TestCredentials } from "../../fixtures";
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  PAYMENT_ELEMENT_IFRAME,
  CLIENT_BASE_URL,
  expectConfirmedWith,
  expectRedirectedToNextAction,
  typeCard,
} from "../../fixtures";

const STRIPE_3DS_URL = /hooks\.stripe\.com\/3d_secure_2/;
const DEMO_SHOP_ORIGIN = new URL(CLIENT_BASE_URL).origin;

/** Clicks COMPLETE ("authorize") or FAIL ("fail") on Stripe's test 3DS challenge. */
async function answerStripeChallenge(
  page: Page,
  answer: "authorize" | "fail",
): Promise<void> {
  await page
    .frameLocator('iframe[name^="__privateStripeFrame"]')
    .frameLocator("#challengeFrame")
    .locator(`#test-source-${answer}-3ds`)
    .click({ timeout: 30_000 });
}

/**
 * Lets the demo shop's return page render the outcome. Back from the redirect,
 * the shop is opened without isTestMode, so it asks its node server for the
 * merchant config and a client secret (to mount the SDK), then calls
 * retrievePaymentIntent with the payment_intent_client_secret from the URL and
 * shows "Thanks for your order!" or the failure message. The harness doesn't
 * run that server, so answer both here; later routes win over the harness's
 * empty /payments/config.
 */
async function serveShopReturnPage(
  page: Page,
  credentials: TestCredentials,
  intent: PaymentIntent,
): Promise<void> {
  await page.context().route(`${DEMO_SHOP_ORIGIN}/payments/config`, (route) =>
    route.fulfill({
      json: {
        publishableKey: credentials.publishableKey,
        profileId: intent.profileId,
      },
    }),
  );
  await page
    .context()
    .route(`${DEMO_SHOP_ORIGIN}/payments/create-intent`, (route) =>
      route.fulfill({ json: { clientSecret: intent.clientSecret } }),
    );
}

/** Waits for the router to send the browser back to the demo shop with `status` in the query. */
async function expectReturnedToShopWith(
  page: Page,
  status: "succeeded" | "failed",
): Promise<void> {
  await page.waitForURL(
    (url) =>
      url.origin === DEMO_SHOP_ORIGIN &&
      url.searchParams.get("status") === status,
    { timeout: 45_000, waitUntil: "commit" },
  );
}

const body = paymentBody({
  authentication_type: "three_ds",
  customer_id: "new_user",
});

test.describe("Stripe 3DS card flow", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body });
  });

  test("title rendered correctly", async ({ page }) => {
    await expect(page.getByText("Hyperswitch Unified Checkout")).toBeVisible();
  });

  test("orca-payment-element iframe loaded", async ({ page, sdk }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();
    // The frame has a loaded document body.
    await expect(sdk.paymentElement.locator("body")).toBeAttached();
  });

  test("should redirect a 3DS card payment to the Stripe 3DS page", async ({
    sdk,
    page,
    hermetic,
  }) => {
    const { cardNo } = stripeCards.threeDSCard;

    await typeCard(sdk, stripeCards.threeDSCard);
    await sdk.submit();

    // Wait for the Stripe 3DS document itself, not just the start of the
    // navigation, so a redirect that never finishes doesn't pass.
    await page.waitForURL(STRIPE_3DS_URL, {
      timeout: 30_000,
      waitUntil: "domcontentloaded",
    });
    await expectConfirmedWith(hermetic, cardNo);
    await expectRedirectedToNextAction(hermetic);
  });

  test("should succeed when the Stripe 3DS challenge is completed", async ({
    sdk,
    page,
    api,
    checkout,
    credentials,
    hermetic,
  }) => {
    await serveShopReturnPage(page, credentials, checkout.lastIntent!);
    await typeCard(sdk, stripeCards.threeDSCard);
    await sdk.submit();

    await page.waitForURL(STRIPE_3DS_URL, {
      timeout: 30_000,
      waitUntil: "domcontentloaded",
    });
    await answerStripeChallenge(page, "authorize");

    await expectReturnedToShopWith(page, "succeeded");
    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });
    await api.pollPaymentStatus(checkout.lastIntent!.paymentId, "succeeded", {
      timeoutMs: 30_000,
    });
    await expectConfirmedWith(hermetic, stripeCards.threeDSCard.cardNo);
  });

  test("should fail when the Stripe 3DS challenge is failed", async ({
    sdk,
    page,
    api,
    checkout,
    credentials,
  }) => {
    await serveShopReturnPage(page, credentials, checkout.lastIntent!);
    await typeCard(sdk, stripeCards.threeDSCard);
    await sdk.submit();

    await page.waitForURL(STRIPE_3DS_URL, {
      timeout: 30_000,
      waitUntil: "domcontentloaded",
    });
    await answerStripeChallenge(page, "fail");

    await expectReturnedToShopWith(page, "failed");
    await expect(
      page.getByText("Payment failed. Please check your payment method."),
    ).toBeVisible({ timeout: 30_000 });
    await api.pollPaymentStatus(checkout.lastIntent!.paymentId, "failed", {
      timeoutMs: 30_000,
    });
  });
});
