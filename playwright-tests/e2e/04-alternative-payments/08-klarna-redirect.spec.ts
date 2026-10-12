// Klarna via Stripe (pay_later / klarna, redirect_to_url).
//
// Hermetic-capable: confirm body, next_action.redirect_to_url and the redirect
// to a klarna host run on both tiers (hermetic answers from
// recordings/04-alternative-payments/08-klarna-redirect.json, which redirects to
// a stubbed pay.playground.klarna.com page). The checks on the rendered Klarna
// page are live only: hermetically they would only test the stub.
import {
  test,
  expect,
  paymentBody,
  defaultBillingAddress,
  connectorEnum,
  DEFAULT_PAYMENT_BODY,
  PAYMENT_ELEMENT_IFRAME,
  expectRedirectedTo,
  payAndCaptureConfirm,
} from "../../fixtures";

const KLARNA_EMAIL = "hyperswitch_sdk_demo_id@gmail.com";

test.describe("Klarna redirect payment flow", () => {
  test("should complete Klarna redirect flow with email", async ({
    page,
    sdk,
    hermetic,
    checkout,
    credentials,
  }) => {
    const stripeProfileId = credentials.profileId(connectorEnum.STRIPE);
    test.skip(
      !stripeProfileId,
      "Stripe was not provisioned. Cannot run Klarna test.",
    );

    const address = {
      ...defaultBillingAddress,
      country: "US",
      state: "NY",
      city: "New York",
      zip: "10001",
    };
    const orderDetails = [
      {
        ...DEFAULT_PAYMENT_BODY.order_details![0],
        tax_rate: 1900,
        total_tax_amount: 479,
      },
    ];
    const base = paymentBody();
    await checkout.open({
      body: paymentBody({
        profile_id: stripeProfileId,
        currency: "USD",
        email: KLARNA_EMAIL,
        billing: { ...base.billing, email: KLARNA_EMAIL, address },
        shipping: { ...base.shipping, address },
        order_details: orderDetails,
      }),
    });

    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await sdk.selectPaymentMethodOrSkip("Klarna");

    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expect(confirm.request.payment_method).toBe("pay_later");
    expect(confirm.request.payment_method_type).toBe("klarna");
    expect(confirm.request.payment_experience).toBe("redirect_to_url");
    expect(typeof confirm.request.payment_method_data?.pay_later).toBe(
      "object",
    );
    expect(confirm.request.payment_method_data?.pay_later).not.toBeNull();
    expect(confirm.status).toBe(200);
    expect(typeof confirm.body?.next_action?.redirect_to_url).toBe("string");

    // Verify redirect to Klarna
    await expectRedirectedTo(page, hermetic, /klarna/, confirm);

    if (!hermetic.enabled) {
      // Live only: wait for the Klarna page (a heavy JS SPA) to finish loading
      // and render some content.
      await page.waitForLoadState("load", { timeout: 30_000 });
      await expect
        .poll(() => page.evaluate(() => document.readyState), {
          timeout: 30_000,
        })
        .toBe("complete");
      await expect(page.locator("body")).not.toBeEmpty();
      await expect(page.locator("body")).not.toHaveText(/^\s*$/, {
        timeout: 30_000,
      });
    }
  });
});
