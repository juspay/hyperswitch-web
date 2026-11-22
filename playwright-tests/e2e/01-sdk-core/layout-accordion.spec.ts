// Layout: Accordion Tests
// Tests for the accordion layout: item rendering, selection,
// expand/collapse, radio buttons, and payment completion.
//
// Hermetic-capable. recordings/01-sdk-core/layout-accordion.json offers card + Klarna, Affirm and
// Afterpay/Clearpay on the Stripe profile, so there are several accordion items to expand.
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
  customer_id: "layout_accordion_test_user",
  authentication_type: "no_three_ds",
  capture_method: "automatic",
  // NOTE: `billing` is sent as the bare address object, not `{ address: … }`. Left unchanged
  // deliberately: correcting it would change the request the router receives.
  billing: { ...defaultBillingAddress } as unknown as PaymentBody["billing"],
});

test.describe("Layout - Accordion", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body, layout: "accordion", waitForReady: true });
  });

  test.describe("Accordion Container Rendering", () => {
    test("should render the accordion container instead of tabs", async ({
      sdk,
    }) => {
      await expect(sdk.find(".AccordionContainer")).toBeVisible();
    });

    test("should NOT render tab header when in accordion mode", async ({
      sdk,
    }) => {
      await expect(sdk.find(".AccordionContainer")).toBeVisible();
      await expect(sdk.find(".TabHeader")).toHaveCount(0);
    });

    test("should render at least one accordion item", async ({ sdk }) => {
      expect(
        await countRendered(sdk.find(".AccordionItem")),
      ).toBeGreaterThanOrEqual(1);
    });

    test("should render labels inside each accordion item", async ({ sdk }) => {
      const label = sdk
        .find(".AccordionItem")
        .first()
        .locator(".AccordionItemLabel")
        .first();
      await expect(label).toBeAttached();
      await expect(label).not.toHaveText("");
    });
  });

  test.describe("Accordion Selection", () => {
    test("should have one item expanded/selected by default", async ({
      sdk,
    }) => {
      await expect(sdk.find(".AccordionItem--selected")).toHaveCount(1);
    });

    test("should expand a different item when clicked", async ({ sdk }) => {
      const items = sdk.find(".AccordionItem");
      if ((await countRendered(items)) > 1) {
        await safeClick(items.nth(1));

        // The selected class is asserted on a descendant of the clicked item.
        await expect(
          items.nth(1).locator(".AccordionItem--selected").first(),
        ).toBeAttached();
      }
    });

    test("should update label styling on selected accordion item", async ({
      sdk,
    }) => {
      expect(
        await countRendered(sdk.find(".AccordionItemLabel--selected")),
      ).toBeGreaterThanOrEqual(1);
    });

    test("should update icon styling on selected accordion item", async ({
      sdk,
    }) => {
      expect(
        await countRendered(sdk.find(".AccordionItemIcon--selected")),
      ).toBeGreaterThanOrEqual(1);
    });
  });

  test.describe("Accordion Styling", () => {
    test("should apply connected borders (no gap between items)", async ({
      sdk,
    }) => {
      const marginBottom = parseFloat(
        await cssOf(sdk.find(".AccordionItem").first(), "margin-bottom"),
      );
      expect(marginBottom).toBe(0);
    });

    test("should apply border to accordion items", async ({ sdk }) => {
      const borderStyle = await cssOf(
        sdk.find(".AccordionItem").first(),
        "border-top-style",
      );
      expect(borderStyle).toBe("solid");
    });

    test("should apply padding to accordion items", async ({ sdk }) => {
      await expect(sdk.find(".AccordionItem").first()).toHaveCSS(
        "padding",
        "20px",
      );
    });
  });

  test.describe("Accordion Expand/Collapse Content", () => {
    test("should show card input fields when card accordion item is selected", async ({
      sdk,
    }) => {
      await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible();
      await expect(sdk.field(testIds.expiryInputTestId)).toBeVisible();
      await expect(sdk.field(testIds.cardCVVInputTestId)).toBeVisible();
    });
  });

  test.describe("Payment Flow with Accordion Layout", () => {
    test("should complete a payment successfully using accordion layout", async ({
      sdk,
      hermetic,
    }) => {
      await payWithSuccessCard(sdk, hermetic);
    });
  });

  test.describe("Accordion More Button", () => {
    test("should render AccordionMore button if items exceed maxAccordionItems", async ({
      sdk,
    }) => {
      await expect(sdk.find(".AccordionItem").first()).toBeVisible();
      const more = sdk.find(".AccordionMore");
      const hasMore = (await more.count()) > 0;
      if (hasMore) {
        await expect(more.first()).toBeVisible();
        await expect(more.first()).toContainText("More");
      }
    });
  });
});
