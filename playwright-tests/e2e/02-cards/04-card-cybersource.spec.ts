// Card payment on the Cybersource profile: a successful no-3DS payment and an
// invalid card number.
//
// Hermetic-capable: the SDK renders and confirms the same way whatever the
// connector. In the hermetic tier the spec fixture
// (recordings/02-cards/04-card-cybersource.json) answers confirm on the
// Cybersource profile with a succeeded payment; live checks the real connector.
import {
  test,
  expect,
  paymentBody,
  cybersourceCards,
  connectorEnum,
  expectConfirmedWith,
  typeCard,
  type TestCredentials,
} from "../../fixtures";

// Each test creates its own intent: Cybersource profile, no 3DS.
const body = (credentials: TestCredentials) =>
  paymentBody({
    profile_id: credentials.profileId(connectorEnum.CYBERSOURCE),
    authentication_type: "no_three_ds",
    customer_id: "new_customer_id",
  });

test.describe("Cybersource Card Payment flow test", () => {
  test("should complete the card payment successfully (No 3DS)", async ({
    checkout,
    credentials,
    sdk,
    page,
    hermetic,
  }) => {
    await checkout.open({ body: body(credentials) });

    await typeCard(sdk, cybersourceCards.successCard);
    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });
    await expectConfirmedWith(hermetic, cybersourceCards.successCard.cardNo);
  });

  test("should fail with an invalid card number", async ({
    checkout,
    credentials,
    sdk,
    page,
  }) => {
    await checkout.open({ body: body(credentials) });

    await typeCard(sdk, cybersourceCards.invalidCard);
    await sdk.submit();

    await expect(page.getByText("Please enter valid details")).toBeVisible({
      timeout: 10_000,
    });
  });
});
