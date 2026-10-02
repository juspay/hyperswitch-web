// Branding Visibility Tests: the `branding` option controls the visibility of the
// "Powered by Hyperswitch" icon in the payment element. Hermetic-capable: only
// needs the SDK to render.
import { test, expect, paymentBody, type Sdk } from "../../fixtures";

/**
 * Number of `<svg>` elements in the payment element whose `<use>` points at the
 * "powerd-by-hyper" icon (href or xlink:href).
 */
async function brandingIconCount(sdk: Sdk): Promise<number> {
  return sdk.find("svg").evaluateAll(
    (svgs) =>
      svgs.filter((el) => {
        const useEl = el.querySelector("use");
        if (!useEl) return false;
        const href =
          useEl.getAttribute("href") ||
          useEl.getAttributeNS("http://www.w3.org/1999/xlink", "href") ||
          "";
        return href.includes("powerd-by-hyper");
      }).length,
  );
}

const body = paymentBody({
  customer_id: "branding_test_user",
  authentication_type: "no_three_ds",
});

test.describe("PaymentElement branding Option", () => {
  test.describe('branding: "auto" (default)', () => {
    test.beforeEach(async ({ checkout }) => {
      await checkout.open({
        body,
        options: { branding: "auto" },
        waitForReady: true,
      });
    });

    test("should display the Hyperswitch branding icon", async ({ sdk }) => {
      await expect
        .poll(() => brandingIconCount(sdk), { timeout: 10_000 })
        .toBeGreaterThan(0);
    });
  });

  test.describe('branding: "never"', () => {
    test.beforeEach(async ({ checkout }) => {
      await checkout.open({
        body,
        options: { branding: "never" },
        waitForReady: true,
      });
    });

    test("should hide the Hyperswitch branding icon", async ({ sdk }) => {
      // A single check is meaningful: the card fields are rendered by now
      // (waitForReady) and PoweredBy renders with them, so this can't pass
      // merely because the element hasn't rendered yet.
      expect(await brandingIconCount(sdk)).toBe(0);
    });
  });
});
