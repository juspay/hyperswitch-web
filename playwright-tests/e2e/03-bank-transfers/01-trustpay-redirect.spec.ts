// TrustPay bank redirects (iDEAL, Blik, EPS): the method is offered, the
// confirm body names the right bank_redirect type, and the SDK navigates to
// next_action.redirect_to_url.
//
// Hermetic-capable: runs on both tiers. Hermetic confirm answers come from
// recordings/03-bank-transfers/01-trustpay-redirect.json and redirect to the
// real bank hosts (pay.ideal.nl, e.blik.com, routing.eps.or.at), where a stub
// page is served.
//
// Payment bodies: every block sends billing/shipping `state: "Noord-Holland"`,
// including Blik (PL) and EPS (AT). The SDK assertions don't depend on it (the
// confirm body checks cover only the payment method fields), but it is part of
// the intent the router receives, so changing it needs a live run first.
import {
  test,
  expect,
  paymentBody,
  defaultBillingAddress,
  connectorEnum,
  expectCheckoutTitle,
  expectConfirmRequest,
  expectPaymentElementLoaded,
  expectRedirectedTo,
  payAndCaptureConfirm,
  type TestCredentials,
} from "../../fixtures";

const trustpayBody = (
  credentials: TestCredentials,
  currency: string,
  country: string,
) => {
  const address = { ...defaultBillingAddress, country, state: "Noord-Holland" };
  const base = paymentBody();
  return paymentBody({
    profile_id: credentials.profileId(connectorEnum.TRUSTPAY),
    currency,
    billing: { ...base.billing, address },
    shipping: { ...base.shipping, address },
  });
};

test.describe("TrustPay iDEAL Bank Redirect Payment flow test", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    await checkout.open({ body: trustpayBody(credentials, "EUR", "NL") });
  });

  test("title rendered correctly", async ({ page }) => {
    await expectCheckoutTitle(page);
  });

  test("orca-payment-element iframe loaded", async ({ page, sdk }) => {
    await expectPaymentElementLoaded(page, sdk);
  });

  test("should complete the iDEAL bank redirect payment successfully", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await sdk.selectPaymentMethodOrSkip("iDEAL");
    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "bank_redirect",
      payment_method_type: "ideal",
      payment_method_data: { bank_redirect: { ideal: {} } },
    });
    await expectRedirectedTo(
      page,
      hermetic,
      /https:\/\/pay\.ideal\.nl\/transactions/,
      confirm,
    );
  });
});

test.describe("TrustPay Blik Bank Redirect Payment flow test", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    await checkout.open({ body: trustpayBody(credentials, "PLN", "PL") });
  });

  test("title rendered correctly", async ({ page }) => {
    await expectCheckoutTitle(page);
  });

  test("orca-payment-element iframe loaded", async ({ page, sdk }) => {
    await expectPaymentElementLoaded(page, sdk);
  });

  test("should complete the Blik bank redirect payment successfully", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await sdk.selectPaymentMethodOrSkip("Blik");
    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "bank_redirect",
      payment_method_type: "blik",
      payment_method_data: { bank_redirect: { blik: {} } },
    });
    await expectRedirectedTo(
      page,
      hermetic,
      /https:\/\/e\.blik\.com\/blik_web\/index\.html/,
      confirm,
    );
  });
});

test.describe("TrustPay EPS Bank Redirect Payment flow test", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    await checkout.open({ body: trustpayBody(credentials, "EUR", "AT") });
  });

  test("title rendered correctly", async ({ page }) => {
    await expectCheckoutTitle(page);
  });

  test("orca-payment-element iframe loaded", async ({ page, sdk }) => {
    await expectPaymentElementLoaded(page, sdk);
  });

  test("should complete the EPS bank redirect payment successfully", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await sdk.selectPaymentMethodOrSkip("EPS");
    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "bank_redirect",
      payment_method_type: "eps",
      payment_method_data: { bank_redirect: { eps: {} } },
    });
    await expectRedirectedTo(
      page,
      hermetic,
      /https:\/\/routing\.eps\.or\.at\/appl\/epsSO\/transinit\/bankauswahl\.htm/,
      confirm,
    );
  });
});
