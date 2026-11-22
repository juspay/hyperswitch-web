// Submit Button State Tests: submit button behavior, disabled during
// processing, re-enabled after error, loading states, and visual feedback.
//
// Hermetic-capable. The "Processing State" tests need the confirm call to take
// a moment, like it does against the sandbox (the demo shop disables #submit
// while confirmPayment() is pending, then replaces the form with the success
// page); in the hermetic tier the recorded confirm answers after a short
// delay so that window is observable. The delay is a no-op on live.
import {
  test,
  expect,
  testIds,
  paymentBody,
  stripeCards,
  slowConfirm,
} from "../../fixtures";

const body = paymentBody({
  customer_id: "submit_button_test_user",
  authentication_type: "no_three_ds",
  capture_method: "automatic",
});

/** Hermetic only: how long confirm takes, like a real connector round trip. */
const CONFIRM_DELAY_MS = 2_000;

test.describe("Submit Button States", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body, waitForReady: true });
  });

  test.describe("Initial State", () => {
    test("should render the submit button as visible and enabled on page load", async ({
      sdk,
    }) => {
      await expect(sdk.submitButton).toBeVisible();
      await expect(sdk.submitButton).toBeEnabled();
    });

    test("should display the submit button with appropriate text", async ({
      sdk,
    }) => {
      await expect(sdk.submitButton).toBeVisible();
      await expect(sdk.submitButton).toHaveText(/\S/);
    });
  });

  test.describe("Processing State", () => {
    test("should disable submit button immediately after click with valid card", async ({
      sdk,
      hermetic,
    }) => {
      slowConfirm(hermetic, CONFIRM_DELAY_MS);
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      await sdk.enterCardDetails({
        cardNo,
        card_exp_month,
        card_exp_year,
        cvc,
      });

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(sdk.submitButton).toBeDisabled();
    });

    test("should show loading indicator while payment is processing", async ({
      sdk,
      hermetic,
    }) => {
      slowConfirm(hermetic, CONFIRM_DELAY_MS);
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      await sdk.enterCardDetails({
        cardNo,
        card_exp_month,
        card_exp_year,
        cvc,
      });

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      // "Loading" is asserted as the disabled state only; no spinner element is checked.
      await expect(sdk.submitButton).toBeDisabled();
    });
  });

  test.describe("Error Recovery State", () => {
    test("should keep submit button enabled after client-side validation error", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "4242 4242");

      await sdk.safeType(testIds.expiryInputTestId, "12");

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "CVC Number cannot be empty" })
          .first(),
      ).toBeVisible({ timeout: 10_000 });

      await expect(sdk.submitButton).toBeVisible();
      await expect(sdk.submitButton).toBeEnabled();
    });

    test("should allow resubmission after fixing validation errors", async ({
      sdk,
      page,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "4242 4242");

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Card expiry date cannot be empty" })
          .first(),
      ).toBeVisible({ timeout: 5_000 });

      await sdk.field(testIds.cardNoInputTestId).clear();

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      await sdk.enterCardDetails({
        cardNo,
        card_exp_month,
        card_exp_year,
        cvc,
      });

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 10_000,
      });
    });
  });

  test.describe("Submit with Incomplete Fields", () => {
    test("should not process payment when only card number is filled", async ({
      sdk,
    }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Card expiry date cannot be empty" })
          .first(),
      ).toBeVisible({ timeout: 5_000 });

      await expect(sdk.submitButton).toBeVisible();
    });

    test("should not process payment when CVC is missing", async ({ sdk }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await sdk.safeType(
        testIds.expiryInputTestId,
        stripeCards.successCard.card_exp_month +
          stripeCards.successCard.card_exp_year,
      );

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "CVC Number cannot be empty" })
          .first(),
      ).toBeVisible({ timeout: 5_000 });
    });

    test("should not process payment when expiry is missing", async ({
      sdk,
    }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await sdk.safeType(
        testIds.cardCVVInputTestId,
        stripeCards.successCard.cvc,
      );

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Card expiry date cannot be empty" })
          .first(),
      ).toBeVisible({ timeout: 5_000 });
    });
  });
});
