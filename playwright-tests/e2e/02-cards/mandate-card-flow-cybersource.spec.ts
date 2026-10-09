// Mandate Card Flow - Cybersource
// Tests the mandate (off_session) card saving and reuse flow:
//
// Flow:
// 1. First payment: Enter card details with setup_future_usage: "off_session"
//    - Check "Save card details" checkbox
//    - Complete payment successfully
// 2. Second payment: Same customer_id with setup_future_usage: "off_session"
//    - Saved card payment sheet should appear
//    - No CVC input required (mandate/off_session)
//    - Complete payment using saved card
//
// Live: test 2 uses the card test 1 saved (the describe runs serially). Hermetic:
// each test stands alone; test 2 layers a saved, recurring-enabled Cybersource
// card (requires_cvv: false) for this customer on top of
// recordings/02-cards/mandate-card-flow-cybersource.json.
import {
  test,
  expect,
  testIds,
  paymentBody,
  cybersourceCards,
  connectorEnum,
  type Hermetic,
} from "../../fixtures";

const customerId = `mandate_test_${Date.now()}`;

const { cardNo, card_exp_month, card_exp_year, cvc } =
  cybersourceCards.successCard;

const SAVED_CARD_TOKEN = "token_hermetic_mandate_visa";

/** Hermetic only: the customer already has the off_session card test 1 saves. No-op on live. */
const withSavedMandateCard = (hermetic: Hermetic) =>
  hermetic.override("clientList", (route) => {
    const body = route.body as Record<string, unknown>;
    body.customer_payment_methods = [
      {
        payment_token: SAVED_CARD_TOKEN,
        payment_method: "card",
        payment_method_type: "credit",
        payment_method_data: {
          card: {
            scheme: "Visa",
            last4_digits: cardNo.slice(-4),
            expiry_month: card_exp_month,
            expiry_year: `20${card_exp_year}`,
            card_token: null,
            card_holder_name: "joseph Doe",
            card_fingerprint: null,
            nick_name: null,
            card_network: "Visa",
            card_isin: cardNo.slice(0, 6),
            card_issuer: null,
            card_type: "CREDIT",
            saved_to_locker: true,
          },
        },
        default_payment_method_set: true,
        // Saved with an off_session mandate: the router doesn't ask for the CVC again.
        requires_cvv: false,
        last_used_at: "2026-09-01T10:00:00.000Z",
        recurring_enabled: true,
      },
    ];
    return route;
  });

test.describe("Mandate Card Flow - Cybersource", () => {
  // Live: test 2 pays with the card test 1 saved for `customerId`. Serial keeps both
  // tests (and their retries) in one worker, so they share the per-worker customer id.
  test.describe.configure({ mode: "serial" });

  const body = (profileId: string | undefined) =>
    paymentBody({
      profile_id: profileId,
      authentication_type: "no_three_ds",
      customer_id: customerId,
      setup_future_usage: "off_session",
    });

  test("should save card with off_session setup and complete first payment", async ({
    checkout,
    sdk,
    page,
    credentials,
    hermetic,
  }) => {
    await checkout.open({
      body: body(credentials.profileId(connectorEnum.CYBERSOURCE)),
    });

    await sdk.waitForReady();

    await sdk.safeType(testIds.cardNoInputTestId, cardNo);
    await sdk.safeType(
      testIds.expiryInputTestId,
      card_exp_month + card_exp_year,
    );
    await sdk.safeType(testIds.cardCVVInputTestId, cvc);

    const saveCard = sdk.find(
      '[role="checkbox"][aria-label="Select to save card details"]',
    );
    await expect(saveCard).toBeVisible({ timeout: 10_000 });
    await saveCard.click();

    await expect(
      sdk.find('[role="checkbox"][aria-checked="true"]'),
    ).not.toHaveCount(0);

    await expect(sdk.submitButton).toBeVisible();
    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });

    // Hermetic only: confirming with "save card" checked sends the customer's acceptance.
    if (hermetic.enabled) {
      const confirm = await hermetic.waitForCall("confirm");
      expect(confirm?.requestBody).toHaveProperty("customer_acceptance");
    }
  });

  test("should use saved card for second payment without CVC (mandate)", async ({
    checkout,
    sdk,
    page,
    credentials,
    hermetic,
  }) => {
    withSavedMandateCard(hermetic);
    await checkout.open({
      body: body(credentials.profileId(connectorEnum.CYBERSOURCE)),
    });

    // The saved-card view does not render cardNoInput, so waitForReady()
    // (which waits for cardNoInput) cannot be used here. Wait for the iframe
    // to be visible, then assert the saved card UI is present.
    await expect(
      page.locator(
        "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element",
      ),
    ).toBeVisible({
      timeout: 15_000,
    });

    // Verify the saved card from the first payment is present.
    // addNewCardIcon appears when at least one saved card exists.
    await expect(sdk.field(testIds.addNewCardIcon)).toBeVisible({
      timeout: 20_000,
    });

    // Card ending in 4242 should be pre-selected
    await expect(sdk.text("4242").first()).toBeVisible();

    // off_session mandate — no CVV input required
    // (Checks the outer frame and the nested paymentMethodsSDK iframe, where the
    // saved-card CVC would render. Both checks can pass before that iframe loads;
    // the real proof is that the payment below completes without a CVC: with
    // requires_cvv the SDK blocks the submit.)
    await expect(sdk.find("[data-testid=cvvInput]")).toHaveCount(0);
    await expect(
      sdk.cardFields.locator(`[data-testid=${testIds.cardCVVInputTestId}]`),
    ).toHaveCount(0);

    await expect(sdk.submitButton).toBeVisible();
    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });

    // Hermetic only: paid with the saved card's token and no CVC.
    if (hermetic.enabled) {
      const confirm = await hermetic.waitForCall("confirm");
      expect(confirm?.requestBody).toMatchObject({
        payment_token: SAVED_CARD_TOKEN,
      });
      expect(JSON.stringify(confirm?.requestBody)).not.toContain("card_cvc");
    }
  });
});
