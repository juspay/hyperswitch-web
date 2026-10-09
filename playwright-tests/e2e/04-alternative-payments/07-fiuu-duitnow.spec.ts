// Fiuu DuitNow (real_time_payment / duit_now): the QR screen after confirm, and
// the error shown when the router rejects an invalid payment variant.
//
// Hermetic-capable, both tests. recordings/04-alternative-payments/07-fiuu-duitnow.json:
//   - confirm answers requires_customer_action + next_action qr_code_information,
//     which the SDK renders in the #orca-fullscreen QR screen (QRCodeDisplay.res);
//   - a confirm carrying real_time_payment.duit_now_qr gets the router's serde
//     400 ("Json deserialize error: unknown variant ..."), standing in for the
//     live router's answer to the rewritten body.
import {
  test,
  expect,
  paymentBody,
  defaultBillingAddress,
  connectorEnum,
  FULLSCREEN_IFRAME,
  PAYMENT_ELEMENT_IFRAME,
  expectConfirmRequest,
  payAndCaptureConfirm,
} from "../../fixtures";

test.describe("Fiuu DuitNow payment flow", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    const fiuuProfileId = credentials.profileId(connectorEnum.FIUU);
    expect(
      fiuuProfileId,
      "Fiuu connector credentials are missing — add fiuu to creds.json to run this test.",
    ).toBeTruthy();

    const base = paymentBody();
    await checkout.open({
      body: paymentBody({
        profile_id: fiuuProfileId,
        currency: "MYR",
        billing: {
          ...base.billing,
          address: { ...defaultBillingAddress, country: "MY" },
        },
        shipping: {
          ...base.shipping,
          address: { ...defaultBillingAddress, country: "MY" },
        },
      }),
    });
  });

  test("should display the DuitNow QR code through Fiuu", async ({
    page,
    sdk,
    hermetic,
  }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await sdk.selectPaymentMethodOrSkip("DuitNow");

    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expectConfirmRequest(confirm, {
      payment_method: "real_time_payment",
      payment_method_type: "duit_now",
      payment_method_data: { real_time_payment: { duit_now: {} } },
    });

    await expect(page.locator(FULLSCREEN_IFRAME)).toBeVisible({
      timeout: 30_000,
    });
    const fullscreen = page.frameLocator(FULLSCREEN_IFRAME);
    const qrImage = fullscreen.locator("img").first();
    await expect(qrImage).toBeVisible({ timeout: 30_000 });
    await expect(qrImage).toHaveAttribute("src", /\S/);
    await expect(fullscreen.getByText("MALAYSIA NATIONAL QR")).toBeVisible({
      timeout: 30_000,
    });
    if (hermetic.enabled) {
      // Hermetic: the screen shows exactly the image the confirm returned.
      await expect(qrImage).toHaveAttribute(
        "src",
        confirm.body.next_action.image_data_url,
      );
    }
  });

  test("should reject an invalid DuitNow QR payment variant", async ({
    page,
    sdk,
    hermetic,
  }) => {
    // Rewrite the SDK's confirm body: real_time_payment.duit_now -> duit_now_qr.
    // `fallback` (not `continue`) so the hermetic engine still answers.
    await page.route("**/payments/*/confirm", async (route) => {
      const request = route.request();
      const body =
        request.method() === "POST" ? request.postDataJSON() : undefined;
      const realTimePayment = body?.payment_method_data?.real_time_payment;
      if (realTimePayment?.duit_now) {
        realTimePayment.duit_now_qr = realTimePayment.duit_now;
        delete realTimePayment.duit_now;
        await route.fallback({ postData: JSON.stringify(body) });
        return;
      }
      await route.fallback();
    });

    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await sdk.selectPaymentMethodOrSkip("DuitNow");

    const confirm = await payAndCaptureConfirm(page, sdk, hermetic);
    expect(
      confirm.request.payment_method_data.real_time_payment,
    ).toHaveProperty("duit_now_qr");
    expect(confirm.status).toBe(400);

    await expect(
      page.getByText("Json deserialize error: unknown variant"),
    ).toBeVisible({ timeout: 15_000 });
    await expect(page.locator(FULLSCREEN_IFRAME)).toHaveCount(0);
  });
});
