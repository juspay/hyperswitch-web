import {
  test,
  expect,
  stripeCards,
  typeCard,
  expectConfirmedWith,
} from "../../fixtures";
import { CLIENT_BASE_URL, SDK_URL } from "../../fixtures/env";

interface TestElements {
  create(
    type: string,
    options: object,
  ): {
    on(name: string, callback: (event?: { complete?: boolean }) => void): void;
    mount(selector: string): void;
  };
}

declare global {
  interface Window {
    Hyper: (
      key: { publishableKey: string },
      options: { customBackendUrl: string; isPreloadEnabled: boolean },
    ) => {
      widgets(options: { clientSecret: string }): TestElements;
      confirmPayment(options: object): Promise<{ status: string }>;
    };
    confirmTestPayment: () => Promise<{ status: string }>;
    cardComplete: boolean;
  }
}

test.describe("Card payment completion with a registered callback @hermetic-only", () => {
  for (const redirect of ["if_required", "always"]) {
    test(`redirect=${redirect} uses normal card completion`, async ({
      page,
      checkout,
      sdk,
      api,
      credentials,
      hermetic,
    }) => {
      const intent = await checkout.createPaymentIntent();
      const returnUrl = `${CLIENT_BASE_URL}/callback-return`;
      await page.route(`${SDK_URL}/**`, async (route) => {
        if (route.request().url().includes("/assets/v1/jsons/location/")) {
          await route.fallback();
        } else {
          await route.fulfill({ response: await route.fetch() });
        }
      });
      await page.route(`${CLIENT_BASE_URL}/callback-checkout`, (route) =>
        route.fulfill({
          contentType: "text/html",
          body: '<div id="orca-elements-payment-element-payment-element"></div>',
        }),
      );
      await page.route(`${returnUrl}*`, (route) =>
        route.fulfill({ contentType: "text/html", body: "Payment returned" }),
      );
      await page.goto(`${CLIENT_BASE_URL}/callback-checkout`);
      await page.addScriptTag({ url: `${SDK_URL}/HyperLoader.js` });
      await page.evaluate(
        ({
          clientSecret,
          publishableKey,
          customBackendUrl,
          returnUrl,
          redirect,
        }) => {
          sessionStorage.setItem("paymentCompleteCalls", "0");
          const hyper = window.Hyper(
            { publishableKey },
            { customBackendUrl, isPreloadEnabled: false },
          );
          const elements = hyper.widgets({ clientSecret });
          const payment = elements.create("payment", {});
          window.cardComplete = false;
          payment.on("change", (event) => {
            if (typeof event?.complete === "boolean") {
              window.cardComplete = event.complete;
            }
          });
          payment.on("paymentComplete", () => {
            sessionStorage.setItem(
              "paymentCompleteCalls",
              String(
                Number(sessionStorage.getItem("paymentCompleteCalls")) + 1,
              ),
            );
          });
          payment.mount("#orca-elements-payment-element-payment-element");
          window.confirmTestPayment = () =>
            hyper.confirmPayment({
              elements,
              confirmParams: { return_url: returnUrl },
              redirect,
            });
        },
        {
          clientSecret: intent.clientSecret,
          publishableKey: credentials.publishableKey,
          customBackendUrl: api.baseUrl,
          returnUrl,
          redirect,
        },
      );
      await typeCard(sdk, stripeCards.successCard);
      await expect
        .poll(() => page.evaluate(() => window.cardComplete))
        .toBe(true);
      if (redirect === "if_required") {
        const result = await page.evaluate(() => window.confirmTestPayment());
        expect(result).toMatchObject({ status: "succeeded" });
        await expect(page).toHaveURL(`${CLIENT_BASE_URL}/callback-checkout`);
      } else {
        await page.evaluate(() => {
          void window.confirmTestPayment();
        });
        await expect(page).toHaveURL(
          `${returnUrl}?payment_intent_client_secret=${intent.clientSecret}&payment_id=${intent.paymentId}&status=succeeded`,
        );
      }
      expect(
        await page.evaluate(() =>
          sessionStorage.getItem("paymentCompleteCalls"),
        ),
      ).toBe("0");
      await expectConfirmedWith(hermetic, stripeCards.successCard.cardNo);
    });
  }
});
