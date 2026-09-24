// External 3DS on the Juspay 3DS-server profile. Like Netcetera, the challenge
// renders in the SDK's fullscreen frame (#orca-fullscreen -> #threeDsAuthFrame);
// unlike Netcetera, these tests assert the demo shop's outcome ("Thanks for your
// order!" / "Payment failed…"), i.e. that the SDK resolved confirmPayment.
//
// Skipped (with a reason) when the merchant has no Juspay profile: some creds.json
// files don't carry juspay credentials.
//
// Every test runs in both tiers. Hermetic (recordings/05-external-3ds/03-juspay-3ds.json)
// replays the router's half (three_ds_invoke, 3ds/authentication, authorize page)
// with a stand-in ACS page, so the SDK's 3dsAuth frame, the CReq post into
// #threeDsAuthFrame and the openurl_if_required -> force-sync -> confirmPayment
// hand-off run for real.
//
// "Add new card" is clicked only when saved cards are shown: a fresh customer
// has none, and the card form is then shown directly.
import {
  test,
  expect,
  paymentBody,
  connectorEnum,
  juspayChallengeTestCard,
  juspayFrictionlessTestCard,
  expectConfirmedWith,
} from "../../fixtures";
import { expectThreeDsAuthenticationCalled, typeCard } from "./threeds-helpers";

const iframeSelector =
  "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

test.describe("External 3DS using Juspay Checks", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    // Run only when the Juspay connector is configured for this merchant;
    // otherwise report the suite as skipped instead of failing.
    const profileId = credentials.profileId(connectorEnum.JUSPAY);
    test.skip(
      !profileId,
      "Juspay connector profile is not provisioned (no 'juspay' entry in creds.json) — add juspay credentials to run these tests",
    );

    await checkout.open({
      body: paymentBody({
        profile_id: profileId,
        request_external_three_ds_authentication: true,
        authentication_type: "three_ds",
      }),
    });
  });

  test("title rendered correctly", async ({ page }) => {
    await expect(page.getByText("Hyperswitch Unified Checkout")).toBeVisible();
  });

  test("orca-payment-element iframe loaded", async ({ page }) => {
    await expect(page.locator(iframeSelector)).toBeVisible();
    await expect(
      page.frameLocator(iframeSelector).locator("body"),
    ).toBeAttached();
  });

  test("If the user completes the challenge, the payment should be successful.", async ({
    sdk,
    page,
    hermetic,
  }) => {
    await sdk.waitForReady();
    await sdk.clickAddNewCardIfPresent();
    await typeCard(sdk, {
      cardNo: juspayChallengeTestCard,
      expiry: "0444",
      cvc: "1234",
    });
    await sdk.submit();

    const acs = await sdk.nestedIFrame("#threeDsAuthFrame");
    await expect(acs.locator("#otp")).toBeVisible({ timeout: 10_000 });
    await acs.locator("#otp").pressSequentially("1234");

    await acs.locator("button", { hasText: "Pay" }).first().click();
    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 15_000,
    });

    await expectConfirmedWith(hermetic, juspayChallengeTestCard);
    await expectThreeDsAuthenticationCalled(hermetic, "U");
  });

  test("If the user closes the challenge, the payment should fail.", async ({
    sdk,
    page,
  }) => {
    await sdk.waitForReady();
    await sdk.clickAddNewCardIfPresent();
    await typeCard(sdk, {
      cardNo: juspayChallengeTestCard,
      expiry: "0444",
      cvc: "1234",
    });
    await sdk.submit();

    const acs = await sdk.nestedIFrame("#threeDsAuthFrame");
    await acs
      .locator("button", { hasText: "Cancel" })
      .first()
      .click({ timeout: 10_000 });
    await expect(
      page.getByText("Payment failed. Please check your payment method."),
    ).toBeVisible({
      timeout: 10_000,
    });
  });

  test("If the user enters a frictionless card, the payment should be successful without a challenge.", async ({
    sdk,
    page,
    hermetic,
  }) => {
    await sdk.waitForReady();
    await sdk.clickAddNewCardIfPresent();
    await typeCard(sdk, {
      cardNo: juspayFrictionlessTestCard,
      expiry: "0444",
      cvc: "1234",
    });
    await sdk.submit();
    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 10_000,
    });

    await expectConfirmedWith(hermetic, juspayFrictionlessTestCard);
    await expectThreeDsAuthenticationCalled(hermetic, "U");
  });
});
