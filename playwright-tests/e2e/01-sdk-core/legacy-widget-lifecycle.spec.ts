import { test, expect } from "../../fixtures/sdk-runtime";

for (const type of ["payment", "cardCvc", "expressCheckout"]) {
  for (const callbackFirst of [true, false]) {
    test(`${type} legacy callbacks follow their mount across remount (callback first: ${callbackFirst}) @hermetic-only`, async ({
      runtimePage,
    }) => {
      const calls = await runtimePage.evaluate(
        ({ type, callbackFirst }) => {
          const { elements } = window.sdkTest.makeElements();
          const callbacks = elements.create(type, {});
          const mounted = elements.create(type, {});
          const calls: string[] = [];
          const register = () => {
            for (const name of ["focus", "blur", "ready", "paymentComplete"])
              callbacks.on(name, () => calls.push(name));
          };
          if (callbackFirst) register();
          mounted.mount("#first");
          if (!callbackFirst) register();
          const old = document.querySelector<HTMLIFrameElement>(
            "#orca-payment-element-iframeRef-first",
          )!;
          const oldSource = old.contentWindow;
          const oldOrigin = new URL(old.src).origin;
          const emit = (id: string) => {
            for (const event of ["focus", "blur", "ready", "paymentComplete"])
              window.sdkTest.notifyElementMessage(id, {
                [event]: true,
                elementType: type,
                iframeId: id,
              });
          };
          emit("first");
          mounted.unmount();
          mounted.mount("#second");
          emit("second");
          window.dispatchEvent(
            new MessageEvent("message", {
              source: oldSource,
              origin: oldOrigin,
              data: { paymentComplete: true, elementType: type },
            }),
          );
          const replacement = elements.create(type, {});
          replacement.mount("#first");
          emit("first");
          return calls;
        },
        { type, callbackFirst },
      );
      expect(calls).toEqual([
        "focus",
        "blur",
        "ready",
        "paymentComplete",
        "focus",
        "blur",
        "ready",
        "paymentComplete",
      ]);
    });
  }
}

test("callback-only handle can update but cannot destroy the paired widget @hermetic-only", async ({
  runtimePage,
}) => {
  const result = await runtimePage.evaluate(async () => {
    const { elements } = window.sdkTest.makeElements();
    const first = elements.create("payment", {});
    first.mount("#first");
    window.sdkTest.notifyMounted("first");
    await window.sdkTest.resolvePreMount();
    const before = window.sdkTest.walletOverlayListenerCount();
    const frame = document.querySelector<HTMLIFrameElement>(
      "#orca-payment-element-iframeRef-first",
    )!;
    const updates: object[] = [];
    frame.contentWindow!.postMessage = (payload: string) => {
      const data = JSON.parse(payload);
      if (data.paymentElementsUpdate || data.doClearValues) updates.push(data);
    };
    const callbacks = elements.create("payment", {});
    callbacks.on("completeDoThis", () => {});
    callbacks.update({ readOnly: true });
    callbacks.clear();
    callbacks.destroy();
    return {
      before,
      after: window.sdkTest.walletOverlayListenerCount(),
      updates,
      connected: frame.isConnected,
    };
  });
  expect(result).toEqual({
    before: 2,
    after: 2,
    updates: [
      { paymentElementsUpdate: true, options: { readOnly: true } },
      { doClearValues: true },
    ],
    connected: true,
  });
});

test("destroying an old handle cannot remove a replacement in the same container @hermetic-only", async ({
  runtimePage,
}) => {
  const connected = await runtimePage.evaluate(() => {
    const { elements } = window.sdkTest.makeElements();
    const first = elements.create("payment", {});
    first.mount("#first");
    first.unmount();
    const replacement = elements.create("payment", {});
    replacement.mount("#first");
    const frame = document.querySelector(
      "#orca-payment-element-iframeRef-first",
    )!;
    first.destroy();
    return frame.isConnected;
  });
  expect(connected).toBe(true);
});

test("callback flags remain enabled for surviving handlers after an alias is destroyed @hermetic-only", async ({
  runtimePage,
}) => {
  const flags = await runtimePage.evaluate(() => {
    const { elements } = window.sdkTest.makeElements();
    const mounted = elements.create("payment", {});
    mounted.mount("#first");
    const frame = document.querySelector<HTMLIFrameElement>(
      "#orca-payment-element-iframeRef-first",
    )!;
    const flags: object[] = [];
    frame.contentWindow!.postMessage = (payload: string) => {
      const data = JSON.parse(payload);
      if ("isPaymentCompleteHandlerProvided" in data) flags.push(data);
    };
    const callbacks = elements.create("payment", {});
    callbacks.on("paymentComplete", () => {});
    callbacks.onSDKHandleClick(() => Promise.resolve());
    mounted.on("paymentComplete", () => {});
    mounted.onSDKHandleClick(() => Promise.resolve());
    callbacks.destroy();
    return flags.at(-1);
  });
  expect(flags).toEqual({
    isPaymentButtonHandlerProvided: true,
    isPaymentCompleteHandlerProvided: true,
  });
});

test("an SDK-click-only alias follows remount and detaches when it mounts its own widget @hermetic-only", async ({
  runtimePage,
}) => {
  const result = await runtimePage.evaluate(async () => {
    const { elements } = window.sdkTest.makeElements();
    const mounted = elements.create("payment", {});
    const callbacks = elements.create("payment", {});
    let calls = 0;
    callbacks.onSDKHandleClick(async () => {
      calls++;
    });
    const click = async (id: string) => {
      window.sdkTest.notifyElementMessage(id, {
        oneClickConfirmTriggered: true,
        elementType: "payment",
      });
      await Promise.resolve();
      await Promise.resolve();
    };
    mounted.mount("#first");
    await click("first");
    mounted.unmount();
    mounted.mount("#second");
    await click("second");
    callbacks.mount("#first");
    await click("second");
    await click("first");
    callbacks.destroy();
    return {
      calls,
      neighborConnected: !!document.querySelector(
        "#orca-payment-element-iframeRef-second",
      ),
    };
  });
  expect(result).toEqual({ calls: 3, neighborConnected: true });
});

test("a callback alias that mounts its own widget stops following the previous owner @hermetic-only", async ({ runtimePage }) => {
  const calls = await runtimePage.evaluate(() => {
    const { elements } = window.sdkTest.makeElements();
    const mounted = elements.create("payment", {});
    mounted.mount("#first");
    const callbacks = elements.create("payment", {});
    let calls = 0;
    callbacks.on("focus", () => calls++);
    const focus = (id: string) => window.sdkTest.notifyElementMessage(id, { focus: true, elementType: "payment", iframeId: id });
    focus("first");
    callbacks.mount("#second");
    focus("first");
    focus("second");
    return calls;
  });
  expect(calls).toBe(2);
});
