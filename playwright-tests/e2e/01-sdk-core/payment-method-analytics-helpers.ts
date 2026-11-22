import type { BrowserContext, Page } from "@playwright/test";
import {
  expect,
  paymentBody,
  type TestFixtures,
  type WorkerFixtures,
} from "../../fixtures";
import { CLIENT_BASE_URL, SDK_URL } from "../../fixtures/env";
import { readFixtureFile } from "../../fixtures/hermetic/engine";

type Fixtures = Pick<TestFixtures, "api" | "hermetic"> &
  Pick<WorkerFixtures, "credentials"> & {
    context: BrowserContext;
    page: Page;
  };

interface Options {
  readOnly?: boolean;
  sdkHandleOneClickConfirmPayment?: boolean;
  progressive?: boolean;
  noGoogle?: boolean;
  saved?: boolean;
  savedWallet?: boolean;
  layout?: Record<string, unknown>;
  wallets?: Record<string, unknown>;
  additionalMethods?: Record<string, unknown>[];
  sessionTokens?: Record<string, unknown>[];
}

interface AnalyticsEvent {
  event_name: string;
  value: string;
}

export interface MethodsSnapshot {
  componentType: string;
  payment_methods: string[];
  saved_methods: string[];
  wallets: string[];
  screen: string;
}

export const savedCard = (
  readFixtureFile("02-cards/07-saved-cards.json").routes[0].body as {
    customer_payment_methods: Record<string, unknown>[];
  }
).customer_payment_methods[0];

// Only the external availability response is deferred; the real SDK decides
// which sections to render and emits both merchant and analytics events.
const googleScript = `window.google = {payments: {api: {PaymentsClient: class {
  isReadyToPay() {
    window.analyticsAvailabilityRequested = true;
    return new Promise(resolve => window.analyticsResolveGoogle = resolve);
  }
  createButton(options) {
    const button = document.createElement('button');
    button.textContent = 'Test Google Pay';
    button.onclick = options.onClick;
    return button;
  }
}}}};`;

export async function openAnalyticsCheckout(
  { context, page, api, credentials, hermetic }: Fixtures,
  options: Options = {},
) {
  const events: AnalyticsEvent[] = [];
  await context.exposeBinding("analyticsBarrier", () => null);
  await context.exposeBinding("recordAnalytics", ({ frame }, data: string) => {
    if (
      new URL(frame.url() || "about:blank").searchParams.get(
        "componentName",
      ) === "payment"
    ) {
      events.push(...(JSON.parse(data) as AnalyticsEvent[]));
    }
  });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, "sendBeacon", {
      value: (_url: string, data: string) => {
        (window as any).recordAnalytics(data);
        return true;
      },
    });
  });
  await context.route("https://pay.google.com/gp/p/js/pay.js", (route) =>
    route.fulfill({
      contentType: "application/javascript",
      body: googleScript,
    }),
  );
  hermetic.override("clientList", (route) => {
    const body = route.body as Record<string, unknown> & {
      payment_methods_enabled: Record<string, unknown>[];
    };
    return {
      ...route,
      body: {
        ...body,
        payment_methods_enabled: [
          ...body.payment_methods_enabled,
          ...(options.additionalMethods ?? []),
          ...(options.noGoogle
            ? []
            : [
                {
                  payment_method: "wallet",
                  payment_method_type: "google_pay",
                  payment_experience: ["invoke_sdk_client"],
                },
              ]),
        ],
        customer_payment_methods: options.saved
          ? [
              savedCard,
              ...(options.savedWallet
                ? [
                    {
                      payment_token: "saved_google",
                      payment_method: "wallet",
                      payment_method_type: "google_pay",
                      last_used_at: "2026-09-01T00:00:00Z",
                    },
                  ]
                : []),
            ]
          : [],
      },
    };
  });
  hermetic.override("sessionTokens", {
    session_token:
      options.sessionTokens ??
      (options.noGoogle
        ? []
        : [
            {
              wallet_name: "google_pay",
              connector: "stripe",
              allowed_payment_methods: [],
              transaction_info: { currency_code: "USD", total_price: "10" },
              merchant_info: { merchant_name: "Analytics test" },
            },
          ]),
  });
  const intent = await api.createPaymentIntent(paymentBody());
  const merchantUrl = `${CLIENT_BASE_URL}/payment-method-analytics`;
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
    ({ intent, key, options }) => {
      const w = window as any;
      w.analyticsReadies = [];
      w.analyticsElements = w.Hyper(key, { isPreloadEnabled: false }).elements({
        clientSecret: intent.clientSecret,
      });
      w.analyticsElement = w.analyticsElements.create("payment", {
        readOnly: options.readOnly ?? false,
        sdkHandleOneClickConfirmPayment:
          options.sdkHandleOneClickConfirmPayment ?? true,
        enableProgressiveLoading: options.progressive ?? false,
        layout: options.layout ?? {
          type: "tabs",
          displayOneClickPaymentMethodsOnTop: false,
        },
        wallets: {
          walletReturnUrl: location.origin + "/return",
          googlePay: "auto",
          applePay: "never",
          payPal: "never",
          ...options.wallets,
        },
      });
      w.analyticsElement.on("ready", () => w.analyticsReadies.push(Date.now()));
      w.analyticsElement.mount("#payment");
    },
    { intent, key: credentials.publishableKey, options },
  );
  const paymentFrame = () =>
    page
      .frames()
      .find(
        (frame) =>
          new URL(frame.url() || "about:blank").searchParams.get(
            "componentName",
          ) === "payment",
      );
  await expect.poll(paymentFrame).toBeTruthy();
  const frame = paymentFrame()!;
  if (!options.noGoogle) {
    await expect
      .poll(() =>
        page.evaluate(() => (window as any).analyticsAvailabilityRequested),
      )
      .toBe(true);
  }
  const rendered = () =>
    events.filter((event) => event.event_name === "ELEMENT_RENDERED");
  const methods = () =>
    events
      .filter((event) => event.event_name === "PAYMENT_METHODS_RENDERED")
      .map((event) => JSON.parse(event.value) as MethodsSnapshot);
  const readyCount = () =>
    page.evaluate(() => (window as any).analyticsReadies.length as number);
  const flush = () =>
    frame.evaluate(async () => {
      // Exercise the logger's real flush path so assertions include buffered updates.
      window.dispatchEvent(new Event("beforeunload"));
      await (window as any).analyticsBarrier();
    });
  const waitMethods = async (count: number) => {
    await expect
      .poll(async () => {
        await flush();
        return methods().length;
      })
      .toBe(count);
  };
  const waitReady = async () => {
    await expect.poll(() => rendered().length, { timeout: 6000 }).toBe(1);
    await expect.poll(readyCount).toBe(1);
  };
  const resolveGoogle = (available: boolean) =>
    page.evaluate(
      (result) => (window as any).analyticsResolveGoogle({ result }),
      available,
    );
  return {
    events,
    frame,
    rendered,
    methods,
    readyCount,
    flush,
    waitMethods,
    waitReady,
    resolveGoogle,
  };
}
