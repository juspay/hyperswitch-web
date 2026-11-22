// Card payment on the Bank of America profile: a successful no-3DS payment
// (filling any required billing field the SDK renders) and an invalid card number.
//
// Hermetic-capable: the SDK renders and confirms the same way whatever the
// connector. In the hermetic tier the spec fixture
// (recordings/02-cards/06-card-bank-of-america.json) answers confirm on the
// Bank of America profile with a succeeded payment; live checks the real connector.
import {
  test,
  expect,
  paymentBody,
  bankOfAmericaCards,
  connectorEnum,
  testIds,
  expectConfirmedWith,
  typeCard,
  type TestCredentials,
} from "../../fixtures";

// Each test creates its own intent: Bank of America profile, no 3DS.
const body = (credentials: TestCredentials) =>
  paymentBody({
    profile_id: credentials.profileId(connectorEnum.BANK_OF_AMERICA),
    authentication_type: "no_three_ds",
    customer_id: "new_customer_id",
  });

test.describe("Bank of America Card Payment flow test", () => {
  test("should complete the card payment successfully (No 3DS)", async ({
    checkout,
    credentials,
    sdk,
    page,
    hermetic,
  }) => {
    await checkout.open({ body: body(credentials) });

    await typeCard(sdk, bankOfAmericaCards.successCard);

    // Bank of America requires billing details; fill whichever dynamic billing
    // fields the SDK renders before submitting (commonly just the email field).
    // The payment body already carries billing.email, so the field is usually
    // absent (always absent in the hermetic tier: base sdk_config has no
    // required fields). Checked once, after the card details are typed, so the
    // dynamic fields have rendered by then.
    const email = sdk.field(testIds.emailInputTestId);
    if ((await email.count()) > 0) {
      await email.pressSequentially("hyperswitch_sdk_demo_id@gmail.com");
    }

    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });
    await expectConfirmedWith(hermetic, bankOfAmericaCards.successCard.cardNo);
  });

  test("should fail with an invalid card number", async ({
    checkout,
    credentials,
    sdk,
    page,
  }) => {
    await checkout.open({ body: body(credentials) });

    await typeCard(sdk, bankOfAmericaCards.invalidCard);
    await sdk.submit();

    await expect(page.getByText("Please enter valid details")).toBeVisible({
      timeout: 10_000,
    });
  });
});
