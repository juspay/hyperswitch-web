// Saved cards: pays with the customer's saved card.
//
// Hermetic-capable. The saved-card test is conditional: it pays with a saved
// card only if the customer already has one (a fresh sandbox merchant has none,
// so live usually takes the "new card flow" branch and asserts nothing). In the
// hermetic tier the spec fixture (recordings/02-cards/07-saved-cards.json) gives
// hyperswitch_sdk_demo_id one saved Amex nicknamed "4 digit" (the label the test
// clicks; Amex takes the 4-digit CVC it types), so the saved-card branch really
// runs, without depending on test order or an earlier run having saved a card.
import {
  test,
  expect,
  testIds,
  paymentBody,
  PAYMENT_ELEMENT_IFRAME,
  expectConfirmedWith,
} from "../../fixtures";

const body = paymentBody({ customer_id: "hyperswitch_sdk_demo_id" });

test.describe("Saved cards", () => {
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

  test("should check if cards are saved", async ({ sdk, page, hermetic }) => {
    const addNewCard = sdk.field(testIds.addNewCardIcon);
    const newCardNumber = sdk.cardFields.getByTestId(testIds.cardNoInputTestId);

    // Wait until the SDK has rendered either the saved-methods screen or the
    // new-card form before branching, so the branch doesn't race the saved-methods
    // call.
    await expect
      .poll(
        async () =>
          (await addNewCard.count()) > 0 || (await newCardNumber.isVisible()),
        { timeout: 15_000 },
      )
      .toBe(true);

    if ((await addNewCard.count()) > 0) {
      await sdk.text("4 digit").first().click();
      await sdk.type(testIds.cardCVVInputTestId, "1234");
      await sdk.submit();
      await expect(page.getByText("Thanks for your order!")).toBeVisible({
        timeout: 30_000,
      });
      // Hermetic: the SDK confirmed with the saved card's token and the typed CVC.
      await expectConfirmedWith(
        hermetic,
        '"payment_token":"token_hermetic_saved_amex"',
        '"card_cvc":"1234"',
      );
    } else {
      console.log("new card flow — no saved cards on fresh merchant");
      // The hermetic fixture always has a saved card, so this branch is live-only.
      expect(
        hermetic.enabled,
        "hermetic fixture should have shown the saved card",
      ).toBe(false);
    }
  });
});
