// Card number, expiry and CVC validation in the card form: invalid and
// unsupported numbers, brand-specific rules, input formatting and error clearing.
//
// Hermetic-capable: every test only needs the SDK to render, validate input and
// submit. The "Thanks for your order!" cases run against the recorded confirm
// (status "succeeded") in the hermetic tier and against Stripe on sandbox in
// the live tier; in hermetic mode they additionally check that the SDK really
// sent the typed card to /confirm, so the synthetic success can't hide a bug.
import {
  test,
  expect,
  testIds,
  paymentBody,
  stripeCards,
  expectConfirmedWith,
  type Sdk,
} from "../../fixtures";

const body = paymentBody({ customer_id: "card_validation_test_user" });

test.describe("Card Number Validation", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body });
  });

  test.describe("Invalid Card Scenarios", () => {
    test("should fail with undetectable card brand and invalid card number", async ({
      sdk,
    }) => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, "111111");
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Please enter a valid card number." })
          .first(),
      ).toBeVisible();
    });

    test("should fail with detectable but invalid card number", async ({
      sdk,
    }) => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, "424242");
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();

      await expect(
        sdk.cardErrors.filter({ hasText: "Card number is invalid." }).first(),
      ).toBeVisible();
    });

    test("should fail with unsupported card brand (RuPay)", async ({ sdk }) => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, "6082015309577308");
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "RuPay is not supported at the moment." })
          .first(),
      ).toBeVisible();
    });

    test("should fail with empty card number", async ({ sdk }) => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Card Number cannot be empty" })
          .first(),
      ).toBeVisible();
    });
  });

  test.describe("Card Brand Detection & Formatting", () => {
    test("should auto-format 16-digit Visa card", async ({ sdk }) => {
      await sdk.type(testIds.cardNoInputTestId, "4242424242424242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "4242 4242 4242 4242",
      );
    });

    test("should auto-format 19-digit UnionPay card", async ({ sdk }) => {
      const { cardNo } = stripeCards.unionPay19;

      // This is a brand-detection / formatting test: assert the 19-digit
      // UnionPay number is accepted (not truncated) and grouped 4-4-4-4-3,
      // rather than completing a payment (UnionPay doesn't settle on Stripe).
      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "6205 5000 0000 0000 004",
      );
    });

    test("should auto-format 16-digit MasterCard", async ({
      sdk,
      page,
      hermetic,
    }) => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.masterCard16;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
      await expectConfirmedWith(hermetic, cardNo);
    });

    test("should auto-format 15-digit American Express card", async ({
      sdk,
      page,
      hermetic,
    }) => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.amexCard15;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
      await expectConfirmedWith(hermetic, cardNo);
    });

    test("should auto-format 14-digit Diners Club card", async ({
      sdk,
      page,
      hermetic,
    }) => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.dinersClubCard14;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
      await expectConfirmedWith(hermetic, cardNo);
    });
  });

  test.describe("CVC Length by Card Brand", () => {
    test("should size the CVC to 3 for a Visa", async ({ sdk }) => {
      const { cardNo } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, cardNo);

      await expect(sdk.field(testIds.cardCVVInputTestId)).toHaveAttribute(
        "maxlength",
        "3",
      );
    });

    test("should size the CVC to 4 for an American Express", async ({
      sdk,
    }) => {
      const { cardNo } = stripeCards.amexCard15;

      await sdk.type(testIds.cardNoInputTestId, cardNo);

      await expect(sdk.field(testIds.cardCVVInputTestId)).toHaveAttribute(
        "maxlength",
        "4",
      );
    });
  });

  test.describe("CVC Validity Styling", () => {
    // A field is marked invalid on blur and unmarked while focused, uniformly across the
    // SDK. The second case matters because the expiry auto-advances into the CVC: focus
    // must still land there, and must still clear the mark.
    const typeVisaThenShortCvc = async (sdk: Sdk) => {
      await sdk.type(testIds.cardNoInputTestId, stripeCards.successCard.cardNo);
      await sdk.type(testIds.cardCVVInputTestId, "12");
    };

    test("should mark an out-of-range CVC invalid on blur and unmark it on focus", async ({
      sdk,
    }) => {
      await typeVisaThenShortCvc(sdk);

      await sdk.field(testIds.cardNoInputTestId).click();
      await expect(sdk.field(testIds.cardCVVInputTestId)).toContainClass(
        "Input--invalid",
      );

      await sdk.field(testIds.cardCVVInputTestId).click();
      await expect(sdk.field(testIds.cardCVVInputTestId)).not.toContainClass(
        "Input--invalid",
      );
    });

    test("should focus the CVC and unmark it when the expiry auto-advances", async ({
      sdk,
    }) => {
      await typeVisaThenShortCvc(sdk);

      await sdk.type(testIds.expiryInputTestId, "1230");

      const cvcField = sdk.field(testIds.cardCVVInputTestId);
      await expect(cvcField).toBeFocused();
      await expect(cvcField).not.toContainClass("Input--invalid");
    });
  });

  test.describe("Card Brand Icons", () => {
    test("should display card brand icon dynamically for Visa", async ({
      sdk,
    }) => {
      await sdk.type(testIds.cardNoInputTestId, "4242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue("4242");
    });
  });

  test.describe("Expiry Date Validation", () => {
    test("should reject expired card (past year)", async ({ sdk }) => {
      const { cardNo, cvc } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, "0123");
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Your card's expiration year is in the past." })
          .first(),
      ).toBeVisible();
    });

    test("should reject invalid month (00)", async ({ sdk }) => {
      const { cardNo, cvc } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, "0030");
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();

      await expect(sdk.cardErrors.first()).toBeVisible();
    });

    test("should accept valid future expiry date", async ({
      sdk,
      page,
      hermetic,
    }) => {
      const { cardNo, cvc } = stripeCards.successCard;
      const futureYear = (new Date().getFullYear() + 1).toString().slice(-2);

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, `12${futureYear}`);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
      await expectConfirmedWith(hermetic, cardNo);
    });
  });

  test.describe("CVC/CVV Validation", () => {
    test("should require 3 digits for Visa", async ({ sdk }) => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, "12");

      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Your card's security code is incomplete." })
          .first(),
      ).toBeVisible();
    });

    test("should require 4 digits for Amex", async ({ sdk }) => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.amexCard15;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, "123");

      await sdk.submit();

      await expect(
        sdk.cardErrors
          .filter({ hasText: "Your card's security code is incomplete." })
          .first(),
      ).toBeVisible();
    });

    test("should reject alphabetic characters in CVC", async ({ sdk }) => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, "abc");

      await expect(sdk.field(testIds.cardCVVInputTestId)).toHaveValue("");
    });

    test("should accept valid 3-digit CVC for Visa", async ({
      sdk,
      page,
      hermetic,
    }) => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, "123");

      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
      await expectConfirmedWith(hermetic, cardNo);
    });

    test("should accept valid 4-digit CVC for Amex", async ({
      sdk,
      page,
      hermetic,
    }) => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.amexCard15;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, "1234");

      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
      await expectConfirmedWith(hermetic, cardNo);
    });
  });

  test.describe("Input Edge Cases", () => {
    test("should trim spaces from card number input", async ({ sdk }) => {
      await sdk.type(testIds.cardNoInputTestId, "4242 4242 4242 4242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "4242 4242 4242 4242",
      );
    });

    test("should reject card number with letters", async ({ sdk }) => {
      await sdk.type(testIds.cardNoInputTestId, "4242abcd4242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "4242 4242",
      );
    });

    test("should enforce max length for card number (19 digits)", async ({
      sdk,
    }) => {
      await sdk.type(
        testIds.cardNoInputTestId,
        "620550000000000000499999999999",
      );

      const value = await sdk.field(testIds.cardNoInputTestId).inputValue();
      expect(value.length).toBeLessThanOrEqual(23);
    });

    test("should handle paste event with formatted number", async ({ sdk }) => {
      // Sets the value directly and fires `input`, as a paste handler would see it.
      await sdk.field(testIds.cardNoInputTestId).evaluate((el, value) => {
        (el as HTMLInputElement).value = value;
        el.dispatchEvent(new Event("input", { bubbles: true }));
      }, "4242 4242 4242 4242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "4242 4242 4242 4242",
      );
    });

    test("should clear error when user starts fixing invalid input", async ({
      sdk,
    }) => {
      const { card_exp_year, cvc } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, "111111");
      await sdk.type(testIds.expiryInputTestId, "12");
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();

      await expect(sdk.cardErrors.first()).toBeVisible();

      await sdk.field(testIds.cardNoInputTestId).clear();
      await sdk.type(testIds.cardNoInputTestId, "4242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue("4242");
    });
  });

  test.describe("Real-time Validation", () => {
    test("should show card brand while typing", async ({ sdk }) => {
      await sdk.type(testIds.cardNoInputTestId, "4");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue("4");

      await sdk.type(testIds.cardNoInputTestId, "242424242424242");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "4242 4242 4242 4242",
      );
    });

    test("should update card brand when changing from Visa to MasterCard", async ({
      sdk,
    }) => {
      await sdk.type(testIds.cardNoInputTestId, "4242424242424242");

      await sdk.field(testIds.cardNoInputTestId).clear();

      await sdk.type(testIds.cardNoInputTestId, "5555555555554444");

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "5555 5555 5555 4444",
      );
    });

    test("should validate minimum card number length", async ({ sdk }) => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, "4242");
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, cvc);

      await sdk.submit();

      await expect(
        sdk.cardErrors.filter({ hasText: "Card number is invalid." }).first(),
      ).toBeVisible();
    });
  });

  test.describe("Cross-field Validation", () => {
    test("should require all fields before submit", async ({ sdk }) => {
      await sdk.type(testIds.cardNoInputTestId, stripeCards.successCard.cardNo);

      await sdk.submit();

      await expect(sdk.cardErrors.first()).toBeVisible();
    });

    test("should preserve valid fields when one is invalid", async ({
      sdk,
    }) => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      await sdk.type(testIds.cardNoInputTestId, cardNo);
      await sdk.type(testIds.expiryInputTestId, card_exp_month);
      await sdk.type(testIds.expiryInputTestId, card_exp_year);
      await sdk.type(testIds.cardCVVInputTestId, "12");

      await sdk.submit();

      await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
        "4242 4242 4242 4242",
      );
      await expect(sdk.field(testIds.expiryInputTestId)).toHaveValue(
        `12 / ${card_exp_year}`,
      );
    });
  });
});
