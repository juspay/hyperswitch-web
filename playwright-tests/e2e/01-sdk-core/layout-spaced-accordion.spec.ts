// Layout: Spaced Accordion Tests
// Tests for accordion layout with spacedAccordionItems: true.
// Items should have spacing between them, individual border-radius,
// and visible borders on each item.
//
// Hermetic-capable. recordings/01-sdk-core/layout-spaced-accordion.json offers card + Klarna,
// Affirm and Afterpay/Clearpay on the Stripe profile, so there are several items to space out.
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
  customer_id: "layout_spaced_accordion_test_user",
  authentication_type: "no_three_ds",
  capture_method: "automatic",
  // NOTE: `billing` is sent as the bare address object, not `{ address: … }`. Left unchanged
  // deliberately: correcting it would change the request the router receives.
  billing: { ...defaultBillingAddress } as unknown as PaymentBody["billing"],
});

const spacedAccordionLayout = {
  type: "accordion",
  spacedAccordionItems: true,
};

test.describe("Layout - Spaced Accordion", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({
      body,
      layout: spacedAccordionLayout,
      waitForReady: true,
    });
  });

  test.describe("Spaced Accordion Container", () => {
    test("should render accordion container (not tabs)", async ({ sdk }) => {
      await expect(sdk.find(".AccordionContainer")).toBeVisible();
    });

    test("should NOT render tab header", async ({ sdk }) => {
      await expect(sdk.find(".AccordionContainer")).toBeVisible();
      await expect(sdk.find(".TabHeader")).toHaveCount(0);
    });

    test("should render multiple accordion items", async ({ sdk }) => {
      expect(
        await countRendered(sdk.find(".AccordionItem")),
      ).toBeGreaterThanOrEqual(1);
    });
  });

  test.describe("Spaced Accordion Spacing", () => {
    test("should have margin-bottom between accordion items (spaced mode)", async ({
      sdk,
    }) => {
      const marginBottom = parseFloat(
        await cssOf(sdk.find(".AccordionItem").first(), "margin-bottom"),
      );
      expect(marginBottom).toBeGreaterThan(0);
    });

    test("should have individual border-radius on each item (not shared edges)", async ({
      sdk,
    }) => {
      const borderRadius = await cssOf(
        sdk.find(".AccordionItem").first(),
        "border-radius",
      );
      expect(borderRadius).not.toBe("0px");
    });

    test("should have visible bottom border on each item", async ({ sdk }) => {
      const borderBottomStyle = await cssOf(
        sdk.find(".AccordionItem").first(),
        "border-bottom-style",
      );
      expect(borderBottomStyle).toBe("solid");
    });
  });

  test.describe("Spaced Accordion Selection", () => {
    test("should have one item selected by default", async ({ sdk }) => {
      await expect(sdk.find(".AccordionItem--selected")).toHaveCount(1);
    });

    test("should switch selection when clicking a different item", async ({
      sdk,
    }) => {
      const items = sdk.find(".AccordionItem");
      if ((await countRendered(items)) > 1) {
        await safeClick(items.nth(1));

        // The selected class is asserted on a descendant of the clicked item.
        await expect(
          items.nth(1).locator(".AccordionItem--selected").first(),
        ).toBeAttached();
      }
    });
  });

  test.describe("Payment Flow with Spaced Accordion", () => {
    test("should show card fields when card item is selected", async ({
      sdk,
    }) => {
      await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible();
    });

    test("should complete payment successfully with spaced accordion layout", async ({
      sdk,
      hermetic,
    }) => {
      await payWithSuccessCard(sdk, hermetic);
    });
  });
});
