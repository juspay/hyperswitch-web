import { test, expect } from "../../fixtures/sdk-runtime";
import type { Page } from "@playwright/test";

// Real Hyper factories, registry, readiness and routing; only the iframe response
// is simulated so these checks cannot bypass the public confirmation path.
async function runScenario(page: Page, scenario: string): Promise<any> {
  await page.route("https://fonts.googleapis.com/**", (route) =>
    route.fulfill({ contentType: "text/css", body: "" }),
  );
  return page.evaluate(async (scenario) => {
    const hyper = window.sdkTest.makeHyper();
    const outgoing: Record<string, any>[] = [];
    const send = (frame: HTMLIFrameElement, data: Record<string, unknown>) =>
      window.dispatchEvent(
        new MessageEvent("message", {
          source: frame.contentWindow,
          origin: new URL(frame.src).origin,
          data,
        }),
      );
    const hook = (frame: HTMLIFrameElement) => {
      const source = frame.contentWindow!,
        origin = new URL(frame.src).origin;
      source.postMessage = (message) => {
        const data =
          typeof message === "string" ? JSON.parse(message) : message;
        outgoing.push(data);
        if (data.doSubmit)
          window.dispatchEvent(
            new MessageEvent("message", {
              source,
              origin,
              data: {
                submitSuccessful: true,
                data: { status: "probe_submitted" },
              },
            }),
          );
      };
    };
    const mount = (
      widget: { mount: (selector: string) => void },
      management = false,
    ) => {
      widget.mount("#first");
      const frame = document.querySelector<HTMLIFrameElement>(
        management
          ? "#orca-payment-methods-management-element-iframeRef-first"
          : "#orca-payment-element-iframeRef-first",
      );
      if (!frame) throw new Error("No mounted iframe");
      hook(frame);
      return frame;
    };
    if (scenario === "management") {
      const collection = hyper.paymentMethodsManagementElements({
        sdkAuthorization: btoa(
          "payment_method_session_id=pms_review,customer_id=cus_review,publishable_key=pk_snd_review",
        ),
      });
      const widget = collection.create("paymentMethodsManagement", {});
      const frame = mount(widget, true);
      send(frame, {
        ready: true,
        elementType: "paymentMethodsManagement",
        iframeId: "first",
      });
      const collectionResult = await hyper.confirmTokenization({
        elements: collection,
      });
      const copyResult = await hyper.confirmTokenization({
        elements: { ...collection },
      });
      const widgetResult = await hyper.confirmTokenization({ element: widget });
      return {
        collectionResult,
        copyResult,
        widgetResult,
        submits: outgoing.filter((x) => x.doSubmit).length,
      };
    }
    const elements = hyper.elements({
      clientSecret: "pay_review_secret_review",
    });
    const callbacks = elements.create("payment", {});
    const mounted = elements.create("payment", {});
    let frame = mount(mounted);
    const calls = { ready: 0, change: 0, complete: 0, click: 0 };
    const register = () => {
      callbacks.on("ready", () => calls.ready++);
      callbacks.on("change", () => calls.change++);
      callbacks.on("completeDoThis", () => calls.complete++);
      callbacks.onSDKHandleClick(async () => {
        calls.click++;
      });
    };
    register();
    const emit = async () => {
      send(frame, { ready: true, elementType: "payment", iframeId: "first" });
      send(frame, {
        value: "changed",
        elementType: "payment",
        iframeId: "first",
      });
      send(frame, {
        paymentComplete: true,
        elementType: "payment",
        iframeId: "first",
      });
      send(frame, {
        oneClickConfirmTriggered: true,
        elementType: "payment",
        iframeId: "first",
      });
      await Promise.resolve();
      await Promise.resolve();
    };
    await emit();
    if (scenario === "imperative") {
      const newer = elements.create("payment", {});
      const fetched = elements.getElement("payment");
      const checks = [];
      for (const [name, handle] of [
        ["getElement", fetched],
        ["paired-callback", callbacks],
        ["mounted", mounted],
      ]) {
        outgoing.length = 0;
        handle.clear();
        handle.focus();
        handle.blur();
        handle.update({ readOnly: true });
        const result = await handle.confirmPayment({});
        checks.push({
          name,
          result,
          commands: outgoing.flatMap((x) =>
            [
              "doClearValues",
              "doFocus",
              "doBlur",
              "paymentElementsUpdate",
              "doSubmit",
            ].filter((key) => x[key]),
          ),
        });
      }
      return { getElementIsUnmounted: fetched === newer, checks };
    }
    const before = { ...calls };
    if (scenario === "unmount-replace" || scenario === "same-handle")
      mounted.unmount();
    if (scenario === "destroy-replace") mounted.destroy();
    const replacement =
      scenario === "same-handle" ? mounted : elements.create("payment", {});
    frame = mount(replacement);
    if (scenario !== "replace-without-registration") register();
    outgoing.length = 0;
    send(frame, { iframeMounted: true });
    await emit();
    return {
      before,
      after: { ...calls },
      flags: outgoing
        .filter((x) => x.paymentElementCreate)
        .map((x) => ({
          button: x.isPaymentButtonHandlerProvided,
          complete: x.isPaymentCompleteHandlerProvided,
        })),
      connected: frame.isConnected,
    };
  }, scenario);
}

test("management collections and context copies confirm through their own mounted widget @hermetic-only", async ({
  runtimePage,
}) => {
  const result = await runScenario(runtimePage, "management");
  expect(result).toEqual({
    collectionResult: { status: "probe_submitted" },
    copyResult: { status: "probe_submitted" },
    widgetResult: { status: "probe_submitted" },
    submits: 3,
  });
});

for (const scenario of [
  "replace",
  "replace-without-registration",
  "unmount-replace",
  "destroy-replace",
  "same-handle",
]) {
  test(`legacy callbacks follow a mount in the same container: ${scenario} @hermetic-only`, async ({
    runtimePage,
  }) => {
    const result = await runScenario(runtimePage, scenario);
    expect(result).toEqual({
      before: { ready: 1, change: 2, complete: 1, click: 1 },
      after: { ready: 2, change: 4, complete: 2, click: 2 },
      flags: [{ button: true, complete: true }],
      connected: true,
    });
  });
}

test("getElement and paired legacy handles preserve imperative operations after a render-only create @hermetic-only", async ({
  runtimePage,
}) => {
  const result = await runScenario(runtimePage, "imperative");
  expect(result.getElementIsUnmounted).toBe(false);
  expect(result.checks).toEqual(
    ["getElement", "paired-callback", "mounted"].map((name) => ({
      name,
      result: { status: "probe_submitted" },
      commands: [
        "doClearValues",
        "doFocus",
        "doBlur",
        "paymentElementsUpdate",
        "doSubmit",
      ],
    })),
  );
});

for (const management of [false, true]) {
  test(`getElement keeps a live owner when newer handles are unmounted or destroyed (management: ${management}) @hermetic-only`, async ({
    runtimePage,
  }) => {
    const result = await runtimePage.evaluate((management) => {
      const collection = management
        ? window.sdkTest.makeManagementElements()
        : window.sdkTest.makeElements().elements;
      const type = management ? "paymentMethodsManagement" : "payment";
      const first = collection.create(type, {});
      first.mount("#first");
      const second = collection.create(type, {});
      second.mount("#second");
      collection.create(type, {}).on("ready", () => {});
      const before = collection.getElement(type) === second;
      second.destroy();
      return { before, after: collection.getElement(type) === first };
    }, management);
    expect(result).toEqual({ before: true, after: true });
  });
}

test("stale callbacks reject other containers and still follow the same handle after an unmounted interval @hermetic-only", async ({
  runtimePage,
}) => {
  const calls = await runtimePage.evaluate(() => {
    const { elements } = window.sdkTest.makeElements();
    const callbacks = elements.create("payment", {});
    const mounted = elements.create("payment", {});
    let calls = 0;
    callbacks.on("ready", () => calls++);
    mounted.mount("#first");
    const old = document.querySelector<HTMLIFrameElement>(
      "#orca-payment-element-iframeRef-first",
    )!;
    const source = old.contentWindow;
    const origin = new URL(old.src).origin;
    window.sdkTest.notifyElementMessage("first", {
      ready: true,
      elementType: "payment",
      iframeId: "first",
    });
    mounted.unmount();
    window.dispatchEvent(
      new MessageEvent("message", {
        source,
        origin,
        data: { ready: true, elementType: "payment", iframeId: "first" },
      }),
    );
    const neighbor = elements.create("payment", {});
    neighbor.mount("#second");
    window.sdkTest.notifyElementMessage("second", {
      ready: true,
      elementType: "payment",
      iframeId: "second",
    });
    const container = document.createElement("div");
    container.id = "third";
    document.body.append(container);
    mounted.mount("#third");
    window.sdkTest.notifyElementMessage("third", {
      ready: true,
      elementType: "payment",
      iframeId: "third",
    });
    window.sdkTest.notifyElementMessage("second", {
      ready: true,
      elementType: "payment",
      iframeId: "second",
    });
    return calls;
  });
  expect(calls).toBe(2);
});

test("a replacement from another collection cannot acquire legacy callbacks @hermetic-only", async ({
  runtimePage,
}) => {
  const calls = await runtimePage.evaluate(() => {
    const { elements } = window.sdkTest.makeElements();
    const callbacks = elements.create("payment", {});
    let calls = 0;
    callbacks.on("ready", () => calls++);
    const mounted = elements.create("payment", {});
    mounted.mount("#first");
    window.sdkTest.notifyElementMessage("first", {
      ready: true,
      elementType: "payment",
      iframeId: "first",
    });
    mounted.destroy();
    const foreign = window.sdkTest
      .makeElements()
      .elements.create("payment", {});
    foreign.mount("#first");
    callbacks.on("ready", () => calls++);
    window.sdkTest.notifyElementMessage("first", {
      ready: true,
      elementType: "payment",
      iframeId: "first",
    });
    foreign.destroy();
    elements.create("payment", {}).mount("#first");
    window.sdkTest.notifyElementMessage("first", {
      ready: true,
      elementType: "payment",
      iframeId: "first",
    });
    return calls;
  });
  expect(calls).toBe(2);
});

test("an unmounted callback alias cannot confirm or control its former widget @hermetic-only", async ({
  runtimePage,
}) => {
  await runtimePage.route("https://fonts.googleapis.com/**", (route) =>
    route.fulfill({ contentType: "text/css", body: "" }),
  );
  const result = await runtimePage.evaluate(async () => {
    const hyper = window.sdkTest.makeHyper();
    const elements = hyper.elements({
      clientSecret: "pay_review_secret_review",
    });
    const mounted = elements.create("payment", {});
    mounted.mount("#first");
    const alias = elements.create("payment", {});
    alias.on("ready", () => {});
    alias.unmount();
    const frame = document.querySelector<HTMLIFrameElement>(
      "#orca-payment-element-iframeRef-first",
    )!;
    const commands: unknown[] = [];
    frame.contentWindow!.postMessage = (data) => commands.push(data);
    alias.clear();
    alias.focus();
    const response = await alias.confirmPayment({});
    return {
      commands,
      error: response.error.type,
      connected: frame.isConnected,
    };
  });
  expect(result).toEqual({
    commands: [],
    error: "invalid_element",
    connected: true,
  });
});

test("management confirmation targets stay live and cannot cross Hyper owners @hermetic-only", async ({
  runtimePage,
}) => {
  await runtimePage.route("https://fonts.googleapis.com/**", (route) =>
    route.fulfill({ contentType: "text/css", body: "" }),
  );
  const result = await runtimePage.evaluate(async () => {
    const hyper = window.sdkTest.makeHyper();
    const otherHyper = window.sdkTest.makeHyper("pk_snd_other", {
      isForceInit: true,
    });
    const options = {
      sdkAuthorization: btoa(
        "payment_method_session_id=pms_review,publishable_key=pk_snd_review",
      ),
    };
    const first = hyper.paymentMethodsManagementElements(options);
    const second = hyper.paymentMethodsManagementElements(options);
    const deliveries: string[] = [];
    const mount = (collection: typeof first, id: string) => {
      const widget = collection.create("paymentMethodsManagement", {});
      widget.mount(`#${id}`);
      const frame = document.querySelector<HTMLIFrameElement>(
        `#orca-payment-methods-management-element-iframeRef-${id}`,
      )!;
      const source = frame.contentWindow;
      const origin = new URL(frame.src).origin;
      source!.postMessage = (payload) => {
        const data = JSON.parse(payload);
        if (data.doSubmit) {
          deliveries.push(id);
          window.dispatchEvent(
            new MessageEvent("message", {
              source,
              origin,
              data: {
                submitSuccessful: true,
                data: { status: "probe_submitted" },
              },
            }),
          );
        }
      };
      window.dispatchEvent(
        new MessageEvent("message", {
          source,
          origin,
          data: {
            ready: true,
            elementType: "paymentMethodsManagement",
            iframeId: id,
          },
        }),
      );
      return widget;
    };
    const removed = mount(first, "first");
    mount(second, "second");
    const success = await hyper.confirmTokenization({ elements: { ...first } });
    const foreign = await otherHyper.confirmTokenization({ elements: first });
    const unknown = await hyper.confirmTokenization({ elements: {} });
    removed.destroy();
    const empty = await hyper.confirmTokenization({ elements: first });
    mount(first, "first");
    const replaced = await hyper.confirmTokenization({ elements: first });
    return {
      deliveries,
      success,
      replaced,
      errors: [foreign, unknown, empty].map((x) => x.error?.type ?? x),
    };
  });
  expect(result).toEqual({
    deliveries: ["first", "first"],
    success: { status: "probe_submitted" },
    replaced: { status: "probe_submitted" },
    errors: ["invalid_element", "invalid_element", "invalid_element"],
  });
});
