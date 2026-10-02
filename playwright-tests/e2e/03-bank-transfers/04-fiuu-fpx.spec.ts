// Fiuu Online Banking FPX (bank_redirect / online_banking_fpx).
//
// Hermetic-capable: confirm body, next_action.redirect_to_url and leaving the
// demo shop run on both tiers (hermetic answers from
// recordings/03-bank-transfers/04-fiuu-fpx.json, which redirects to a stubbed
// synthetic Fiuu host). The checks on the real Fiuu page (document loaded,
// body has text) are live only: hermetically they would only test the stub.
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

test.describe("Fiuu Online Banking FPX payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    const fiuuProfileId = credentials.profileId(connectorEnum.FIUU);
    expect(
      fiuuProfileId,
      "Fiuu connector credentials are missing — add fiuu to creds.json to run this test.",
    ).toBeTruthy();

    const address = {
      ...defaultBillingAddress,
      country: "MY",
      state: "Kuala Lumpur",
    };
    const base = paymentBody();
    await checkout.open({
      body: paymentBody({
        profile_id: fiuuProfileId,
        currency: "MYR",
        billing: { ...base.billing, address },
        shipping: { ...base.shipping, address },
      }),
    });
  });

  test("should redirect an FPX payment through Fiuu", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await sdk.selectPaymentMethodOrSkip("Online Banking Fpx");

    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);

    expect(confirm.request.payment_method).toBe("bank_redirect");
    expect(confirm.request.payment_method_type).toBe("online_banking_fpx");
    expect(confirm.status).toBe(200);
    expect(typeof confirm.body?.next_action?.redirect_to_url).toBe("string");

    // The SDK must leave the demo shop for the redirect target.
    const demoShopHost = new URL(CLIENT_BASE_URL).host;
    await page.waitForURL((url) => !url.href.includes(demoShopHost), {
      timeout: 30_000,
      waitUntil: "commit",
    });
    expect(page.url()).not.toBe(`${new URL(CLIENT_BASE_URL).origin}/`);

    if (hermetic.enabled) {
      // Hermetic: exactly the fixture's redirect_to_url (stub page).
      await expectRedirectedTo(
        page,
        hermetic,
        /fiuu\.hermetic\.invalid/,
        confirm,
      );
    } else {
      // Live only: the real Fiuu page rendered.
      await page.waitForLoadState("load", { timeout: 30_000 });
      await expect
        .poll(() => page.evaluate(() => document.readyState), {
          timeout: 30_000,
        })
        .toBe("complete");
      await expect(page.locator("body")).not.toHaveText(/^\s*$/);
    }
  });
});
