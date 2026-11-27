import { test, expect, CARD_FIELDS_IFRAME, testIds } from "../../fixtures";
import { CLIENT_BASE_URL, SDK_URL } from "../../fixtures/env";
import type { Page } from "@playwright/test";

declare global {
  interface Window {
    filterWidgets: { update(options: object): void; mount(selector: string): void; unmount(): void }[];
    filterReady: number[];
  }
}
const outer = (page: Page, index: number) => page.frameLocator(`#orca-payment-element-iframeRef-multi-${index}`);
const cardFields = (page: Page, index: number) => outer(page, index).locator(CARD_FIELDS_IFRAME).filter({ visible: true }).first().contentFrame();

async function mount(page: Page, clientSecret: string, publishableKey: string, options: object[], waitForIframe?: () => Promise<void>) {
  // This fixture mounts exactly one widget and works without multi-widget support.
  expect(options).toHaveLength(1);
  // Navigate to a real local document before replacing its contents. This keeps
  // Chromium's address-space policy consistent without proxying iframe assets
  // that can be cancelled when a filter removes a saved-card form.
  // Suppress the demo entry point; this document is only a local test host.
  await page.route(`${CLIENT_BASE_URL}/app.js`, route => route.fulfill({ contentType: "application/javascript", body: "" }));
  await page.route("https://fonts.googleapis.com/**", route => route.fulfill({ contentType: "text/css", body: "" }));
  await page.goto(CLIENT_BASE_URL);
  await page.setContent('<div id="multi-0" style="width:500px"></div>');
  if (waitForIframe) {
    await page.route(`${SDK_URL}/index.html?componentName=payment`, async route => {
      await waitForIframe();
      await route.continue();
    });
  }
  await page.addScriptTag({ url: `${SDK_URL}/HyperLoader.js` });
  await page.evaluate(({ clientSecret, publishableKey, options }) => {
    const elements = (window as any).Hyper(publishableKey).elements({ clientSecret });
    const widget = elements.create("payment", { displaySavedPaymentMethods: false, ...options[0] });
    window.filterWidgets = [widget];
    window.filterReady = [];
    widget.on("ready", () => window.filterReady.push(0));
    widget.mount("#multi-0");
  }, { clientSecret, publishableKey, options });
  await expect.poll(() => page.evaluate(() => window.filterReady.length), { timeout: 30_000 }).toBeGreaterThan(0);
}

test.describe("Payment method filter updates @hermetic-only", () => {
  test.afterEach(async ({ page }) => { await page.unrouteAll({ behavior: "wait" }); });
  test("updating nested types replaces the previous list and can restore the whole family", async ({ checkout, page, hermetic, credentials }) => {
    hermetic.override("clientList", route => ({
      ...route,
      body: {
        ...(route.body as object),
        payment_methods_enabled: [{ payment_method: "card", payment_method_type: "credit", payment_experience: [] }],
      },
    }));
    const { clientSecret } = await checkout.createPaymentIntent();
    await mount(page, clientSecret, credentials.publishableKey, [{ allowedPaymentMethods: [{
      paymentMethod: "card",
      paymentMethodTypes: [{ paymentMethodType: "debit" }, { paymentMethodType: "credit" }],
    }] }]);
    const cardNumber = cardFields(page, 0).getByTestId(testIds.cardNoInputTestId);
    await expect(cardNumber).toBeVisible();
    await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: [{
      paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: "debit" }],
    }] }));
    await expect(outer(page, 0).locator(CARD_FIELDS_IFRAME)).toHaveCount(0);
    await expect(outer(page, 0).getByText("Oops, something went wrong!", { exact: true })).toBeVisible();
    await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: [{ paymentMethod: "card" }] }));
    await expect(cardNumber).toBeVisible();
    await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: [{ paymentMethod: "card", paymentMethodTypes: [] }] }));
    await expect(outer(page, 0).locator(CARD_FIELDS_IFRAME)).toHaveCount(0);
    await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: null }));
    await expect(cardNumber).toBeVisible();
  });

  test("an explicit allowlist can hide card and never enables a backend-unavailable method", async ({ checkout, page, credentials }) => {
    const { clientSecret } = await checkout.createPaymentIntent();
    await mount(page, clientSecret, credentials.publishableKey, [
      { allowedPaymentMethods: [{ paymentMethod: "wallet", paymentMethodTypes: [{ paymentMethodType: "does_not_exist" }] }, { paymentMethod: "card" }] },
    ]);
    await expect(cardFields(page, 0).getByTestId(testIds.cardNoInputTestId)).toBeVisible();
    // Replacing two object entries with one must not retain the trailing card entry.
    await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: [{ paymentMethod: "wallet", paymentMethodTypes: [{ paymentMethodType: "does_not_exist" }] }] }));
    await expect(outer(page, 0).locator(CARD_FIELDS_IFRAME)).toHaveCount(0);
    await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: [] }));
    await expect(outer(page, 0).locator(CARD_FIELDS_IFRAME)).toHaveCount(0);
    await expect(outer(page, 0).getByText("Oops, something went wrong!", { exact: true })).toBeVisible();
    await expect(outer(page, 0).locator(".animate-pulse")).toHaveCount(0);
    await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: [{ paymentMethod: "card" }] }));
    await expect(cardFields(page, 0).getByTestId(testIds.cardNoInputTestId)).toBeVisible();
    await expect(outer(page, 0).getByText("Oops, something went wrong!", { exact: true })).toHaveCount(0);
  });

  test("filter updates before iframe initialization survive mounting and remounting", async ({ checkout, page, credentials }) => {
    const { clientSecret } = await checkout.createPaymentIntent();
    let release!: () => void;
    const held = new Promise<void>(resolve => { release = resolve; });
    let requested = false;
    const mounting = mount(page, clientSecret, credentials.publishableKey, [{}], async () => {
      requested = true;
      await held;
    });
    try {
      await expect.poll(() => requested).toBe(true);
      await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: [] }));
      release();
      await mounting;
      await expect(outer(page, 0).locator(CARD_FIELDS_IFRAME)).toHaveCount(0);
      await page.evaluate(() => {
        window.filterWidgets[0].unmount();
        window.filterWidgets[0].mount("#multi-0");
      });
      await expect.poll(() => page.evaluate(() => window.filterReady.length)).toBe(2);
      await expect(outer(page, 0).locator(CARD_FIELDS_IFRAME)).toHaveCount(0);
    } finally { release(); await mounting; }
  });

  test.describe("saved methods", () => {
    test.use({ hermeticFixtures: ["02-cards/07-saved-cards.json"] });
    test("filters saved cards and restores them when the filter is removed", async ({ checkout, page, credentials }) => {
      const { clientSecret } = await checkout.createPaymentIntent();
      await mount(page, clientSecret, credentials.publishableKey, [
        { displaySavedPaymentMethods: true, allowedPaymentMethods: [{ paymentMethod: "card" }] },
      ]);
      await expect(outer(page, 0).getByText("4 digit", { exact: true }).first()).toBeVisible();
      await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: [] }));
      await expect(outer(page, 0).getByText("4 digit", { exact: true })).toHaveCount(0);
      await page.evaluate(() => window.filterWidgets[0].update({ allowedPaymentMethods: null }));
      await expect(outer(page, 0).getByText("4 digit", { exact: true }).first()).toBeVisible();
    });
  });
});
