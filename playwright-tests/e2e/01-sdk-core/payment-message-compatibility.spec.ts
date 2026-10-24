import {
  test,
  expect,
  paymentBody,
  PAYMENT_ELEMENT_IFRAME,
  CLIENT_BASE_URL,
  SDK_URL,
  stripeCards,
} from "../../fixtures";

type Hyper = {
  elements(options: { clientSecret: string }): {
    create(type: string): {
      mount(selector: string): void;
      unmount(): void;
      destroy(): void;
      on(event: string, callback: () => Promise<void>): void;
    };
    createCardForm(): {
      create(type: string, options: object): { mount(selector: string): void };
    };
  };
  confirmPayment(payload: object): Promise<unknown>;
  confirmCardPayment(clientSecret: string, data?: object): Promise<unknown>;
  confirmOneClickPayment(payload: object, result: boolean): Promise<unknown>;
};

test.describe("Payment message compatibility @hermetic-only", () => {
  test("ignores a removed widget's delayed retrieval while another widget remains mounted", async ({
    checkout,
    page,
  }) => {
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await page.evaluate((clientSecret) => {
      const hyper = (window as unknown as { HyperMethod: Hyper }).HyperMethod;
      const first = hyper.elements({ clientSecret }).create("payment");
      first.mount("#orca-elements-payment-element-payment-element");
      Object.assign(window, { compatPollingFirst: first });
    }, intent.clientSecret);
    await expect(
      page
        .frameLocator(PAYMENT_ELEMENT_IFRAME)
        .getByRole("region", { name: "Payment Section", exact: true }),
    ).toBeVisible();
    await page.evaluate((clientSecret) => {
      const hyper = (window as unknown as { HyperMethod: Hyper }).HyperMethod;
      const node = document.createElement("div");
      node.id = "compat-poll-second";
      document.body.appendChild(node);
      hyper
        .elements({ clientSecret })
        .create("payment")
        .mount("#compat-poll-second");
    }, intent.clientSecret);
    const secondSelector = "#orca-payment-element-iframeRef-compat-poll-second";
    await expect(
      page.frameLocator(secondSelector).locator("body"),
    ).toBeAttached();
    // Wait for both real bootstrap handshakes before asking the first widget to poll.
    for (const selector of [PAYMENT_ELEMENT_IFRAME, secondSelector]) {
      await expect(
        page
          .frameLocator(selector)
          .getByRole("region", { name: "Payment Section", exact: true }),
      ).toBeVisible();
    }
    let release!: () => void;
    let started!: () => void;
    const pending = new Promise<void>((resolve) => {
      release = resolve;
    });
    const requested = new Promise<void>((resolve) => {
      started = resolve;
    });
    await page.route("**/payments/**", async (route) => {
      const url = new URL(route.request().url());
      if (
        route.request().method() !== "GET" ||
        url.searchParams.get("force_sync") !== "true"
      )
        return route.fallback();
      started();
      await pending;
      await route.fulfill({
        json: {
          status: "succeeded",
          return_url: CLIENT_BASE_URL,
          payment_id: intent.paymentId,
        },
      });
    });
    await page
      .frameLocator(PAYMENT_ELEMENT_IFRAME)
      .locator("body")
      .evaluate(
        (_el, url) => parent.postMessage({ openurl_if_required: url }, "*"),
        CLIENT_BASE_URL,
      );
    await requested;
    await page.evaluate(() =>
      (
        window as unknown as { compatPollingFirst: { unmount(): void } }
      ).compatPollingFirst.unmount(),
    );
    await page
      .frameLocator(secondSelector)
      .locator("body")
      .evaluate(() =>
        parent.postMessage(
          {
            fullscreen: true,
            iframeId: "compat-poll-second",
            param: "paymentloader",
            metadata: {},
          },
          "*",
        ),
      );
    await expect(
      page.frameLocator("#orca-fullscreen").locator("body"),
    ).toBeAttached();
    const response = page.waitForResponse(
      (response) =>
        new URL(response.url()).searchParams.get("force_sync") === "true",
    );
    release();
    await (await response).finished();
    // A message round trip runs after the fetch continuation and any queued overlay close.
    await page.evaluate(
      () =>
        new Promise<void>((resolve) => {
          const barrier = (event: MessageEvent) => {
            if (event.data?.compatPollBarrier) {
              removeEventListener("message", barrier);
              resolve();
            }
          };
          addEventListener("message", barrier);
          postMessage({ compatPollBarrier: true }, location.origin);
        }),
    );
    await expect(page.locator("#orca-fullscreen")).toHaveCount(1);
  });

  for (const method of ["confirmPayment", "sdkButton", "retrieval"] as const) {
    test(`allows retry after ${method} navigation is canceled`, async ({
      checkout,
      page,
      sdk,
    }) => {
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      await sdk.enterCardDetails(stripeCards.successCard);
      let dismissed = 0;
      page.on("dialog", async (dialog) => {
        expect(dialog.type()).toBe("beforeunload");
        await dialog.dismiss();
        dismissed++;
      });
      await page.evaluate(() =>
        addEventListener("beforeunload", (event) => {
          event.preventDefault();
          event.returnValue = "";
        }),
      );
      if (method === "sdkButton") {
        await sdk.paymentElement
          .locator("body")
          .evaluate(
            (_el, url) =>
              parent.postMessage(
                { handleSdkConfirm: { confirmParams: { return_url: url } } },
                "*",
              ),
            CLIENT_BASE_URL,
          );
      } else {
        await page.evaluate(
          ({ method, clientSecret, url }) => {
            const hyper = (window as unknown as { HyperMethod: Hyper })
              .HyperMethod;
            const payload = {
              confirmParams: { return_url: url },
              redirect: "always",
            };
            const attempt =
              method === "retrieval"
                ? hyper.confirmOneClickPayment(payload, true)
                : hyper.confirmPayment(payload);
            void attempt.then((result) =>
              Object.assign(window, { compatNavigationResult: result }),
            );
          },
          { method, clientSecret: intent.clientSecret, url: CLIENT_BASE_URL },
        );
        if (method === "retrieval") {
          await sdk.paymentElement.locator("body").evaluate((_el, url) => {
            parent.postMessage({ confirmParams: { redirect: "always" } }, "*");
            parent.postMessage({ openurl_if_required: url }, "*");
          }, CLIENT_BASE_URL);
        }
      }
      await expect.poll(() => dismissed).toBeGreaterThan(0);
      expect(page.url()).toBe(new URL(intent.url).href);
      if (method !== "sdkButton") {
        await expect
          .poll(() =>
            page.evaluate(
              () =>
                (window as unknown as { compatNavigationResult?: unknown })
                  .compatNavigationResult,
            ),
          )
          .toBeTruthy();
      }
      const retry = await page.evaluate(
        (url) =>
          (
            window as unknown as { HyperMethod: Hyper }
          ).HyperMethod.confirmPayment({
            confirmParams: { return_url: url },
            redirect: "if_required",
          }),
        CLIENT_BASE_URL,
      );
      expect(retry).not.toMatchObject({
        error: { type: "confirmation_in_progress" },
      });
    });
  }

  for (const outcome of ["canceled", "declined by the merchant"] as const) {
    test(`allows card confirmation after a one-click Apple Pay sheet is ${outcome}`, async ({
      checkout,
      page,
      sdk,
      hermetic,
    }) => {
      await page.addInitScript(
        (outcome) =>
          Object.defineProperty(window, "ApplePaySession", {
            configurable: true,
            writable: true,
            value: class {
              oncancel?: (event: object) => void;
              onvalidatemerchant?: (event: object) => void;
              onpaymentauthorized?: (event: object) => void;
              static canMakePayments() {
                return true;
              }
              begin() {
                const state = window as unknown as {
                  compatAppleSessions?: number;
                };
                state.compatAppleSessions =
                  (state.compatAppleSessions ?? 0) + 1;
                queueMicrotask(() =>
                  outcome === "canceled"
                    ? this.oncancel?.({})
                    : this.onvalidatemerchant?.({}),
                );
              }
              abort() {
                // Providers can report cancellation synchronously while aborting validation.
                this.oncancel?.({});
                this.onpaymentauthorized?.({ payment: {} });
              }
              completeMerchantValidation() {
                throw new Error("Declined sessions must be aborted");
              }
            },
          }),
        outcome,
      );
      hermetic.override("sessionTokens", {
        session_token: [
          {
            wallet_name: "apple_pay",
            connector: "stripe",
            session_token_data: {},
            payment_request_data: {
              country_code: "US",
              currency_code: "USD",
              merchant_capabilities: ["supports3DS"],
              supported_networks: ["visa"],
              total: { label: "Cancel test", amount: "29.99" },
            },
          },
        ],
      });
      hermetic.override("clientList", (route) => ({
        ...route,
        body: {
          ...(route.body as object),
          payment_methods_enabled: [
            ...(route.body as { payment_methods_enabled: unknown[] })
              .payment_methods_enabled,
            {
              payment_method: "wallet",
              payment_method_type: "apple_pay",
              payment_experience: ["invoke_sdk_client"],
            },
          ],
        },
      }));
      const intent = await checkout.open({
        body: paymentBody(),
        options: { wallets: { walletReturnUrl: CLIENT_BASE_URL } },
      });
      const appleButton = sdk.paymentElement.locator(
        ".apple-pay-button-with-text",
      );
      await expect(appleButton).toBeVisible();
      if (outcome === "declined by the merchant") {
        await page.evaluate((clientSecret) => {
          const widget = (
            window as unknown as { HyperMethod: Hyper }
          ).HyperMethod.elements({ clientSecret }).create("payment");
          widget.on("paymentButtonClick", () =>
            Promise.reject(new Error("Merchant declined")),
          );
        }, intent.clientSecret);
      }
      await page.evaluate(() => {
        Object.assign(window, { compatWalletFailures: [] });
        addEventListener("message", (event) => {
          if (event.data?.submitSuccessful === false) {
            (
              window as unknown as { compatWalletFailures: unknown[] }
            ).compatWalletFailures.push(event.data);
          }
        });
      });
      await page.evaluate((returnUrl) => {
        void (
          window as unknown as { HyperMethod: Hyper }
        ).HyperMethod.confirmOneClickPayment(
          { confirmParams: { return_url: returnUrl } },
          true,
        ).then((result) =>
          Object.assign(window, { compatWalletCancelResult: result }),
        );
      }, CLIENT_BASE_URL);
      await appleButton.click();
      await expect
        .poll(() =>
          page.evaluate(
            () =>
              (
                window as unknown as {
                  compatWalletCancelResult?: { error?: unknown };
                }
              ).compatWalletCancelResult?.error,
          ),
        )
        .toBeTruthy();
      await sdk.selectPaymentMethod("Card");
      await sdk.enterCardDetails(stripeCards.successCard);
      const retry = await page.evaluate(
        (returnUrl) =>
          (
            window as unknown as { HyperMethod: Hyper }
          ).HyperMethod.confirmPayment({
            confirmParams: { return_url: returnUrl },
            redirect: "if_required",
          }),
        CLIENT_BASE_URL,
      );
      expect(retry).toMatchObject({ status: "succeeded" });
      const counts = await page.evaluate(() => {
        const state = window as unknown as {
          compatWalletFailures: unknown[];
          compatAppleSessions: number;
        };
        return {
          failures: state.compatWalletFailures.length,
          sessions: state.compatAppleSessions,
        };
      });
      // The playground and loader bundles both register the native relay. Each session
      // must report only once, including when abort triggers more provider callbacks.
      expect(counts.sessions).toBeGreaterThan(0);
      expect(counts.failures).toBe(counts.sessions);
    });
  }

  for (const action of ["unmount", "destroy"] as const) {
    test(`settles a pending confirmation on ${action} and permits remount`, async ({
      checkout,
      page,
      sdk,
    }) => {
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      await page.evaluate((clientSecret) => {
        const hyper = (window as unknown as { HyperMethod: Hyper }).HyperMethod;
        const element = hyper.elements({ clientSecret }).create("payment");
        element.mount("#orca-elements-payment-element-payment-element");
        Object.assign(window, { compatLifecycleElement: element });
      }, intent.clientSecret);
      await expect(sdk.paymentElement.locator("body")).toBeAttached();
      await page.evaluate(() => {
        void (
          window as unknown as { HyperMethod: Hyper }
        ).HyperMethod.confirmOneClickPayment({}, true).then((result) =>
          Object.assign(window, { compatRemovedResult: result }),
        );
      });
      await page.evaluate(
        (action) =>
          (
            window as unknown as {
              compatLifecycleElement: { unmount(): void; destroy(): void };
            }
          ).compatLifecycleElement[action](),
        action,
      );
      await expect
        .poll(() =>
          page.evaluate(
            () =>
              (
                window as unknown as {
                  compatRemovedResult?: { error?: { type?: string } };
                }
              ).compatRemovedResult?.error?.type,
          ),
        )
        .toBe("payment_element_unmounted");
      await page.evaluate(
        (clientSecret) =>
          (window as unknown as { HyperMethod: Hyper }).HyperMethod.elements({
            clientSecret,
          })
            .create("payment")
            .mount("#orca-elements-payment-element-payment-element"),
        intent.clientSecret,
      );
      await sdk.enterCardDetails(stripeCards.successCard);
      const retry = await page.evaluate(
        (returnUrl) =>
          (
            window as unknown as { HyperMethod: Hyper }
          ).HyperMethod.confirmPayment({
            confirmParams: { return_url: returnUrl },
            redirect: "if_required",
          }),
        CLIENT_BASE_URL,
      );
      expect(retry).toMatchObject({ status: "succeeded" });
    });
  }
  test("releases confirmation ownership after listener setup fails", async ({
    checkout,
    page,
  }) => {
    await checkout.open({ body: paymentBody(), waitForReady: true });
    await page.evaluate((returnUrl) => {
      const addListener = window.addEventListener;
      window.addEventListener = function (
        ...args: Parameters<typeof addListener>
      ) {
        if (args[0] === "message") {
          window.addEventListener = addListener;
          throw new Error("compat-listener-setup-failed");
        }
        return addListener.apply(window, args);
      } as typeof addListener;
      void (
        window as unknown as { HyperMethod: Hyper }
      ).HyperMethod.confirmPayment({
        confirmParams: { return_url: returnUrl },
        redirect: "if_required",
      }).catch((error) =>
        Object.assign(window, { compatSetupError: String(error) }),
      );
    }, CLIENT_BASE_URL);
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (window as unknown as { compatSetupError?: string })
              .compatSetupError,
        ),
      )
      .toBeTruthy();
    // Invalid card input produces an ordinary validation response on the next attempt.
    const retry = await page.evaluate(
      (returnUrl) =>
        (
          window as unknown as { HyperMethod: Hyper }
        ).HyperMethod.confirmPayment({
          confirmParams: { return_url: returnUrl },
          redirect: "if_required",
        }),
      CLIENT_BASE_URL,
    );
    expect(retry).toMatchObject({ error: { type: "validation_error" } });
  });

  test("keeps simultaneous confirmations on separate Hyper instances independent", async ({
    checkout,
    page,
  }) => {
    await page.addInitScript(() =>
      addEventListener("message", (ev) => {
        let data = ev.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (data?.doSubmit) ev.stopImmediatePropagation();
      }),
    );
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await page.evaluate((clientSecret) => {
      const state = window as unknown as {
        Hyper: (key: string, options: object) => Hyper;
        HyperMethod: Hyper;
        compatOriginalHyper: Hyper;
        compatOtherHyper: Hyper;
      };
      const node = document.createElement("div");
      node.id = "compat-second-instance";
      document.body.appendChild(node);
      state.compatOriginalHyper = state.HyperMethod;
      state.compatOtherHyper = state.Hyper("pk_snd_compat_independent", {
        isForceInit: true,
      });
      addEventListener("message", (event) => {
        let data = event.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        const iframe = document.querySelector<HTMLIFrameElement>(
          "#orca-payment-element-iframeRef-compat-second-instance",
        );
        if (data?.ready && event.source === iframe?.contentWindow)
          Object.assign(window, { compatOtherReady: true });
      });
      state.compatOtherHyper
        .elements({ clientSecret })
        .create("payment")
        .mount("#compat-second-instance");
    }, intent.clientSecret);
    const other = page
      .frameLocator("#orca-payment-element-iframeRef-compat-second-instance")
      .locator("body");
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (window as unknown as { compatOtherReady?: boolean })
              .compatOtherReady,
        ),
      )
      .toBe(true);
    await page.evaluate((returnUrl) => {
      const state = window as unknown as {
        compatOriginalHyper: Hyper;
        compatOtherHyper: Hyper;
      };
      const payload = {
        confirmParams: { return_url: returnUrl },
        redirect: "if_required",
      };
      void state.compatOriginalHyper
        .confirmPayment(payload)
        .then((result) =>
          Object.assign(window, { compatOriginalResult: result }),
        );
      void state.compatOtherHyper
        .confirmPayment(payload)
        .then((result) => Object.assign(window, { compatOtherResult: result }));
    }, CLIENT_BASE_URL);
    await other.evaluate(() =>
      parent.postMessage(
        { submitSuccessful: true, data: { owner: "second" } },
        "*",
      ),
    );
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (window as unknown as { compatOtherResult?: unknown })
              .compatOtherResult,
        ),
      )
      .toEqual({ owner: "second" });
    expect(
      await page.evaluate(
        () =>
          (window as unknown as { compatOriginalResult?: unknown })
            .compatOriginalResult,
      ),
    ).toBeUndefined();
    await page
      .frameLocator(PAYMENT_ELEMENT_IFRAME)
      .locator("body")
      .evaluate(() =>
        parent.postMessage(
          { submitSuccessful: true, data: { owner: "original" } },
          "*",
        ),
      );
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (window as unknown as { compatOriginalResult?: unknown })
              .compatOriginalResult,
        ),
      )
      .toEqual({ owner: "original" });
  });

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

  for (const [first, second] of [
    ["confirmPayment", "confirmPayment"],
    ["confirmPayment", "confirmCardPayment"],
    ["confirmCardPayment", "confirmPayment"],
    ["confirmCardPayment", "confirmCardPayment"],
  ] as const) {
    test(`preserves an active ${first} overlay when ${second} overlaps`, async ({
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
            (window as unknown as { compatHoldSubmit?: boolean })
              .compatHoldSubmit
          )
            ev.stopImmediatePropagation();
        });
      });
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      const frame = await page
        .locator(PAYMENT_ELEMENT_IFRAME)
        .elementHandle()
        .then((el) => el!.contentFrame());
      await frame!.evaluate(() =>
        Object.assign(window, { compatHoldSubmit: true }),
      );
      await page.evaluate(() => {
        void (
          window as unknown as { HyperMethod: Hyper }
        ).HyperMethod.confirmOneClickPayment({}, false).then((result) =>
          Object.assign(window, { compatResetResult: result }),
        );
      });
      await expect
        .poll(() =>
          page.evaluate(
            () =>
              (window as unknown as { compatResetResult?: unknown })
                .compatResetResult,
          ),
        )
        .toEqual({});
      await page.evaluate(
        ({ first, clientSecret, returnUrl }) => {
          const hyper = (window as unknown as { HyperMethod: Hyper })
            .HyperMethod;
          const promise =
            first === "confirmCardPayment"
              ? hyper.confirmCardPayment(clientSecret)
              : hyper.confirmPayment({
                  confirmParams: { return_url: returnUrl },
                  redirect: "if_required",
                });
          void promise.then((result) =>
            Object.assign(window, { compatFirstResult: result }),
          );
        },
        {
          first,
          clientSecret: intent.clientSecret,
          returnUrl: CLIENT_BASE_URL,
        },
      );
      await frame!.evaluate(() =>
        parent.postMessage({ ready: true, iframeHeight: 400 }, "*"),
      );
      const iframeId = (await page
        .locator(PAYMENT_ELEMENT_IFRAME)
        .getAttribute("id"))!.replace("orca-payment-element-iframeRef-", "");
      await frame!.evaluate(
        (iframeId) =>
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
      const overlay = page.frameLocator("#orca-fullscreen").locator("body");
      await expect(overlay).toBeAttached();
      await page.evaluate(() => {
        void (
          window as unknown as { HyperMethod: Hyper }
        ).HyperMethod.confirmOneClickPayment({}, false).then((result) =>
          Object.assign(window, { compatActiveResetResult: result }),
        );
      });
      await expect
        .poll(() =>
          page.evaluate(
            () =>
              (window as unknown as { compatActiveResetResult?: unknown })
                .compatActiveResetResult,
          ),
        )
        .toEqual({});
      await page.evaluate(
        ({ second, clientSecret, returnUrl }) => {
          const hyper = (window as unknown as { HyperMethod: Hyper })
            .HyperMethod;
          const promise =
            second === "confirmPayment"
              ? hyper.confirmPayment({
                  confirmParams: { return_url: returnUrl },
                  redirect: "if_required",
                })
              : hyper.confirmCardPayment(clientSecret);
          void promise.then((result) =>
            Object.assign(window, { compatSecondResult: result }),
          );
        },
        {
          second,
          clientSecret: intent.clientSecret,
          returnUrl: CLIENT_BASE_URL,
        },
      );
      await expect
        .poll(() =>
          page.evaluate(
            () =>
              (
                window as unknown as {
                  compatSecondResult?: { error?: { type?: string } };
                }
              ).compatSecondResult?.error?.type,
          ),
        )
        .toBe("confirmation_in_progress");
      await overlay.evaluate(() =>
        parent.postMessage(
          { submitSuccessful: true, data: { status: "succeeded" } },
          "*",
        ),
      );
      await expect
        .poll(() =>
          page.evaluate(
            () =>
              (window as unknown as { compatFirstResult?: unknown })
                .compatFirstResult,
          ),
        )
        .toEqual(
          first === "confirmCardPayment"
            ? { submitSuccessful: true, data: { status: "succeeded" } }
            : { status: "succeeded" },
        );
      // Settling the first confirmation unlocks a subsequent attempt, retaining a still-open overlay.
      await page.evaluate((returnUrl) => {
        void (
          window as unknown as { HyperMethod: Hyper }
        ).HyperMethod.confirmPayment({
          confirmParams: { return_url: returnUrl },
          redirect: "if_required",
        }).then((result) =>
          Object.assign(window, { compatRetryResult: result }),
        );
      }, CLIENT_BASE_URL);
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
  }
});
