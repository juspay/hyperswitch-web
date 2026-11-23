import { test, expect } from "../../fixtures/sdk-runtime";

test.describe("Multiple widgets @hermetic-only", () => {
  for (const destroyBeforeData of [false, true]) {
    test(`wallet overlay listeners are disposed with their widget (delayed data: ${destroyBeforeData})`, async ({ runtimePage }) => {
      const counts = await runtimePage.evaluate(async destroyBeforeData => {
        const { elements } = window.sdkTest.makeElements();
        const counts: number[] = [];
        for (let cycle = 0; cycle < 2; cycle++) {
          const widget = elements.create("payment", {});
          widget.mount("#first");
          window.sdkTest.notifyMounted("first");
          if (destroyBeforeData) widget.destroy();
          if (cycle === 0) await window.sdkTest.resolvePreMount();
          await Promise.resolve();
          await Promise.resolve();
          counts.push(window.sdkTest.walletOverlayListenerCount());
          if (!destroyBeforeData) widget.destroy();
          counts.push(window.sdkTest.walletOverlayListenerCount());
        }
        return counts;
      }, destroyBeforeData);
      expect(counts).toEqual(destroyBeforeData ? [0, 0, 0, 0] : [2, 0, 2, 0]);
    });
  }

  test("legacy split handles accept only their paired widget's overlay", async ({ runtimePage }) => {
    await runtimePage.evaluate(() => {
      const { elements } = window.sdkTest.makeElements();
      const mounts: { unmount(): void }[] = [];
      Object.assign(window, { pairedCompletions: [0, 0], pairedMounts: mounts });
      for (const [index, id] of ["first", "second"].entries()) {
        const callbackHandle = elements.create("payment", {});
        callbackHandle.on("paymentComplete", () => {
          (window as unknown as { pairedCompletions: number[] }).pairedCompletions[index]++;
        });
        const mounted = elements.create("payment", {});
        mounted.mount(`#${id}`);
        mounts.push(mounted);
      }
      window.sdkTest.notifyElementMessage("first", { fullscreen: true, iframeId: "first", param: "paymentloader", metadata: {} });
    });
    await expect(runtimePage.locator("#orca-fullscreen")).toBeAttached();
    const counts = await runtimePage.evaluate(() => {
      const iframe = document.querySelector<HTMLIFrameElement>("#orca-fullscreen")!;
      const event = {
        data: { paymentComplete: true, elementType: "payment" },
        source: iframe.contentWindow,
        origin: new URL(iframe.src).origin,
      };
      window.dispatchEvent(new MessageEvent("message", event));
      (window as unknown as { pairedMounts: { unmount(): void }[] }).pairedMounts[0].unmount();
      window.dispatchEvent(new MessageEvent("message", event));
      return (window as unknown as { pairedCompletions: number[] }).pairedCompletions;
    });
    expect(counts).toEqual([1, 0]);
  });

  test("wallet and completion callbacks belong to their mounted widget", async ({ runtimePage }) => {
    const result = await runtimePage.evaluate(async () => {
      const { elements } = window.sdkTest.makeElements();
      const clicks = [0, 0];
      const completed = [0, 0];
      const widgets = ["first", "second"].map((id, index) => {
        const widget = elements.create("payment", {});
        widget.on("paymentButtonClick", () => { clicks[index]++; });
        widget.on("paymentComplete", () => { completed[index]++; });
        widget.mount(`#${id}`);
        return widget;
      });
      window.sdkTest.notifyElementMessage("first", { oneClickConfirmTriggered: true });
      window.sdkTest.notifyElementMessage("second", { paymentComplete: true });
      await Promise.resolve();
      await Promise.resolve();
      widgets[0].destroy();
      window.sdkTest.notifyElementMessage("second", { oneClickConfirmTriggered: true });
      await Promise.resolve();
      await Promise.resolve();
      return { clicks, completed };
    });
    expect(result).toEqual({ clicks: [1, 1], completed: [0, 1] });
  });

  for (const type of ["payment", "card", "cardCvc", "expressCheckout"]) {
    test(`${type} keeps mount and change events local to each instance`, async ({ runtimePage }) => {
      const result = await runtimePage.evaluate(async (type) => {
        const { elements, logs } = window.sdkTest.makeElements();
        const changes = [0, 0];
        for (const [index, id] of ["first", "second"].entries()) {
          const widget = elements.create(type, {});
          widget.on("change", () => changes[index]++);
          widget.mount(`#${id}`);
        }
        await Promise.resolve();
        window.sdkTest.notifyMounted("first");
        window.sdkTest.notifyMounted("second");
        window.sdkTest.notifyElementMessage("first", { elementType: type, iframeId: "first" });
        return { changes, logs };
      }, type);
      expect(result.changes).toEqual([1, 0]);
      expect(result.logs).toEqual([
        { componentType: type, eventListeners: ["change"] },
        { componentType: type, eventListeners: ["change"] },
      ]);
    });
  }
});
