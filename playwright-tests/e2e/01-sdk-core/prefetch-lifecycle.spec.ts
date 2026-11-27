import { test, expect } from "../../fixtures/sdk-runtime";

test("completed collection prefetch removes its message listener @hermetic-only", async ({
  runtimePage,
}) => {
  const cdp = await runtimePage.context().newCDPSession(runtimePage);
  const count = async () => {
    const result = await cdp.send("Runtime.evaluate", {
      expression: "(getEventListeners(window).message || []).length",
      includeCommandLineAPI: true,
      returnByValue: true,
    });
    return result.result.value;
  };
  const counts = [await count()];
  for (let i = 0; i < 3; i++) {
    await runtimePage.evaluate(async () => {
      window.sdkTest.makeElements();
      const iframe = document.querySelector<HTMLIFrameElement>(
        'iframe[id*="hyper-preMountLoader-iframe-"]',
      )!;
      await window.sdkTest.resolvePreMount();
      window.dispatchEvent(
        new MessageEvent("message", {
          data: { preMountLoaderIframeUnMount: true },
          source: iframe.contentWindow,
          origin: new URL(iframe.src).origin,
        }),
      );
    });
    expect(
      await runtimePage
        .locator('iframe[id*="hyper-preMountLoader-iframe-"]')
        .count(),
    ).toBe(0);
    counts.push(await count());
  }
  expect(counts).toEqual(Array(4).fill(counts[0]));
});
