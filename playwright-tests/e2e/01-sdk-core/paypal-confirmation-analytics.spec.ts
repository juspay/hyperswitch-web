import { createHash } from "node:crypto";
import { test, expect, SDK_URL } from "../../fixtures";
import { openAnalyticsCheckout } from "./payment-method-analytics-helpers";

// Replace only vendor APIs; the real SDK registers the callbacks, handles option
// updates, and sends the analytics batches observed by openAnalyticsCheckout.
const paypalScript = `window.paypal = {
  FUNDING: {PAYPAL: 'paypal'},
  Buttons(config) {
    window.analyticsPaypalCallbacks = config;
    return { render(selector) {
      const button = document.createElement('button');
      button.textContent = 'Test PayPal';
      button.onclick = () => config.onClick();
      document.querySelector(selector).appendChild(button);
      return Promise.resolve();
    }};
  }
};`;

const braintreeScripts: Record<string, string> = {
  "client.min.js": `window.braintree ||= {};
    window.braintree.client = {create(options, done) {done(false, {});}};`,
  "paypal-checkout.min.js": `window.braintree ||= {};
    window.braintree.paypalCheckout = {create(options, done) {
      done(null, {loadPayPalSDK(options, loaded) {
        ${paypalScript}
        loaded();
      }});
    }};`,
};

test.use({
  launchOptions: { args: ["--disable-features=LocalNetworkAccessChecks"] },
});

test.describe("PayPal confirmation analytics @hermetic-only", () => {
  for (const connector of ["paypal", "braintree"]) {
    for (const initiallyReadOnly of [false, true]) {
      test(`${connector}: one event per click, with current readOnly=${initiallyReadOnly}`, async ({
        context,
        page,
        api,
        credentials,
        hermetic,
      }) => {
        await context.route("https://www.paypal.com/sdk/js?**", (route) =>
          route.fulfill({
            contentType: "application/javascript",
            body: paypalScript,
          }),
        );
        for (const [file, body] of Object.entries(braintreeScripts)) {
          await context.route(
            `https://js.braintreegateway.com/web/**/js/${file}`,
            (route) =>
              route.fulfill({
                contentType: "application/javascript",
                headers: { "access-control-allow-origin": "*" },
                body,
              }),
          );
        }
        await context.route(`${SDK_URL}/index.html?**`, async (route) => {
          const response = await route.fetch();
          // The iframe pins these vendor scripts with SRI. Pin the test doubles
          // to their own hashes, preserving the browser's integrity checks.
          const body = (await response.text()).replace(
            /<script\b[^>]*src="https:\/\/js\.braintreegateway\.com\/[^\"]*"[^>]*>/g,
            (tag) => {
              const file = Object.keys(braintreeScripts).find((name) =>
                tag.includes(name),
              )!;
              const hash = createHash("sha384")
                .update(braintreeScripts[file])
                .digest("base64");
              return tag.replace(
                /integrity="[^"]*"/,
                `integrity="sha384-${hash}"`,
              );
            },
          );
          await route.fulfill({ response, body });
        });
        const r = await openAnalyticsCheckout(
          { context, page, api, credentials, hermetic },
          {
            noGoogle: true,
            readOnly: initiallyReadOnly,
            // The Braintree setup otherwise waits for a merchant one-click
            // handler; this checkout intentionally has no such handler.
            sdkHandleOneClickConfirmPayment: false,
            layout: { type: "tabs" },
            wallets: { payPal: "auto" },
            additionalMethods: [
              {
                payment_method: "wallet",
                payment_method_type: "paypal",
                payment_experience: ["invoke_sdk_client"],
              },
            ],
            sessionTokens: [
              {
                wallet_name: "paypal",
                connector,
                session_token: "test-paypal-client",
                intent: "capture",
                currency: "USD",
              },
            ],
          },
        );
        await r.waitReady();
        await r.waitMethods(1);
        const attempts = () =>
          r.events.filter(
            (event) => event.event_name === "PAYMENT_CONFIRM_TRIGGERED",
          );
        const click = async () => {
          // Invoke the vendor callback even in read-only mode, so the SDK guard
          // is exercised independently of CSS pointer-events protection.
          await r.frame
            .getByRole("button", { name: "Test PayPal" })
            .evaluate((button) => (button as HTMLButtonElement).click());
          await r.flush();
        };
        const updateReadOnly = async (readOnly: boolean, radius: number) => {
          await page.evaluate(
            ({ readOnly, radius }) =>
              (window as any).analyticsElement.update({
                readOnly,
                wallets: { style: { buttonRadius: radius } },
              }),
            { readOnly, radius },
          );
          // This style and the confirmation guard consume the same options atom.
          await expect(r.frame.locator("#paypal-button")).toHaveCSS(
            "border-radius",
            `${radius}px`,
          );
        };
        expect(attempts()).toHaveLength(0);
        if (initiallyReadOnly) {
          await click();
          expect(attempts()).toHaveLength(0);
          await updateReadOnly(false, 11);
        }
        await click();
        expect(attempts()).toHaveLength(1);
        expect(JSON.parse(attempts()[0].value)).toEqual({
          source: "wallet",
          paymentMethodType: "paypal",
        });
        await r.frame.evaluate(() => {
          const callbacks = (window as any).analyticsPaypalCallbacks;
          callbacks.onCancel({});
          callbacks.onError(
            new Error("Window is closed, can not determine type"),
          );
        });
        await r.flush();
        expect(attempts()).toHaveLength(1);
        await click();
        expect(attempts()).toHaveLength(2);
        await updateReadOnly(true, 12);
        await click();
        expect(attempts()).toHaveLength(2);
        await updateReadOnly(false, 13);
        await click();
        expect(attempts()).toHaveLength(3);
        expect(r.rendered()).toHaveLength(1);
        expect(await r.readyCount()).toBe(1);
      });
    }
  }
});
