// TrustPay SEPA Bank Transfer (bank_transfer / sepa_bank_transfer).
//
// Hermetic-capable: the confirm body and next_action type run on both tiers.
// Hermetic answers come from recordings/03-bank-transfers/03-trustpay-sepa-transfer.json
// (redirect_to_url to a stubbed synthetic host), and in hermetic mode the test
// also checks the SDK followed that redirect. The live router may answer
// display_bank_transfer_information instead, so both next_action types pass.
import {
  test,
  expect,
  paymentBody,
  defaultBillingAddress,
  connectorEnum,
  PAYMENT_ELEMENT_IFRAME,
  expectRedirectedTo,
  payAndCaptureConfirm,
} from "../../fixtures";

test.describe("Trustpay SEPA Bank Transfer payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    const trustpayProfileId = credentials.profileId(connectorEnum.TRUSTPAY);
    expect(
      trustpayProfileId,
      "Trustpay connector credentials are missing — add trustpay to creds.json to run this test.",
    ).toBeTruthy();

    const base = paymentBody();
    await checkout.open({
      body: paymentBody({
        profile_id: trustpayProfileId,
        currency: "EUR",
        email: "test@example.com",
        billing: {
          ...base.billing,
          address: {
            ...defaultBillingAddress,
            country: "DE",
            state: "Berlin",
            line1: "123 Test Street",
            city: "Berlin",
            zip: "10115",
          },
        },
        shipping: {
          ...base.shipping,
          address: { ...defaultBillingAddress, country: "DE", state: "Berlin" },
        },
      }),
    });
  });

  test("should redirect a SEPA Bank Transfer through Trustpay", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await sdk.selectPaymentMethodOrSkip("SEPA Bank Transfer");

    // Wait for the SepaBankTransferLazy component to fully mount before clicking.
    // The info text signals the lazy chunk is loaded and the submit listener is registered.
    await expect(
      sdk.text("After submitting these details").first(),
    ).toBeVisible({ timeout: 15_000 });

    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);

    expect(confirm.request.payment_method).toBe("bank_transfer");
    expect(confirm.request.payment_method_type).toBe("sepa_bank_transfer");
    expect(
      confirm.request.payment_method_data?.bank_transfer?.sepa_bank_transfer,
    ).toEqual({});
    expect(confirm.status).toBe(200);
    expect(["redirect_to_url", "display_bank_transfer_information"]).toContain(
      confirm.body?.next_action?.type,
    );

    // Hermetic: the fixture answers redirect_to_url; the SDK must follow it.
    if (hermetic.enabled)
      await expectRedirectedTo(
        page,
        hermetic,
        /trustpay\.hermetic\.invalid/,
        confirm,
      );
  });
});
