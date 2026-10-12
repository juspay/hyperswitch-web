// External 3DS on the Netcetera (authentication) + Cybersource (payment) profile.
// The challenge renders inside the SDK's own fullscreen frame
// (#orca-fullscreen -> fullscreenIndex.html?fullscreenType=3dsAuth -> #threeDsAuthFrame),
// so sdk.nestedIFrame() reaches the ACS page directly.
// The live project already sends the Chromium UA override the Netcetera ACS needs.
//
// Every test runs in both tiers. Hermetic (recordings/05-external-3ds/02-netcetera-3ds.json)
// replays the router's side of the flow (three_ds_invoke, 3ds/authentication, the
// authorize page) plus a stand-in ACS page, so the SDK's 3DS-method frame, the
// 3dsAuth frame, the CReq form post into #threeDsAuthFrame and the
// openurl_if_required -> force-sync hand-off all run for real. Every outcome is
// checked twice: the demo shop's message ("Thanks for your order!" / "Payment
// failed…"), i.e. that the SDK resolved confirmPayment, and the payment status
// (the real one on live, where the challenge runs on the Netcetera NDM simulator).
import {
  test,
  expect,
  paymentBody,
  connectorEnum,
  netceteraChallengeTestCard,
  netceteraFrictionlessTestCard,
  expectConfirmedWith,
} from "../../fixtures";
import { expectThreeDsAuthenticationCalled, typeCard } from "./threeds-helpers";

test.describe("External 3DS using Netcetera Checks", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    // Fail fast if Netcetera credentials are absent — this is a config problem,
    // not an intentional skip. Add netcetera to creds.json to run these tests.
    const profileId = credentials.profileId(connectorEnum.NETCETERA);
    expect(
      profileId,
      "Netcetera connector credentials are missing — add netcetera to creds.json to run these tests.",
    ).toBeTruthy();

    await checkout.open({
      body: paymentBody({
        profile_id: profileId,
        request_external_three_ds_authentication: true,
        connector: ["cybersource"],
        authentication_type: "three_ds",
      }),
    });
  });

  test("title rendered correctly", async ({ page }) => {
    await expect(page.getByText("Hyperswitch Unified Checkout")).toBeVisible();
  });

  test("orca-payment-element iframe loaded", async ({ page }) => {
    const iframe =
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
    await expect(page.locator(iframe)).toBeVisible();
    await expect(page.frameLocator(iframe).locator("body")).toBeAttached();
  });

  test("If the user completes the challenge, the payment should be successful.", async ({
    sdk,
    page,
    api,
    checkout,
    hermetic,
  }) => {
    await sdk.waitForReady();
    // Click "Add New Card" only when saved cards are present; a fresh customer
    // has none, so the card form is shown directly.
    await sdk.clickAddNewCardIfPresent();
    await typeCard(sdk, {
      cardNo: netceteraChallengeTestCard,
      expiry: "0444",
      cvc: "1234",
    });
    await sdk.submit();

    // Wait for the fullscreen overlay to appear, then go into the nested 3DS iframe
    await expect(page.locator("#orca-fullscreen")).toBeVisible({
      timeout: 30_000,
    });
    const acs = await sdk.nestedIFrame("#threeDsAuthFrame", {
      timeout: 30_000,
    });
    // NDM Simulator: only visible text inputs (OTP field)
    const otp = acs
      .locator("input[type='text']")
      .filter({ visible: true })
      .first();
    await expect(otp).toBeVisible({ timeout: 30_000 });
    await otp.pressSequentially("1234");
    // Click the Pay button
    await acs
      .locator("button[type='submit']")
      .filter({ hasText: "Pay" })
      .first()
      .click();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });
    // Poll the payment status via API until succeeded
    await api.pollPaymentStatus(checkout.lastIntent!.paymentId, "succeeded", {
      timeoutMs: 30_000,
    });

    await expectConfirmedWith(hermetic, netceteraChallengeTestCard);
    // The challenge card comes with a 3DS method URL, so the SDK's 3DS-method frame ran first.
    await expectThreeDsAuthenticationCalled(hermetic, "Y");
  });

  test("If the user closes the challenge, the payment should fail.", async ({
    sdk,
    page,
    api,
    checkout,
  }) => {
    await sdk.waitForReady();
    await sdk.clickAddNewCardIfPresent();
    await typeCard(sdk, {
      cardNo: netceteraChallengeTestCard,
      expiry: "0444",
      cvc: "1234",
    });
    await sdk.submit();

    await expect(page.locator("#orca-fullscreen")).toBeVisible({
      timeout: 30_000,
    });
    const acs = await sdk.nestedIFrame("#threeDsAuthFrame", {
      timeout: 30_000,
    });
    // Find the Cancel button in NDM Simulator
    await acs.locator("button").filter({ hasText: "Cancel" }).first().click();

    await expect(
      page.getByText("Payment failed. Please check your payment method."),
    ).toBeVisible({ timeout: 30_000 });
    // Poll the payment status via API until it reaches "failed"
    await api.pollPaymentStatus(checkout.lastIntent!.paymentId, "failed");
  });

  test("If the user enters a frictionless card, the payment should be successful without a challenge.", async ({
    sdk,
    page,
    api,
    checkout,
    hermetic,
  }) => {
    await sdk.waitForReady();
    await sdk.clickAddNewCardIfPresent();
    await typeCard(sdk, {
      cardNo: netceteraFrictionlessTestCard,
      expiry: "0444",
      cvc: "1234",
    });
    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });
    // Poll the payment status via Retrieve Payment Intent API until succeeded
    await api.pollPaymentStatus(checkout.lastIntent!.paymentId, "succeeded", {
      timeoutMs: 30_000,
    });

    await expectConfirmedWith(hermetic, netceteraFrictionlessTestCard);
    await expectThreeDsAuthenticationCalled(hermetic, "U");
  });
});
