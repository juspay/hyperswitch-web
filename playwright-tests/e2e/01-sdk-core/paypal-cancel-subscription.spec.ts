import type { Frame, Page } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  CLIENT_BASE_URL,
  SDK_URL,
} from "../../fixtures";

interface CancellationEvent {
  eventName: string;
  payload: {
    paymentMethod: string;
    paymentMethodType: string;
    canRetryPayment: boolean;
  };
}

interface PaymentElement {
  on(event: string, callback: (event?: CancellationEvent) => void): void;
  mount(selector: string): void;
  update(options: object): void;
}

declare global {
  interface Window {
    paypalSubscriptionElement: PaymentElement;
    paypalCancellationEvents: CancellationEvent[];
    paypalCancellationHandled: number;
    paypalSubscriptionCallbacks: {
      onCancel(data: object): void;
      onError(error: Error): void;
    };
  }
}

async function updateSubscription(
  page: Page,
  frame: Frame,
  enabled: boolean,
  radius: number,
) {
  await page.evaluate(
    ({ enabled, radius }) =>
      window.paypalSubscriptionElement.update({
        subscriptionEvents: enabled ? ["paymentMethodFlowCancel"] : [],
        wallets: { style: { buttonRadius: radius } },
      }),
    { enabled, radius },
  );
  // This style uses the same options atom as the emitter, proving the iframe
  // rendered the update before invoking the already-registered PayPal callback.
  await expect(frame.locator("#paypal-button")).toHaveCSS(
    "border-radius",
    `${radius}px`,
  );
}

async function cancel(
  page: Page,
  frame: Frame,
  callback: "onCancel" | "onError",
) {
  const handled = await page.evaluate(() => window.paypalCancellationHandled);
  await frame.evaluate((callback) => {
    if (callback === "onCancel") {
      window.paypalSubscriptionCallbacks.onCancel({});
    } else {
      window.paypalSubscriptionCallbacks.onError(
        new Error("Window is closed, can not determine type"),
      );
    }
    // Messages from this frame are ordered: once this reaches the merchant,
    // any cancellation event emitted by the callback has arrived too.
    window.parent.postMessage("paypal-cancellation-handled", "*");
  }, callback);
  await expect
    .poll(() => page.evaluate(() => window.paypalCancellationHandled))
    .toBe(handled + 1);
}

test.use({
  hermeticFixtures: ["04-alternative-payments/popups.json"],
  // Routed merchant HTML has no local-network classification in Chromium.
  launchOptions: { args: ["--disable-features=LocalNetworkAccessChecks"] },
});

test.describe("PayPal cancellation subscription updates @hermetic-only", () => {
  for (const type of ["payment", "expressCheckout", "payPal"]) {
    for (const callback of ["onCancel", "onError"] as const) {
      test(`${type}: ${callback} uses subscriptions updated after mounting`, async ({
        page,
        api,
        credentials,
        hermetic,
      }) => {
        hermetic.override("paypalSdkScript", (route) => ({
          ...route,
          body: `${route.body}
            const originalButtons = window.paypal.Buttons;
            window.paypal.Buttons = (config) => {
              window.paypalSubscriptionCallbacks = config;
              return originalButtons(config);
            };
          `,
        }));
        const intent = await api.createPaymentIntent(
          paymentBody({ customer_id: "popups_paypal_user" }),
        );
        const merchantUrl = `${CLIENT_BASE_URL}/paypal-subscription`;
        await page.route(merchantUrl, (route) =>
          route.fulfill({
            contentType: "text/html",
            body: '<div id="payment" style="width:460px"></div>',
          }),
        );
        await page.goto(merchantUrl);
        const loader = await page.request.get(`${SDK_URL}/HyperLoader.js`);
        expect(loader.ok()).toBe(true);
        await page.addScriptTag({ content: await loader.text() });
        await page.evaluate(
          ({ clientSecret, publishableKey, type }) => {
            const { Hyper } = window as unknown as {
              Hyper(
                key: string,
                options: object,
              ): {
                elements(options: object): {
                  create(type: string, options: object): PaymentElement;
                };
              };
            };
            window.paypalCancellationEvents = [];
            window.paypalCancellationHandled = 0;
            window.addEventListener("message", (event) => {
              if (event.data === "paypal-cancellation-handled")
                window.paypalCancellationHandled++;
            });
            const elements = Hyper(publishableKey, {
              isPreloadEnabled: false,
            }).elements({ clientSecret });
            const element = elements.create(type, {
              subscriptionEvents: [],
              wallets: { walletReturnUrl: `${location.origin}/return` },
            });
            element.on("change", (event) => {
              if (event?.eventName === "paymentMethodFlowCancel")
                window.paypalCancellationEvents.push(event);
            });
            element.mount("#payment");
            window.paypalSubscriptionElement = element;
          },
          {
            clientSecret: intent.clientSecret,
            publishableKey: credentials.publishableKey,
            type,
          },
        );
        const iframe = page.locator("#orca-payment-element-iframeRef-payment");
        await expect(iframe).toBeAttached();
        const frame = await (await iframe.elementHandle())!.contentFrame();
        expect(frame).not.toBeNull();
        await expect(
          frame!.getByRole("button", { name: "PayPal", exact: true }),
        ).toBeVisible();

        const expectedEvent: CancellationEvent = {
          eventName: "paymentMethodFlowCancel",
          payload: {
            paymentMethod: "wallet",
            paymentMethodType: "paypal",
            canRetryPayment: true,
          },
        };
        await updateSubscription(page, frame!, true, 11);
        await cancel(page, frame!, callback);
        expect(
          await page.evaluate(() => window.paypalCancellationEvents),
        ).toEqual([expectedEvent]);

        await updateSubscription(page, frame!, false, 12);
        await cancel(page, frame!, callback);
        expect(
          await page.evaluate(() => window.paypalCancellationEvents),
        ).toEqual([expectedEvent]);

        await updateSubscription(page, frame!, true, 13);
        await cancel(page, frame!, callback);
        expect(
          await page.evaluate(() => window.paypalCancellationEvents),
        ).toEqual([expectedEvent, expectedEvent]);
      });
    }
  }
});
