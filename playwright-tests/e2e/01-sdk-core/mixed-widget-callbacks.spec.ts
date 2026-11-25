import { test, expect } from "../../fixtures/sdk-runtime";

for (const event of [
  "focus",
  "completeDoThis",
  "paymentButtonClick",
  "sdkClick",
] as const) {
  for (const remove of [false, true]) {
    test(`registering ${event} on the mounted handle preserves unrelated legacy callbacks (remove: ${remove}) @hermetic-only`, async ({
      runtimePage,
    }) => {
      const result = await runtimePage.evaluate(
        async ({ event, remove }) => {
          const { elements } = window.sdkTest.makeElements();
          const alias = elements.create("payment", {});
          const mounted = elements.create("payment", {});
          const calls: string[] = [];
          alias.on("ready", () => calls.push("legacy ready"));
          alias.on("focus", () => calls.push("legacy focus"));
          alias.on("paymentComplete", () => calls.push("legacy complete"));
          alias.onSDKHandleClick(async () => {
            calls.push("legacy click");
          });
          mounted.mount("#first");
          const frame = document.querySelector<HTMLIFrameElement>(
            "#orca-payment-element-iframeRef-first",
          )!;
          const flags: Record<string, boolean>[] = [];
          frame.contentWindow!.postMessage = (message) => {
            const data =
              typeof message === "string" ? JSON.parse(message) : message;
            if ("isPaymentCompleteHandlerProvided" in data) flags.push(data);
          };
          const handle = elements.getElement("payment")!;
          if (event === "sdkClick")
            handle.onSDKHandleClick(
              remove
                ? undefined
                : async () => {
                    calls.push("merchant click");
                  },
            );
          else
            handle.on(
              event,
              remove ? undefined : () => calls.push(`merchant ${event}`),
            );
          for (const name of [
            "ready",
            "focus",
            "paymentComplete",
            "oneClickConfirmTriggered",
          ])
            window.sdkTest.notifyElementMessage("first", {
              [name]: true,
              elementType: "payment",
              iframeId: "first",
            });
          await Promise.resolve();
          await Promise.resolve();
          // No callback from either handle may follow an unrelated live widget.
          elements.create("payment", {}).mount("#second");
          for (const name of [
            "focus",
            "paymentComplete",
            "oneClickConfirmTriggered",
          ])
            window.sdkTest.notifyElementMessage("second", {
              [name]: true,
              elementType: "payment",
              iframeId: "second",
            });
          await Promise.resolve();
          await Promise.resolve();
          return { calls, flags };
        },
        { event, remove },
      );
      expect(result.calls).toEqual([
        "legacy ready",
        ...(event === "focus"
          ? remove
            ? []
            : ["merchant focus"]
          : ["legacy focus"]),
        ...(event === "completeDoThis"
          ? remove
            ? []
            : ["merchant completeDoThis"]
          : ["legacy complete"]),
        ...(["paymentButtonClick", "sdkClick"].includes(event)
          ? remove
            ? []
            : [
                event === "sdkClick"
                  ? "merchant click"
                  : "merchant paymentButtonClick",
              ]
          : ["legacy click"]),
      ]);
      expect(result.flags.length).toBeGreaterThan(0);
      // Observe every publication: unrelated handlers must never be advertised absent.
      for (const flags of result.flags)
        expect(flags).toEqual({
          isPaymentCompleteHandlerProvided: !(
            event === "completeDoThis" && remove
          ),
          isPaymentButtonHandlerProvided: !(
            ["paymentButtonClick", "sdkClick"].includes(event) && remove
          ),
        });
    });
  }
}

for (const lifecycle of ["remount", "replacement", "destroyAlias"] as const) {
  test(`mixed registrations preserve their own lifetimes across ${lifecycle} @hermetic-only`, async ({
    runtimePage,
  }) => {
    const calls = await runtimePage.evaluate(async (lifecycle) => {
      const { elements } = window.sdkTest.makeElements();
      const alias = elements.create("payment", {});
      const mounted = elements.create("payment", {});
      const calls: string[] = [];
      alias.on("focus", () => calls.push("legacy focus"));
      alias.on("paymentComplete", () => calls.push("legacy complete"));
      alias.onSDKHandleClick(async () => {
        calls.push("legacy click");
      });
      mounted.mount("#first");
      mounted.on("focus", () => calls.push("merchant focus"));
      if (lifecycle === "remount") {
        mounted.unmount();
        mounted.mount("#first");
      } else if (lifecycle === "replacement")
        elements.create("payment", {}).mount("#first");
      else alias.destroy();
      for (const name of [
        "focus",
        "paymentComplete",
        "oneClickConfirmTriggered",
      ])
        window.sdkTest.notifyElementMessage("first", {
          [name]: true,
          elementType: "payment",
          iframeId: "first",
        });
      await Promise.resolve();
      await Promise.resolve();
      return calls;
    }, lifecycle);
    expect(calls).toEqual(
      lifecycle === "destroyAlias"
        ? ["merchant focus"]
        : [
            lifecycle === "replacement" ? "legacy focus" : "merchant focus",
            "legacy complete",
            "legacy click",
          ],
    );
  });
}
