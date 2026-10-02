// Layout: Tabs (Default) Tests
// Tests for the default tabs layout: tab rendering, selection,
// styling, overflow dropdown, and payment completion.
//
// Hermetic-capable. recordings/01-sdk-core/layout-tabs.json offers card + Klarna, Affirm and
// Afterpay/Clearpay on the Stripe profile, so the tab-switching test really switches tabs
// (on integ, Stripe/USD often surfaces a single "card" tab, and live skips that branch).
import {
  test,
  expect,
  testIds,
  paymentBody,
  defaultBillingAddress,
  type PaymentBody,
} from "../../fixtures";
import { countRendered, payWithSuccessCard, safeClick } from "./core-a-helpers";

const body = paymentBody({
  customer_id: "layout_tabs_test_user",
  authentication_type: "no_three_ds",
  capture_method: "automatic",
  // NOTE: `billing` is sent as the bare address object, not `{ address: … }`. Left unchanged
  // deliberately: correcting it would change the request the router receives.
  billing: { ...defaultBillingAddress } as unknown as PaymentBody["billing"],
});

test.describe("Layout - Tabs (Default)", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body, waitForReady: true });
  });

  test.describe("Tab Header Rendering", () => {
    test("should render the tab header container with paymentList testid", async ({
      sdk,
    }) => {
      await expect(sdk.field(testIds.paymentMethodListTestId)).toBeVisible();
    });

    test("should render tab header with TabHeader CSS class and flex-row layout", async ({
      sdk,
    }) => {
      const header = sdk.find(".TabHeader");
      await expect(header).toBeVisible();
      await expect(header).toContainClass("flex");
      await expect(header).toContainClass("flex-row");
    });

    test("should render at least one payment method tab", async ({ sdk }) => {
      expect(await countRendered(sdk.find(".Tab"))).toBeGreaterThanOrEqual(1);
    });

    test("should have exactly one selected tab by default", async ({ sdk }) => {
      await expect(sdk.find(".Tab--selected")).toHaveCount(1);
    });

    test("should render tab icons and labels inside each tab", async ({
      sdk,
    }) => {
      const firstTab = sdk.find(".Tab").first();
      await expect(firstTab.locator(".TabIcon").first()).toBeAttached();
      await expect(firstTab.locator(".TabLabel").first()).toBeAttached();
    });
  });

  test.describe("Tab Selection", () => {
    test("should highlight the selected tab with Tab--selected class", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).toContainClass("Tab--selected");
    });

    test("should switch selected tab when clicking a different tab", async ({
      sdk,
    }) => {
      const tabs = sdk.find(".Tab");
      if ((await countRendered(tabs)) > 1) {
        await safeClick(tabs.nth(1));

        await expect(tabs.nth(1)).toContainClass("Tab--selected");
        await expect(tabs.first()).not.toContainClass("Tab--selected");
      }
    });

    test("should update the selected tab label with TabLabel--selected class", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab--selected .TabLabel").first()).toContainClass(
        "TabLabel--selected",
      );
    });
  });

  test.describe("Tab Styling", () => {
    test("should apply Default theme styles to tabs (border and border-radius)", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).toHaveCSS("border-radius", "4px");
    });

    test("should apply box-shadow to the selected tab", async ({ sdk }) => {
      // Retrying assertion: the selected tab applies its box-shadow via the
      // `animate-slowShow` enter-animation, so a one-shot read can capture the
      // pre-animation `none`.
      await expect(sdk.find(".Tab--selected").first()).not.toHaveCSS(
        "box-shadow",
        "none",
      );
    });
  });

  test.describe("Payment Flow with Tabs Layout", () => {
    test("should display card input fields when card tab is selected", async ({
      sdk,
    }) => {
      await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible();
      await expect(sdk.field(testIds.expiryInputTestId)).toBeVisible();
      await expect(sdk.field(testIds.cardCVVInputTestId)).toBeVisible();
    });

    test("should complete a payment successfully using tabs layout", async ({
      sdk,
      hermetic,
    }) => {
      await payWithSuccessCard(sdk, hermetic);
    });
  });

  test.describe("Overflow Dropdown", () => {
    test("should render overflow dropdown if there are more payment methods than visible tabs", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).toBeVisible();
      const dropdown = sdk.field(testIds.paymentMethodDropDownTestId);
      const hasDropdown = (await dropdown.count()) > 0;
      if (hasDropdown) {
        await expect(dropdown).toContainClass("TabMore");
      }
    });
  });
});
