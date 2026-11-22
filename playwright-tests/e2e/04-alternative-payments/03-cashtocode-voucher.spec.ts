// CashtoCode Cash / Voucher (reward / classic).
//
// Hermetic-capable: the SDK half (Cash / Voucher offered, confirm body,
// navigation to next_action.redirect_to_url) runs against
// recordings/04-alternative-payments/03-cashtocode-voucher.json, which
// redirects to a stubbed cluster05.wcl-test.cashtocode.com page. CashtoCode is
// a redirect (the SDK's display_voucher_information screen is not involved).
import {
  test,
  paymentBody,
  connectorEnum,
  expectCheckoutTitle,
  expectConfirmRequest,
  expectPaymentElementLoaded,
  expectRedirectedTo,
  payAndCaptureConfirm,
} from "../../fixtures";

test.describe("CashtoCode Cash / Voucher payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    await checkout.open({
      body: paymentBody({
        profile_id: credentials.profileId(connectorEnum.CASHTOCODE),
        currency: "EUR",
      }),
    });
  });

  test("title rendered correctly", async ({ page }) => {
    await expectCheckoutTitle(page);
  });

  test("orca-payment-element iframe loaded", async ({ page, sdk }) => {
    await expectPaymentElementLoaded(page, sdk);
  });

  test("should complete the Cash / Voucher payment successfully", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await sdk.selectPaymentMethodOrSkip("Cash / Voucher");
    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    // The SDK sends payment_method_data as the bare string "reward" (PaymentBody.rewardBody).
    expectConfirmRequest(confirm, {
      payment_method: "reward",
      payment_method_type: "classic",
    });
    await expectRedirectedTo(
      page,
      hermetic,
      /https:\/\/cluster05\.wcl-test\.cashtocode\.com\//,
      confirm,
    );
  });
});
