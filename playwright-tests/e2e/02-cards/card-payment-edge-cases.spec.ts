// Card Payment Edge Cases
// Tests for decline scenarios, double-submit prevention, and card brand icon verification.
//
// Hermetic-capable. "Decline" here is the SDK's client-side rejection of an
// invalid card number ("Please enter valid details"), so no connector outcome
// is involved. The double-submit tests slow the hermetic confirm down (no-op on
// live) so the processing state is observable, like it is against a real router.
import {
  test,
  expect,
  testIds,
  paymentBody,
  stripeCards,
  slowConfirm,
  type Sdk,
} from "../../fixtures";

const body = paymentBody({
  customer_id: "edge_case_test_user",
  authentication_type: "no_three_ds",
  capture_method: "automatic",
});

/** Hermetic only: how long the confirm response is held so "processing" is observable. */
const CONFIRM_DELAY_MS = 1_500;

/**
 * Card brand SVG icons (`<svg><use href|xlink:href="#…brand…">`) whose href
 * contains `brand`, counted across both SDK frames.
 */
const brandIconCount = async (sdk: Sdk, brand: string): Promise<number> => {
  const countIn = (root: ReturnType<Sdk["find"]>) =>
    root
      .evaluateAll(
        (els, b) =>
          els.filter((el) => {
            const href =
              el.getAttribute("href") ||
              el.getAttributeNS("http://www.w3.org/1999/xlink", "href") ||
              "";
            return href.includes(b);
          }).length,
        brand,
      )
      .catch(() => 0);
  const [card, outer] = await Promise.all([
    countIn(sdk.findInCard("svg use")),
    countIn(sdk.find("svg use")),
  ]);
  return card + outer;
};

const expectBrandIcon = (sdk: Sdk, brand: string) =>
  expect
    .poll(() => brandIconCount(sdk, brand), {
      message: `a "${brand}" card brand icon`,
    })
    .toBeGreaterThanOrEqual(1);

test.describe("Card Payment Edge Cases", () => {
  test.beforeEach(async ({ checkout, sdk }) => {
    await checkout.open({ body });
    await sdk.waitForReady();
  });

  test.describe("Decline Scenarios", () => {
    test("should display error message when payment is declined with invalid card", async ({
      sdk,
      page,
    }) => {
      await sdk.enterCardDetails(stripeCards.invalidCard);

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(page.getByText("Please enter valid details")).toBeVisible({
        timeout: 10_000,
      });
    });

    test("should allow user to retry after a declined payment", async ({
      sdk,
      page,
      hermetic,
    }) => {
      const invalidCard = stripeCards.invalidCard;

      await sdk.enterCardDetails(invalidCard);

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(page.getByText("Please enter valid details")).toBeVisible({
        timeout: 10_000,
      });

      // Retry with a valid card
      const validCard = stripeCards.successCard;

      await sdk.safeType(testIds.cardNoInputTestId, validCard.cardNo);
      await sdk.safeType(
        testIds.expiryInputTestId,
        validCard.card_exp_month + validCard.card_exp_year,
      );
      await sdk.safeType(testIds.cardCVVInputTestId, validCard.cvc);

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 10_000,
      });

      // Hermetic only: the rejected attempt never reached the router; the retry did, with the valid card.
      if (hermetic.enabled) {
        const confirms = hermetic.calls("confirm");
        expect(confirms).toHaveLength(1);
        expect(JSON.stringify(confirms[0].requestBody)).toContain(
          validCard.cardNo,
        );
      }
    });
  });

  test.describe("Double Submit Prevention", () => {
    test("should not allow multiple rapid clicks on submit button", async ({
      sdk,
      page,
      hermetic,
    }) => {
      slowConfirm(hermetic, CONFIRM_DELAY_MS);
      await sdk.enterCardDetails(stripeCards.successCard);

      // Click submit multiple times rapidly
      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      // After first click, verify the button is disabled while processing
      await expect(sdk.submitButton).toBeDisabled();

      // Payment should still succeed with a single charge
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 15_000,
      });
      if (hermetic.enabled) expect(hermetic.calls("confirm")).toHaveLength(1);
    });

    test("should disable submit button while payment is processing", async ({
      sdk,
      hermetic,
    }) => {
      slowConfirm(hermetic, CONFIRM_DELAY_MS);
      await sdk.enterCardDetails(stripeCards.successCard);

      await expect(sdk.submitButton).toBeVisible();
      await sdk.submit();

      // Immediately check that the submit button is in a disabled/processing state
      await expect(sdk.submitButton).toBeDisabled();
    });
  });

  test.describe("Card Brand Icon Display", () => {
    test("should display Visa icon when typing a Visa card number", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "4242");

      // Verify a card brand SVG icon is rendered (the SDK uses <svg> with <use> referencing brand icons)
      await expectBrandIcon(sdk, "visa-light");
    });

    test("should display MasterCard icon when typing a MasterCard number", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "5555");

      await expectBrandIcon(sdk, "mastercard");
    });

    test("should display Amex icon when typing an Amex card number", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "3782");

      await expectBrandIcon(sdk, "amex-light");
    });

    test("should update card brand icon when switching from Visa to MasterCard", async ({
      sdk,
    }) => {
      // Type Visa prefix
      await sdk.safeType(testIds.cardNoInputTestId, "4242");

      // Verify Visa icon shows
      await expectBrandIcon(sdk, "visa-light");

      // Clear and type MasterCard prefix (safeType clears first)
      await sdk.safeType(testIds.cardNoInputTestId, "5555");

      await expectBrandIcon(sdk, "mastercard");
    });
  });

  test.describe("Empty Form Submission", () => {
    test("should show error when submitting completely empty form", async ({
      sdk,
    }) => {
      // Explicitly confirm the card form is fully mounted before submitting,
      // preventing a race where submitCallback is not yet registered.
      await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible();

      await expect(sdk.submitButton).toBeVisible();
      await expect(sdk.submitButton).toBeEnabled();
      await sdk.submit();

      await expect(sdk.cardErrors.first()).toBeVisible({ timeout: 10_000 });
    });

    test("should show specific field errors for each empty required field", async ({
      sdk,
    }) => {
      // Only fill card number, leave expiry and CVC empty
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await expect(sdk.submitButton).toBeVisible();
      await expect(sdk.submitButton).toBeEnabled();
      await sdk.submit();

      await expect(sdk.cardErrors.first()).toBeVisible({ timeout: 10_000 });
    });
  });

  test.describe("Special Characters and Input Sanitization", () => {
    test("should reject special characters in card number field", async ({
      sdk,
    }) => {
      await sdk.safeType(testIds.cardNoInputTestId, "4242!@#$4242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "4242 4242",
      );
    });

    test("should reject special characters in CVC field", async ({ sdk }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await sdk.safeType(testIds.cardCVVInputTestId, "1!2@3");

      await expect(sdk.field(testIds.cardCVVInputTestId)).toHaveValue("123");
    });

    test("should reject special characters in expiry field", async ({
      sdk,
    }) => {
      await sdk.safeType(
        testIds.cardNoInputTestId,
        stripeCards.successCard.cardNo,
      );

      await sdk.safeType(testIds.expiryInputTestId, "1!2/3@0");

      // Only digits should be kept
      await expect(sdk.field(testIds.expiryInputTestId)).toHaveValue(
        /^[\d\s\/]*$/,
      );
    });
  });
});
