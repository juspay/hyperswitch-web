// Stripe 3DS card flow end to end: the checkout page and payment element load,
// then a 3DS card payment redirects to the Stripe 3DS page.
//
// Hermetic-capable: the 3DS test stops at the Stripe 3DS page's URL and never
// interacts with the challenge. In the hermetic tier the spec fixture
// (recordings/02-cards/stripe-3DS-card-flow-e2e-test.json) answers confirm with
// requires_customer_action + next_action.redirect_to_url on the router's
// /payments/redirect endpoint, whose page forwards to hooks.stripe.com/3d_secure_2
// (a blank stub). The live tier gets the real router + Stripe redirect.
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  PAYMENT_ELEMENT_IFRAME,
  expectConfirmedWith,
  expectRedirectedToNextAction,
  typeCard,
} from "../../fixtures";

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

  test("should complete the card payment successfully", async ({
    sdk,
    page,
    hermetic,
  }) => {
    const { cardNo } = stripeCards.threeDSCard;

    await typeCard(sdk, stripeCards.threeDSCard);
    await sdk.submit();

    // Only the URL matters; don't wait for the third-party page to finish loading.
    await page.waitForURL(/hooks\.stripe\.com\/3d_secure_2/, {
      timeout: 30_000,
      waitUntil: "commit",
    });
    await expectConfirmedWith(hermetic, cardNo);
    await expectRedirectedToNextAction(hermetic);
  });
});
