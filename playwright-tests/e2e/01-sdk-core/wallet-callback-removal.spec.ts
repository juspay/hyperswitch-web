import { test, expect } from "../../fixtures/sdk-runtime";

for (const registration of ["direct", "legacy", "legacy override"] as const) {
  for (const api of ["onSDKHandleClick", "paymentButtonClick"] as const) {
    test(`${api} removal acknowledges a delayed wallet request (${registration}) @hermetic-only`, async ({ runtimePage }) => {
      const result = await runtimePage.evaluate(async ({ registration, api }) => {
        const { elements } = window.sdkTest.makeElements();
        const mounted = elements.create("payment", {});
        mounted.mount("#first");
        // Register after mounting so the empty mount owner precedes the alias.
        // It must not bypass the alias's active merchant callback.
        const callbacks = registration === "direct"
          ? mounted : elements.create("payment", {});
        const calls: string[] = [];
        callbacks.onSDKHandleClick(async () => {
          calls.push("first");
          throw new Error("Merchant declined");
        });
        const sibling = elements.create("payment", {});
        sibling.onSDKHandleClick(async () => { calls.push("second"); });
        sibling.mount("#second");

        const replies: { widget: string; accepted: boolean; requestId: string; origin: string }[] = [];
        const completed = new Map<string, () => void>();
        const origins: Record<string, string> = {};
        for (const id of ["first", "second"]) {
          const frame = document.querySelector<HTMLIFrameElement>(`#orca-payment-element-iframeRef-${id}`)!;
          origins[id] = new URL(frame.src).origin;
          frame.contentWindow!.postMessage = (message, targetOrigin) => {
            const data = typeof message === "string" ? JSON.parse(message) : message;
            if (typeof data.walletClickEvent === "boolean") {
              replies.push({ widget: id, accepted: data.walletClickEvent, requestId: data.walletClickRequestId, origin: targetOrigin as string });
              completed.get(data.walletClickRequestId)?.();
            }
          };
        }
        const send = (id: string, requestId: string) => window.sdkTest.notifyElementMessage(id, {
          oneClickConfirmTriggered: true, walletClickRequestId: requestId,
        });
        const control = new Promise<void>(resolve => completed.set("before-removal", resolve));
        send("first", "before-removal");
        await control;

        const handle = registration === "legacy override" ? mounted : callbacks;
        if (api === "onSDKHandleClick") handle.onSDKHandleClick(undefined);
        else handle.on("paymentButtonClick", undefined);
        // Vendor callbacks can retain the old enabled flag after its removal.
        send("first", "after-removal");
        const siblingDone = new Promise<void>(resolve => completed.set("sibling", resolve));
        send("second", "sibling");
        await siblingDone;
        return { calls, replies, origins };
      }, { registration, api });

      expect(result.calls).toEqual(["first", "second"]);
      expect(result.replies).toEqual([
        { widget: "first", accepted: false, requestId: "before-removal", origin: result.origins.first },
        { widget: "first", accepted: true, requestId: "after-removal", origin: result.origins.first },
        { widget: "second", accepted: true, requestId: "sibling", origin: result.origins.second },
      ]);
    });
  }
}

test("missing wallet callbacks do not acknowledge untrusted or destroyed frames @hermetic-only", async ({ runtimePage }) => {
  const result = await runtimePage.evaluate(() => {
    const { elements } = window.sdkTest.makeElements();
    const widget = elements.create("payment", {});
    widget.onSDKHandleClick(async () => {});
    widget.mount("#first");
    widget.onSDKHandleClick(undefined);
    const frame = document.querySelector<HTMLIFrameElement>("#orca-payment-element-iframeRef-first")!;
    const source = frame.contentWindow!;
    const origin = new URL(frame.src).origin;
    const replies: string[] = [];
    const capture = (message: any) => {
      const data = typeof message === "string" ? JSON.parse(message) : message;
      if (typeof data.walletClickEvent === "boolean") replies.push(data.walletClickRequestId);
    };
    source.postMessage = capture;
    const send = (requestId: string, source: Window, origin: string) => window.dispatchEvent(new MessageEvent("message", {
      source, origin, data: { oneClickConfirmTriggered: true, walletClickRequestId: requestId },
    }));
    send("wrong-origin", source, "https://untrusted.example.test");
    const foreign = document.createElement("iframe");
    document.body.append(foreign);
    foreign.contentWindow!.postMessage = capture;
    send("unregistered", foreign.contentWindow!, origin);
    send("trusted", source, origin);
    widget.destroy();
    // Reusing a container must not authorize requests from its previous iframe.
    elements.create("payment", {}).mount("#first");
    send("destroyed", source, origin);
    return replies;
  });
  expect(result).toEqual(["trusted"]);
});
