import type { Page } from "@playwright/test";
import {
  test,
  expect,
  paymentBody,
  CLIENT_BASE_URL,
  SDK_URL,
} from "../../fixtures";

async function openMerchant(page: Page) {
  const url = `${CLIENT_BASE_URL}/widget-events`;
  await page.route(url, (route) =>
    route.fulfill({ contentType: "text/html", body: "<body></body>" }),
  );
  await page.goto(url);
  const loader = await page.request.get(`${SDK_URL}/HyperLoader.js`);
  expect(loader.ok()).toBe(true);
  await page.addScriptTag({ content: await loader.text() });
}

test.use({
  launchOptions: { args: ["--disable-features=LocalNetworkAccessChecks"] },
});

test.describe("Widget event producers @hermetic-only", () => {
  for (const type of ["card", "cardNumber", "cardExpiry", "cardCvc"]) {
    test(`${type} emits one ready after receiving its iframe identity`, async ({
      page,
      api,
      credentials,
    }) => {
      const intent = await api.createPaymentIntent(paymentBody());
      await openMerchant(page);
      await page.evaluate(
        ({ type, clientSecret, publishableKey }) => {
          const w = window as any;
          const container = document.createElement("div");
          container.id = "field";
          document.body.append(container);
          w.fieldReadyMessages = [];
          w.fieldReadyCallbacks = 0;
          w.fieldEventBarrier = false;
          window.addEventListener("message", (event) => {
            const iframe = document.querySelector<HTMLIFrameElement>(
              "#orca-payment-element-iframeRef-field",
            );
            if (event.source !== iframe?.contentWindow) return;
            if (event.data?.ready) w.fieldReadyMessages.push(event.data);
            if (event.data === "field-events-handled")
              w.fieldEventBarrier = true;
          });
          const elements = w
            .Hyper(publishableKey, {
              isPreloadEnabled: false,
            })
            .elements({ clientSecret });
          const widget = elements.create(type, {});
          widget.on("ready", () => w.fieldReadyCallbacks++);
          widget.mount("#field");
        },
        {
          type,
          clientSecret: intent.clientSecret,
          publishableKey: credentials.publishableKey,
        },
      );
      await expect
        .poll(() =>
          page.evaluate(() =>
            (window as any).fieldReadyMessages.some(
              (event: any) => event.iframeId === "field",
            ),
          ),
        )
        .toBe(true);
      const frame = page.frameLocator("#orca-payment-element-iframeRef-field");
      await expect(frame.locator("input").first()).toBeVisible();
      // A message from the same mounted frame is ordered after its ready events.
      await frame
        .locator("body")
        .evaluate(() => parent.postMessage("field-events-handled", "*"));
      await expect
        .poll(() => page.evaluate(() => (window as any).fieldEventBarrier))
        .toBe(true);
      expect(
        await page.evaluate(() => ({
          callbacks: (window as any).fieldReadyCallbacks,
          messages: (window as any).fieldReadyMessages,
        })),
      ).toEqual({
        callbacks: 1,
        messages: [{ ready: true, elementType: type, iframeId: "field" }],
      });
    });
  }

  test.describe("wallet subscription routing", () => {
    test.use({ hermeticFixtures: ["04-alternative-payments/popups.json"] });

    for (const type of ["payment", "expressCheckout", "payPal"]) {
      test(`${type} sends subscribed changes only to its own handler`, async ({
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
              window.walletEventCallbacks = config;
              return originalButtons(config);
            };
          `,
        }));
        const intent = await api.createPaymentIntent(
          paymentBody({ customer_id: "popups_paypal_user" }),
        );
        await openMerchant(page);
        await page.evaluate(
          ({ type, clientSecret, publishableKey }) => {
            const w = window as any;
            w.walletChanges = { owner: [], sibling: [] };
            w.walletEventsHandled = false;
            window.addEventListener("message", (event) => {
              if (event.data === "wallet-events-handled")
                w.walletEventsHandled = true;
            });
            const elements = w
              .Hyper(publishableKey, {
                isPreloadEnabled: false,
              })
              .elements({ clientSecret });
            for (const [id, elementType] of [
              ["owner", type],
              ["sibling", type === "payment" ? "expressCheckout" : "payment"],
            ]) {
              const container = document.createElement("div");
              container.id = id;
              container.style.width = "460px";
              document.body.append(container);
              const widget = elements.create(elementType, {
                subscriptionEvents: [
                  "paymentMethodChange",
                  "billingDetailsChange",
                ],
              });
              widget.on("change", (event: any) => {
                if (event?.eventName) w.walletChanges[id].push(event);
              });
              // Stop before confirmation; the vendor callback still runs the real emitters.
              widget.onSDKHandleClick(async () => false);
              widget.mount(`#${id}`);
            }
          },
          {
            type,
            clientSecret: intent.clientSecret,
            publishableKey: credentials.publishableKey,
          },
        );
        for (const id of ["owner", "sibling"])
          await expect(
            page
              .frameLocator(`#orca-payment-element-iframeRef-${id}`)
              .getByRole("button", { name: "PayPal", exact: true }),
          ).toBeVisible();
        await page.evaluate(() => {
          (window as any).walletChanges = { owner: [], sibling: [] };
        });
        await page
          .frameLocator("#orca-payment-element-iframeRef-owner")
          .locator("body")
          .evaluate(() => {
            void (window as any).walletEventCallbacks.createOrder();
            parent.postMessage("wallet-events-handled", "*");
          });
        await expect
          .poll(() => page.evaluate(() => (window as any).walletEventsHandled))
          .toBe(true);
        const changes = await page.evaluate(
          () => (window as any).walletChanges,
        );
        expect(changes.owner).toEqual([
          {
            eventName: "paymentMethodChange",
            payload: {
              paymentMethod: "wallet",
              paymentMethodType: "paypal",
              isSavedPaymentMethod: false,
              isOneClickWallet: true,
            },
          },
          {
            eventName: "billingDetailsChange",
            payload: expect.objectContaining({
              country: expect.any(String),
              state: expect.any(String),
              postalCode: expect.any(String),
            }),
          },
        ]);
        expect(changes.sibling).toEqual([]);
      });
    }
  });
});
