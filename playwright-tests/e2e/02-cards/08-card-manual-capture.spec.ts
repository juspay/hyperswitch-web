// Stripe card payment with manual capture: the payment is authorised, not captured.
//
// Hermetic-capable. With capture_method "manual" the router authorises without
// capturing (status requires_capture) and the demo shop shows its
// requires_capture message. The spec fixture
// (recordings/02-cards/08-card-manual-capture.json) answers confirm that way
// in the hermetic tier; live gets the real Stripe authorisation.
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  expectConfirmedWith,
  typeCard,
} from "../../fixtures";

const body = paymentBody({ capture_method: "manual", customer_id: "new_user" });

test.describe("Card payment with manual capture", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body });
  });

  test("should authorise the card payment without capturing it", async ({
    sdk,
    page,
    hermetic,
    api,
    checkout,
  }) => {
    await typeCard(sdk, stripeCards.successCard);
    await sdk.submit();

    await expect(
      page.getByText("Payment is authorized and requires manual capture."),
    ).toBeVisible({
      timeout: 30_000,
    });
    await expectConfirmedWith(hermetic, stripeCards.successCard.cardNo);
    // The router agrees the payment awaits capture (no capture call is made).
    await api.pollPaymentStatus(
      checkout.lastIntent!.paymentId,
      "requires_capture",
    );
  });
});
