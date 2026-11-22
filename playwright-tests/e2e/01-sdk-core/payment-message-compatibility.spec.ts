import {
  test,
  expect,
  paymentBody,
  PAYMENT_ELEMENT_IFRAME,
  CLIENT_BASE_URL,
  SDK_URL,
} from "../../fixtures";

type Hyper = {
  elements(options: { clientSecret: string }): {
    createCardForm(): {
      create(type: string, options: object): { mount(selector: string): void };
    };
  };
  confirmPayment(payload: object): Promise<unknown>;
};

test.describe("Payment message compatibility @hermetic-only", () => {
  test("rejects opaque-origin completion even when the authorize URL has an opaque origin", async ({
    checkout,
    page,
  }) => {
    await page.addInitScript(() =>
      addEventListener("message", (ev) => {
        if (ev.data?.compatBarrier) ev.ports[0]?.postMessage(true);
      }),
    );
    await checkout.open({ body: paymentBody(), waitForReady: true });
    const iframeId = (await page
      .locator(PAYMENT_ELEMENT_IFRAME)
      .getAttribute("id"))!.replace("orca-payment-element-iframeRef-", "");
    const widget = await page
      .locator(PAYMENT_ELEMENT_IFRAME)
      .elementHandle()
      .then((el) => el!.contentFrame());
    await widget!.evaluate(
      (iframeId) =>
        parent.postMessage(
          {
            fullscreen: true,
            iframeId,
            param: "paymentloader",
            metadata: {
              threeDSData: { three_ds_authorize_url: "data:text/html,opaque" },
            },
          },
          "*",
        ),
      iframeId,
    );
    await expect(
      page.frameLocator("#orca-fullscreen").locator("body"),
    ).toBeAttached();
    await page.route(`${SDK_URL}/compat-opaque.html`, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: "<body>opaque callback</body>",
      }),
    );
    await page.locator("#orca-fullscreen").evaluate((el, url) => {
      el.setAttribute("sandbox", "allow-scripts");
      (el as HTMLIFrameElement).src = url;
    }, `${SDK_URL}/compat-opaque.html`);
    const overlay = page.frameLocator("#orca-fullscreen").locator("body");
    await expect(overlay).toHaveText("opaque callback");
    const retrievals: string[] = [];
    page.on("request", (request) => {
      if (
        request.method() === "GET" &&
        /\/payments\/pay_[^/]+$/.test(new URL(request.url()).pathname)
      )
        retrievals.push(request.url());
    });
    await overlay.evaluate(async (_el, url) => {
      const channel = new MessageChannel();
      const delivered = new Promise<void>(
        (resolve) =>
          (channel.port1.onmessage = () => {
            channel.port1.close();
            resolve();
          }),
      );
      parent.postMessage({ openurl_if_required: url }, "*");
      parent.postMessage({ compatBarrier: true }, "*", [channel.port2]);
      await delivered;
    }, CLIENT_BASE_URL);
    expect(retrievals).toEqual([]);
    await expect(overlay).toHaveText("opaque callback");
  });

  for (const owner of ["payment", "coordinator"] as const) {
    test(`initializes bank-debit overlay fonts and styles through ${owner}`, async ({
      checkout,
      page,
    }) => {
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      const selector = PAYMENT_ELEMENT_IFRAME;
      let frame = await page
        .locator(selector)
        .elementHandle()
        .then((el) => el!.contentFrame());
      if (owner === "coordinator") {
        await page.evaluate((clientSecret) => {
          const node = document.createElement("div");
          node.id = "compat-card";
          document.body.appendChild(node);
          (window as unknown as { HyperMethod: Hyper }).HyperMethod.elements({
            clientSecret,
          })
            .createCardForm()
            .create("cardNumber", {})
            .mount("#compat-card");
        }, intent.clientSecret);
        await expect(
          page
            .frameLocator("#orca-payment-element-iframeRef-compat-card")
            .locator("#card-number"),
        ).toBeVisible();
        frame = page
          .frames()
          .find((frame) =>
            frame.url().includes("componentName=cardFormCoordinator"),
          )!;
      }
      const iframeId =
        owner === "coordinator"
          ? new URL(frame!.url()).searchParams.get("groupId")!
          : (await page.locator(selector).getAttribute("id"))!.replace(
              "orca-payment-element-iframeRef-",
              "",
            );
      const fontUrl = "https://merchant-fonts.example.test/checkout.css";
      await page.route(fontUrl, (route) =>
        route.fulfill({ contentType: "text/css", body: "" }),
      );
      await frame!.evaluate(
        ({ iframeId, fontUrl }) =>
          parent.postMessage(
            {
              fullscreen: true,
              iframeId,
              metadata: {
                config: {
                  fonts: [{ cssSrc: fontUrl }],
                  appearance: {
                    rules: { ".compat-bank-debit": { color: "rgb(1, 2, 3)" } },
                  },
                },
              },
            },
            "*",
          ),
        { iframeId, fontUrl },
      );
      const overlay = page.frameLocator("#orca-fullscreen");
      await expect
        .poll(() =>
          overlay.locator("#mystyle").evaluate((el) => el.textContent),
        )
        .toContain("compat-bank-debit");
      await expect(overlay.locator(`link[href="${fontUrl}"]`)).toHaveCount(1);
    });
  }

  test("replies to same-origin Apple Pay grandchildren but rejects foreign descendants and unrelated popups", async ({
    checkout,
    page,
    context,
  }) => {
    await checkout.open({ body: paymentBody(), waitForReady: true });
    const path = "/compat-apple-relay.html";
    for (const origin of [CLIENT_BASE_URL, "https://foreign.example.test"]) {
      await page.route(`${origin}${path}`, (route) =>
        route.fulfill({ contentType: "text/html", body: "<body>relay</body>" }),
      );
    }
    await page.evaluate(
      ({ path, origin }) => {
        const outer = document.createElement("iframe");
        outer.id = "compat-merchant";
        document.body.appendChild(outer);
        for (const host of [origin, "https://foreign.example.test"]) {
          const inner = outer.contentDocument!.createElement("iframe");
          inner.src = `${host}${path}`;
          outer.contentDocument!.body.appendChild(inner);
        }
      },
      { path, origin: CLIENT_BASE_URL },
    );
    await expect(
      page
        .frameLocator("#compat-merchant")
        .frameLocator("iframe")
        .first()
        .locator("body"),
    ).toHaveText("relay");
    const sameOrigin = page
      .frames()
      .find((frame) => frame.url() === `${CLIENT_BASE_URL}${path}`)!;
    await sameOrigin.evaluate(() => {
      Object.assign(window, { compatReplies: [] });
      addEventListener("message", (ev) => {
        if (ev.data?.applePayCanMakePayments)
          (
            window as unknown as { compatReplies: unknown[] }
          ).compatReplies.push(ev.data);
      });
      top!.postMessage(
        {
          hyperApplePayCanMakePayments: true,
          walletRoutingId: "nested-merchant",
        },
        location.origin,
      );
    });
    await expect
      .poll(() =>
        sameOrigin.evaluate(
          () =>
            (window as unknown as { compatReplies: unknown[] }).compatReplies,
        ),
      )
      .toContainEqual({
        applePayCanMakePayments: true,
        componentName: "payment",
        walletRoutingId: "nested-merchant",
      });
    // The foreign child and a same-origin popup must not gain the merchant frame's authority.
    const foreign = page
      .frames()
      .find((frame) => frame.url() === `https://foreign.example.test${path}`)!;
    await foreign.evaluate((origin) => {
      Object.assign(window, { compatReplies: [] });
      addEventListener("message", (ev) => {
        if (ev.data?.applePayCanMakePayments)
          (
            window as unknown as { compatReplies: unknown[] }
          ).compatReplies.push(ev.data);
      });
      top!.postMessage({ hyperApplePayCanMakePayments: true }, origin);
    }, new URL(CLIENT_BASE_URL).origin);
    const popupPromise = context.waitForEvent("page");
    await page.evaluate(() => window.open("about:blank"));
    const popup = await popupPromise;
    await popup.evaluate((origin) => {
      Object.assign(window, { compatReplies: [] });
      addEventListener("message", (ev) => {
        if (ev.data?.applePayCanMakePayments)
          (
            window as unknown as { compatReplies: unknown[] }
          ).compatReplies.push(ev.data);
      });
      opener.postMessage({ hyperApplePayCanMakePayments: true }, origin);
    }, new URL(CLIENT_BASE_URL).origin);
    // A subsequent accepted request gives a delivery barrier in the top window.
    const accepted = await sameOrigin.evaluate(
      () =>
        (window as unknown as { compatReplies: unknown[] }).compatReplies
          .length,
    );
    await sameOrigin.evaluate(() =>
      top!.postMessage({ hyperApplePayCanMakePayments: true }, location.origin),
    );
    await expect
      .poll(() =>
        sameOrigin.evaluate(
          () =>
            (window as unknown as { compatReplies: unknown[] }).compatReplies
              .length,
        ),
      )
      .toBeGreaterThan(accepted);
    expect(
      await foreign.evaluate(
        () => (window as unknown as { compatReplies: unknown[] }).compatReplies,
      ),
    ).toEqual([]);
    expect(
      await popup.evaluate(
        () => (window as unknown as { compatReplies: unknown[] }).compatReplies,
      ),
    ).toEqual([]);
  });

  test("keeps an open overlay trusted when another confirmation starts", async ({
    checkout,
    page,
  }) => {
    await page.addInitScript(() => {
      addEventListener("message", (ev) => {
        let data = ev.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (
          data?.doSubmit &&
          (window as unknown as { compatHoldSubmit?: boolean }).compatHoldSubmit
        )
          ev.stopImmediatePropagation();
      });
    });
    await checkout.open({ body: paymentBody(), waitForReady: true });
    const frame = await page
      .locator(PAYMENT_ELEMENT_IFRAME)
      .elementHandle()
      .then((el) => el!.contentFrame());
    await frame!.evaluate(() =>
      Object.assign(window, { compatHoldSubmit: true }),
    );
    const confirm = (resultKey: string) =>
      page.evaluate(
        ({ resultKey, returnUrl }) => {
          void (
            window as unknown as { HyperMethod: Hyper }
          ).HyperMethod.confirmPayment({
            confirmParams: { return_url: returnUrl },
            redirect: "if_required",
          }).then((result) => Object.assign(window, { [resultKey]: result }));
        },
        { resultKey, returnUrl: CLIENT_BASE_URL },
      );
    const result = (resultKey: string) =>
      page.evaluate(
        (resultKey) =>
          (window as unknown as Record<string, unknown>)[resultKey],
        resultKey,
      );
    await confirm("compatFirstResult");
    const iframeId = (await page
      .locator(PAYMENT_ELEMENT_IFRAME)
      .getAttribute("id"))!.replace("orca-payment-element-iframeRef-", "");
    await frame!.evaluate(
      (iframeId) =>
        parent.postMessage(
          { fullscreen: true, iframeId, param: "paymentloader", metadata: {} },
          "*",
        ),
      iframeId,
    );
    const overlay = page.frameLocator("#orca-fullscreen").locator("body");
    await expect(overlay).toBeAttached();
    // As on main, a later confirmation takes over the response listener.
    await confirm("compatSecondResult");
    await overlay.evaluate(() =>
      parent.postMessage(
        { submitSuccessful: true, data: { status: "succeeded" } },
        "*",
      ),
    );
    await expect
      .poll(() => result("compatSecondResult"))
      .toEqual({ status: "succeeded" });
    await confirm("compatRetryResult");
    await overlay.evaluate((_el, iframeId) => {
      // Both messages are queued before removal; the second must still complete the attempt.
      parent.postMessage({ fullscreen: false, iframeId }, "*");
      parent.postMessage(
        { submitSuccessful: false, error: { type: "test_retry" } },
        "*",
      );
    }, iframeId);
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (
              window as unknown as {
                compatRetryResult?: { error?: { type?: string } };
              }
            ).compatRetryResult?.error?.type,
        ),
      )
      .toBe("test_retry");
  });
});
