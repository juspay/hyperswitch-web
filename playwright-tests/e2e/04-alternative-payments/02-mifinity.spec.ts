// Mifinity wallet: the required date-of-birth field (under-18 validation) and
// the redirect after confirm.
//
// Hermetic-capable: recordings/04-alternative-payments/02-mifinity.json offers
// Mifinity and carries a superposition config that renders the required
// date-of-birth field (so the under-18 validation runs hermetically), and its
// confirm redirects to a stubbed router /api/payments/redirect page. The check
// on the real Mifinity iframe inside that page is live only.
//
// Live: when the merchant has no Mifinity profile every test is skipped with a
// named reason rather than failing. That happens when creds.json has no mifinity
// entry (setup/merchant-setup.js never provisions it) and also when it has one
// but setup failed to create the Mifinity profile or connector account (setup
// logs "[setup] Error setting up "mifinity"" and carries on without it).
import {
  test,
  expect,
  testIds,
  paymentBody,
  connectorEnum,
  expectCheckoutTitle,
  expectConfirmRequest,
  expectPaymentElementLoaded,
  expectRedirectedTo,
  payAndCaptureConfirm,
} from "../../fixtures";

const MIFINITY_NOT_PROVISIONED =
  "Known environment failure: no mifinity profile was provisioned — either creds.json has no " +
  "mifinity entry, or live-setup failed to create its profile/connector account (see the " +
  '"[setup] Error setting up" log).';

test.describe("Mifinity wallet payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    const mifinityProfileId = credentials.profileId(connectorEnum.MIFINITY);
    test.skip(!mifinityProfileId, MIFINITY_NOT_PROVISIONED);

    await checkout.open({
      body: paymentBody({
        profile_id: mifinityProfileId,
        currency: "EUR",
        billing: {
          address: {
            line1: "1467",
            line2: "Harrison Street",
            line3: "Harrison Street",
            city: "San Francisco",
            state: "California",
            zip: "94122",
            country: "DE",
            first_name: "joseph",
            last_name: "Doe",
          },
          phone: {
            number: "8056594427",
            country_code: "+91",
          },
        },
      }),
    });
  });

  test("title rendered correctly", async ({ page }) => {
    await expectCheckoutTitle(page);
  });

  test("orca-payment-element iframe loaded", async ({ page, sdk }) => {
    await expectPaymentElementLoaded(page, sdk);
  });

  test("should fail if age is less than 18", async ({ sdk }) => {
    await sdk.selectPaymentMethodOrSkip("Mifinity");
    const today = new Date();
    const formattedDate = `${String(today.getDate()).padStart(2, "0")}-${String(
      today.getMonth() + 1,
    ).padStart(2, "0")}-${today.getFullYear()}`;
    await sdk
      .find(`input[placeholder="${testIds.datePickerPlaceHolderText}"]`)
      .pressSequentially(formattedDate);
    await sdk.submit();

    await expect(
      sdk.formErrors
        .filter({ hasText: "Age should be greater than or equal to 18 years" })
        .first(),
    ).toBeVisible();
  });

  test("should complete the mifinity payment successfully", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await sdk.selectPaymentMethodOrSkip("Mifinity");
    await sdk
      .find(`input[placeholder="${testIds.datePickerPlaceHolderText}"]`)
      .pressSequentially("30-04-2000");

    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "wallet",
      payment_method_type: "mifinity",
      payment_method_data: {
        wallet: { mifinity: { date_of_birth: "2000-04-30" } },
      },
    });

    await expectRedirectedTo(
      page,
      hermetic,
      /api\/payments\/redirect/,
      confirm,
    );
    if (!hermetic.enabled) {
      // Live only: the router's redirect page embeds the real Mifinity iframe.
      await expect(page.locator("iframe").first()).toHaveAttribute(
        "src",
        /^https:\/\/demo\.mifinity\.com\/iframe2\//,
        { timeout: 10_000 },
      );
    }
  });
});
