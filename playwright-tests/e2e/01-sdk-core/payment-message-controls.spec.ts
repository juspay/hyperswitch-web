import type { Locator, Page } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  PAYMENT_ELEMENT_IFRAME,
  CLIENT_BASE_URL,
  SDK_URL,
} from "../../fixtures";

declare global {
  interface Window {
    controlUnloadCalls: number;
    removeBeforeUnloadEventListeners(handlers: (() => void)[]): void;
  }
}

const foreignOrigin = "https://untrusted-controls.example.test";

async function sender(page: Page, origin: string): Promise<Locator> {
  const url = `${origin}/message-controls-sender.html`;
  await page.route(url, (route) =>
    route.fulfill({ contentType: "text/html", body: "<body>Sender</body>" }),
  );
  await page.evaluate((url) => {
    document.querySelector("#control-sender")?.remove();
    const frame = document.createElement("iframe");
    frame.id = "control-sender";
    frame.src = url;
    document.body.appendChild(frame);
  }, url);
  const body = page.frameLocator("#control-sender").locator("body");
  await expect(body).toHaveText("Sender");
  return body;
}

async function postAndDrain(
  from: Locator,
  payload: unknown,
  targetIndex?: number,
) {
  await from.evaluate(
    async (_el, { payload, targetIndex }) => {
      const target =
        targetIndex === undefined ? parent : parent.frames[targetIndex];
      const channel = new MessageChannel();
      const delivered = new Promise<void>((resolve) => {
        channel.port1.onmessage = () => {
          channel.port1.close();
          resolve();
        };
      });
      target.postMessage(payload, "*");
      target.postMessage({ controlBarrier: true }, "*", [channel.port2]);
      await delivered;
    },
    { payload, targetIndex },
  );
}

async function registerUnloadHandler(page: Page) {
  await page.evaluate(() => {
    window.controlUnloadCalls = 0;
    const handler = () => {
      window.controlUnloadCalls++;
    };
    addEventListener("beforeunload", handler);
    window.removeBeforeUnloadEventListeners([handler]);
  });
}

async function fireUnload(page: Page) {
  return page.evaluate(() => {
    dispatchEvent(new Event("beforeunload"));
    return window.controlUnloadCalls;
  });
}

test.describe("Payment control sender validation @hermetic-only", () => {
  test.afterEach(async ({ page }) => {
    // Nested SDK prefetches can still be loading app.js when assertions finish.
    // Drain those routes before Playwright closes the page and its API context.
    await page.unrouteAll({ behavior: "wait" });
  });

  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() =>
      addEventListener("message", (event) => {
        if (event.data?.controlBarrier) event.ports[0]?.postMessage(true);
      }),
    );
  });

  test("keeps the SDK pay button disabled for foreign controls and accepts a genuine payment error", async ({
    checkout,
    page,
    sdk,
  }) => {
    await checkout.open({
      body: paymentBody(),
      waitForReady: true,
      options: {
        sdkHandleConfirmPayment: {
          handleConfirm: true,
          buttonText: "Secure pay",
          confirmParams: { return_url: CLIENT_BASE_URL },
        },
      },
    });
    await sdk.enterCardDetails(stripeCards.successCard);
    let release!: () => void;
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    await page.route("**/payments/*/confirm", async (route) => {
      await gate;
      await route.fulfill({
        status: 400,
        json: {
          error: {
            type: "invalid_request",
            code: "payment_failed",
            message: "Payment declined",
          },
        },
      });
    });
    const requested = page.waitForRequest(
      (request) =>
        request.method() === "POST" &&
        new URL(request.url()).pathname.endsWith("/confirm"),
    );
    await sdk.paymentElement
      .getByRole("button", { name: "Secure pay", exact: true })
      .evaluate((el) => el.setAttribute("data-testid", "control-pay"));
    const button = sdk.paymentElement.getByTestId("control-pay");
    await button.click();
    await requested;
    try {
      await expect(button).toBeDisabled();
      const index = await page
        .locator(PAYMENT_ELEMENT_IFRAME)
        .evaluate((el) =>
          Array.from(window.frames).indexOf(
            (el as HTMLIFrameElement).contentWindow!,
          ),
        );
      for (const origin of [foreignOrigin, SDK_URL, CLIENT_BASE_URL]) {
        await postAndDrain(
          await sender(page, origin),
          JSON.stringify({ submitSuccessful: false }),
          index,
        );
        await expect(button).toBeDisabled();
      }
      // A WindowProxy can survive navigation; its identity alone must not suffice.
      await sdk.paymentElement.locator("body").evaluate((_el, origin) => {
        dispatchEvent(
          new MessageEvent("message", {
            source: parent,
            origin,
            data: JSON.stringify({ submitSuccessful: false }),
          }),
        );
      }, foreignOrigin);
      await expect(button).toBeDisabled();
    } finally {
      release();
    }
    await expect(button).toBeEnabled();
    await expect(button).toHaveText("Secure pay");
  });

  test("rejects unload cleanup from unregistered windows and accepts its mounted SDK widget", async ({
    checkout,
    page,
    sdk,
  }) => {
    await checkout.open({ body: paymentBody(), waitForReady: true });
    await registerUnloadHandler(page);
    let expected = 0;
    for (const origin of [foreignOrigin, SDK_URL]) {
      await postAndDrain(await sender(page, origin), {
        disableBeforeUnloadEventListener: true,
      });
      expect(await fireUnload(page)).toBe(++expected);
    }
    await postAndDrain(sdk.paymentElement.locator("body"), {
      disableBeforeUnloadEventListener: true,
    });
    expect(await fireUnload(page)).toBe(expected);
  });

  test("rejects unload cleanup after a registered SDK widget navigates to another origin", async ({
    checkout,
    page,
    sdk,
  }) => {
    await checkout.open({ body: paymentBody(), waitForReady: true });
    await registerUnloadHandler(page);
    const url = `${foreignOrigin}/navigated-widget.html`;
    await page.route(url, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: "<body>Navigated widget</body>",
      }),
    );
    await page.locator(PAYMENT_ELEMENT_IFRAME).evaluate((el, url) => {
      (el as HTMLIFrameElement).src = url;
    }, url);
    await expect(sdk.paymentElement.locator("body")).toHaveText(
      "Navigated widget",
    );
    await postAndDrain(sdk.paymentElement.locator("body"), {
      disableBeforeUnloadEventListener: true,
    });
    expect(await fireUnload(page)).toBe(1);
  });

  test("accepts unload cleanup from the merchant window itself", async ({
    checkout,
    page,
  }) => {
    await checkout.open({ body: paymentBody(), waitForReady: true });
    await registerUnloadHandler(page);
    await page.evaluate(async () => {
      const channel = new MessageChannel();
      const delivered = new Promise<void>((resolve) => {
        channel.port1.onmessage = () => {
          channel.port1.close();
          resolve();
        };
      });
      postMessage({ disableBeforeUnloadEventListener: true }, location.origin);
      postMessage({ controlBarrier: true }, location.origin, [channel.port2]);
      await delivered;
    });
    expect(await fireUnload(page)).toBe(0);
  });

  test("rejects queued unload cleanup after its SDK widget is removed", async ({
    checkout,
    page,
  }) => {
    await checkout.open({ body: paymentBody(), waitForReady: true });
    await registerUnloadHandler(page);
    await page.locator(PAYMENT_ELEMENT_IFRAME).evaluate((el, origin) => {
      const source = (el as HTMLIFrameElement).contentWindow;
      el.remove();
      dispatchEvent(
        new MessageEvent("message", {
          source,
          origin,
          data: { disableBeforeUnloadEventListener: true },
        }),
      );
    }, SDK_URL);
    expect(await fireUnload(page)).toBe(1);
  });

  for (const merchantOrigin of [CLIENT_BASE_URL, foreignOrigin]) {
    test(`${merchantOrigin === CLIENT_BASE_URL ? "accepts" : "rejects"} unload cleanup from an SDK frame registered by a ${merchantOrigin === CLIENT_BASE_URL ? "same-origin" : "foreign"} merchant child`, async ({
      checkout,
      page,
      credentials,
    }) => {
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      await page.route(`${SDK_URL}/**`, async (route) => {
        if (route.request().url().includes("/assets/v1/jsons/location/"))
          await route.fallback();
        else await route.fulfill({ response: await route.fetch() });
      });
      const url = `${merchantOrigin}/nested-control-merchant.html`;
      await page.route(url, (route) =>
        route.fulfill({
          contentType: "text/html",
          body: '<body><div id="nested-payment"></div></body>',
        }),
      );
      await page.evaluate((url) => {
        const frame = document.createElement("iframe");
        frame.id = "nested-merchant";
        frame.src = url;
        document.body.appendChild(frame);
      }, url);
      await expect(
        page.frameLocator("#nested-merchant").locator("#nested-payment"),
      ).toBeAttached();
      const merchant = page.frames().find((frame) => frame.url() === url)!;
      // Run the actual loader in the child without depending on cross-site local
      // network script permissions for the intentionally foreign merchant fixture.
      const loader = await page.request.get(`${SDK_URL}/HyperLoader.js`);
      expect(loader.ok()).toBe(true);
      await merchant.addScriptTag({ content: await loader.text() });
      await merchant.evaluate(
        ({ clientSecret, publishableKey }) => {
          const hyper = (
            window as unknown as {
              Hyper: (
                key: string,
                options: object,
              ) => {
                elements(options: object): {
                  create(type: string): { mount(selector: string): void };
                };
              };
            }
          ).Hyper;
          hyper(publishableKey, { isPreloadEnabled: false })
            .elements({ clientSecret })
            .create("payment")
            .mount("#nested-payment");
        },
        {
          clientSecret: intent.clientSecret,
          publishableKey: credentials.publishableKey,
        },
      );
      const nested = merchant
        .frameLocator("#orca-payment-element-iframeRef-nested-payment")
        .locator("body");
      await expect(nested).toBeAttached();
      await expect
        .poll(() =>
          merchant
            .childFrames()
            .some((frame) => frame.url().startsWith(SDK_URL)),
        )
        .toBe(true);
      await registerUnloadHandler(page);
      // Merchant-side Hyper confirmation sends cleanup from its own wrapper.
      await postAndDrain(merchant.locator("body"), {
        disableBeforeUnloadEventListener: true,
      });
      expect(await fireUnload(page)).toBe(
        merchantOrigin === CLIENT_BASE_URL ? 0 : 1,
      );
      await registerUnloadHandler(page);
      await nested.evaluate(async () => {
        const channel = new MessageChannel();
        const delivered = new Promise<void>((resolve) => {
          channel.port1.onmessage = () => {
            channel.port1.close();
            resolve();
          };
        });
        top!.postMessage({ disableBeforeUnloadEventListener: true }, "*");
        top!.postMessage({ controlBarrier: true }, "*", [channel.port2]);
        await delivered;
      });
      expect(await fireUnload(page)).toBe(
        // Both registered handlers remain active after foreign cleanup requests.
        merchantOrigin === CLIENT_BASE_URL ? 0 : 2,
      );
    });
  }

  for (const owner of [
    "widget overlay",
    "coordinator",
    "coordinator overlay",
  ] as const) {
    test(`accepts unload cleanup from its ${owner}`, async ({
      checkout,
      page,
      sdk,
    }) => {
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      let source = sdk.paymentElement.locator("body");
      let iframeId = (await page
        .locator(PAYMENT_ELEMENT_IFRAME)
        .getAttribute("id"))!.replace("orca-payment-element-iframeRef-", "");
      if (owner !== "widget overlay") {
        await page.evaluate((clientSecret) => {
          const container = document.createElement("div");
          container.id = "control-card";
          document.body.appendChild(container);
          const hyper = (
            window as unknown as {
              HyperMethod: {
                elements(options: object): {
                  createCardForm(): {
                    create(
                      type: string,
                      options: object,
                    ): { mount(selector: string): void };
                  };
                };
              };
            }
          ).HyperMethod;
          hyper
            .elements({ clientSecret })
            .createCardForm()
            .create("cardNumber", {})
            .mount("#control-card");
        }, intent.clientSecret);
        await expect(
          page
            .frameLocator("#orca-payment-element-iframeRef-control-card")
            .locator("#card-number"),
        ).toBeVisible();
        const coordinator = page
          .frames()
          .find((frame) =>
            frame.url().includes("componentName=cardFormCoordinator"),
          )!;
        iframeId = new URL(coordinator.url()).searchParams.get("groupId")!;
        source = coordinator.locator("body");
      }
      if (owner !== "coordinator") {
        await source.evaluate(
          (_el, iframeId) =>
            parent.postMessage(
              {
                fullscreen: true,
                iframeId,
                param: "paymentloader",
                metadata: {},
              },
              "*",
            ),
          iframeId,
        );
        await expect
          .poll(() =>
            page
              .frames()
              .some((frame) =>
                frame.url().includes("fullscreenType=paymentloader"),
              ),
          )
          .toBe(true);
        source = page.frameLocator("#orca-fullscreen").locator("body");
        await expect(source).toBeAttached();
      }
      await registerUnloadHandler(page);
      await postAndDrain(source, { disableBeforeUnloadEventListener: true });
      expect(await fireUnload(page)).toBe(0);
    });
  }
});
