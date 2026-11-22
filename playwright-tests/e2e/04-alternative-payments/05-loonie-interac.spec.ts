// Interac (bank_redirect / interac) routed to GigaDat or Loonio.
//
// Hermetic-capable: the SDK half (Interac offered, confirm body, navigation to
// next_action.redirect_to_url) runs against
// recordings/04-alternative-payments/05-loonie-interac.json, whose confirm
// picks the GigaDat or Loonio redirect from the intent's `connector` list (as
// the router does) and redirects to a stubbed synthetic host.
//
// Each test opens its own checkout because the payment tests pin a different
// connector. The title and iframe tests create their intent with an empty
// `connector` list (no routing preference); it reaches the router as sent.
import {
  test,
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

const interacBody = (credentials: TestCredentials, connector: string[]) => {
  const base = paymentBody();
  return paymentBody({
    profile_id: credentials.profileId(connectorEnum.INTERAC),
    currency: "CAD",
    billing: {
      ...base.billing,
      address: { ...defaultBillingAddress, country: "CA" },
    },
    shipping: {
      ...base.shipping,
      address: { ...defaultBillingAddress, country: "CA" },
    },
    connector,
  });
};

test.describe("Interac payment flow (GigaDat and Loonio)", () => {
  test("title rendered correctly", async ({ page, checkout, credentials }) => {
    await checkout.open({ body: interacBody(credentials, []) });
    await expectCheckoutTitle(page);
  });

  test("orca-payment-element iframe loaded", async ({
    page,
    sdk,
    checkout,
    credentials,
  }) => {
    await checkout.open({ body: interacBody(credentials, []) });
    await expectPaymentElementLoaded(page, sdk);
  });

  test("should complete Interac payment via GigaDat connector", async ({
    page,
    sdk,
    hermetic,
    checkout,
    credentials,
  }) => {
    await checkout.open({ body: interacBody(credentials, ["gigadat"]) });

    await sdk.selectPaymentMethodOrSkip("Interac");
    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "bank_redirect",
      payment_method_type: "interac",
      payment_method_data: { bank_redirect: { interac: {} } },
    });
    await expectRedirectedTo(page, hermetic, /interac/, confirm);
  });

  test("should complete Interac payment via Loonio connector", async ({
    page,
    sdk,
    hermetic,
    checkout,
    credentials,
  }) => {
    await checkout.open({ body: interacBody(credentials, ["loonio"]) });

    await sdk.selectPaymentMethodOrSkip("Interac");
    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "bank_redirect",
      payment_method_type: "interac",
      payment_method_data: { bank_redirect: { interac: {} } },
    });
    await expectRedirectedTo(page, hermetic, /interac/, confirm);
  });
});
