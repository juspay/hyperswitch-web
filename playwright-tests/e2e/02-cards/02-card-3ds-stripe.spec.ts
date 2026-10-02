// Stripe 3DS card payment: confirm redirects to the Stripe 3DS page.
//
// Hermetic-capable: both tests stop at the Stripe 3DS page's URL and never
// interact with the challenge. In the hermetic tier the spec fixture
// (recordings/02-cards/02-card-3ds-stripe.json) answers confirm with
// requires_customer_action + next_action.redirect_to_url on the router's
// /payments/redirect endpoint, whose page forwards to hooks.stripe.com/3d_secure_2
// (a blank stub). The live tier gets the real router + Stripe redirect.
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  expectConfirmedWith,
  expectRedirectedToNextAction,
  typeCard,
} from "../../fixtures";

const body = paymentBody({
  authentication_type: "three_ds",
  customer_id: "stripe_3ds_test_user",
});

test.describe("Stripe 3DS Card Payment", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body });
  });

  test("should complete the 3DS card payment successfully", async ({
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

  test("should redirect to 3DS authentication page", async ({
    sdk,
    page,
    hermetic,
  }) => {
    await typeCard(sdk, stripeCards.threeDSCard);
    await sdk.submit();

    await expect(page).toHaveURL(/stripe\.com/, { timeout: 30_000 });
    await expectRedirectedToNextAction(hermetic);
  });
});
