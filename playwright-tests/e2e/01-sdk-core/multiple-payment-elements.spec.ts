import { test, expect, CARD_FIELDS_IFRAME, stripeCards, testIds } from "../../fixtures";
import type { Page } from "@playwright/test";

type Widget = {
  mount(selector: string): void;
  clear(): void;
  update(options: object): void;
  destroy(): void;
  unmount(): void;
  on(event: string, handler: (data: unknown) => void): void;
  confirmPayment(options: object): Promise<Record<string, unknown>>;
};
type Widgets = { create(type: string, options: object): Widget; updateIntent(callback: () => Promise<object>): Promise<object> };
type PaymentSession = { updateIntent(callback: () => Promise<object>): Promise<object>; getCustomerSavedPaymentMethods(): Promise<object> };
declare global {
  interface Window {
    multiWidgets: Widget[];
    multiElements: Widgets;
    multiResults: Record<string, unknown>[];
    multiReady: number[];
    multiHyper: { elements(options: object): Widgets; initPaymentSession(options: object): PaymentSession; confirmPayment(options: object): Promise<Record<string, unknown>> };
    multiSession: PaymentSession;
    multiLastAuth?: string;
  }
}

const outer = (page: Page, index: number) => page.frameLocator(`#orca-payment-element-iframeRef-multi-${index}`);
const cardFields = (page: Page, index: number) => outer(page, index).locator(CARD_FIELDS_IFRAME).filter({ visible: true }).first().contentFrame();

async function waitForReady(page: Page, index: number, count = 1) {
  await expect.poll(
    () => page.evaluate(index => window.multiReady.filter(ready => ready === index).length, index),
    { timeout: 30_000, message: `Payment widget ${index + 1} should emit ready after mount` },
  ).toBeGreaterThanOrEqual(count);
}

async function remount(page: Page, index: number) {
  const nextReady = await page.evaluate(index => {
    const nextReady = window.multiReady.filter(ready => ready === index).length + 1;
    window.multiWidgets[index].unmount();
    window.multiWidgets[index].mount(`#multi-${index}`);
    return nextReady;
  }, index);
  // The replacement iframe starts at about:blank. Wait on the parent callback
  // before evaluating in its document, which is destroyed by its first navigation.
  await waitForReady(page, index, nextReady);
}

async function fillCard(page: Page, index: number, cvc: string) {
  const frame = cardFields(page, index);
  await frame.getByTestId(testIds.cardNoInputTestId).pressSequentially(stripeCards.successCard.cardNo, { delay: 20 });
  await frame.getByTestId(testIds.expiryInputTestId).pressSequentially("1230", { delay: 20 });
  await frame.getByTestId(testIds.cardCVVInputTestId).pressSequentially(cvc, { delay: 20 });
}

async function mount(page: Page, clientSecret: string | string[], options: object[] = [{}, {}]) {
  await page.evaluate(({ clientSecret, options }) => {
    document.body.style.display = "block";
    document.querySelector<HTMLElement>(".mainContainer")!.style.display = "none";
    const panel = document.createElement("div");
    panel.style.cssText = "display:flex;align-items:flex-start;gap:24px";
    document.body.append(panel);
    window.multiHyper = (window as unknown as { HyperMethod: Window["multiHyper"] }).HyperMethod;
    const collections = (Array.isArray(clientSecret) ? clientSecret : [clientSecret])
      .map(secret => window.multiHyper.elements({ clientSecret: secret }));
    window.multiElements = collections[0];
    window.multiResults = [];
    window.multiReady = [];
    window.multiWidgets = options.map((opts, index) => {
      const container = document.createElement("div");
      container.id = `multi-${index}`;
      container.style.width = "500px";
      const section = document.createElement("section");
      section.append(container);
      panel.append(section);
      const widget = (collections[index] || collections[0]).create("payment", { displaySavedPaymentMethods: false, ...opts });
      widget.on("ready", () => window.multiReady.push(index));
      widget.mount(`#multi-${index}`);
      const button = document.createElement("button");
      button.textContent = `Pay widget ${index + 1}`;
      button.onclick = async () => {
        window.multiResults[index] = await widget.confirmPayment({ confirmParams: { return_url: location.origin }, redirect: "if_required" });
      };
      section.append(button);
      return widget;
    });
  }, { clientSecret, options });
  await Promise.all(options.map((_, index) => waitForReady(page, index)));
}

test.describe("Independent PaymentElements @hermetic-only", () => {
  test.afterEach(async ({ page }) => { await page.unrouteAll({ behavior: "wait" }); });

  test("two buttons confirm only their own widget and clear is local", async ({ checkout, page }) => {
    const { clientSecret } = await checkout.open({ waitForReady: true });
    await mount(page, clientSecret);
    for (const index of [0, 1]) await expect(cardFields(page, index).getByTestId(testIds.cardNoInputTestId)).toBeVisible();
    await cardFields(page, 1).getByTestId(testIds.cardNoInputTestId).fill(stripeCards.successCard.cardNo);
    await page.evaluate(() => window.multiWidgets[0].clear());
    await expect(cardFields(page, 1).getByTestId(testIds.cardNoInputTestId)).not.toHaveValue("");

    // Invalid forms still exercise confirmation routing: only the chosen form
    // may display validation errors, and its own promise must settle.
    await page.getByRole("button", { name: "Pay widget 1", exact: true }).click();
    await expect.poll(() => page.evaluate(() => window.multiResults[0])).toHaveProperty("error");
    await expect(cardFields(page, 1).locator(".Error.pt-1")).toHaveCount(0);
    await page.getByRole("button", { name: "Pay widget 2", exact: true }).click();
    await expect.poll(() => page.evaluate(() => window.multiResults[1])).toHaveProperty("error");
  });

  test("an ambiguous collection is rejected rather than submitting both widgets", async ({ checkout, page }) => {
    const { clientSecret } = await checkout.open({ waitForReady: true });
    await mount(page, clientSecret);
    const response = await page.evaluate(() => window.multiHyper.confirmPayment({ elements: window.multiElements }));
    expect(response).toHaveProperty("error.type", "ambiguous_element");
  });

  test("separate Elements collections retain their own intent credentials", async ({ checkout, page }) => {
    const first = await checkout.open({ waitForReady: true });
    // The fixture engine stores one intent. Reuse its availability responses
    // for a second synthetic intent, while asserting the original confirm payloads.
    const second = { paymentId: "pay_second", clientSecret: "pay_second_secret_second" };
    await page.route("**/*", route => {
      const rewrite = (value: string) => value.replaceAll(second.clientSecret, first.clientSecret).replaceAll(second.paymentId, first.paymentId);
      const body = route.request().postData();
      return route.fallback({ url: rewrite(route.request().url()), ...(body ? { postData: rewrite(body) } : {}) });
    });
    await mount(page, [first.clientSecret, second.clientSecret]);
    const secrets: string[] = [];
    await page.route("**/payments/*/confirm", async route => {
      secrets.push(route.request().postDataJSON().client_secret);
      await route.fulfill({ status: 400, json: { error: { message: "Declined" } } });
    });
    for (const index of [0, 1]) {
      await fillCard(page, index, "123");
      await page.getByRole("button", { name: `Pay widget ${index + 1}`, exact: true }).click();
      await expect.poll(() => page.evaluate(index => window.multiResults[index], index)).toHaveProperty("error");
    }
    expect(secrets).toEqual([first.clientSecret, second.clientSecret]);
  });

  test("concurrent confirmations send each widget's card and settle from its own response", async ({ checkout, page }) => {
    const { clientSecret } = await checkout.open({ waitForReady: true });
    await mount(page, clientSecret);
    await fillCard(page, 0, "123");
    await fillCard(page, 1, "456");
    const requests: string[] = [];
    let releaseFirst!: () => void;
    const secondArrived = new Promise<void>(resolve => { releaseFirst = resolve; });
    await page.route("**/payments/*/confirm", async route => {
      const cvc = route.request().postDataJSON().payment_method_data.card.card_cvc;
      requests.push(cvc);
      if (cvc === "123") await secondArrived;
      await route.fulfill({ status: 400, json: { error: { type: "invalid_request", code: "declined", message: `Declined ${cvc}` } } });
      if (cvc === "456") releaseFirst();
    });
    try {
      await page.getByRole("button", { name: "Pay widget 1", exact: true }).click();
      await expect.poll(() => requests).toEqual(["123"]);
      const duplicate = await page.evaluate(() => window.multiWidgets[0].confirmPayment({}));
      expect(duplicate).toHaveProperty("error.type", "confirmation_in_progress");
      await page.getByRole("button", { name: "Pay widget 2", exact: true }).click();
      await expect.poll(() => page.evaluate(() => window.multiResults.map(result => JSON.stringify(result)))).toEqual([
        expect.stringContaining("Declined 123"), expect.stringContaining("Declined 456"),
      ]);
      expect(requests).toEqual(["123", "456"]);
    } finally { releaseFirst(); }
  });

  test("companion session updates survive remount and share refreshed credentials in both directions", async ({ checkout, page }) => {
    await page.addInitScript(() => {
      window.addEventListener("message", event => {
        let data = event.data;
        if (typeof data === "string") { try { data = JSON.parse(data); } catch { return; } }
        if (data?.paymentElementCreate) window.multiLastAuth = data.paymentOptions?.sdkAuthorization;
        if (data?.ElementsUpdate && data.sdkAuthorization) window.multiLastAuth = data.sdkAuthorization;
      });
    });
    const { clientSecret } = await checkout.open({ waitForReady: true });
    await mount(page, [clientSecret, clientSecret]);
    const result = await page.evaluate(async clientSecret => {
      window.multiSession = window.multiHyper.initPaymentSession({ clientSecret });
      return window.multiSession.updateIntent(async () => ({ sdkAuthorization: "session-refreshed-auth" }));
    }, clientSecret);
    expect(result).toHaveProperty("status", "succeeded");
    await remount(page, 0);
    await expect.poll(() => outer(page, 0).locator("body").evaluate(() => window.multiLastAuth)).toBe("session-refreshed-auth");
    const updated = await page.evaluate(() => window.multiElements.updateIntent(async () => ({ sdkAuthorization: "elements-refreshed-auth" })));
    expect(updated).toHaveProperty("status", "succeeded");
    await expect.poll(() => outer(page, 1).locator("body").evaluate(() => window.multiLastAuth)).toBe("elements-refreshed-auth");
    const request = page.waitForRequest(request => request.url().includes("/client") && Object.values(request.headers()).includes("elements-refreshed-auth"));
    await page.evaluate(() => window.multiSession.getCustomerSavedPaymentMethods());
    await request;
    await page.evaluate(clientSecret => {
      window.multiHyper.initPaymentSession({ clientSecret, sdkAuthorization: "constructor-refreshed-auth" });
    }, clientSecret);
    await remount(page, 0);
    await expect.poll(() => outer(page, 0).locator("body").evaluate(() => window.multiLastAuth)).toBe("constructor-refreshed-auth");
  });

  test("destroying a widget settles its pending confirmation and leaves its sibling usable", async ({ checkout, page }) => {
    const { clientSecret } = await checkout.open({ waitForReady: true });
    await mount(page, clientSecret);
    await fillCard(page, 0, "123");
    let release!: () => void;
    const held = new Promise<void>(resolve => { release = resolve; });
    let requested = false;
    await page.route("**/payments/*/confirm", async route => {
      requested = true;
      await held;
      await route.fulfill({ status: 400, json: { error: { message: "declined" } } });
    });
    try {
      await page.getByRole("button", { name: "Pay widget 1", exact: true }).click();
      await expect.poll(() => requested).toBe(true);
      await page.evaluate(() => window.multiWidgets[0].destroy());
      await expect.poll(() => page.evaluate(() => window.multiResults[0])).toHaveProperty("error.type", "invalid_element");
      await page.getByRole("button", { name: "Pay widget 2", exact: true }).click();
      await expect.poll(() => page.evaluate(() => window.multiResults[1])).toHaveProperty("error");
    } finally { release(); }
  });
  test("option updates before iframe initialization survive mounting and remounting", async ({ checkout, page }) => {
    const { clientSecret } = await checkout.open({ waitForReady: true });
    let release!: () => void;
    const held = new Promise<void>(resolve => { release = resolve; });
    let requested = false;
    await page.route("**/index.html?componentName=payment", async route => {
      requested = true;
      await held;
      await route.continue();
    });
    const mounting = mount(page, clientSecret, [{}]);
    try {
      await expect.poll(() => requested).toBe(true);
      await page.evaluate(() => window.multiWidgets[0].update({ readOnly: true }));
      release();
      await mounting;
      await expect(outer(page, 0).getByRole("button", { name: "Card", exact: true })).toBeDisabled();
      await page.evaluate(() => {
        window.multiWidgets[0].unmount();
        window.multiWidgets[0].mount("#multi-0");
      });
      await expect.poll(() => page.evaluate(() => window.multiReady.length)).toBe(2);
      await expect(outer(page, 0).getByRole("button", { name: "Card", exact: true })).toBeDisabled();
    } finally { release(); await mounting; }
  });

});
