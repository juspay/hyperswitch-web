import type { Page } from "@playwright/test";
import type { Hermetic } from "../../fixtures/hermetic";
import {
  test,
  expect,
  paymentBody,
  stripeCards,
  slowConfirm,
  testIds,
  PAYMENT_ELEMENT_IFRAME,
  CLIENT_BASE_URL,
  HYPERSWITCH_API_URL,
  SDK_URL,
} from "../../fixtures";

type CustomerPaymentSession = {
  confirmWithCustomerDefaultPaymentMethod(payload: unknown): Promise<unknown>;
};

type SessionHyper = {
  elements(options: { clientSecret: string }): {
    create(type: string): {
      mount(selector: string): void;
      unmount(): void;
      on(event: string, callback: () => void): void;
    };
    createCardForm(): {
      create(
        type: string,
        options: Record<string, unknown>,
      ): { mount(selector: string): void };
    };
  };
  paymentMethodsManagementElements(options: { sdkAuthorization: string }): {
    create(
      type: string,
      options: Record<string, unknown>,
    ): {
      mount(selector: string): void;
      on(event: string, callback: () => void): void;
    };
  };
  initPaymentSession(options: {
    clientSecret: string;
    sdkAuthorization: string;
  }): {
    updateIntent(
      callback: () => Promise<{ sdkAuthorization: string }>,
    ): Promise<unknown>;
    getCustomerSavedPaymentMethods(): Promise<CustomerPaymentSession>;
  };
};

declare global {
  interface Window {
    boundarySession: CustomerPaymentSession;
    boundaryCvcResult: unknown;
    boundaryCvcRequestId: string;
    boundaryUpdateResult?: { status?: string; error?: unknown };
    boundaryPrefetchRequest: boolean;
  }
}

// Exercise actual browser senders; the barrier only observes delivery order.
async function sendFromSibling(
  page: Page,
  payload: unknown,
  targetSelector?: string,
  origin = "https://untrusted.example.test",
) {
  const url = `${origin}/boundary-sender.html`;
  await page.route(url, (route) =>
    route.fulfill({ contentType: "text/html", body: "<body>sender</body>" }),
  );
  await page.evaluate((url) => {
    document.querySelector("#boundary-sender")?.remove();
    const frame = document.createElement("iframe");
    frame.id = "boundary-sender";
    frame.src = url;
    document.body.appendChild(frame);
  }, url);
  await expect(
    page.frameLocator("#boundary-sender").locator("body"),
  ).toHaveText("sender");
  const index = targetSelector
    ? await page
        .locator(targetSelector)
        .evaluate((el) =>
          Array.from(window.frames).indexOf(
            (el as HTMLIFrameElement).contentWindow!,
          ),
        )
    : -1;
  await page
    .frameLocator("#boundary-sender")
    .locator("body")
    .evaluate(
      async (_el, { payload, index }) => {
        const target = index < 0 ? window.parent : window.parent.frames[index];
        const channel = new MessageChannel();
        const delivered = new Promise<void>((resolve) => {
          channel.port1.onmessage = () => {
            channel.port1.close();
            resolve();
          };
        });
        target.postMessage(payload, "*");
        target.postMessage({ boundaryBarrier: true }, "*", [channel.port2]);
        await delivered;
        if (index >= 0) {
          for (let i = 0; i < (target.frames?.length ?? 0); i++) {
            const nestedChannel = new MessageChannel();
            const nestedDelivered = new Promise<void>((resolve) => {
              nestedChannel.port1.onmessage = () => {
                nestedChannel.port1.close();
                resolve();
              };
            });
            target.frames[i].postMessage({ boundaryBarrier: true }, "*", [
              nestedChannel.port2,
            ]);
            await nestedDelivered;
          }
        }
      },
      { payload, index },
    );
}

async function enableApplePay(page: Page, hermetic: Hermetic) {
  await page.addInitScript(() =>
    Object.defineProperty(window, "ApplePaySession", {
      configurable: true,
      writable: true,
      value: class {
        static canMakePayments() {
          return true;
        }
      },
    }),
  );
  hermetic.override("sessionTokens", {
    session_token: [
      {
        wallet_name: "apple_pay",
        connector: "stripe",
        payment_request_data: {
          country_code: "US",
          currency_code: "USD",
          merchant_capabilities: ["supports3DS"],
          supported_networks: ["visa"],
          total: { label: "Boundary Merchant", amount: "29.99" },
        },
        session_token_data: {},
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
          payment_experience: [
            {
              payment_experience_type: "invoke_sdk_client",
              eligible_connectors: ["trustpay"],
            },
          ],
        },
      ],
    },
  }));
}

async function observeWalletReplies(page: Page) {
  await page.addInitScript(() => {
    const deliveries: unknown[] = [];
    const routes: string[] = [];
    Object.assign(window, {
      walletDeliveries: deliveries,
      walletRoutes: routes,
    });
    window.addEventListener("message", (ev) => {
      let data = ev.data;
      if (typeof data === "string") {
        try {
          data = JSON.parse(data);
        } catch {
          return;
        }
      }
      if (window === window.top && data?.hyperApplePayCanMakePayments) {
        routes.push(data.walletRoutingId);
      }
      if (window !== window.top && data?.applePayPaymentToken) {
        deliveries.push(data);
        // Observe delivery without starting a synthetic wallet confirmation.
        ev.stopImmediatePropagation();
      }
    });
  });
}

async function mountCvcSession(page: Page, clientSecret: string) {
  await page.waitForFunction(
    () => !!(window as unknown as { HyperMethod?: SessionHyper }).HyperMethod,
  );
  await page.evaluate(async (clientSecret) => {
    const hyper = (window as unknown as { HyperMethod: SessionHyper })
      .HyperMethod;
    const node = document.createElement("div");
    node.id = "boundary-cvc";
    document.body.appendChild(node);
    hyper.elements({ clientSecret }).create("cardCvc").mount("#boundary-cvc");
    const sdkAuthorization = btoa(
      `payment_id=${clientSecret.split("_secret_")[0]},client_secret=${clientSecret}`,
    );
    window.boundarySession = await hyper
      .initPaymentSession({ clientSecret, sdkAuthorization })
      .getCustomerSavedPaymentMethods();
  }, clientSecret);
  const cvc = page.frameLocator("#orca-payment-element-iframeRef-boundary-cvc");
  await cvc.getByTestId(testIds.cardCVVInputTestId).fill("1234");
  return cvc;
}

test.describe("Remaining payment message boundaries @hermetic-only", () => {
  test.beforeEach(async ({ page }) => {
    await page.addInitScript(() =>
      window.addEventListener("message", (ev) => {
        let data = ev.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (data?.boundaryBarrier) ev.ports[0]?.postMessage(true);
        if (data?.requestCVCConfirm)
          window.boundaryCvcRequestId = data.requestCVCConfirm.requestId;
      }),
    );
  });

  test("rejects a direct sibling doSubmit on a saved card without a CVC requirement", async ({
    checkout,
    sdk,
    page,
    hermetic,
    credentials,
  }) => {
    hermetic.load("02-cards/07-saved-cards.json");
    hermetic.override("clientList", (route) => ({
      ...route,
      body: {
        ...(route.body as object),
        customer_payment_methods: (
          route.body as { customer_payment_methods: object[] }
        ).customer_payment_methods.map((method) => ({
          ...method,
          requires_cvv: false,
        })),
      },
    }));
    await checkout.open({
      body: paymentBody({ customer_id: "hyperswitch_sdk_demo_id" }),
    });
    await sdk.text("4 digit").first().click();
    slowConfirm(hermetic, 2_000);
    for (const origin of ["https://untrusted.example.test", SDK_URL]) {
      await sendFromSibling(
        page,
        JSON.stringify({
          doSubmit: true,
          confirmTimestamp: Date.now() + 10_000,
          readyTimestamp: 0,
          confirmParams: {
            return_url: CLIENT_BASE_URL,
            publishableKey: credentials.publishableKey,
          },
        }),
        PAYMENT_ELEMENT_IFRAME,
        origin,
      );
      expect(hermetic.calls("confirm")).toHaveLength(0);
    }
    slowConfirm(hermetic, 0);
    await sdk.submit();
    await expect(page.getByText("Thanks for your order!")).toBeVisible();
    expect(hermetic.calls("confirm")).toHaveLength(1);
  });

  test("ignores forged DDC actions and accepts its own iframe response", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    const ddcUrl = "https://ddc.example.test/collect";
    await page.route(ddcUrl, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: "<body>Collecting device data</body>",
      }),
    );
    hermetic.override("confirm", {
      status: "requires_customer_action",
      next_action: {
        type: "invoke_ddc",
        ddc_data: { iframe_url: ddcUrl, timeout_ms: 30_000 },
      },
    });
    await checkout.open({ body: paymentBody(), waitForReady: true });
    await sdk.enterCardDetails(stripeCards.successCard);
    await sdk.submit();
    const ddc = sdk.paymentElement.locator("#ddc-iframe");
    await expect(ddc).toBeAttached();
    await sendFromSibling(
      page,
      {
        next_action: {
          type: "redirect_to_url",
          url: "https://untrusted.example.test/redirect",
          redirect_mode: "always",
        },
      },
      PAYMENT_ELEMENT_IFRAME,
    );
    await expect(ddc).toBeAttached();
    await sendFromSibling(
      page,
      {
        next_action: {
          type: "redirect_to_url",
          url: CLIENT_BASE_URL,
          redirect_mode: "always",
        },
      },
      PAYMENT_ELEMENT_IFRAME,
      "https://ddc.example.test",
    );
    await expect(ddc).toBeAttached();
    await sdk.paymentElement.locator("body").evaluate(() => {
      const frame = document.querySelector<HTMLIFrameElement>("#ddc-iframe")!;
      window.dispatchEvent(
        new MessageEvent("message", {
          source: frame.contentWindow,
          origin: "https://untrusted.example.test",
          data: {
            next_action: {
              type: "redirect_to_url",
              url: "https://untrusted.example.test/redirect",
            },
          },
        }),
      );
    });
    await expect(ddc).toBeAttached();
    hermetic.setIntent({ status: "succeeded" });
    await sdk.paymentElement
      .frameLocator("#ddc-iframe")
      .locator("body")
      .evaluate((_el, url) => {
        window.parent.postMessage(
          {
            next_action: {
              type: "redirect_to_url",
              url,
              redirect_mode: "if_required",
            },
          },
          "*",
        );
      }, CLIENT_BASE_URL);
    await expect(page.getByText("Thanks for your order!")).toBeVisible();
  });

  test("rejects wallet confirmation controls from a sibling", async ({
    checkout,
    page,
    hermetic,
    sdk,
  }) => {
    await enableApplePay(page, hermetic);
    await checkout.open({
      body: paymentBody(),
      options: { wallets: { walletReturnUrl: CLIENT_BASE_URL } },
    });
    await expect(
      sdk.paymentElement.locator(".apple-pay-button-with-text"),
    ).toBeVisible();
    await sendFromSibling(
      page,
      JSON.stringify({ applePayConfirmRequest: true }),
      PAYMENT_ELEMENT_IFRAME,
    );
    expect(hermetic.calls("confirm")).toHaveLength(0);
    await page.locator(PAYMENT_ELEMENT_IFRAME).evaluate((el) => {
      (el as HTMLIFrameElement).contentWindow!.postMessage(
        JSON.stringify({ applePayConfirmRequest: true }),
        new URL((el as HTMLIFrameElement).src).origin,
      );
    });
    await hermetic.waitForCall("confirm");
    expect(hermetic.calls("confirm")).toHaveLength(1);
  });

  for (const navigateWidget of [false, true]) {
    test(`keeps wallet replies inside registered SDK frames${navigateWidget ? " after navigation" : ""}`, async ({
      checkout,
      page,
      sdk,
      hermetic,
    }) => {
      await enableApplePay(page, hermetic);
      await observeWalletReplies(page);
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      await expect(
        sdk.paymentElement.locator(".apple-pay-button-with-text"),
      ).toBeVisible();
      if (!navigateWidget) {
        await page.evaluate((clientSecret) => {
          const node = document.createElement("div");
          node.id = "boundary-second-payment";
          document.body.appendChild(node);
          (
            window as unknown as { HyperMethod: SessionHyper }
          ).HyperMethod.elements({ clientSecret })
            .create("payment")
            .mount("#boundary-second-payment");
        }, intent.clientSecret);
        await expect(
          page
            .frameLocator(
              "#orca-payment-element-iframeRef-boundary-second-payment",
            )
            .locator(".apple-pay-button-with-text"),
        ).toBeVisible();
      }
      const receiverUrl =
        "https://wallet-receiver.example.test/ad?componentName=payment";
      const sdkReceiverUrl = `${SDK_URL}/unregistered?componentName=payment`;
      for (const url of [receiverUrl, sdkReceiverUrl]) {
        await page.route(url, (route) =>
          route.fulfill({
            contentType: "text/html",
            body: "<body>receiver</body>",
          }),
        );
      }
      const widgetFrame = page
        .frames()
        .find((frame) =>
          frame.url().includes("/index.html?componentName=payment"),
        )!;
      if (navigateWidget) {
        const frame = widgetFrame;
        // Navigating the browsing context leaves the iframe's declared src unchanged.
        await frame.goto(receiverUrl);
      } else {
        await page.evaluate(
          (urls) => {
            urls.forEach((url, index) => {
              const iframe = document.createElement("iframe");
              iframe.id = `wallet-receiver-${index}`;
              iframe.src = url;
              document.body.appendChild(iframe);
            });
          },
          [receiverUrl, sdkReceiverUrl],
        );
        for (const index of [0, 1]) {
          await expect(
            page.frameLocator(`#wallet-receiver-${index}`).locator("body"),
          ).toHaveText("receiver");
        }
      }
      // The merchant's same-window Apple Pay relay is a supported authenticated sender.
      for (const componentName of navigateWidget
        ? ["payment", "missing-component"]
        : ["payment"]) {
        await page.evaluate(async (componentName) => {
          const channel = new MessageChannel();
          const delivered = new Promise<void>((resolve) => {
            channel.port1.onmessage = () => resolve();
          });
          window.postMessage(
            {
              applePayPaymentToken: { synthetic: "wallet-token" },
              applePayBillingContact: { emailAddress: "test@example.test" },
              componentName,
              walletRoutingId: (window as unknown as { walletRoutes: string[] })
                .walletRoutes[0],
            },
            location.origin,
          );
          window.postMessage({ boundaryBarrier: true }, location.origin, [
            channel.port2,
          ]);
          await delivered;
          channel.port1.close();
        }, componentName);
      }
      for (const frame of page
        .frames()
        .filter((frame) => frame !== page.mainFrame())) {
        // A round trip to each recipient observes any preceding wallet delivery.
        await frame.evaluate(async () => {
          const channel = new MessageChannel();
          const delivered = new Promise<void>((resolve) => {
            channel.port1.onmessage = () => resolve();
          });
          window.postMessage({ boundaryBarrier: true }, location.origin, [
            channel.port2,
          ]);
          await delivered;
          channel.port1.close();
        });
        const deliveries = await frame.evaluate(
          () =>
            (window as unknown as { walletDeliveries: unknown[] })
              .walletDeliveries,
        );
        const registeredWidget = !navigateWidget && frame === widgetFrame;
        expect(deliveries).toHaveLength(registeredWidget ? 1 : 0);
      }
    });
  }

  test("ignores an old wallet session reply after remounting the same container", async ({
    checkout,
    page,
    hermetic,
  }) => {
    await enableApplePay(page, hermetic);
    await observeWalletReplies(page);
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await page.evaluate((clientSecret) => {
      const node = document.createElement("div");
      node.id = "boundary-remounted-payment";
      document.body.appendChild(node);
      const widget = (
        window as unknown as { HyperMethod: SessionHyper }
      ).HyperMethod.elements({ clientSecret }).create("payment");
      Object.assign(window, { remountedWidget: widget });
      widget.mount("#boundary-remounted-payment");
    }, intent.clientSecret);
    const selector =
      "#orca-payment-element-iframeRef-boundary-remounted-payment";
    await expect(
      page.frameLocator(selector).locator(".apple-pay-button-with-text"),
    ).toBeVisible();
    const previousRoute = await page.evaluate(() =>
      (window as unknown as { walletRoutes: string[] }).walletRoutes.at(-1)!,
    );
    await page.evaluate(() => {
      const widget = (
        window as unknown as {
          remountedWidget: { unmount(): void; mount(selector: string): void };
        }
      ).remountedWidget;
      widget.unmount();
      widget.mount("#boundary-remounted-payment");
    });
    await expect(
      page.frameLocator(selector).locator(".apple-pay-button-with-text"),
    ).toBeVisible();
    const currentRoute = await page.evaluate(() =>
      (window as unknown as { walletRoutes: string[] }).walletRoutes.at(-1)!,
    );
    const deliveries: unknown[] = [];
    for (const walletRoutingId of [previousRoute, currentRoute]) {
      await page.evaluate(async (walletRoutingId) => {
        const channel = new MessageChannel();
        const delivered = new Promise<void>((resolve) => {
          channel.port1.onmessage = () => resolve();
        });
        window.postMessage(
          {
            applePayPaymentToken: { synthetic: "delayed-wallet-token" },
            componentName: "payment",
            walletRoutingId,
          },
          location.origin,
        );
        window.postMessage({ boundaryBarrier: true }, location.origin, [
          channel.port2,
        ]);
        await delivered;
        channel.port1.close();
      }, walletRoutingId);
      deliveries.push(
        await page
          .frameLocator(selector)
          .locator("body")
          .evaluate(async () => {
            const channel = new MessageChannel();
            const delivered = new Promise<void>((resolve) => {
              channel.port1.onmessage = () => resolve();
            });
            window.postMessage({ boundaryBarrier: true }, location.origin, [
              channel.port2,
            ]);
            await delivered;
            channel.port1.close();
            return (window as unknown as { walletDeliveries: unknown[] })
              .walletDeliveries.length;
          }),
      );
    }
    expect(deliveries).toEqual([0, 1]);
    expect(currentRoute).not.toBe(previousRoute);
  });

  test("accepts Paze completion only from the merchant parent", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    hermetic.override("clientList", (route) => ({
      ...route,
      body: {
        ...(route.body as object),
        payment_methods_enabled: [
          ...(route.body as { payment_methods_enabled: unknown[] })
            .payment_methods_enabled,
          {
            payment_method: "wallet",
            payment_method_type: "paze",
            payment_experience: [
              {
                payment_experience_type: "invoke_sdk_client",
                eligible_connectors: ["paze"],
              },
            ],
          },
        ],
      },
    }));
    hermetic.override("sessionTokens", {
      session_token: [
        {
          wallet_name: "paze",
          client_id: "boundary-client",
          client_name: "Boundary Merchant",
          client_profile_id: "boundary-profile",
        },
      ],
    });
    await checkout.open({
      body: paymentBody(),
      waitForReady: true,
      options: { wallets: { walletReturnUrl: CLIENT_BASE_URL } },
    });
    await expect(
      sdk.paymentElement.locator('use[*|href$="#paze"]'),
    ).toBeAttached();
    const payload = JSON.stringify({
      data: { isPaze: true, completeResponse: "synthetic-paze-response" },
    });
    await sendFromSibling(page, payload, PAYMENT_ELEMENT_IFRAME);
    expect(hermetic.calls("confirm")).toHaveLength(0);
    await page.locator(PAYMENT_ELEMENT_IFRAME).evaluate((el, payload) => {
      (el as HTMLIFrameElement).contentWindow!.postMessage(
        payload,
        new URL((el as HTMLIFrameElement).src).origin,
      );
    }, payload);
    await hermetic.waitForCall("confirm");
    expect(hermetic.calls("confirm")).toHaveLength(1);
  });

  test("accepts Plaid public tokens only from the merchant parent", async ({
    checkout,
    sdk,
    page,
    hermetic,
  }) => {
    hermetic.override("clientList", (route) => ({
      ...route,
      body: {
        ...(route.body as object),
        payment_methods_enabled: [
          ...(route.body as { payment_methods_enabled: unknown[] })
            .payment_methods_enabled,
          {
            payment_method: "bank_debit",
            payment_method_type: "ach",
            pm_auth_connector: "plaid",
            payment_experience: [],
          },
        ],
      },
    }));
    hermetic.use({
      name: "authExchange",
      method: "POST",
      path: "/payment_methods/auth/exchange",
      body: {},
    });
    await checkout.open({
      body: paymentBody(),
      waitForReady: true,
      options: { displaySavedPaymentMethods: true },
    });
    await sdk.selectPaymentMethod("ACH Debit");
    await expect(
      sdk.paymentElement.getByRole("button", {
        name: "Add Bank Details",
        exact: true,
      }),
    ).toBeVisible();
    const payload = JSON.stringify({
      isPlaid: true,
      data: { publicToken: "synthetic-public-token", isExited: false },
    });
    await sendFromSibling(page, payload, PAYMENT_ELEMENT_IFRAME);
    expect(hermetic.calls("authExchange")).toHaveLength(0);
    await page.locator(PAYMENT_ELEMENT_IFRAME).evaluate((el, payload) => {
      (el as HTMLIFrameElement).contentWindow!.postMessage(
        payload,
        new URL((el as HTMLIFrameElement).src).origin,
      );
    }, payload);
    await hermetic.waitForCall("authExchange");
    expect(hermetic.calls("authExchange")).toHaveLength(1);
  });

  test("does not send a Plaid token to a widget that navigated away", async ({
    checkout,
    page,
    sdk,
  }) => {
    await page.addInitScript(() => {
      const deliveries: unknown[] = [];
      Object.assign(window, { plaidDeliveries: deliveries });
      window.addEventListener("message", (ev) => {
        let data = ev.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (window !== window.top && data?.isPlaid) {
          deliveries.push(data);
          ev.stopImmediatePropagation();
        }
      });
    });
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await mountCvcSession(page, intent.clientSecret);
    const receiver = page
      .frames()
      .find((frame) => frame.url().includes("componentName=cardCvc"))!;
    const sendPlaid = async () => {
      await sdk.paymentElement.locator("body").evaluate(async () => {
        const channel = new MessageChannel();
        const delivered = new Promise<void>((resolve) => {
          channel.port1.onmessage = () => resolve();
        });
        parent.postMessage(
          { isPlaid: true, public_token: "synthetic-plaid-token" },
          "*",
        );
        parent.postMessage({ boundaryBarrier: true }, "*", [channel.port2]);
        await delivered;
        channel.port1.close();
      });
    };
    await sendPlaid();
    await expect
      .poll(() =>
        receiver.evaluate(
          () =>
            (window as unknown as { plaidDeliveries: unknown[] })
              .plaidDeliveries.length,
        ),
      )
      .toBe(1);
    const receiverUrl = "https://plaid-receiver.example.test/receiver";
    await page.route(receiverUrl, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: "<body>receiver</body>",
      }),
    );
    await receiver.goto(receiverUrl);
    await sendPlaid();
    await receiver.evaluate(async () => {
      const channel = new MessageChannel();
      const delivered = new Promise<void>((resolve) => {
        channel.port1.onmessage = () => resolve();
      });
      window.postMessage({ boundaryBarrier: true }, location.origin, [
        channel.port2,
      ]);
      await delivered;
      channel.port1.close();
    });
    expect(
      await receiver.evaluate(
        () =>
          (window as unknown as { plaidDeliveries: unknown[] }).plaidDeliveries,
      ),
    ).toHaveLength(0);
  });

  test("authenticates appearance metadata before injecting styles", async ({
    checkout,
    page,
    sdk,
  }) => {
    await checkout.open({ body: paymentBody(), waitForReady: true });
    const payload = JSON.stringify({
      metadata: {
        config: {
          appearance: {
            rules: { ".boundary-proof": { color: "rgb(1, 2, 3)" } },
          },
        },
      },
    });
    for (const origin of ["https://untrusted.example.test", SDK_URL]) {
      await sendFromSibling(page, payload, PAYMENT_ELEMENT_IFRAME, origin);
      expect(
        await sdk.paymentElement
          .locator("body")
          .evaluate(
            () =>
              document
                .getElementById("mystyle")
                ?.textContent?.includes("boundary-proof") ?? false,
          ),
      ).toBe(false);
    }
    await page.locator(PAYMENT_ELEMENT_IFRAME).evaluate((el, payload) => {
      (el as HTMLIFrameElement).contentWindow!.postMessage(
        payload,
        new URL((el as HTMLIFrameElement).src).origin,
      );
    }, payload);
    await expect
      .poll(() =>
        sdk.paymentElement.locator("#mystyle").evaluate((el) => el.textContent),
      )
      .toContain("boundary-proof");
  });

  for (const attack of ["data", "unmount", "cleanup"] as const) {
    test(`authenticates prefetch loader ${attack} messages during updateIntent`, async ({
      checkout,
      page,
      hermetic,
    }) => {
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      for (const name of ["sessionTokens", "sdkConfigs", "clientList"]) {
        hermetic.override(name, (route) => ({ ...route, delayMs: 5_000 }));
      }
      await page.addInitScript(() => {
        window.addEventListener("message", (ev) => {
          let data = ev.data;
          if (typeof data === "string") {
            try {
              data = JSON.parse(data);
            } catch {
              return;
            }
          }
          if (data?.sendSessionTokensResponse)
            window.boundaryPrefetchRequest = true;
        });
      });
      await page.evaluate((clientSecret) => {
        const hyper = (window as unknown as { HyperMethod: SessionHyper })
          .HyperMethod;
        const session = hyper.initPaymentSession({
          clientSecret,
          sdkAuthorization: "boundary-current-authorization",
        });
        session
          .updateIntent(async () => ({
            sdkAuthorization: "boundary-new-authorization",
          }))
          .then((result) => {
            window.boundaryUpdateResult = result as { status?: string };
          });
      }, intent.clientSecret);
      const selector = 'iframe[src*="fullscreenType=preMountLoader"]';
      const loader = page.locator(selector);
      await expect(loader).toBeAttached();
      const frame = page
        .frames()
        .find((frame) =>
          frame.url().includes("fullscreenType=preMountLoader"),
        )!;
      await expect
        .poll(() => frame.evaluate(() => window.boundaryPrefetchRequest))
        .toBe(true);
      if (attack === "data") {
        for (const origin of ["https://untrusted.example.test", SDK_URL]) {
          for (const data of ["session_tokens", "sdk_configs", "client_list"]) {
            await sendFromSibling(
              page,
              { data, response: { error: { message: "forged-prefetch" } } },
              undefined,
              origin,
            );
          }
        }
      } else if (attack === "unmount") {
        await sendFromSibling(page, { preMountLoaderIframeUnMount: true });
        await expect(loader).toBeAttached();
      } else {
        await sendFromSibling(
          page,
          JSON.stringify({ cleanUpPreMountLoaderIframe: true }),
          selector,
        );
        // A forged cleanup must not produce the genuine loader's unmount notification.
        await expect(loader).toBeAttached();
      }
      expect(
        await page.evaluate(() => window.boundaryUpdateResult),
      ).toBeUndefined();
      await expect
        .poll(() => page.evaluate(() => window.boundaryUpdateResult?.status), {
          timeout: 15_000,
        })
        .toBe("succeeded");
    });
  }

  test("authenticates payment-management prefetch responses", async ({
    checkout,
    page,
    hermetic,
  }) => {
    await checkout.open({ body: paymentBody(), waitForReady: true });
    hermetic.use({
      name: "boundaryManagementList",
      path: "/v1/payment-method-sessions/pms_boundary/list-payment-methods",
      delayMs: 4_000,
      body: { payment_methods: [] },
    });
    await page.addInitScript(() => {
      Object.assign(window, { boundaryManagementResponses: [] });
      window.addEventListener("message", (ev) => {
        let data = ev.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (data?.paymentManagementMethods)
          (
            window as unknown as { boundaryManagementResponses: unknown[] }
          ).boundaryManagementResponses.push(data.paymentManagementMethods);
      });
    });
    await page.evaluate(() => {
      const node = document.createElement("div");
      node.id = "boundary-management";
      document.body.appendChild(node);
      const management = (
        window as unknown as { HyperMethod: SessionHyper }
      ).HyperMethod.paymentMethodsManagementElements({
        sdkAuthorization: btoa("payment_method_session_id=pms_boundary"),
      });
      Object.assign(window, { boundaryManagementReady: 0 });
      management.create("paymentMethodsManagement", {}).on("ready", () => {
        (window as unknown as { boundaryManagementReady: number })
          .boundaryManagementReady++;
      });
      management
        .create("paymentMethodsManagement", {})
        .mount("#boundary-management");
    });
    const widget = page.frameLocator(
      "#orca-payment-methods-management-element-iframeRef-boundary-management",
    );
    await expect(widget.locator("body")).toBeAttached();
    await hermetic.waitForCall("boundaryManagementList");
    for (const origin of ["https://untrusted.example.test", SDK_URL]) {
      await sendFromSibling(
        page,
        {
          data: "payment_management_list",
          response: { payment_methods: [], boundaryMarker: "untrusted" },
        },
        undefined,
        origin,
      );
    }
    await expect
      .poll(() =>
        widget
          .locator("body")
          .evaluate(
            () =>
              (window as unknown as { boundaryManagementResponses: unknown[] })
                .boundaryManagementResponses,
          ),
      )
      .toEqual([{ payment_methods: [] }]);
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (window as unknown as { boundaryManagementReady: number })
              .boundaryManagementReady,
        ),
      )
      .toBeGreaterThan(0);
  });

  test("pins refreshed credentials and sessions when a registered widget navigates", async ({
    checkout,
    page,
  }) => {
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await page.addInitScript(() => {
      Object.assign(window, { boundaryCredentialMessages: [] });
      window.addEventListener("message", (ev) => {
        let data = ev.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (
          data?.clientSecret ||
          data?.sdkAuthorization ||
          data?.sessions ||
          data?.clientList
        )
          (
            window as unknown as { boundaryCredentialMessages: unknown[] }
          ).boundaryCredentialMessages.push(data);
      });
    });
    const widget = page
      .frames()
      .find((frame) =>
        frame.url().includes("/index.html?componentName=payment"),
      )!;
    const url = "https://widget-receiver.example.test/receiver";
    await page.route(url, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: "<body>receiver</body>",
      }),
    );
    await widget.goto(url);
    const result = await page.evaluate(async (clientSecret) => {
      const session = (
        window as unknown as { HyperMethod: SessionHyper }
      ).HyperMethod.initPaymentSession({
        clientSecret,
        sdkAuthorization: "boundary-current-authorization",
      });
      return await session.updateIntent(async () => ({
        sdkAuthorization: "boundary-new-authorization",
      }));
    }, intent.clientSecret);
    expect(result).toEqual({ status: "succeeded" });
    expect(
      await widget.evaluate(
        () =>
          (window as unknown as { boundaryCredentialMessages: unknown[] })
            .boundaryCredentialMessages,
      ),
    ).toEqual([]);
  });

  test("waits for the authenticated merchant one-click decision", async ({
    checkout,
    page,
    sdk,
    hermetic,
  }) => {
    await enableApplePay(page, hermetic);
    await page.addInitScript(() => {
      Object.assign(window, { boundaryValidatedSessions: 0 });
      Object.defineProperty(window, "ApplePaySession", {
        configurable: true,
        writable: true,
        value: class {
          onvalidatemerchant: ((event: object) => void) | null = null;
          static canMakePayments() {
            return true;
          }
          begin() {
            this.onvalidatemerchant?.({});
          }
          abort() {}
          completeMerchantValidation() {
            const state = window as unknown as {
              boundaryValidatedSessions: number;
            };
            state.boundaryValidatedSessions++;
          }
        },
      });
      window.addEventListener("message", (ev) => {
        if (ev.data?.oneClickConfirmTriggered && ev.data.walletClickRequestId)
          Object.assign(window, {
            boundaryClickRequestId: ev.data.walletClickRequestId,
          });
      });
    });
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await page.evaluate((clientSecret) => {
      const widget = (
        window as unknown as { HyperMethod: SessionHyper }
      ).HyperMethod.elements({ clientSecret }).create("payment");
      widget.on(
        "paymentButtonClick",
        () =>
          new Promise<void>((resolve) =>
            Object.assign(window, { boundaryReleaseClick: resolve }),
          ),
      );
    }, intent.clientSecret);
    await page.evaluate(() =>
      window.postMessage(
        {
          hyperApplePayButtonClicked: true,
          paymentRequest: {
            countryCode: "US",
            currencyCode: "USD",
            merchantCapabilities: ["supports3DS"],
            supportedNetworks: ["visa"],
            total: { label: "Boundary Merchant", amount: "29.99" },
          },
          applePayPresent: { session_token_data: {} },
        },
        location.origin,
      ),
    );
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (window as unknown as { boundaryClickRequestId?: string })
              .boundaryClickRequestId,
        ),
      )
      .toBeTruthy();
    const baseline = await page.evaluate(
      () =>
        (window as unknown as { boundaryValidatedSessions: number })
          .boundaryValidatedSessions,
    );
    const requestId = await page.evaluate(
      () =>
        (window as unknown as { boundaryClickRequestId: string })
          .boundaryClickRequestId,
    );
    for (const origin of ["https://untrusted.example.test", SDK_URL]) {
      await sendFromSibling(
        page,
        JSON.stringify({
          walletClickEvent: true,
          walletClickRequestId: requestId,
        }),
        undefined,
        origin,
      );
    }
    await page.evaluate(() =>
      window.postMessage(
        JSON.stringify({
          walletClickEvent: true,
          walletClickRequestId: "stale-request",
        }),
        location.origin,
      ),
    );
    expect(
      await page.evaluate(
        () =>
          (window as unknown as { boundaryValidatedSessions: number })
            .boundaryValidatedSessions,
      ),
    ).toBe(baseline);
    await page.evaluate(() =>
      (
        window as unknown as { boundaryReleaseClick: () => void }
      ).boundaryReleaseClick(),
    );
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (window as unknown as { boundaryValidatedSessions: number })
              .boundaryValidatedSessions,
        ),
      )
      .toBe(baseline + 1);
  });

  test("authenticates merchant callbacks and the one-click payment handler", async ({
    checkout,
    page,
  }) => {
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await page.evaluate((clientSecret) => {
      const counts: Record<string, number> = {};
      Object.assign(window, { boundaryCallbackCounts: counts });
      const widget = (
        window as unknown as { HyperMethod: SessionHyper }
      ).HyperMethod.elements({ clientSecret }).create("payment");
      for (const name of [
        "paymentButtonClick",
        "ready",
        "focus",
        "blur",
        "change",
        "clickTriggered",
        "paymentComplete",
        "confirmTriggered",
        "oneClickConfirmTriggered",
        "surchargeInfo",
      ]) {
        counts[name] = 0;
        widget.on(name, () => {
          counts[name]++;
        });
      }
    }, intent.clientSecret);
    await page.evaluate((clientSecret) => {
      const node = document.createElement("div");
      node.id = "boundary-callback-field";
      document.body.appendChild(node);
      (window as unknown as { HyperMethod: SessionHyper }).HyperMethod.elements(
        { clientSecret },
      )
        .createCardForm()
        .create("cardNumber", {})
        .mount("#boundary-callback-field");
    }, intent.clientSecret);
    await expect(
      page
        .frameLocator("#orca-payment-element-iframeRef-boundary-callback-field")
        .locator("#card-number"),
    ).toBeVisible();
    const payloads = [
      {
        oneClickConfirmTriggered: true,
        walletClickRequestId: "boundary-click",
      },
      { ready: true },
      { focus: true },
      { blur: true },
      { value: "synthetic-change" },
      { clickTriggered: true },
      { paymentComplete: true },
      { confirmTriggered: true },
      { eventName: "surchargeInfo" },
    ].map((data) => ({ ...data, elementType: "payment" }));
    for (const origin of ["https://untrusted.example.test", SDK_URL]) {
      for (const payload of payloads)
        await sendFromSibling(page, payload, undefined, origin);
    }
    expect(
      await page.evaluate(() =>
        Object.values(
          (
            window as unknown as {
              boundaryCallbackCounts: Record<string, number>;
            }
          ).boundaryCallbackCounts,
        ),
      ),
    ).toEqual(Array(10).fill(0));
    const widgetFrame = page
      .frames()
      .find((frame) =>
        frame.url().includes("/index.html?componentName=payment"),
      )!;
    await widgetFrame.evaluate(() => {
      parent.postMessage(
        {
          oneClickConfirmTriggered: true,
          walletClickRequestId: "boundary-click",
          elementType: "payment",
        },
        "*",
      );
      parent.postMessage({ ready: true, elementType: "payment" }, "*");
      parent.postMessage(
        { paymentComplete: true, elementType: "payment" },
        "*",
      );
      parent.postMessage(
        { eventName: "surchargeInfo", elementType: "payment" },
        "*",
      );
    });
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (
              window as unknown as {
                boundaryCallbackCounts: Record<string, number>;
              }
            ).boundaryCallbackCounts.paymentButtonClick,
        ),
      )
      .toBe(1);
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (
              window as unknown as {
                boundaryCallbackCounts: Record<string, number>;
              }
            ).boundaryCallbackCounts.ready,
        ),
      )
      .toBe(1);
    await expect
      .poll(() =>
        page.evaluate(
          () =>
            (
              window as unknown as {
                boundaryCallbackCounts: Record<string, number>;
              }
            ).boundaryCallbackCounts.surchargeInfo,
        ),
      )
      .toBe(1);
    expect(
      await page.evaluate(
        () =>
          (
            window as unknown as {
              boundaryCallbackCounts: Record<string, number>;
            }
          ).boundaryCallbackCounts.paymentComplete,
      ),
    ).toBe(1);
  });

  test("authenticates coordinator overlays and allowlists relayed fields", async ({
    checkout,
    page,
  }) => {
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await page.evaluate((clientSecret) => {
      const node = document.createElement("div");
      node.id = "boundary-field";
      document.body.appendChild(node);
      (window as unknown as { HyperMethod: SessionHyper }).HyperMethod.elements(
        { clientSecret },
      )
        .createCardForm()
        .create("cardNumber", {})
        .mount("#boundary-field");
    }, intent.clientSecret);
    const field = page.frameLocator(
      "#orca-payment-element-iframeRef-boundary-field",
    );
    await expect(field.locator("#card-number")).toBeVisible();
    const coordinator = page
      .frames()
      .find((frame) =>
        frame.url().includes("componentName=cardFormCoordinator"),
      )!;
    const groupId = new URL(coordinator.url()).searchParams.get("groupId")!;
    const request = {
      fullscreen: true,
      iframeId: groupId,
      param: "paymentloader",
      metadata: {},
    };
    await sendFromSibling(page, request);
    expect(await page.locator("#orca-fullscreen").count()).toBe(0);
    await coordinator.evaluate(
      (request) => parent.postMessage(request, "*"),
      request,
    );
    await expect(page.locator("#orca-fullscreen")).toBeAttached();
    await expect
      .poll(() =>
        page
          .frames()
          .some((frame) =>
            frame.url().includes("fullscreenType=paymentloader"),
          ),
      )
      .toBe(true);
    const overlay = page
      .frames()
      .find((frame) => frame.url().includes("fullscreenType=paymentloader"))!;
    await coordinator.evaluate(() => {
      const replies: unknown[] = [];
      Object.assign(window, { boundaryCoordinatorReplies: replies });
      window.addEventListener("message", (ev) => {
        let data = ev.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (data?.poll_status) {
          replies.push(data);
          ev.stopImmediatePropagation();
        }
      });
    });
    const terminal = {
      poll_status: "synthetic-status",
      cardFormCoordinatorCommand: "boundary-unexpected-command",
    };
    await sendFromSibling(page, terminal);
    expect(
      await coordinator.evaluate(
        () =>
          (window as unknown as { boundaryCoordinatorReplies: unknown[] })
            .boundaryCoordinatorReplies,
      ),
    ).toEqual([]);
    await overlay.evaluate(
      (terminal) => parent.postMessage(terminal, "*"),
      terminal,
    );
    await expect
      .poll(() =>
        coordinator.evaluate(
          () =>
            (window as unknown as { boundaryCoordinatorReplies: unknown[] })
              .boundaryCoordinatorReplies,
        ),
      )
      .toEqual([{ poll_status: "synthetic-status" }]);
    await sendFromSibling(page, { fullscreen: false });
    await expect(page.locator("#orca-fullscreen")).toBeAttached();
    await overlay.evaluate(() =>
      parent.postMessage({ fullscreen: false }, "*"),
    );
    await expect(page.locator("#orca-fullscreen")).toHaveCount(0);
  });

  for (const closeFirst of [true, false]) {
    test(`preserves the coordinator 3DS Method to Authentication transition${closeFirst ? " after close" : " without close"}`, async ({
      checkout,
      page,
    }) => {
      const intent = await checkout.open({
        body: paymentBody(),
        waitForReady: true,
      });
      for (const type of ["3ds", "3dsAuth"])
        await page.route(
          (url) =>
            url.origin === new URL(SDK_URL).origin &&
            url.pathname === new URL(`${SDK_URL}/fullscreenIndex.html`).pathname &&
            url.searchParams.get("fullscreenType") === type,
          (route) =>
            route.fulfill({
              contentType: "text/html",
              body: `<body>${type}</body>`,
            }),
        );
      await page.evaluate((clientSecret) => {
        const node = document.createElement("div");
        node.id = "boundary-transition";
        document.body.appendChild(node);
        (
          window as unknown as { HyperMethod: SessionHyper }
        ).HyperMethod.elements({ clientSecret })
          .createCardForm()
          .create("cardNumber", {})
          .mount("#boundary-transition");
      }, intent.clientSecret);
      await expect(
        page
          .frameLocator("#orca-payment-element-iframeRef-boundary-transition")
          .locator("#card-number"),
      ).toBeVisible();
      const coordinator = page
        .frames()
        .find((frame) =>
          frame.url().includes("componentName=cardFormCoordinator"),
        )!;
      const iframeId = new URL(coordinator.url()).searchParams.get("groupId")!;
      await coordinator.evaluate(
        (iframeId) =>
          parent.postMessage(
            {
              fullscreen: true,
              param: "3ds",
              iframeId,
              metadata: { iframeId, original: "trusted-metadata" },
            },
            "*",
          ),
        iframeId,
      );
      await expect(
        page.frameLocator("#orca-fullscreen").locator("body"),
      ).toHaveText("3ds");
      const overlay = page
        .frames()
        .find((frame) => frame.url().includes("fullscreenType=3ds"))!;
      expect(new URL(overlay.url()).searchParams.get("endpoint")).toBe(
        HYPERSWITCH_API_URL,
      );
      await sendFromSibling(page, {
        fullscreen: true,
        param: "3dsAuth",
        iframeId,
        metadata: {},
      });
      await expect(
        page.frameLocator("#orca-fullscreen").locator("body"),
      ).toHaveText("3ds");
      await overlay.evaluate(
        ({ iframeId, closeFirst }) => {
          if (closeFirst)
            parent.postMessage(
              { fullscreen: false, param: "paymentloader", iframeId },
              "*",
            );
          parent.postMessage(
            {
              fullscreen: true,
              param: "3dsAuth",
              iframeId,
              metadata: {
                iframeId,
                "3dsMethodComp": closeFirst ? "Y" : "N",
                original: "should-not-replace-trusted-metadata",
              },
            },
            "*",
          );
        },
        { iframeId, closeFirst },
      );
      await expect(
        page.frameLocator("#orca-fullscreen").locator("body"),
      ).toHaveText("3dsAuth");
      const authenticationFrame = page
        .frames()
        .find((frame) => frame.url().includes("fullscreenType=3dsAuth"))!;
      expect(new URL(authenticationFrame.url()).searchParams.get("endpoint")).toBe(
        HYPERSWITCH_API_URL,
      );
      await page
        .frameLocator("#orca-fullscreen")
        .locator("body")
        .evaluate(() => {
          window.addEventListener("message", (ev) => {
            let data = ev.data;
            if (typeof data === "string") {
              try {
                data = JSON.parse(data);
              } catch {
                return;
              }
            }
            if (data?.fullScreenIframeMounted)
              Object.assign(window, {
                boundaryTransitionMetadata: data.metadata,
              });
          });
          parent.postMessage({ iframeMountedCallback: true }, "*");
        });
      await expect
        .poll(() =>
          page
            .frameLocator("#orca-fullscreen")
            .locator("body")
            .evaluate(
              () =>
                (window as unknown as { boundaryTransitionMetadata: unknown })
                  .boundaryTransitionMetadata,
            ),
        )
        .toEqual({
          iframeId,
          original: "trusted-metadata",
          "3dsMethodComp": closeFirst ? "Y" : "N",
        });
    });
  }

  test("forwards the custom backend endpoint to the card form coordinator", async ({
    checkout,
    page,
  }) => {
    await page.addInitScript(() => {
      if (!location.href.includes("componentName=cardFormCoordinator")) return;
      window.addEventListener("message", (ev) => {
        let data = ev.data;
        if (typeof data === "string") {
          try {
            data = JSON.parse(data);
          } catch {
            return;
          }
        }
        if (data?.paymentElementCreate === true)
          Object.assign(window, { boundaryCoordinatorCreate: data });
      });
    });
    const intent = await checkout.open({
      body: paymentBody(),
      waitForReady: true,
    });
    await page.evaluate((clientSecret) => {
      const node = document.createElement("div");
      node.id = "boundary-coordinator-backend";
      document.body.appendChild(node);
      (window as unknown as { HyperMethod: SessionHyper }).HyperMethod.elements(
        { clientSecret },
      )
        .createCardForm()
        .create("cardNumber", {})
        .mount("#boundary-coordinator-backend");
    }, intent.clientSecret);
    await expect(
      page
        .frameLocator(
          "#orca-payment-element-iframeRef-boundary-coordinator-backend",
        )
        .locator("#card-number"),
    ).toBeVisible();
    const coordinator = page
      .frames()
      .find((frame) =>
        frame.url().includes("componentName=cardFormCoordinator"),
      )!;
    // LoaderController only adopts `endpoint` when `customBackendUrl` is present.
    await expect
      .poll(() =>
        coordinator.evaluate(
          () =>
            (window as unknown as { boundaryCoordinatorCreate?: unknown })
              .boundaryCoordinatorCreate,
        ),
      )
      .toMatchObject({
        endpoint: HYPERSWITCH_API_URL,
        customBackendUrl: HYPERSWITCH_API_URL,
      });
  });

  test("leaves the endpoint off coordinator overlays without a custom backend", async ({
    checkout,
    credentials,
    page,
  }) => {
    const intent = await checkout.createPaymentIntent();
    await page.route(`${SDK_URL}/**`, async (route) => {
      if (route.request().url().includes("/assets/v1/jsons/location/")) {
        await route.fallback();
      } else {
        await route.fulfill({ response: await route.fetch() });
      }
    });
    await page.route(
      (url) =>
        url.origin === new URL(SDK_URL).origin &&
        url.pathname === new URL(`${SDK_URL}/fullscreenIndex.html`).pathname,
      (route) =>
        route.fulfill({ contentType: "text/html", body: "<body>3ds</body>" }),
    );
    await page.route(`${CLIENT_BASE_URL}/default-backend-checkout`, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: '<div id="boundary-default-backend"></div>',
      }),
    );
    await page.goto(`${CLIENT_BASE_URL}/default-backend-checkout`);
    await page.addScriptTag({ url: `${SDK_URL}/HyperLoader.js` });
    await page.evaluate(
      ({ clientSecret, publishableKey }) => {
        (
          window as unknown as {
            Hyper: (
              key: { publishableKey: string },
              options: { isPreloadEnabled: boolean },
            ) => SessionHyper;
          }
        )
          .Hyper({ publishableKey }, { isPreloadEnabled: false })
          .elements({ clientSecret })
          .createCardForm()
          .create("cardNumber", {})
          .mount("#boundary-default-backend");
      },
      {
        clientSecret: intent.clientSecret,
        publishableKey: credentials.publishableKey,
      },
    );
    await expect(
      page
        .frameLocator(
          "#orca-payment-element-iframeRef-boundary-default-backend",
        )
        .locator("#card-number"),
    ).toBeVisible();
    const coordinator = page
      .frames()
      .find((frame) =>
        frame.url().includes("componentName=cardFormCoordinator"),
      )!;
    const iframeId = new URL(coordinator.url()).searchParams.get("groupId")!;
    await coordinator.evaluate(
      (iframeId) =>
        parent.postMessage(
          { fullscreen: true, param: "3ds", iframeId, metadata: { iframeId } },
          "*",
        ),
      iframeId,
    );
    await expect(
      page.frameLocator("#orca-fullscreen").locator("body"),
    ).toHaveText("3ds");
    const overlay = page
      .frames()
      .find((frame) => frame.url().includes("fullscreenType=3ds"))!;
    expect(new URL(overlay.url()).searchParams.has("endpoint")).toBe(false);
  });

  test("ignores forged CVC widget success and error responses", async ({
    checkout,
    page,
    hermetic,
  }) => {
    hermetic.load("02-cards/07-saved-cards.json");
    const intent = await checkout.open({
      body: paymentBody({ customer_id: "hyperswitch_sdk_demo_id" }),
    });
    const cvc = await mountCvcSession(page, intent.clientSecret);
    let releaseConfirm = () => {};
    const responseGate = new Promise<void>((resolve) => {
      releaseConfirm = resolve;
    });
    await page.route("**/payments/*/confirm", async (route) => {
      await responseGate;
      await route.fallback();
    });
    const confirmRequest = page.waitForRequest(
      (request) =>
        request.method() === "POST" &&
        new URL(request.url()).pathname.endsWith("/confirm"),
    );
    await page.evaluate((returnUrl) => {
      window.boundaryCvcResult = "pending";
      void window.boundarySession
        .confirmWithCustomerDefaultPaymentMethod({
          id: "boundary-cvc",
          redirect: "if_required",
          confirmParams: { return_url: returnUrl },
        })
        .then((result) => {
          window.boundaryCvcResult = result;
        });
    }, CLIENT_BASE_URL);
    await confirmRequest;
    const requestId = await cvc
      .locator("body")
      .evaluate(() => window.boundaryCvcRequestId);
    try {
      for (const payload of [
        {
          cvcWidgetConfirmResponse: {
            data: { status: "forged" },
            returnUrl: "https://untrusted.example.test",
          },
        },
        { cvcWidgetConfirmErrorResponse: { error: "forged" } },
      ]) {
        await sendFromSibling(page, {
          ...payload,
          cvcWidgetRequestId: requestId,
        });
        expect(await page.evaluate(() => window.boundaryCvcResult)).toBe(
          "pending",
        );
      }
      await page.evaluate((requestId) => {
        const frame = document.querySelector<HTMLIFrameElement>(
          "#orca-payment-element-iframeRef-boundary-cvc",
        )!;
        window.dispatchEvent(
          new MessageEvent("message", {
            source: frame.contentWindow,
            origin: "https://untrusted.example.test",
            data: {
              cvcWidgetRequestId: requestId,
              cvcWidgetConfirmResponse: { data: { status: "forged" } },
            },
          }),
        );
      }, requestId);
      expect(await page.evaluate(() => window.boundaryCvcResult)).toBe(
        "pending",
      );
      await cvc.locator("body").evaluate(async () => {
        window.parent.postMessage(
          {
            cvcWidgetRequestId: "stale-request",
            cvcWidgetConfirmResponse: { data: { status: "forged" } },
          },
          "*",
        );
        const channel = new MessageChannel();
        const delivered = new Promise<void>((resolve) => {
          channel.port1.onmessage = () => {
            channel.port1.close();
            resolve();
          };
        });
        window.parent.postMessage({ boundaryBarrier: true }, "*", [
          channel.port2,
        ]);
        await delivered;
      });
      expect(await page.evaluate(() => window.boundaryCvcResult)).toBe(
        "pending",
      );
    } finally {
      releaseConfirm();
    }
    await expect
      .poll(() => page.evaluate(() => window.boundaryCvcResult))
      .toMatchObject({ status: "succeeded" });
  });
  test("redirects CVC completion to the configured merchant destination", async ({
    checkout,
    page,
    hermetic,
  }) => {
    hermetic.load("02-cards/07-saved-cards.json");
    const intent = await checkout.open({
      body: paymentBody({ customer_id: "hyperswitch_sdk_demo_id" }),
    });
    await mountCvcSession(page, intent.clientSecret);
    const returnUrl = `${CLIENT_BASE_URL}/cvc-completed`;
    await page.route(`${returnUrl}**`, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: "<body>CVC payment completed</body>",
      }),
    );
    await page.evaluate((returnUrl) => {
      void window.boundarySession.confirmWithCustomerDefaultPaymentMethod({
        id: "boundary-cvc",
        redirect: "always",
        confirmParams: { return_url: returnUrl },
      });
    }, returnUrl);
    await expect(page.getByText("CVC payment completed")).toBeVisible();
    expect(new URL(page.url()).searchParams.get("status")).toBe("succeeded");
  });

  for (const returnUrl of [
    "https://untrusted.example.test/redirect",
    "javascript:alert(1)",
  ]) {
    test(`rejects a CVC response redirect to ${returnUrl}`, async ({
      checkout,
      page,
      hermetic,
    }) => {
      hermetic.load("02-cards/07-saved-cards.json");
      const intent = await checkout.open({
        body: paymentBody({ customer_id: "hyperswitch_sdk_demo_id" }),
      });
      const cvc = await mountCvcSession(page, intent.clientSecret);
      let releaseConfirm = () => {};
      const gate = new Promise<void>((resolve) => {
        releaseConfirm = resolve;
      });
      await page.route("**/payments/*/confirm", async (route) => {
        await gate;
        await route.fallback();
      });
      const requested = page.waitForRequest(
        (request) =>
          request.method() === "POST" &&
          new URL(request.url()).pathname.endsWith("/confirm"),
      );
      await page.evaluate((url) => {
        window.boundaryCvcResult = "pending";
        void window.boundarySession
          .confirmWithCustomerDefaultPaymentMethod({
            id: "boundary-cvc",
            redirect: "always",
            confirmParams: { return_url: url },
          })
          .then((result) => {
            window.boundaryCvcResult = result;
          });
      }, CLIENT_BASE_URL);
      await requested;
      try {
        await cvc.locator("body").evaluate((_el, returnUrl) => {
          window.parent.postMessage(
            {
              cvcWidgetRequestId: window.boundaryCvcRequestId,
              cvcWidgetConfirmResponse: {
                data: { status: "succeeded" },
                returnUrl,
              },
            },
            "*",
          );
        }, returnUrl);
        await expect
          .poll(() => page.evaluate(() => window.boundaryCvcResult))
          .toMatchObject({ error: { type: "invalid_request" } });
        expect(new URL(page.url()).origin).toBe(CLIENT_BASE_URL);
      } finally {
        releaseConfirm();
      }
    });
  }
});
