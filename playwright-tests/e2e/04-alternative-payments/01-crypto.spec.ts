// Cryptopay crypto payment (crypto / crypto_currency, redirect_to_url).
//
// Hermetic-capable: the SDK half (Crypto offered, confirm body, navigation to
// next_action.redirect_to_url) runs against
// recordings/04-alternative-payments/01-crypto.json, which redirects to a
// stubbed hosted-business-sandbox.cryptopay.me invoice page.
//
// Live: the payment test is a known environment failure and is marked fixme
// (reported as skipped with the reason below) rather than failing.
import {
  test,
  expect,
  paymentBody,
  connectorEnum,
  expectCheckoutTitle,
  expectConfirmRequest,
  expectPaymentElementLoaded,
  expectRedirectedTo,
  payAndCaptureConfirm,
} from "../../fixtures";

const CRYPTOPAY_NO_REDIRECT =
  "Known sandbox failure: the Cryptopay connector on sandbox never redirects to " +
  "hosted-business-sandbox.cryptopay.me/invoices, so this redirect cannot be verified live. " +
  "The SDK half is covered by the hermetic tier.";

test.describe("Cryptopay crypto payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    await checkout.open({
      body: paymentBody({
        profile_id: credentials.profileId(connectorEnum.CRYPTOPAY),
      }),
    });
  });

  test("title rendered correctly", async ({ page }) => {
    await expectCheckoutTitle(page);
  });

  test("orca-payment-element iframe loaded", async ({ page, sdk }) => {
    await expectPaymentElementLoaded(page, sdk);
  });

  test("should complete the crypto payment successfully", async ({
    page,
    sdk,
    hermetic,
  }) => {
    test.fixme(!hermetic.enabled, CRYPTOPAY_NO_REDIRECT);

    await sdk.selectPaymentMethodOrSkip("Crypto");
    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "crypto",
      payment_method_type: "crypto_currency",
      payment_method_data: { crypto: {} },
    });
    expect(confirm.request.payment_experience).toBe("redirect_to_url");
    await expectRedirectedTo(
      page,
      hermetic,
      /hosted-business-sandbox\.cryptopay\.me\/invoices/,
      confirm,
    );
  });
});
