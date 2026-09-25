// External 3DS on the Redsys profile, with and without the 3DS method
// ("3ds invoke") step, for challenge and frictionless test cards.
//
// A challenge ends on the Redsys simulator (sis-d.redsys.es), so "the SDK sent
// us to Redsys" is a waitForURL(). The simulator's own page errors (it throws
// "$ is not defined") don't fail the test.
//
// Every test runs in both tiers. Hermetic (recordings/05-external-3ds/01-redsys-3ds.json)
// answers /confirm per Redsys test card, so the SDK-side half runs for real:
//   - "3ds invoke" cards: next_action invoke_hidden_iframe -> the SDK opens the
//     fullscreen `redsys3ds` frame, POSTs the 3DS method form into
//     #threeDsAuthFrame and, once it loads, calls /complete_authorize with
//     threeds_method_comp_ind=Y; the answer is a redirect (challenge) or success.
//   - "No 3ds invoke" cards: /confirm answers redirect_to_url or success directly.
// The Redsys pages are stand-ins in hermetic mode; live reaches the real simulator.
import {
  test,
  expect,
  paymentBody,
  redsysCards,
  connectorEnum,
  DEFAULT_PAYMENT_BODY,
  expectConfirmedWith,
  type Hermetic,
} from "../../fixtures";
import { typeCard } from "./threeds-helpers";

const iframeSelector =
  "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

// Billing and shipping use the default address moved to Ceuta, Spain.
const spanishAddress = {
  ...DEFAULT_PAYMENT_BODY.shipping!.address,
  state: "Ceuta",
  country: "ES",
};

const redsysCard = ({
  cardNo,
  card_exp_month,
  card_exp_year,
  cvc,
}: (typeof redsysCards)[keyof typeof redsysCards]) => ({
  cardNo,
  expiry: card_exp_month + card_exp_year,
  cvc,
});

/** Hermetic only: /complete_authorize reported that the 3DS method iframe completed. */
const expectThreeDsMethodCompleted = async (hermetic: Hermetic) => {
  if (!hermetic.enabled) return;
  const method = await hermetic.waitForCall("redsysThreeDsMethod");
  expect(String(method?.requestBody)).toContain("threeDSMethodData=");
  const completeAuthorize = await hermetic.waitForCall("completeAuthorize");
  expect(completeAuthorize?.requestBody).toMatchObject({
    threeds_method_comp_ind: "Y",
  });
};

test.describe("External 3DS using Redsys flow test", () => {
  test.beforeEach(async ({ checkout, credentials }) => {
    // Fail fast without a Redsys profile — the intent would otherwise silently
    // fall back to Stripe. This is a config or provisioning problem (no 'redsys'
    // entry in creds.json, or its connector account failed to create), not an
    // intentional skip.
    const profileId = credentials.profileId(connectorEnum.REDSYS);
    expect(
      profileId,
      "Redsys connector profile is not provisioned — add redsys to creds.json (and check live-setup created its connector account) to run these tests.",
    ).toBeTruthy();

    await checkout.open({
      body: paymentBody({
        profile_id: profileId,
        request_external_three_ds_authentication: true,
        authentication_type: "three_ds",
        currency: "EUR",
        shipping: { ...DEFAULT_PAYMENT_BODY.shipping, address: spanishAddress },
        billing: { ...DEFAULT_PAYMENT_BODY.billing, address: spanishAddress },
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

  test("3ds invoke: challenge test", async ({ sdk, page, hermetic }) => {
    await sdk.waitForReady();
    await sdk.selectPaymentMethodOrSkip("Card");
    const card = redsysCard(redsysCards.threedsInvokeChallengeTestCard);
    await typeCard(sdk, card);
    await sdk.submit();

    // "commit": arriving on Redsys is the SDK's job; the third-party page need not finish loading.
    await page.waitForURL(/sis-d\.redsys\.es/, {
      timeout: 20_000,
      waitUntil: "commit",
    });
    await expectConfirmedWith(hermetic, card.cardNo);
    await expectThreeDsMethodCompleted(hermetic);
  });

  test("3ds invoke: frictionless flow", async ({ sdk, page, hermetic }) => {
    await sdk.waitForReady();
    await sdk.selectPaymentMethodOrSkip("Card");
    const card = redsysCard(redsysCards.threedsInvokeFrictionlessTestCard);
    await typeCard(sdk, card);
    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 16_000,
    });
    await expectConfirmedWith(hermetic, card.cardNo);
    await expectThreeDsMethodCompleted(hermetic);
  });

  test("No 3ds invoke: challenge flow", async ({ sdk, page, hermetic }) => {
    await sdk.waitForReady();
    await sdk.selectPaymentMethodOrSkip("Card");
    const card = redsysCard(redsysCards.challengeTestCard);
    await typeCard(sdk, card);
    await sdk.submit();

    await page.waitForURL(/sis-d\.redsys\.es/, {
      timeout: 10_000,
      waitUntil: "commit",
    });
    await expectConfirmedWith(hermetic, card.cardNo);
  });

  test("No 3ds invoke: frictionless flow", async ({ sdk, page, hermetic }) => {
    await sdk.waitForReady();
    await sdk.selectPaymentMethodOrSkip("Card");
    const card = redsysCard(redsysCards.frictionlessTestCard);
    await typeCard(sdk, card);
    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 10_000,
    });
    await expectConfirmedWith(hermetic, card.cardNo);
  });
});
