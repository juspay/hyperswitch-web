// Stripe non-3DS card payment: a successful payment plus client-side
// validation errors.
//
// Hermetic-capable: the success case runs against the base confirm fixture
// (status "succeeded") in the hermetic tier, and additionally checks that the
// typed card reached /confirm; the validation cases never leave the SDK.
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  expectConfirmedWith,
  typeCard,
} from "../../fixtures";

const body = paymentBody({ customer_id: "stripe_no_3ds_test_user" });

test.describe("Stripe Non-3DS Card Payment", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body });
  });

  test.describe("Successful Payments", () => {
    test("should complete the card payment successfully", async ({
      sdk,
      page,
      hermetic,
    }) => {
      await typeCard(sdk, stripeCards.successCard);
      await sdk.submit();

      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
      await expectConfirmedWith(hermetic, stripeCards.successCard.cardNo);
    });
  });

  test.describe("Validation Errors", () => {
    test("should fail with an invalid card number", async ({ sdk, page }) => {
      await typeCard(sdk, stripeCards.invalidCard);
      await sdk.submit();

      await expect(page.getByText("Please enter valid details")).toBeVisible({
        timeout: 10_000,
      });
    });

    test("should show error for expired card year", async ({ sdk }) => {
      await typeCard(sdk, { ...stripeCards.successCard, card_exp_year: "10" });
      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Your card's expiration year is in the past." })
          .first(),
      ).toBeVisible({ timeout: 10_000 });
    });

    test("should show error for incomplete card CVV", async ({ sdk }) => {
      await typeCard(sdk, { ...stripeCards.successCard, cvc: "1" });
      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Your card's security code is incomplete." })
          .first(),
      ).toBeVisible({ timeout: 10_000 });
    });
  });
});
