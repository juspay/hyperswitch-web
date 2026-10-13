// Adyen AlipayHK (wallet / ali_pay_hk, redirect_to_url).
//
// Hermetic-capable: the SDK half (AlipayHK offered, confirm body, navigation
// to next_action.redirect_to_url) runs against
// recordings/04-alternative-payments/06-adyen-alipayhk.json, which redirects to
// a stubbed checkoutshopper-test.adyen.com page.
import {
  test,
  expect,
  paymentBody,
  defaultBillingAddress,
  connectorEnum,
  PAYMENT_ELEMENT_IFRAME,
  expectConfirmRequest,
  expectRedirectedTo,
  payAndCaptureConfirm,
} from "../../fixtures";

test.describe("Adyen AlipayHK payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    const adyenProfileId = credentials.profileId(connectorEnum.ADYEN);
    expect(
      adyenProfileId,
      "Adyen connector credentials are missing — add adyen to creds.json to run this test.",
    ).toBeTruthy();

    const base = paymentBody();
    await checkout.open({
      body: paymentBody({
        profile_id: adyenProfileId,
        currency: "HKD",
        billing: {
          ...base.billing,
          address: { ...defaultBillingAddress, country: "HK" },
        },
        shipping: {
          ...base.shipping,
          address: { ...defaultBillingAddress, country: "HK" },
        },
      }),
    });
  });

  // NOTE: The Adyen Acquirer Simulator page (authorised / cancelled / error /
  // refused buttons) is intermittent, so the test intentionally stops at the
  // redirect — it asserts the browser reaches the Adyen-hosted page and does
  // not interact with the simulator outcomes.
  test("should redirect to Adyen for the AlipayHK payment", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await sdk.selectPaymentMethodOrSkip("AlipayHK");

    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "wallet",
      payment_method_type: "ali_pay_hk",
      payment_method_data: { wallet: { ali_pay_hk_redirect: {} } },
    });

    await expectRedirectedTo(page, hermetic, /adyen/, confirm);
  });
});
