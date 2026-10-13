// Themes / Appearance Tests
// Tests that each theme preset applies correct visual styling:
// default, midnight, charcoal, soft, brutal, bubblegum.
//
// Key architectural notes:
// - Each theme has unique styling approaches (some use background-color,
//   some use CSS gradients, some only set color/box-shadow on selected tabs).
// - Border-radius is consistently set by all themes on .Tab elements.
// - The #submit button is on the HOST page and does NOT get theme styles.
// - Theme rules are injected via <style id="themestyle"> in iframe body.
// - We focus on reliably testable properties: border-radius, existence of
//   theme stylesheet, and theme-specific visual differentiation.
//
// Hermetic-capable. recordings/01-sdk-core/themes.json gives intents on the TrustPay profile
// card + iDEAL/EPS/Giropay (see setupMultiTabAndVisit), so the non-selected-tab assertions
// have a non-selected tab; Stripe-profile intents keep the base card-only list.
//
// For the multi-tab tests (MULTI_TAB_TESTS) the describe's beforeEach opens nothing; they open the
// TrustPay checkout themselves, so each test opens only the checkout it asserts on.
import type { TestInfo } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  connectorEnum,
  defaultBillingAddress,
  type Checkout,
  type PaymentBody,
  type TestCredentials,
} from "../../fixtures";
import { countRendered, cssOf, payWithSuccessCard } from "./core-a-helpers";

/**
 * Theme preset expected border-radius values (from *Theme.res files).
 */
const themeBorderRadius: Record<string, string> = {
  default: "4px",
  midnight: "10px",
  charcoal: "10px",
  soft: "10px",
  brutal: "6px",
  bubblegum: "2px",
};

/** Opens a Stripe-profile, USD, card-only checkout with the given theme. */
const setupAndVisit = async (
  checkout: Checkout,
  credentials: TestCredentials,
  theme?: string,
) => {
  const body = paymentBody({
    customer_id: "theme_test_user",
    authentication_type: "no_three_ds",
    capture_method: "automatic",
    profile_id: credentials.profileId(connectorEnum.STRIPE),
    currency: "USD",
    // NOTE: `billing` is sent as the bare address object, not `{ address: … }`. Left unchanged
    // deliberately: correcting it would change the request the router receives.
    billing: { ...defaultBillingAddress } as unknown as PaymentBody["billing"],
  });
  await checkout.open({ body, theme, waitForReady: true });
};

// TrustPay (EUR + NL) exposes card + bank_redirect, so the SDK renders
// multiple payment-method tabs (Card selected by default). Used by the
// non-selected-tab assertions, which need at least one non-selected tab to
// exist — stripe/USD only ever surfaces a single "card" tab on integ.
const setupMultiTabAndVisit = async (
  checkout: Checkout,
  credentials: TestCredentials,
  theme?: string,
) => {
  const body = paymentBody({
    customer_id: "theme_multitab_user",
    authentication_type: "no_three_ds",
    capture_method: "automatic",
    profile_id: credentials.profileId(connectorEnum.TRUSTPAY),
    currency: "EUR",
    billing: {
      email: "theme_test@example.com",
      address: {
        ...defaultBillingAddress,
        city: "Amsterdam",
        state: "Noord-Holland",
        zip: "1011",
        country: "NL",
      },
    },
  });
  await checkout.open({ body, theme, waitForReady: true });
};

/** Tests that open the TrustPay multi-tab checkout themselves instead of the describe's default one. */
const MULTI_TAB_TESTS = new Set([
  "should apply border to non-selected tab elements",
  "should apply midnight dark background to non-selected tabs",
  "should apply charcoal light-gray background to non-selected tabs",
]);
const opensOwnCheckout = (testInfo: TestInfo) =>
  MULTI_TAB_TESTS.has(testInfo.title);

test.describe("Themes / Appearance", () => {
  test.describe("Default Theme", () => {
    test.beforeEach(async ({ checkout, credentials }, testInfo) => {
      if (!opensOwnCheckout(testInfo))
        await setupAndVisit(checkout, credentials); // No theme param = default
    });

    test("should render SDK with tabs in default theme", async ({ sdk }) => {
      expect(await countRendered(sdk.find(".Tab"))).toBeGreaterThanOrEqual(1);
    });

    test("should apply default border-radius (4px) to tab elements", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).toHaveCSS(
        "border-radius",
        themeBorderRadius.default,
      );
    });

    test("should have a selected tab with primary-colored text", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab--selected").first()).toHaveCSS(
        "color",
        "rgb(0, 109, 249)",
      );
    });

    test("should apply border to non-selected tab elements", async ({
      checkout,
      credentials,
      sdk,
    }) => {
      await setupMultiTabAndVisit(checkout, credentials);
      const borderStyle = await cssOf(
        sdk.find(".Tab:not(.Tab--selected)").first(),
        "border-top-style",
      );
      expect(borderStyle).toBe("solid");
    });

    test("should complete payment with default theme", async ({
      sdk,
      hermetic,
    }) => {
      await payWithSuccessCard(sdk, hermetic);
    });
  });

  test.describe("Midnight Theme", () => {
    test.beforeEach(async ({ checkout, credentials }, testInfo) => {
      if (!opensOwnCheckout(testInfo))
        await setupAndVisit(checkout, credentials, "midnight");
    });

    test("should apply midnight border-radius (10px) to tabs", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).toHaveCSS(
        "border-radius",
        themeBorderRadius.midnight,
      );
    });

    test("should apply midnight dark background to non-selected tabs", async ({
      checkout,
      credentials,
      sdk,
    }) => {
      await setupMultiTabAndVisit(checkout, credentials, "midnight");
      await expect(sdk.find(".Tab:not(.Tab--selected)").first()).toHaveCSS(
        "background-color",
        "rgb(48, 49, 61)",
      );
    });

    test("should apply midnight primary color as selected tab background", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab--selected").first()).toHaveCSS(
        "background-color",
        "rgb(133, 217, 150)",
      );
    });

    test("should visually differ from default theme (border-radius)", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).not.toHaveCSS(
        "border-radius",
        themeBorderRadius.default,
      );
    });

    test("should complete payment with midnight theme", async ({
      sdk,
      hermetic,
    }) => {
      await payWithSuccessCard(sdk, hermetic);
    });
  });

  test.describe("Charcoal Theme", () => {
    test.beforeEach(async ({ checkout, credentials }, testInfo) => {
      if (!opensOwnCheckout(testInfo))
        await setupAndVisit(checkout, credentials, "charcoal");
    });

    test("should apply charcoal border-radius (10px)", async ({ sdk }) => {
      await expect(sdk.find(".Tab").first()).toHaveCSS(
        "border-radius",
        themeBorderRadius.charcoal,
      );
    });

    test("should apply charcoal light-gray background to non-selected tabs", async ({
      checkout,
      credentials,
      sdk,
    }) => {
      await setupMultiTabAndVisit(checkout, credentials, "charcoal");
      await expect(sdk.find(".Tab:not(.Tab--selected)").first()).toHaveCSS(
        "background-color",
        "rgb(240, 243, 245)",
      );
    });

    test("should apply charcoal primary (black) to selected tab background", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab--selected").first()).toHaveCSS(
        "background-color",
        "rgb(0, 0, 0)",
      );
    });
  });

  test.describe("Soft Theme", () => {
    test.beforeEach(async ({ checkout, credentials }) => {
      await setupAndVisit(checkout, credentials, "soft");
    });

    test("should apply soft border-radius (10px)", async ({ sdk }) => {
      await expect(sdk.find(".Tab").first()).toHaveCSS(
        "border-radius",
        themeBorderRadius.soft,
      );
    });

    test("should apply soft styling distinct from default theme", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).not.toHaveCSS(
        "border-radius",
        "4px",
      );
    });

    test("should apply soft primary color to selected tab text", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab--selected").first()).toHaveCSS(
        "color",
        "rgb(125, 143, 255)",
      );
    });
  });

  test.describe("Brutal Theme", () => {
    test.beforeEach(async ({ checkout, credentials }) => {
      await setupAndVisit(checkout, credentials, "brutal");
    });

    test("should apply brutal border-radius (6px)", async ({ sdk }) => {
      await expect(sdk.find(".Tab").first()).toHaveCSS(
        "border-radius",
        themeBorderRadius.brutal,
      );
    });

    test("should apply brutal yellow background to selected tab", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab--selected").first()).toHaveCSS(
        "background-color",
        "rgb(245, 251, 31)",
      );
    });

    test("should have distinct visual styling from default theme", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).not.toHaveCSS(
        "border-radius",
        themeBorderRadius.default,
      );
    });
  });

  test.describe("Bubblegum Theme", () => {
    test.beforeEach(async ({ checkout, credentials }) => {
      await setupAndVisit(checkout, credentials, "bubblegum");
    });

    test("should apply bubblegum border-radius (2px)", async ({ sdk }) => {
      await expect(sdk.find(".Tab").first()).toHaveCSS(
        "border-radius",
        themeBorderRadius.bubblegum,
      );
    });

    test("should apply bubblegum pink background to selected tab", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab--selected").first()).toHaveCSS(
        "background-color",
        "rgb(243, 96, 166)",
      );
    });

    test("should have smallest border-radius of all themes", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).toHaveCSS("border-radius", "2px");
    });
  });

  test.describe("Theme Visual Differentiation", () => {
    test("should render different border-radius for each theme", async ({
      checkout,
      credentials,
      sdk,
    }) => {
      await setupAndVisit(checkout, credentials, "brutal");
      await expect(sdk.find(".Tab").first()).toHaveCSS("border-radius", "6px");
    });

    test("should render midnight theme with different styling from default", async ({
      checkout,
      credentials,
      sdk,
    }) => {
      await setupMultiTabAndVisit(checkout, credentials, "midnight");
      await expect(sdk.find(".Tab:not(.Tab--selected)").first()).toHaveCSS(
        "background-color",
        "rgb(48, 49, 61)",
      );
    });
  });
});
