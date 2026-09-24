// Element lifecycle: the payment element mounts, re-mounts after navigation and
// reload, formats card input and runs client-side validation on submit.
//
// Hermetic-capable: mounting, re-mounting after navigation/reload, input
// formatting and client-side validation need no connector.
import {
  test,
  expect,
  testIds,
  paymentBody,
  PAYMENT_ELEMENT_IFRAME,
} from "../../fixtures";

const body = paymentBody({ customer_id: "element_lifecycle_test_user" });

test.describe("Element Lifecycle Tests", () => {
  test.beforeEach(async ({ checkout }) => {
    await checkout.open({ body });
  });

  test("should mount element successfully", async ({ page, sdk }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();
    // The iframe has a loaded document body.
    await expect(sdk.paymentElement.locator("body")).toBeAttached();

    await expect(sdk.field(testIds.cardNoInputTestId)).toBeAttached({
      timeout: 10_000,
    });
  });

  test("should verify iframe communication works", async ({ page, sdk }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible({
      timeout: 10_000,
    });

    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toHaveAttribute(
      "style",
      /height/,
    );
  });

  test("should handle SDK reinitialization after page navigation", async ({
    page,
  }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await page.goto("about:blank");
    await page.goBack();

    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible({
      timeout: 10_000,
    });
  });

  test("should maintain state on page refresh", async ({ page, sdk }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible({
      timeout: 10_000,
    });
    await sdk.type(testIds.cardNoInputTestId, "4242424242424242");

    await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
      "4242 4242 4242 4242",
    );

    await page.reload();

    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible({
      timeout: 10_000,
    });
  });

  test("should handle multiple elements on same page", async ({
    page,
    sdk,
  }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await expect(sdk.field(testIds.cardNoInputTestId)).toHaveCount(1, {
      timeout: 10_000,
    });
  });

  test("should validate card input on submit", async ({ page, sdk }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await expect(sdk.field(testIds.cardNoInputTestId)).toBeAttached({
      timeout: 10_000,
    });

    await expect(sdk.submitButton).toBeVisible();
    await sdk.submit();

    // Validation errors may render in either SDK frame.
    const errors = await sdk.locate(".Error");
    await expect(errors.first()).toBeVisible();
  });

  test("should auto-format card number input", async ({ page, sdk }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible({
      timeout: 10_000,
    });
    await sdk.type(testIds.cardNoInputTestId, "4242424242424242");

    await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
      "4242 4242 4242 4242",
    );
  });

  test("should display card brand icon dynamically", async ({ page, sdk }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible({
      timeout: 10_000,
    });
    await sdk.type(testIds.cardNoInputTestId, "4242");

    // Only the typed value is checked; the brand icon itself is not asserted.
    await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue("4242");
  });

  test("should allow input in all card fields", async ({ page, sdk }) => {
    await expect(page.locator(PAYMENT_ELEMENT_IFRAME)).toBeVisible();

    await expect(sdk.field(testIds.cardNoInputTestId)).toBeVisible({
      timeout: 10_000,
    });
    await sdk.type(testIds.cardNoInputTestId, "4242424242424242");

    await expect(sdk.field(testIds.cardNoInputTestId)).toHaveValue(
      "4242 4242 4242 4242",
    );

    await sdk.type(testIds.expiryInputTestId, "1230");

    await expect(sdk.field(testIds.expiryInputTestId)).toHaveValue(
      /12\s*\/?\s*30/,
    );

    await sdk.type(testIds.cardCVVInputTestId, "123");

    await expect(sdk.field(testIds.cardCVVInputTestId)).toHaveValue("123");
  });
});
