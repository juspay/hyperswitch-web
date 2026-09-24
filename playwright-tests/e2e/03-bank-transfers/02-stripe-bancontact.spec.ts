// Stripe Bancontact Card: a pure redirect flow (no form inputs).
//
// Hermetic-capable: confirm body + next_action.redirect_to_url + leaving the
// demo shop run on both tiers (hermetic answers from
// recordings/03-bank-transfers/02-stripe-bancontact.json, which redirects to a
// stubbed hooks.stripe.com page).
import {
  test,
  expect,
  paymentBody,
  defaultBillingAddress,
  connectorEnum,
  CLIENT_BASE_URL,
  PAYMENT_ELEMENT_IFRAME,
  expectRedirectedTo,
  payAndCaptureConfirm,
} from "../../fixtures";

test.describe("Stripe Bancontact Card payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    const stripeProfileId = credentials.profileId(connectorEnum.STRIPE);
    expect(
      stripeProfileId,
      "Stripe connector credentials are missing — add stripe to creds.json to run this test.",
    ).toBeTruthy();

    const address = {
      ...defaultBillingAddress,
      country: "BE",
      state: "Brussels",
    };
    const base = paymentBody();
    await checkout.open({
      body: paymentBody({
        profile_id: stripeProfileId,
        currency: "EUR",
        billing: { ...base.billing, address },
        shipping: { ...base.shipping, address },
      }),
    });
  });

  test("should redirect a Bancontact Card payment through Stripe", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await sdk.selectPaymentMethodOrSkip("Bancontact Card");

    // Bancontact via Stripe is a pure redirect flow. The SDK shows only an
    // InfoElement ("After submitting your order, you will be redirected...") —
    // no form inputs. It only appears once the inner paymentMethodsSDK iframe
    // has loaded; wait for it before submitting, otherwise the outer-valid
    // check fails silently.
    await expect(
      sdk.text("After submitting your order, you will be redirected").first(),
    ).toBeVisible({
      timeout: 15_000,
    });

    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);

    expect(confirm.request.payment_method).toBe("bank_redirect");
    expect(confirm.request.payment_method_type).toBe("bancontact_card");
    expect(
      confirm.request.payment_method_data?.bank_redirect?.bancontact_card,
    ).toEqual({});
    expect(confirm.status).toBe(200);
    expect(typeof confirm.body?.next_action?.redirect_to_url).toBe("string");

    // The SDK must leave the demo shop for the redirect target.
    const demoShopHost = new URL(CLIENT_BASE_URL).host;
    await page.waitForURL((url) => !url.href.includes(demoShopHost), {
      timeout: 30_000,
      waitUntil: "commit",
    });
    // Hermetic: exactly the fixture's redirect_to_url (a stubbed hooks.stripe.com page).
    if (hermetic.enabled)
      await expectRedirectedTo(page, hermetic, /hooks\.stripe\.com/, confirm);
  });
});
