// Locale / i18n in the browser.
//
// Per the testing plan this is deliberately NOT a per-locale browser loop (a checkout per locale
// would cost minutes to look for one string each). Split:
//   - locale-strings.spec.ts (browser-free, ~2 s): every per-locale expectation in
//     core-a-helpers.ts, asserted against the SDK's locale data.
//   - this file: a handful of real checkouts proving the SDK actually wires the locale through to
//     the iframes: one LTR locale (French) and one RTL locale (Arabic) end to end (labels, `dir`,
//     localized validation error, payment), the billing section header, and the English fallbacks.
//
// Hermetic-capable. The billing-header test uses recordings/01-sdk-core/locale-i18n.json (a
// Cybersource-only sdk_config with superposition raw_configs that requires billing fields).
import {
  test,
  expect,
  testIds,
  paymentBody,
  connectorEnum,
  defaultBillingAddress,
  withoutKeys,
  type PaymentBody,
  type Sdk,
} from "../../fixtures";
import {
  localeByCode,
  billingLocales,
  payWithSuccessCard,
} from "./core-a-helpers";

/** Stripe profile, USD, no 3DS, with email and billing on the intent. */
const localeBody = (locale: string) =>
  paymentBody({
    customer_id: `locale_test_${locale}`,
    authentication_type: "no_three_ds",
    capture_method: "automatic",
    currency: "USD",
    email: "hyperswitch_sdk_demo_id@gmail.com",
    // NOTE: `billing` is the bare address object, not `{ address: … }` as the payments API
    // documents. Deliberately left unchanged here so this test's request body stays stable.
    billing: { ...defaultBillingAddress } as unknown as PaymentBody["billing"],
  });

/** Expects `text` to be visible in either SDK frame. */
const expectVisibleText = async (sdk: Sdk, text: string) => {
  const el = await sdk.locate(`:text(${JSON.stringify(text)})`);
  await expect(el.first()).toBeVisible();
};

/**
 * One locale end to end: translated card labels, expiry input + floating label, `dir`,
 * the localized empty-card-number error on submit, then a successful payment.
 * The in-browser counterpart of locale-strings.spec.ts's per-locale label, error-message and
 * direction checks, plus the payment flow that has no data equivalent.
 */
const checkLocaleEndToEnd = async (
  {
    sdk,
    hermetic,
  }: { sdk: Sdk; hermetic: Parameters<typeof payWithSuccessCard>[1] },
  code: string,
) => {
  const l = localeByCode(code);

  await expect(
    sdk.page.locator(
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element",
    ),
  ).toBeVisible();
  await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible();
  await expect(sdk.submitButton).toBeVisible();

  await expectVisibleText(sdk, l.cardNumberLabel);
  await expectVisibleText(sdk, l.validThruText);
  await expectVisibleText(sdk, l.cvcTextLabel);
  await expect(sdk.field(testIds.expiryInputTestId)).toBeVisible();

  await expect(sdk.find("[dir]").first()).toHaveAttribute("dir", l.direction);

  await sdk.safeType(testIds.expiryInputTestId, "1230");
  await sdk.safeType(testIds.cardCVVInputTestId, "123");
  await sdk.submit();
  await expect(
    sdk.cardErrors.filter({ hasText: l.cardNumberEmptyText }).first(),
  ).toBeVisible();

  await payWithSuccessCard(sdk, hermetic);
};

test.describe("Locale / i18n Tests", () => {
  test("should render and pay in an LTR locale: French (fr)", async ({
    checkout,
    sdk,
    hermetic,
  }) => {
    await checkout.open({
      body: localeBody("fr"),
      locale: "fr",
      waitForReady: true,
    });
    await checkLocaleEndToEnd({ sdk, hermetic }, "fr");
  });

  test("should render and pay in an RTL locale: Arabic (ar)", async ({
    checkout,
    sdk,
    hermetic,
  }) => {
    await checkout.open({
      body: localeBody("ar"),
      locale: "ar",
      waitForReady: true,
    });
    await checkLocaleEndToEnd({ sdk, hermetic }, "ar");
  });

  test("should display translated billing details header in German (de)", async ({
    checkout,
    credentials,
    sdk,
  }) => {
    const { code, billingDetailsText } = billingLocales.find(
      (b) => b.code === "de",
    )!;
    // Cybersource returns the billing fields through required_fields only
    // when the payment intent does not already provide the contact data.
    const body = withoutKeys(
      paymentBody({
        profile_id: credentials.profileId(connectorEnum.CYBERSOURCE),
        customer_id: `locale_billing_${code}`,
        authentication_type: "no_three_ds",
      }),
      "billing",
      "email",
    );
    await checkout.open({ body, locale: code, waitForReady: true });

    // Billing fields remain owned by the outer Payment Element iframe.
    await expect(sdk.text(billingDetailsText).first()).toBeVisible();
  });

  test.describe("Locale Fallback Behaviour", () => {
    test("should fall back to English for an unsupported locale code", async ({
      checkout,
      sdk,
    }) => {
      await checkout.open({
        body: localeBody("xx-UNKNOWN"),
        locale: "xx-UNKNOWN",
        waitForReady: true,
      });

      await expectVisibleText(sdk, "Card Number");
      await expectVisibleText(sdk, "Expiry");
      await expectVisibleText(sdk, "CVC");
    });

    test("should fall back to English for empty locale string", async ({
      checkout,
      sdk,
    }) => {
      // No locale param: the SDK uses "auto" -> navigator.language (en-US here).
      await checkout.open({
        body: paymentBody({
          ...localeBody(""),
          customer_id: "locale_empty_test",
        }),
        waitForReady: true,
      });

      await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible();
      await expectVisibleText(sdk, "Card Number");
    });
  });
});
