import { test, expect } from "../../fixtures/sdk-runtime";

test.beforeEach(async ({ runtimePage }) => {
  await runtimePage.route("https://fonts.googleapis.com/**", route =>
    route.fulfill({ contentType: "text/css", body: "" }),
  );
  await runtimePage.evaluate(() => {
    const hyper = window.sdkTest.makeHyper();
    const elements = hyper.elements({ clientSecret: "pay_legacy_secret_test" });
    const submissions: string[] = [];
    const mount = (id: string, type = "payment", collection = elements) => {
      const widget = collection.create(type, {});
      widget.mount(`#${id}`);
      const frame = document.querySelector<HTMLIFrameElement>(
        `#orca-payment-element-iframeRef-${id}`,
      )!;
      frame.contentWindow!.postMessage = message => {
        const data = typeof message === "string" ? JSON.parse(message) : message;
        if (!data.doSubmit) return;
        submissions.push(id);
        window.sdkTest.notifyElementMessage(id, {
          submitSuccessful: true,
          data: { status: `submitted-${id}` },
        });
      };
      window.sdkTest.notifyElementMessage(id, {
        ready: true, elementType: type, iframeId: id,
      });
      return widget;
    };
    Object.assign(window, { legacyConfirmation: { hyper, elements, submissions, mount } });
  });
});

for (const key of ["elementId", "paymentElementId", "element", "elements"]) {
  test(`single-widget hyper.confirmPayment ignores a stale ${key} @hermetic-only`, async ({ runtimePage }) => {
    const result = await runtimePage.evaluate(async key => {
      const state = (window as any).legacyConfirmation;
      state.mount("first");
      const payload = { [key]: key.endsWith("Id") ? "missing-widget" : {} };
      const response = await state.hyper.confirmPayment(payload);
      return { response, submissions: state.submissions };
    }, key);
    expect(result).toEqual({ response: { status: "submitted-first" }, submissions: ["first"] });
  });

  for (const secondType of ["payment", "expressCheckout"]) {
    test(`hyper.confirmPayment rejects ${key} with payment + ${secondType} mounted @hermetic-only`, async ({ runtimePage }) => {
      const result = await runtimePage.evaluate(async ({ key, secondType }) => {
        const state = (window as any).legacyConfirmation;
        const first = state.mount("first");
        state.mount("second", secondType);
        const reference = key.endsWith("Id") ? "first" : key === "element" ? first : state.elements;
        const response = await state.hyper.confirmPayment({ [key]: reference });
        return { response, submissions: state.submissions };
      }, { key, secondType });
      expect(result.response).toHaveProperty("error.type", "ambiguous_element");
      expect(result.response.error.message).toContain("widget.confirmPayment()");
      expect(result.submissions).toEqual([]);
    });
  }
}

test("widget confirmation remains scoped when two widgets and legacy IDs are present @hermetic-only", async ({ runtimePage }) => {
  const result = await runtimePage.evaluate(async () => {
    const state = (window as any).legacyConfirmation;
    const first = state.mount("first");
    const second = state.mount("second");
    const results = [
      await second.confirmPayment({ elementId: "first", elements: state.elements }),
      await first.confirmPayment({ paymentElementId: "second" }),
    ];
    return { results, submissions: state.submissions };
  });
  expect(result).toEqual({
    results: [{ status: "submitted-second" }, { status: "submitted-first" }],
    submissions: ["second", "first"],
  });
});

for (const cleanup of ["unmount", "destroy"]) {
  test(`hyper.confirmPayment ignores ${cleanup}ed widgets when checking legacy references @hermetic-only`, async ({ runtimePage }) => {
    const result = await runtimePage.evaluate(async cleanup => {
      const state = (window as any).legacyConfirmation;
      const removed = state.mount("first");
      state.mount("second");
      removed[cleanup]();
      const response = await state.hyper.confirmPayment({ element: removed });
      return { response, submissions: state.submissions };
    }, cleanup);
    expect(result).toEqual({ response: { status: "submitted-second" }, submissions: ["second"] });
  });
}

test("hyper.confirmPayment counts only its own mounted widgets @hermetic-only", async ({ runtimePage }) => {
  const result = await runtimePage.evaluate(async () => {
    const state = (window as any).legacyConfirmation;
    state.mount("first");
    const other = window.sdkTest.makeHyper("pk_snd_other", { isForceInit: true });
    const foreign = state.mount("second", "payment", other.elements({ clientSecret: "pay_other_secret_test" }));
    const response = await state.hyper.confirmPayment({ element: foreign });
    return { response, submissions: state.submissions };
  });
  expect(result).toEqual({ response: { status: "submitted-first" }, submissions: ["first"] });
});

test("legacy confirmation without a target still supports card fields beside express checkout @hermetic-only", async ({ runtimePage }) => {
  const result = await runtimePage.evaluate(async () => {
    const state = (window as any).legacyConfirmation;
    state.mount("first", "card");
    state.mount("second", "expressCheckout");
    const response = await state.hyper.confirmPayment({});
    return { response, submissions: state.submissions };
  });
  expect(result).toEqual({ response: { status: "submitted-first" }, submissions: ["first"] });
});
