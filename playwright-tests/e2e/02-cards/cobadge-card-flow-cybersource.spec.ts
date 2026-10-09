// Cobadge Card Flow - Cybersource
// Tests the cobadge (multi-brand) card flow where a single card number
// matches multiple card networks (e.g., Visa + CartesBancaires).
//
// Flow:
// 1. Enter a cobadge card number (4010061700000021) that matches both Visa and CartesBancaires
// 2. Verify the card brand dropdown appears with both options
// 3. Select a brand from the dropdown
// 4. Complete the payment with the selected brand
//
// DOM structure of the cobadge dropdown:
// - It's a native <select> inside a div with class "hellow-rodl"
// - Options: disabled "Select a card brand", then brand names (e.g., "Visa", "CartesBancaires")
// - Dropdown only appears when card number >= 16 digits AND matches multiple brands
//
// Hermetic: recordings/02-cards/cobadge-card-flow-cybersource.json enables
// CartesBancaires on the Cybersource profile so the dropdown renders.
//
// The brand is chosen with selectOption() directly on the native <select>.
import {
  test,
  expect,
  testIds,
  paymentBody,
  cobadgeCards,
  cobadgeCardBrands,
  connectorEnum,
  expectConfirmedWith,
  type Sdk,
} from "../../fixtures";

const { cardNo, card_exp_month, card_exp_year, cvc } =
  cobadgeCards.visaCartesBancaires;

/** The co-badge brand <select> (in the card-number field, i.e. the card iframe). */
const brandSelect = (sdk: Sdk) =>
  sdk.locate(".hellow-rodl select", { timeout: 10_000 });

test.describe("Cobadge Card Flow - Cybersource", () => {
  test.beforeEach(async ({ checkout, sdk, credentials }) => {
    await checkout.open({
      body: paymentBody({
        profile_id: credentials.profileId(connectorEnum.CYBERSOURCE),
        authentication_type: "no_three_ds",
        customer_id: `cobadge_test_${Date.now()}`,
      }),
    });

    await sdk.waitForReady();
  });

  test("should display card brand dropdown for cobadge card (Visa + CartesBancaires)", async ({
    sdk,
  }) => {
    await sdk.safeType(testIds.cardNoInputTestId, cardNo);

    const select = await brandSelect(sdk);
    await expect(select).toBeAttached({ timeout: 10_000 });

    const options = select.locator("option");
    // disabled placeholder + at least 2 brands
    await expect.poll(() => options.count()).toBeGreaterThanOrEqual(3);
    const optionTexts = await options.allTextContents();
    expect(optionTexts).toContain(cobadgeCardBrands.VISA);
    expect(optionTexts).toContain(cobadgeCardBrands.CARTES_BANCAIRES);

    await expect(select.locator("option:disabled")).toContainText(
      "Select a card brand",
    );
  });

  test("should allow selecting Visa from cobadge dropdown", async ({ sdk }) => {
    await sdk.safeType(testIds.cardNoInputTestId, cardNo);

    const select = await brandSelect(sdk);
    await select.selectOption(cobadgeCardBrands.VISA);

    await expect(select).toHaveValue(cobadgeCardBrands.VISA);
  });

  test("should allow switching between Visa and CartesBancaires brands", async ({
    sdk,
  }) => {
    await sdk.safeType(testIds.cardNoInputTestId, cardNo);

    const select = await brandSelect(sdk);
    await select.selectOption(cobadgeCardBrands.VISA);

    await expect(select).toHaveValue(cobadgeCardBrands.VISA);

    await select.selectOption(cobadgeCardBrands.CARTES_BANCAIRES);

    await expect(select).toHaveValue(cobadgeCardBrands.CARTES_BANCAIRES);
  });

  test("should complete payment with selected cobadge card brand (Visa)", async ({
    sdk,
    page,
    hermetic,
  }) => {
    await sdk.safeType(testIds.cardNoInputTestId, cardNo);

    const select = await brandSelect(sdk);
    await select.selectOption(cobadgeCardBrands.VISA);

    await expect(select).toHaveValue(cobadgeCardBrands.VISA);

    await sdk.safeType(
      testIds.expiryInputTestId,
      card_exp_month + card_exp_year,
    );
    await sdk.safeType(testIds.cardCVVInputTestId, cvc);

    await expect(sdk.submitButton).toBeVisible();
    await sdk.submit();

    await expect(page.getByText("Thanks for your order!")).toBeVisible({
      timeout: 30_000,
    });

    // Hermetic only: the co-badged card went to /confirm with the network the user picked.
    await expectConfirmedWith(
      hermetic,
      cardNo,
      `"card_network":"${cobadgeCardBrands.VISA}"`,
    );
  });
});
