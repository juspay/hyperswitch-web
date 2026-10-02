// Layout: Grid Tabs Tests
// Tests for tabs layout with paymentMethodsArrangementForTabs: "grid".
// Tabs should be arranged in a CSS grid instead of a horizontal flex row.
//
// Hermetic-capable. recordings/01-sdk-core/layout-grid-tabs.json offers card + Klarna, Affirm and
// Afterpay/Clearpay on the Stripe profile, so the grid has several tabs to arrange and switch.
import {
  test,
  expect,
  testIds,
  paymentBody,
  defaultBillingAddress,
  type PaymentBody,
} from "../../fixtures";
import {
  countRendered,
  cssOf,
  payWithSuccessCard,
  safeClick,
} from "./core-a-helpers";

const body = paymentBody({
  customer_id: "layout_grid_tabs_test_user",
  authentication_type: "no_three_ds",
  capture_method: "automatic",
  // NOTE: `billing` is sent as the bare address object, not `{ address: … }`. Left unchanged
  // deliberately: correcting it would change the request the router receives.
  billing: { ...defaultBillingAddress } as unknown as PaymentBody["billing"],
});

const gridTabsLayout = {
  type: "tabs",
  paymentMethodsArrangementForTabs: "grid",
};

test.describe("Layout - Grid Tabs", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body, layout: gridTabsLayout, waitForReady: true });
  });

  test.describe("Grid Tabs Container", () => {
    test("should render tabs layout (not accordion)", async ({ sdk }) => {
      await expect(sdk.find(".TabHeader")).toBeVisible();

      await expect(sdk.find(".AccordionContainer")).toHaveCount(0);
    });

    test("should use CSS grid display on the tab header", async ({ sdk }) => {
      await expect(sdk.find(".TabHeader")).toHaveCSS("display", "grid");
    });

    test("should have grid-template-columns set for grid arrangement", async ({
      sdk,
    }) => {
      const gridCols = await cssOf(
        sdk.find(".TabHeader"),
        "grid-template-columns",
      );
      expect(gridCols).not.toBe("");
      expect(gridCols).not.toBe("none");
    });

    test("should have gap between grid items", async ({ sdk }) => {
      const gap = await cssOf(sdk.find(".TabHeader"), "gap");
      expect(gap).not.toBe("normal");
    });
  });

  test.describe("Grid Tabs Items", () => {
    test("should render tab buttons with Tab CSS class", async ({ sdk }) => {
      expect(await countRendered(sdk.find(".Tab"))).toBeGreaterThanOrEqual(1);
    });

    test("should display all payment methods without overflow dropdown", async ({
      sdk,
    }) => {
      await expect(sdk.find(".Tab").first()).toBeVisible();
      await expect(sdk.field(testIds.paymentMethodDropDownTestId)).toHaveCount(
        0,
      );
    });

    test("should have one selected tab by default", async ({ sdk }) => {
      await expect(sdk.find(".Tab--selected")).toHaveCount(1);
    });

    test("should switch selection when clicking a different grid tab", async ({
      sdk,
    }) => {
      const tabs = sdk.find(".Tab");
      if ((await countRendered(tabs)) > 1) {
        await safeClick(tabs.nth(1));

        await expect(tabs.nth(1)).toContainClass("Tab--selected");
      }
    });
  });

  test.describe("Payment Flow with Grid Tabs", () => {
    test("should show card input fields when card tab is selected", async ({
      sdk,
    }) => {
      await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible();
    });

    test("should complete payment successfully with grid tabs layout", async ({
      sdk,
      hermetic,
    }) => {
      await payWithSuccessCard(sdk, hermetic);
    });
  });
});
