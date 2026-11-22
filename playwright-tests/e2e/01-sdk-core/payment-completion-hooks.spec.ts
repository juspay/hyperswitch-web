import { test, expect } from "../../fixtures/sdk-runtime";
import { paymentBody } from "../../fixtures";
import { CLIENT_BASE_URL } from "../../fixtures/env";
import { readFixtureFile } from "../../fixtures/hermetic/engine";
import type { PaymentHookOptions } from "../../fixtures/sdk-runtime-entry";

declare global {
  interface Window {
    paymentMessages: Record<string, unknown>[];
  }
}

const scenarios: {
  name: string;
  paymentType: PaymentHookOptions["paymentType"];
  oneClick?: boolean;
  callbackRegistered?: boolean;
}[] = [
  { name: "Google Pay button", paymentType: "Gpay", oneClick: true },
  { name: "Apple Pay button", paymentType: "Applepay", oneClick: true },
  { name: "PayPal button", paymentType: "Paypal", oneClick: true },
  { name: "Samsung Pay button", paymentType: "Samsungpay", oneClick: true },
  { name: "Google Pay tab", paymentType: "Gpay", oneClick: false },
  { name: "Apple Pay tab", paymentType: "Applepay", oneClick: false },
  { name: "PayPal tab", paymentType: "Paypal", oneClick: false },
  { name: "Samsung Pay tab", paymentType: "Samsungpay", oneClick: false },
  { name: "card (default flag)", paymentType: "Card", oneClick: undefined },
  {
    name: "wallet button without a callback",
    paymentType: "Gpay",
    oneClick: true,
    callbackRegistered: false,
  },
];

test.describe("Payment completion hooks @hermetic-only", () => {
  for (const hook of ["intent", "sync"]) {
    for (const button of [true, false]) {
      test(`Google Pay component ${hook}: ${button ? "button" : "tab"} context`, async ({
        runtimePage,
        api,
        credentials,
        hermetic,
      }) => {
        const intent = await api.createPaymentIntent(paymentBody());
        hermetic.setIntent({ status: "succeeded" });
        const returnUrl = `${CLIENT_BASE_URL}/completion`;
        await runtimePage.evaluate(
          async (options) => {
            window.paymentMessages = [];
            window.addEventListener("message", ({ data }) => {
              if (
                data.paymentComplete ||
                data.submitSuccessful ||
                data.openurl
              ) {
                window.paymentMessages.push(data);
              }
            });
            await window.sdkTest.mountGooglePay(options);
          },
          {
            button,
            clientSecret: intent.clientSecret,
            publishableKey: credentials.publishableKey,
            returnUrl,
          },
        );
        await expect(runtimePage.locator("#google-pay-button")).toHaveCount(
          button ? 1 : 0,
        );
        await runtimePage.evaluate((hook) => {
          window.postMessage(
            JSON.stringify(
              hook === "sync"
                ? { googlePaySyncPayment: true }
                : {
                    gpayResponse: {
                      apiVersion: 2,
                      apiVersionMinor: 0,
                      paymentMethodData: {
                        type: "CARD",
                        description: "Visa ending in 4242",
                        info: { cardDetails: "4242", cardNetwork: "VISA" },
                        tokenizationData: {
                          type: "PAYMENT_GATEWAY",
                          token: '{"id":"tok_test"}',
                        },
                      },
                    },
                  },
            ),
            "*",
          );
        }, hook);
        const expectedUrl = `${returnUrl}?payment_intent_client_secret=${intent.clientSecret}&payment_id=${intent.paymentId}&status=succeeded`;
        await expect
          .poll(() => runtimePage.evaluate(() => window.paymentMessages))
          .toEqual(
            button ? [{ paymentComplete: true }] : [{ openurl: expectedUrl }],
          );
      });
    }
  }

  for (const hook of ["intent", "sync", "complete", "handler"] as const) {
    for (const scenario of scenarios) {
      test(`${hook}: ${scenario.name}`, async ({
        runtimePage,
        api,
        credentials,
        hermetic,
      }) => {
        const intent = await api.createPaymentIntent(paymentBody());
        hermetic.setIntent({ status: "succeeded" });
        const confirmRoute = readFixtureFile("base/payments.json").routes.find(
          (route) => route.name === "confirm",
        )!;
        hermetic.use({
          ...confirmRoute,
          name: "completeAuthorize",
          path: "/payments/:paymentId/complete_authorize",
        });
        const returnUrl = `${CLIENT_BASE_URL}/completion`;
        await runtimePage.evaluate(
          async (options) => {
            window.paymentMessages = [];
            window.addEventListener("message", ({ data }) => {
              if (
                data.paymentComplete ||
                data.submitSuccessful ||
                data.openurl
              ) {
                window.paymentMessages.push(data);
              }
            });
            const run = await window.sdkTest.mountPaymentHook(options);
            run();
          },
          {
            hook,
            paymentType: scenario.paymentType,
            isOneClickWallet: scenario.oneClick,
            callbackRegistered: scenario.callbackRegistered,
            clientSecret: intent.clientSecret,
            publishableKey: credentials.publishableKey,
            returnUrl,
          },
        );
        const shouldComplete =
          scenario.oneClick === true && scenario.callbackRegistered !== false;
        const expectedUrl = `${returnUrl}?payment_intent_client_secret=${intent.clientSecret}&payment_id=${intent.paymentId}&status=succeeded`;
        await expect
          .poll(() => runtimePage.evaluate(() => window.paymentMessages))
          .toEqual(
            shouldComplete
              ? [{ paymentComplete: true }]
              : scenario.paymentType === "Card"
                ? [
                    {
                      submitSuccessful: true,
                      data: expect.objectContaining({ status: "succeeded" }),
                      url: expectedUrl,
                    },
                  ]
                : [{ openurl: expectedUrl }],
          );
      });
    }
  }
});
