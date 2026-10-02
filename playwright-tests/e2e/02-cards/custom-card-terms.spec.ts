// Custom Card Terms Message Tests
// Verifies that the customMessageForCardTerms option renders
// custom text in place of the default card terms message.
//
// Hermetic-capable: rendering only.
import { test, expect, paymentBody } from "../../fixtures";

const body = paymentBody({
  customer_id: "custom_terms_test_user",
  authentication_type: "no_three_ds",
  setup_future_usage: "off_session",
});

test.describe("PaymentElement customMessageForCardTerms Option", () => {
  test.describe("custom terms message", () => {
    const customTermsText =
      "By proceeding, you agree to our custom payment terms and conditions.";

    test.beforeEach(async ({ checkout, sdk }) => {
      await checkout.open({
        body,
        options: {
          customMessageForCardTerms: customTermsText,
          terms: { card: "always" },
        },
      });
      await sdk.waitForReady();
    });

    test("should display the custom terms message text", async ({ sdk }) => {
      const terms = sdk.find(".TermsTextLabel");
      await expect(terms).toBeVisible({ timeout: 10_000 });
      await expect(terms).toContainText(customTermsText);
    });
  });

  test.describe("empty custom terms message (uses default)", () => {
    test.beforeEach(async ({ checkout, sdk }) => {
      await checkout.open({
        body,
        options: {
          customMessageForCardTerms: "",
          terms: { card: "always" },
        },
      });
      await sdk.waitForReady();
    });

    test("should display the default terms message when custom message is empty", async ({
      sdk,
    }) => {
      const terms = sdk.find(".TermsTextLabel");
      await expect(terms).toBeVisible({ timeout: 10_000 });
      await expect(terms).not.toHaveText("");
    });
  });
});
