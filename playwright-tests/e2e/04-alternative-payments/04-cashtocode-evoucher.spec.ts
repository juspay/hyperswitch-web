// CashtoCode E-Voucher (reward / evoucher).
//
// Hermetic-capable: the SDK half (E-Voucher offered, confirm body, navigation
// to next_action.redirect_to_url) runs against
// recordings/04-alternative-payments/04-cashtocode-evoucher.json, which
// redirects to a stubbed clusterNN.wcl-test.cashtocode.com page.
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

test.describe("CashtoCode E-Voucher payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    await checkout.open({
      body: paymentBody({
        profile_id: credentials.profileId(connectorEnum.CASHTOCODE),
        currency: "USD",
      }),
    });
  });

  test("title rendered correctly", async ({ page }) => {
    await expectCheckoutTitle(page);
  });

  test("orca-payment-element iframe loaded", async ({ page, sdk }) => {
    await expectPaymentElementLoaded(page, sdk);
  });

  test("should complete the E-voucher payment successfully", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await sdk.selectPaymentMethodOrSkip("E-Voucher");
    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    // The SDK sends payment_method_data as the bare string "reward" (PaymentBody.rewardBody).
    expectConfirmRequest(confirm, {
      payment_method: "reward",
      payment_method_type: "evoucher",
    });
    // CashtoCode now serves E-voucher from the same WCL sandbox host as the
    // Cash / Voucher flow. The cluster number is assigned per request, so match
    // the host pattern rather than a fixed cluster.
    await expectRedirectedTo(
      page,
      hermetic,
      /^https:\/\/cluster\d+\.wcl-test\.cashtocode\.com\//,
      confirm,
    );
  });
});
