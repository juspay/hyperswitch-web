// Card payment on the Trustpay profile: a successful no-3DS payment, a 3DS
// payment that starts the challenge, and an invalid card number.
//
// Hermetic-capable. The spec fixture (recordings/02-cards/05-card-trustpay.json)
// answers confirm on the Trustpay profile: no_three_ds -> succeeded, three_ds ->
// requires_customer_action + next_action.redirect_to_url. Live gets the real
// router and Trustpay.
import {
  test,
  expect,
  paymentBody,
  trustpayCards,
  connectorEnum,
  expectConfirmedWith,
  expectRedirectedToNextAction,
  typeCard,
  waitForConfirm,
  type TestCredentials,
} from "../../fixtures";

// Each test creates its own intent on the Trustpay profile with the given authentication type.
const body = (
  credentials: TestCredentials,
  authentication_type: "no_three_ds" | "three_ds",
) =>
  paymentBody({
    profile_id: credentials.profileId(connectorEnum.TRUSTPAY),
    authentication_type,
    customer_id: "new_customer_id",
  });

test.describe("Trustpay Card Payment flow test", () => {
  test("should complete the card payment successfully (No 3DS)", async ({
    checkout,
    credentials,
    sdk,
    page,
    hermetic,
  }) => {
    await checkout.open({ body: body(credentials, "no_three_ds") });

    await typeCard(sdk, trustpayCards.successCard);
    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });
    await expectConfirmedWith(hermetic, trustpayCards.successCard.cardNo);
  });

  test("should show the 3DS challenge page", async ({
    checkout,
    credentials,
    sdk,
    page,
    hermetic,
  }) => {
    await checkout.open({ body: body(credentials, "three_ds") });

    await typeCard(sdk, trustpayCards.threeDSCard);
    const confirm = waitForConfirm(page);
    await sdk.submit();

    // The hard assertions are that confirm succeeded and, in hermetic mode, that
    // the SDK followed next_action.redirect_to_url. The Trustpay challenge frame
    // (#tp-iframe) is only checked if it is present (the hermetic redirect page is
    // a blank stub), and only after confirm has answered and the resulting
    // navigation has settled, so the check isn't racing the click.
    expect((await confirm).ok()).toBe(true);
    await expectRedirectedToNextAction(hermetic);
    await page.waitForLoadState();
    if (
      (await page
        .locator("#tp-iframe")
        .count()
        .catch(() => 0)) > 0
    ) {
      await expect(page.locator("#tp-iframe")).toBeVisible();
    }
  });

  test("should fail with an invalid card number", async ({
    checkout,
    credentials,
    sdk,
    page,
  }) => {
    await checkout.open({ body: body(credentials, "no_three_ds") });

    await typeCard(sdk, trustpayCards.invalidCard);
    await sdk.submit();

    await expect(page.getByText("Please enter valid details")).toBeVisible({
      timeout: 10_000,
    });
  });
});
