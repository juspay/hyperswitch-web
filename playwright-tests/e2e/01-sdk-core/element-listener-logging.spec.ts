import { test, expect } from "../../fixtures/sdk-runtime";

test.describe("Element listener logging @hermetic-only", () => {
  for (const handshakeFirst of [false, true]) {
    test(`a handler created after mounting shares the element's listener log (handshake first: ${handshakeFirst})`, async ({
      runtimePage,
    }) => {
      const result = await runtimePage.evaluate(async (handshakeFirst) => {
        const { elements, logs } = window.sdkTest.makeElements();
        const mounting = elements.create("cardCvc", {});
        mounting.mount("#first");
        if (handshakeFirst) window.sdkTest.notifyMounted("first");
        const registration = elements.create("cardCvc", {});
        let changes = 0;
        registration.on("change", () => changes++);
        window.dispatchEvent(
          new MessageEvent("message", {
            data: { elementType: "cardCvc", iframeId: "first" },
          }),
        );
        await Promise.resolve();
        if (!handshakeFirst) window.sdkTest.notifyMounted("first");
        registration.on("focus", () => {});
        return { changes, logs };
      }, handshakeFirst);
      expect(result.changes).toBe(1);
      expect(result.logs).toEqual([
        ...(handshakeFirst
          ? [{ componentType: "cardCvc", eventListeners: [] }]
          : []),
        { componentType: "cardCvc", eventListeners: ["change"] },
        { componentType: "cardCvc", eventListeners: ["change", "focus"] },
      ]);
    });
  }

  test("React elements without callbacks do not take a sibling's listener scope", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(async () => {
      const { elements, logs } = window.sdkTest.makeElements();
      const emptyRegistration = elements.create("cardCvc", {});
      const registration = elements.create("cardCvc", {});
      const emptyMount = elements.create("cardCvc", {});
      emptyMount.mount("#first");
      emptyRegistration.on("ready", undefined);
      emptyRegistration.on("change", undefined);
      emptyRegistration.onSDKHandleClick(undefined);
      elements.create("cardCvc", {}).mount("#second");
      registration.on("ready", undefined);
      registration.on("change", () => {});
      await Promise.resolve();
      window.sdkTest.notifyMounted("first");
      window.sdkTest.notifyMounted("second");
      emptyMount.destroy();
      registration.on("focus", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: [] },
      { componentType: "cardCvc", eventListeners: ["change"] },
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });

  test("multiple React registrations stay paired with their own mounting instances", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(async () => {
      const { elements, logs } = window.sdkTest.makeElements();
      const firstRegistration = elements.create("cardCvc", {});
      const secondRegistration = elements.create("cardCvc", {});
      elements.create("cardCvc", {}).mount("#first");
      firstRegistration.on("ready", () => {});
      firstRegistration.on("change", () => {});
      elements.create("cardCvc", {}).mount("#second");
      secondRegistration.on("focus", () => {});
      await Promise.resolve();
      window.sdkTest.notifyMounted("first");
      window.sdkTest.notifyMounted("second");
      firstRegistration.on("blur", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["ready", "change"] },
      { componentType: "cardCvc", eventListeners: ["focus"] },
      { componentType: "cardCvc", eventListeners: ["ready", "change", "blur"] },
    ]);
  });

  test("the real cross-origin iframe window can send its mount handshake", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(async () => {
      const { elements, logs } = window.sdkTest.makeElements();
      const element = elements.create("cardCvc", {});
      element.on("change", () => {});
      element.mount("#first");
      const iframe = document.getElementById(
        "orca-payment-element-iframeRef-first",
      )!;
      await new Promise<void>((resolve) =>
        iframe.addEventListener("load", () => resolve(), { once: true }),
      );
      window.sdkTest.notifyMounted("first");
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["change"] },
    ]);
  });

  test("a direct element retains registrations while another pending mount is destroyed", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(() => {
      const { elements, logs } = window.sdkTest.makeElements();
      const surviving = elements.create("cardCvc", {});
      const discarded = elements.create("cardCvc", {});
      surviving.on("change", () => {});
      discarded.mount("#first");
      discarded.destroy();
      surviving.on("focus", () => {});
      surviving.mount("#second");
      window.sdkTest.notifyMounted("second");
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });

  test("destroying a React element before its handshake retires pending registrations", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(async () => {
      const { elements, logs } = window.sdkTest.makeElements();
      const oldRegistration = elements.create("cardCvc", {});
      const oldMount = elements.create("cardCvc", {});
      oldMount.mount("#first");
      oldRegistration.on("ready", () => {});
      oldMount.destroy();
      const registration = elements.create("cardCvc", {});
      elements.create("cardCvc", {}).mount("#first");
      registration.on("change", () => {});
      await Promise.resolve();
      window.sdkTest.notifyMounted("first");
      registration.on("focus", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["change"] },
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });

  test("an old mount does not accept the handshake of a different element at the same selector", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(() => {
      const { elements, logs } = window.sdkTest.makeElements();
      const old = elements.create("cardCvc", {});
      old.on("ready", () => {});
      old.mount("#first");
      old.unmount();
      const replacement = elements.create("cardNumber", {});
      replacement.on("change", () => {});
      replacement.mount("#first");
      window.sdkTest.notifyMounted("first");
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardNumber", eventListeners: ["change"] },
    ]);
  });

  for (const reverseCreation of [false, true]) {
    test(`a mounted element without listeners stays independent of another direct element (reverse creation: ${reverseCreation})`, async ({
      runtimePage,
    }) => {
      const logs = await runtimePage.evaluate(async (reverseCreation) => {
        const { elements, logs } = window.sdkTest.makeElements();
        const handles = [
          elements.create("cardCvc", {}),
          elements.create("cardCvc", {}),
        ];
        if (reverseCreation) handles.reverse();
        const [first, second] = handles;
        first.mount("#first");
        window.sdkTest.notifyMounted("first");
        second.on("change", () => {});
        second.mount("#second");
        window.sdkTest.notifyMounted("second");
        second.destroy();
        first.on("focus", () => {});
        await Promise.resolve();
        return logs;
      }, reverseCreation);
      expect(logs).toEqual([
        { componentType: "cardCvc", eventListeners: [] },
        { componentType: "cardCvc", eventListeners: ["change"] },
        { componentType: "cardCvc", eventListeners: ["focus"] },
      ]);
    });
  }

  test("a destroyed CVC element does not contribute listeners to its replacement", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(() => {
      const { elements, logs } = window.sdkTest.makeElements();
      const mounted = (iframeId: string) =>
        window.sdkTest.notifyMounted(iframeId);
      const first = elements.create("cardCvc", {});
      first.on("ready", () => {});
      first.mount("#first");
      mounted("first");
      first.destroy();

      const replacement = elements.create("cardCvc", {});
      replacement.on("change", () => {});
      replacement.mount("#first");
      mounted("first");
      replacement.on("focus", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["ready"] },
      { componentType: "cardCvc", eventListeners: ["change"] },
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });

  for (const registerFirst of [true, false]) {
    test(`React registration and mounting instances share listeners (${registerFirst ? "registration" : "mount"} first)`, async ({
      runtimePage,
    }) => {
      const logs = await runtimePage.evaluate((registerFirst) => {
        const { elements, logs } = window.sdkTest.makeElements();
        const registration = elements.create("cardCvc", {});
        const mounting = elements.create("cardCvc", {});
        const register = () => registration.on("change", () => {});
        if (registerFirst) register();
        mounting.mount("#first");
        if (!registerFirst) register();
        window.sdkTest.notifyMounted("first");
        registration.on("change", () => {});
        registration.on("ready", undefined);
        registration.onSDKHandleClick(() => Promise.resolve());
        return logs;
      }, registerFirst);
      expect(logs).toEqual([
        { componentType: "cardCvc", eventListeners: ["change"] },
        {
          componentType: "cardCvc",
          eventListeners: ["change", "onSDKHandleClick"],
        },
      ]);
    });
  }

  test("same-type elements created before mounting keep separate listeners", async ({
    runtimePage,
  }) => {
    const result = await runtimePage.evaluate(() => {
      const { elements, logs } = window.sdkTest.makeElements();
      const first = elements.create("cardCvc", {});
      const second = elements.create("cardCvc", {});
      first.on("ready", () => {});
      second.on("change", () => {});
      first.mount("#first");
      second.mount("#second");
      window.sdkTest.notifyMounted("first");
      const afterFirstMount = logs.slice();
      window.sdkTest.notifyMounted("second");
      return { afterFirstMount, logs };
    });
    expect(result.afterFirstMount).toEqual([
      { componentType: "cardCvc", eventListeners: ["ready"] },
    ]);
    expect(result.logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["ready"] },
      { componentType: "cardCvc", eventListeners: ["change"] },
    ]);
  });

  test("React StrictMode effect replay keeps registration paired with the remounted iframe", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(() => {
      const { elements, logs } = window.sdkTest.makeElements();
      const registration = elements.create("cardCvc", {});
      elements.create("cardCvc", {}).mount("#first");
      registration.on("change", () => {});
      elements.create("cardCvc", {}).mount("#first");
      registration.on("change", () => {});
      window.sdkTest.notifyMounted("first");
      registration.on("focus", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["change"] },
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });

  test("destroying a React mounting instance retires its registration scope", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(() => {
      const { elements, logs } = window.sdkTest.makeElements();
      const mounted = () => window.sdkTest.notifyMounted("first");
      const registration = elements.create("cardCvc", {});
      const mounting = elements.create("cardCvc", {});
      mounting.mount("#first");
      registration.on("ready", () => {});
      mounted();
      mounting.destroy();

      const replacementRegistration = elements.create("cardCvc", {});
      elements.create("cardCvc", {}).mount("#first");
      replacementRegistration.on("change", () => {});
      mounted();
      registration.on("blur", () => {});
      replacementRegistration.on("focus", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["ready"] },
      { componentType: "cardCvc", eventListeners: ["change"] },
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });

  test("unmounting and remounting the same element preserves its listeners", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(() => {
      const { elements, logs } = window.sdkTest.makeElements();
      const element = elements.create("cardCvc", {});
      element.on("change", () => {});
      for (let i = 0; i < 2; i++) {
        element.mount("#first");
        window.sdkTest.notifyMounted("first");
        element.unmount();
      }
      element.on("focus", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["change"] },
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });

  test("React registration after the iframe handshake logs the new listeners", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(async () => {
      const { elements, logs } = window.sdkTest.makeElements();
      const registration = elements.create("cardCvc", {});
      elements.create("cardCvc", {}).mount("#first");
      window.sdkTest.notifyMounted("first");
      registration.on("change", () => {});
      await Promise.resolve();
      registration.on("focus", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: [] },
      { componentType: "cardCvc", eventListeners: ["change"] },
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });

  test("React effect replay after an earlier mount preserves the logical logger", async ({
    runtimePage,
  }) => {
    const logs = await runtimePage.evaluate(async () => {
      const { elements, logs } = window.sdkTest.makeElements();
      const registration = elements.create("cardCvc", {});
      elements.create("cardCvc", {}).mount("#first");
      registration.on("change", () => {});
      window.sdkTest.notifyMounted("first");
      elements.create("cardCvc", {}).mount("#first");
      registration.on("change", () => {});
      await Promise.resolve();
      window.sdkTest.notifyMounted("first");
      registration.on("focus", () => {});
      return logs;
    });
    expect(logs).toEqual([
      { componentType: "cardCvc", eventListeners: ["change"] },
      { componentType: "cardCvc", eventListeners: ["change", "focus"] },
    ]);
  });
});
