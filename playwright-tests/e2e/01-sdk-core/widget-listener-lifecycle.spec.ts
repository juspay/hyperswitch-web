import { test, expect } from "../../fixtures/sdk-runtime";

test("replacing a widget without destroy releases its window listeners and preserves reuse @hermetic-only", async ({
  runtimePage,
}) => {
  const result = await runtimePage.evaluate(() => {
    const active = new Set<EventListenerOrEventListenerObject>();
    const add = window.addEventListener.bind(window);
    const remove = window.removeEventListener.bind(window);
    window.addEventListener = ((
      type: string,
      listener: EventListenerOrEventListenerObject,
      options: any,
    ) => {
      if (type === "message") active.add(listener);
      add(type, listener, options);
    }) as typeof window.addEventListener;
    window.removeEventListener = ((
      type: string,
      listener: EventListenerOrEventListenerObject,
      options: any,
    ) => {
      if (type === "message") active.delete(listener);
      remove(type, listener, options);
    }) as typeof window.removeEventListener;
    const { elements } = window.sdkTest.makeElements();
    const calls: number[] = [];
    const counts: number[] = [];
    const widgets = [];
    for (let i = 0; i < 6; i++) {
      const widget = elements.create("payment", {});
      for (const name of [
        "ready",
        "focus",
        "blur",
        "change",
        "resize",
        "paymentComplete",
      ])
        widget.on(name, () => calls.push(i));
      widget.mount("#first");
      widgets.push(widget);
      counts.push(active.size);
      window.sdkTest.notifyElementMessage("first", {
        focus: true,
        elementType: "payment",
        iframeId: "first",
      });
    }
    // A superseded handle is unmounted, not destroyed. Its callbacks survive reuse.
    widgets[0].mount("#second");
    window.sdkTest.notifyElementMessage("second", {
      focus: true,
      elementType: "payment",
      iframeId: "second",
    });
    widgets[0].unmount();
    const unmountedCount = active.size;
    widgets[0].mount("#second");
    window.sdkTest.notifyElementMessage("second", {
      focus: true,
      elementType: "payment",
      iframeId: "second",
    });
    widgets[0].destroy();
    return { counts, calls, unmountedCount, destroyedCount: active.size };
  });
  expect(result.counts).toEqual(Array(6).fill(result.counts[0]));
  expect(result.calls).toEqual([0, 1, 2, 3, 4, 5, 0, 0]);
  expect(result.unmountedCount).toBe(result.counts[0]);
  expect(result.destroyedCount).toBe(result.counts[0]);
});

for (const event of [
  "focus",
  "paymentComplete",
  "paymentButtonClick",
  "sdkClick",
]) {
  test(`mounted ${event} registration supersedes its legacy alias @hermetic-only`, async ({
    runtimePage,
  }) => {
    const result = await runtimePage.evaluate(async (event) => {
      const { elements } = window.sdkTest.makeElements();
      const alias = elements.create("payment", {});
      const mounted = elements.create("payment", {});
      const calls: string[] = [];
      const register = (widget: typeof mounted, label: string) => {
        if (event === "sdkClick")
          widget.onSDKHandleClick(async () => {
            calls.push(label);
          });
        else widget.on(event, () => calls.push(label));
      };
      const emit = async (id: string) => {
        window.sdkTest.notifyElementMessage(id, {
          [event === "sdkClick" || event === "paymentButtonClick"
            ? "oneClickConfirmTriggered"
            : event]: true,
          elementType: "payment",
          iframeId: id,
        });
        await Promise.resolve();
        await Promise.resolve();
      };
      register(alias, "alias");
      mounted.mount("#first");
      await emit("first");
      register(mounted, "mounted");
      await emit("first");
      // Another unregistered mount must not acquire the superseded callback.
      elements.create("payment", {}).mount("#second");
      await emit("second");
      // The retired alias may still be explicitly reused as its own widget.
      alias.mount("#second");
      await emit("second");
      return calls;
    }, event);
    expect(result).toEqual(["alias", "mounted", "alias"]);
  });
}

test("a removed completion callback stays removed after remount @hermetic-only", async ({
  runtimePage,
}) => {
  const calls = await runtimePage.evaluate(() => {
    const { elements } = window.sdkTest.makeElements();
    const widget = elements.create("payment", {});
    let calls = 0;
    widget.on("paymentComplete", () => calls++);
    widget.mount("#first");
    window.sdkTest.notifyElementMessage("first", { paymentComplete: true });
    widget.on("paymentComplete", undefined);
    widget.unmount();
    widget.mount("#first");
    window.sdkTest.notifyElementMessage("first", { paymentComplete: true });
    return calls;
  });
  expect(calls).toBe(1);
});

test("a replaced mount no longer controls its former callback alias @hermetic-only", async ({
  runtimePage,
}) => {
  const calls = await runtimePage.evaluate(() => {
    const { elements } = window.sdkTest.makeElements();
    const alias = elements.create("payment", {});
    let calls = 0;
    alias.on("focus", () => calls++);
    const first = elements.create("payment", {});
    first.mount("#first");
    elements.create("payment", {}).mount("#first");
    window.sdkTest.notifyElementMessage("first", {
      focus: true,
      elementType: "payment",
      iframeId: "first",
    });
    first.on("focus", () => {});
    window.sdkTest.notifyElementMessage("first", {
      focus: true,
      elementType: "payment",
      iframeId: "first",
    });
    return calls;
  });
  expect(calls).toBe(2);
});

for (const cleanup of ["replace", "unmount", "destroy"] as const) {
  test(`fresh legacy pairs retire superseded aliases (cleanup: ${cleanup}) @hermetic-only`, async ({
    runtimePage,
  }) => {
    const result = await runtimePage.evaluate((cleanup) => {
      const active = new Set<EventListenerOrEventListenerObject>();
      const add = window.addEventListener.bind(window);
      const remove = window.removeEventListener.bind(window);
      window.addEventListener = ((
        type: string,
        listener: EventListenerOrEventListenerObject,
        options: any,
      ) => {
        if (type === "message") active.add(listener);
        add(type, listener, options);
      }) as typeof window.addEventListener;
      window.removeEventListener = ((
        type: string,
        listener: EventListenerOrEventListenerObject,
        options: any,
      ) => {
        if (type === "message") active.delete(listener);
        remove(type, listener, options);
      }) as typeof window.removeEventListener;
      const { elements } = window.sdkTest.makeElements();
      const counts: number[] = [];
      const calls: number[] = [];
      for (let i = 0; i < 6; i++) {
        const alias = elements.create("payment", {});
        alias.on("focus", () => calls.push(i));
        alias.on("paymentComplete", () => calls.push(i));
        const mounted = elements.create("payment", {});
        mounted.mount("#first");
        window.sdkTest.notifyElementMessage("first", {
          focus: true,
          elementType: "payment",
          iframeId: "first",
        });
        counts.push(active.size);
        if (cleanup !== "replace") mounted[cleanup]();
      }
      return { counts, calls };
    }, cleanup);
    expect(result.calls).toEqual([0, 1, 2, 3, 4, 5]);
    expect(result.counts).toEqual(Array(6).fill(result.counts[0]));
  });
}

for (const waitingMount of [false, true]) {
  test(`inherited aliases stay scoped when another widget registers (waiting mount: ${waitingMount}) @hermetic-only`, async ({
    runtimePage,
  }) => {
    const calls = await runtimePage.evaluate((waitingMount) => {
      const { elements } = window.sdkTest.makeElements();
      const calls: string[] = [];
      const old = elements.create("payment", {});
      old.on("focus", () => calls.push("old"));
      const mounted = elements.create("payment", {});
      mounted.mount("#first");
      mounted.unmount();
      // A handle made before the replacement can claim an inherited pair, but
      // must prefer its genuinely unpaired mount when one is waiting.
      const early = waitingMount ? elements.create("payment", {}) : undefined;
      elements.create("payment", {}).mount("#first");
      if (waitingMount) elements.create("payment", {}).mount("#second");
      const next = early ?? elements.create("payment", {});
      next.on("focus", () => calls.push("next"));
      window.sdkTest.notifyElementMessage("first", {
        focus: true,
        elementType: "payment",
        iframeId: "first",
      });
      if (!waitingMount) next.mount("#second");
      window.sdkTest.notifyElementMessage("second", {
        focus: true,
        elementType: "payment",
        iframeId: "second",
      });
      window.sdkTest.notifyElementMessage("first", {
        focus: true,
        elementType: "payment",
        iframeId: "first",
      });
      return calls;
    }, waitingMount);
    expect(calls).toEqual(["old", "next", "old"]);
  });
}

for (const registration of ["alias", "mounted"] as const) {
  test(`taking an inherited pair is atomic (${registration}) @hermetic-only`, async ({
    runtimePage,
  }) => {
    const calls = await runtimePage.evaluate((registration) => {
      const { elements } = window.sdkTest.makeElements();
      const calls: string[] = [];
      const original = elements.create("payment", {});
      original.on("focus", () => calls.push("original"));
      const oldMount = elements.create("payment", {});
      oldMount.mount("#first");
      oldMount.unmount();
      const early = elements.create("payment", {});
      const replacement = elements.create("payment", {});
      replacement.mount("#first");
      const future = elements.create("payment", {});
      future.on("focus", () => calls.push("future"));
      const owner = registration === "alias" ? early : replacement;
      owner.on("focus", () => calls.push("owner"));
      window.sdkTest.notifyElementMessage("first", {
        focus: true,
        elementType: "payment",
        iframeId: "first",
      });
      future.mount("#second");
      window.sdkTest.notifyElementMessage("second", {
        focus: true,
        elementType: "payment",
        iframeId: "second",
      });
      window.sdkTest.notifyElementMessage("first", {
        focus: true,
        elementType: "payment",
        iframeId: "first",
      });
      return calls;
    }, registration);
    expect(calls).toEqual(["owner", "future", "owner"]);
  });
}
