import { CARD_FIELDS_IFRAME, testIds } from "../../fixtures";
import { test, expect } from "../../fixtures/react-widgets";

test.describe("React PaymentElement refs @hermetic-only", () => {
  test.skip(!process.env.REACT_HYPER_JS_PATH, "Requires the local react-hyper-js build via REACT_HYPER_JS_PATH");

  test("confirmation returns a usable error while Hyper is pending and recovers after initialization", async ({ checkout, page, openReactWidgets, hermetic }) => {
    const errors: string[] = [];
    const confirmations: string[] = [];
    page.on("pageerror", error => errors.push(error.message));
    page.on("request", request => {
      if (/\/payments\/[^/]+\/confirm(?:\?|$)/.test(request.url())) confirmations.push(request.url());
    });
    const intent = await checkout.createPaymentIntent();
    await openReactWidgets(intent.clientSecret, { deferHyper: true });
    const first = page.getByRole("form", { name: "Checkout 1", exact: true });
    const second = page.getByRole("form", { name: "Checkout 2", exact: true });
    for (const [index, form] of [first, second].entries()) {
      await form.getByRole("button", { name: `Pay checkout ${index + 1}` }).click();
      expect(errors).toEqual([]);
      await expect(form.getByRole("status")).toContainText("Hyper is not initialized yet");
    }
    expect(confirmations).toEqual([]);

    await page.evaluate(() => (window as any).resolveReactWidgetHyper());
    const fields = first.frameLocator('iframe[id^="orca-payment-element-iframeRef-"]').frameLocator(CARD_FIELDS_IFRAME);
    await expect(fields.getByTestId(testIds.cardNoInputTestId)).toBeVisible();
    await first.getByRole("button", { name: "Pay checkout 1" }).click();
    await expect(first.getByRole("status")).not.toContainText("Hyper is not initialized yet");
    await expect(first.getByRole("status")).not.toBeEmpty();
    expect(errors).toEqual([]);
    // Location data must use the hermetic routes, not the SDK server's live proxy.
    expect(hermetic.engine!.calls.some(call =>
      new URL(call.url).pathname.startsWith("/assets/v1/jsons/location/"),
    )).toBe(true);
  });

  test("each React button submits its own entered card across merchant rerenders", async ({ checkout, page, openReactWidgets }) => {
    const intent = await checkout.createPaymentIntent();
    await openReactWidgets(intent.clientSecret);
    const widgets = page.locator('[id^="orca-elements-payment-element-"]');
    await expect(widgets).toHaveCount(2);
    const ids = await widgets.evaluateAll(nodes => nodes.map(node => node.id));
    expect(new Set(ids).size).toBe(2);
    for (const id of ids) expect(id).toMatch(/^[a-zA-Z0-9_-]+$/);
    const requests: string[] = [];
    await page.route("**/payments/*/confirm", async route => {
      const cvc = route.request().postDataJSON().payment_method_data.card.card_cvc;
      requests.push(cvc);
      await route.fulfill({ status: 400, json: { error: { type: "invalid_request", message: `Declined ${cvc}` } } });
    });
    for (const index of [1, 2]) {
      const form = page.getByRole("form", { name: `Checkout ${index}`, exact: true });
      await form.getByLabel(`Read only ${index}`, { exact: true }).check();
      await form.getByLabel(`Read only ${index}`, { exact: true }).uncheck();
      await expect(form.getByRole("button", { name: `Pay checkout ${index}` })).toBeEnabled();
      const fields = form.frameLocator('iframe[id^="orca-payment-element-iframeRef-"]').frameLocator(CARD_FIELDS_IFRAME);
      await fields.getByTestId(testIds.cardNoInputTestId).pressSequentially("4242424242424242", { delay: 20 });
      await fields.getByTestId(testIds.expiryInputTestId).pressSequentially("1230", { delay: 20 });
      await fields.getByTestId(testIds.cardCVVInputTestId).pressSequentially(index === 1 ? "123" : "456", { delay: 20 });
    }
    for (const index of [1, 2]) {
      const form = page.getByRole("form", { name: `Checkout ${index}`, exact: true });
      await form.getByRole("button", { name: `Pay checkout ${index}` }).click();
      await expect(form.getByRole("status")).toContainText(`Declined ${index === 1 ? "123" : "456"}`);
    }
    expect(requests).toEqual(["123", "456"]);
    expect(await widgets.evaluateAll(nodes => nodes.map(node => node.id))).toEqual(ids);
  });

  test("two React refs confirm independently and updating one widget preserves the other form", async ({ checkout, page, openReactWidgets }) => {
    const intent = await checkout.createPaymentIntent();
    await openReactWidgets(intent.clientSecret);
    const first = page.getByRole("form", { name: "Checkout 1", exact: true });
    const second = page.getByRole("form", { name: "Checkout 2", exact: true });
    const frame = (index: number) => page.frameLocator(`[aria-label="Checkout ${index}"] iframe[id^="orca-payment-element-iframeRef-"]`);
    await expect(first.getByRole("button", { name: "Pay checkout 1" })).toBeEnabled();
    await expect(second.getByRole("button", { name: "Pay checkout 2" })).toBeEnabled();
    const secondNumber = frame(2).frameLocator(CARD_FIELDS_IFRAME).getByTestId(testIds.cardNoInputTestId);
    await secondNumber.fill("4242424242424242");
    await first.getByRole("button", { name: "Pay checkout 1" }).click();
    await expect(first.getByRole("status")).not.toBeEmpty();
    await expect(second.getByRole("status")).toBeEmpty();
    await page.getByLabel("Read only 1", { exact: true }).check();
    await expect(frame(1).getByRole("button", { name: "Card", exact: true })).toBeDisabled();
    await expect(secondNumber).toHaveValue("4242 4242 4242 4242");
    await second.getByRole("button", { name: "Pay checkout 2" }).click();
    await expect(second.getByRole("status")).not.toBeEmpty();
    await page.getByLabel("Read only 1", { exact: true }).uncheck();
    await expect(frame(1).getByRole("button", { name: "Card", exact: true })).toBeEnabled();
  });
});
