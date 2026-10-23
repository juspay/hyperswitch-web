// Terms Display Tests: the `terms` option controls the visibility of terms text
// for different payment methods (Auto, Always, Never).
// Note: Card terms only display for mandate/setup flows (NEW_MANDATE/SETUP_MANDATE).
//
// Hermetic-capable. recordings/01-sdk-core/terms-display.json answers the
// client list with payment_type "new_mandate" for intents created with
// setup_future_usage=off_session (what the router does); other intents get the
// base "normal" list.
import { test, expect, paymentBody } from "../../fixtures";

const mandateBody = paymentBody({
  customer_id: "terms_test_user",
  authentication_type: "no_three_ds",
  setup_future_usage: "off_session",
});
// Same intent without setup_future_usage: a normal (non-mandate) payment.
const nonMandateBody = paymentBody({
  customer_id: "terms_test_user",
  authentication_type: "no_three_ds",
  setup_future_usage: undefined,
});

const termsOptions = (card: string) => ({
  terms: {
    card,
    auBecsDebit: "auto",
    bancontact: "auto",
    ideal: "auto",
    sepaDebit: "auto",
    sofort: "auto",
    usBankAccount: "auto",
  },
});

test.describe("PaymentElement terms Option", () => {
  test.describe('terms.card: "always" with mandate flow', () => {
    test.beforeEach(async ({ checkout }) => {
      await checkout.open({
        body: mandateBody,
        options: termsOptions("always"),
        waitForReady: true,
      });
    });

    test("should display card terms text when card is selected", async ({
      sdk,
    }) => {
      await expect(sdk.find(".TermsTextLabel").first()).toBeVisible({
        timeout: 10_000,
      });
    });
  });

  test.describe('terms.card: "never" with mandate flow', () => {
    test.beforeEach(async ({ checkout }) => {
      await checkout.open({
        body: mandateBody,
        options: termsOptions("never"),
        waitForReady: true,
      });
    });

    test("should hide card terms text when card is selected", async ({
      sdk,
    }) => {
      await expect(sdk.find(".TermsTextLabel")).toHaveCount(0);
    });
  });

  test.describe("terms.card: not applicable for non-mandate flow", () => {
    test.beforeEach(async ({ checkout }) => {
      await checkout.open({
        body: nonMandateBody,
        options: termsOptions("always"),
        waitForReady: true,
      });
    });

    test("should not show card terms for non-mandate payment flows", async ({
      sdk,
    }) => {
      await expect(sdk.find(".TermsTextLabel")).toHaveCount(0);
    });
  });
});
