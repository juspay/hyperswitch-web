import type { BrowserContext, Page } from "@playwright/test";
import { test, expect, paymentBody } from "../../fixtures";
import { CLIENT_BASE_URL, SDK_URL } from "../../fixtures/env";
import { savedCard } from "./payment-method-analytics-helpers";

test.use({
  launchOptions: { args: ["--disable-features=LocalNetworkAccessChecks"] },
});

type AnalyticsLog = {
  frameKind: string;
  event_name: string;
  payment_id: string;
  merchant_id: string;
  session_id: string;
  value: string;
};
async function captureLogs(context: BrowserContext) {
  const rows: AnalyticsLog[] = [];
  await context.exposeBinding("identityBarrier", () => null);
  await context.exposeBinding("auditLogs", ({ frame }, data: string) => {
    const url = new URL(frame.url() || "about:blank");
    const frameKind =
      url.searchParams.get("fullscreenType") ||
      url.searchParams.get("componentName") ||
      "host";
    for (const row of JSON.parse(data)) rows.push({ frameKind, ...row });
  });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, "sendBeacon", {
      value: (_url: string, data: string) => {
        (window as any).auditLogs(data);
        return true;
      },
    });
  });
  return rows;
}

for (const { name, key, token, merchantId, paymentId } of [
  {
    name: "explicit key wins",
    key: "pk_explicit",
    token: Buffer.from("payment_id=pay_A,publishable_key=pk_token").toString(
      "base64",
    ),
    merchantId: "pk_explicit",
    paymentId: "pay_A",
  },
  {
    name: "embedded key fallback",
    key: "",
    token: Buffer.from("payment_id=pay_A,publishable_key=pk_token").toString(
      "base64",
    ),
    merchantId: "pk_token",
    paymentId: "pay_A",
  },
  {
    name: "malformed token fallback",
    key: "",
    token: "malformed!",
    merchantId: "",
    paymentId: "pay_legacy",
  },
  {
    name: "missing merchant key",
    key: "",
    token: Buffer.from("payment_id=pay_A").toString("base64"),
    merchantId: "",
    paymentId: "pay_A",
  },
]) {
  test(`merchant identity: ${name}`, async ({ context, page }) => {
    const rows = await captureLogs(context);
    await openHost(page);
    await page.evaluate(
      ({ key, token }) => {
        const w = window as any;
        w.Hyper(key, {
          isPreloadEnabled: false,
        }).initPaymentSession({
          clientSecret: "pay_legacy_secret_sample",
          sdkAuthorization: token,
        });
      },
      { key, token },
    );
    await expect
      .poll(async () => {
        await flushLogs(page);
        return rows.filter((r) => r.event_name === "PAYMENT_SESSION_INITIATED")
          .length;
      })
      .toBe(1);
    expect(
      rows
        .filter((r) => r.event_name === "PAYMENT_SESSION_INITIATED")
        .map((r) => [r.merchant_id, r.payment_id]),
    ).toEqual([[merchantId, paymentId]]);
  });
}

test("Apple Pay bridge logs retain token identity", async ({
  context,
  page,
}) => {
  const rows = await captureLogs(context);
  await page.addInitScript(() => {
    Object.defineProperty(window, "ApplePaySession", {
      value: class {
        oncancel?: () => void;
        begin() {
          this.oncancel?.();
        }
      },
    });
  });
  await openHost(page);
  await page.evaluate(() => {
    window.postMessage(
      {
        hyperApplePayButtonClicked: true,
        paymentRequest: {},
        sdkAuthorization: btoa("payment_id=pay_apple,publishable_key=pk_apple"),
        sdkSessionId: "hyp_apple",
      },
      location.origin,
    );
  });
  await expect
    .poll(async () => {
      await flushLogs(page);
      return rows.filter((row) => row.event_name === "APPLE_PAY_FLOW");
    })
    .toEqual([
      expect.objectContaining({
        payment_id: "pay_apple",
        merchant_id: "pk_apple",
        session_id: "hyp_apple",
        value: "Apple Pay Payment Cancelled",
      }),
    ]);
});

test("headless payment-method session logs use the token's merchant", async ({
  context,
  page,
  hermetic,
}) => {
  const rows = await captureLogs(context);
  hermetic.use({
    name: "identityPaymentMethodSession",
    path: "/v1/payment-method-sessions/pms_identity",
    body: {
      payment_method_session_id: "pms_identity",
      customer_id: "cus_identity",
      vault_details: { vault_type: "hyperswitch", vault_data: {} },
    },
  });
  await openHost(page);
  await page.evaluate(() => {
    (window as any)
      .Hyper({}, { isPreloadEnabled: false })
      .initPaymentMethodSession({
        sdkAuthorization: btoa(
          "payment_method_session_id=pms_identity,publishable_key=pk_management",
        ),
      });
  });
  await hermetic.waitForCall("identityPaymentMethodSession");
  await expect
    .poll(async () => {
      await flushLogs(page);
      return rows.filter(
        (row) => row.event_name === "PAYMENT_METHOD_SESSION_INITIATED",
      );
    })
    .toEqual([
      expect.objectContaining({
        payment_id: "pms_identity",
        merchant_id: "pk_management",
      }),
    ]);
});

for (const merchantKey of ["embedded", "explicit"]) {
  for (const surface of ["pazeWallet", "plaidSDK", "voucherData", "qrData"]) {
    test(`fullscreen ${surface} logs retain token identity with ${merchantKey} key`, async ({
      context,
      page,
      api,
      hermetic,
    }) => {
      const rows = await captureLogs(context);
      const intent = await api.createPaymentIntent(paymentBody());
      await context.route(
        "https://cdn.plaid.com/link/v2/stable/link-initialize.js",
        (route) =>
          route.fulfill({
            contentType: "application/javascript",
            body: "window.Plaid={create:options=>({open:()=>options.onLoad()})};",
          }),
      );
      await context.route(
        "https://checkout.paze.com/web/resources/js/digitalwallet-sdk.js",
        (route) =>
          route.fulfill({
            contentType: "application/javascript",
            body: 'window.DIGITAL_WALLET_SDK={initialize:async()=>{throw new Error("test vendor failure")}};',
          }),
      );
      await openHost(page);
      await page.evaluate(
        ({ surface, sdkUrl, intent, merchantKey }) => {
          const metadata = {
            sdkAuthorization: btoa(
              "payment_id=" +
                intent.paymentId +
                (merchantKey === "embedded" ? ",publishable_key=pk_token" : ""),
            ),
            publishableKey: merchantKey === "explicit" ? "pk_explicit" : "",
            wallet: "Paze",
            clientId: "test",
            clientName: "test",
            clientProfileId: "test",
            sessionId: intent.paymentId,
            transactionAmount: "10",
            transactionCurrencyCode: "USD",
            linkToken: "test",
            pmAuthConnectorArray: ["plaid"],
            isForceSync: false,
            voucherUrl: location.origin + "/voucher",
            returnUrl: location.origin + "/return",
            reference: "123",
            paymentMethod: "boleto",
            payment_intent_data: {
              payment_id: intent.paymentId,
              status: "requires_customer_action",
            },
            qrData: "",
            rawQrData: "test",
            url: location.origin + "/return",
          };
          const frame = document.createElement("iframe");
          frame.id = "identity-fullscreen";
          window.addEventListener("message", (event) => {
            let data = event.data;
            if (typeof data === "string") {
              try {
                data = JSON.parse(data);
              } catch {
                return;
              }
            }
            if (
              event.source === frame.contentWindow &&
              data?.iframeMountedCallback
            ) {
              frame.contentWindow!.postMessage(
                JSON.stringify({ fullScreenIframeMounted: true, metadata }),
                new URL(sdkUrl).origin,
              );
            }
          });
          frame.src =
            sdkUrl + "/fullscreenIndex.html?fullscreenType=" + surface;
          document.body.appendChild(frame);
        },
        { surface, sdkUrl: SDK_URL, intent, merchantKey },
      );
      const event = {
        pazeWallet: "PAZE_SDK_FLOW",
        plaidSDK: "PLAID_SDK",
        voucherData: "DISPLAY_VOUCHER",
        qrData: "RETRIEVE_CALL",
      }[surface]!;
      // Voucher's existing first auto-click happens before metadata arrives.
      // Verify the subsequent download, when token identity is available.
      const matchingLogs = () =>
        rows.filter(
          (r) =>
            r.frameKind === surface &&
            r.event_name === event &&
            (surface !== "voucherData" || r.value !== "0"),
        );
      await expect
        .poll(
          async () => {
            await flushLogs(page);
            return matchingLogs().length;
          },
          { timeout: 10_000 },
        )
        .toBeGreaterThan(0);
      for (const row of matchingLogs()) {
        expect(row.payment_id, row.value).toBe(intent.paymentId);
        expect(row.merchant_id, row.value).toBe(
          merchantKey === "embedded" ? "pk_token" : "pk_explicit",
        );
      }
      expect(hermetic.unmatched).toEqual([]);
    });
  }
}
async function openHost(page: Page) {
  const merchantUrl = CLIENT_BASE_URL + "/audit-identity";
  await page.route(merchantUrl, (route) =>
    route.fulfill({
      contentType: "text/html",
      body: '<div id="payment" style="width:460px"></div>',
    }),
  );
  await page.goto(merchantUrl);
  const script = await page.request.get(SDK_URL + "/HyperLoader.js");
  expect(script.ok()).toBe(true);
  await page.addScriptTag({ content: await script.text() });
}
async function flushLogs(page: Page) {
  for (const frame of page.frames())
    await frame
      .evaluate(async () => {
        window.dispatchEvent(new Event("beforeunload"));
        await (window as any).identityBarrier();
      })
      .catch(() => {});
}

for (const mode of [
  "legacy",
  "token-with-key",
  "token-only",
  "token-with-embedded-key",
  "token-key-update",
  "token-delayed",
  "token-update",
  "legacy-update",
  "failed-update",
]) {
  test(mode, async ({ context, page, api, credentials, hermetic }) => {
    const rows = await captureLogs(context);
    hermetic.override("sessionTokens", { session_token: [] });
    hermetic.override("clientList", (route) => ({
      ...route,
      delayMs: mode === "token-delayed" ? 700 : 0,
      body: {
        ...(route.body as any),
        payment_methods_enabled: (
          route.body as any
        ).payment_methods_enabled.filter(
          (m: any) => m.payment_method === "card",
        ),
        customer_payment_methods: [],
      },
    }));
    const intent = await api.createPaymentIntent(paymentBody());
    await openHost(page);
    await page.evaluate(
      ({ mode, intent, key }) => {
        const w = window as any;
        const token = btoa(
          "payment_id=" +
            intent.paymentId +
            (mode === "token-with-embedded-key" || mode === "token-key-update"
              ? ",publishable_key=" + key
              : ""),
        );
        const legacy = mode.startsWith("legacy");
        w.auditHyper = w.Hyper(
          [
            "token-only",
            "token-with-embedded-key",
            "token-key-update",
          ].includes(mode)
            ? {}
            : key,
          { isPreloadEnabled: false },
        );
        w.auditElements = w.auditHyper.elements(
          legacy
            ? { clientSecret: intent.clientSecret }
            : { sdkAuthorization: token },
        );
        w.auditElement = w.auditElements.create("payment", {
          layout: { type: "tabs" },
          wallets: {
            walletReturnUrl: location.origin + "/return",
            googlePay: "never",
            applePay: "never",
            payPal: "never",
          },
        });
        w.auditElement.mount("#payment");
      },
      { mode, intent, key: credentials.publishableKey },
    );
    await expect
      .poll(
        () => rows.filter((r) => r.event_name === "ELEMENT_RENDERED").length,
      )
      .toBe(1);
    const flush = () => flushLogs(page);
    await flush();
    const initial = rows.slice();
    if (mode.endsWith("update")) {
      hermetic.setIntent({
        payment_id: "pay_audit_B",
        client_secret: "pay_audit_B_secret_sample",
      });
      hermetic.override("clientList", (route) =>
        mode === "failed-update"
          ? {
              ...route,
              status: 400,
              body: { error: { message: "Update rejected for test" } },
            }
          : {
              ...route,
              body: {
                ...(route.body as any),
                customer_payment_methods: [savedCard],
              },
            },
      );
      const response = await page.evaluate(
        (mode) =>
          (window as any).auditElements.updateIntent(async () => ({
            sdkAuthorization: btoa(
              "payment_id=pay_audit_B" +
                (mode === "token-key-update"
                  ? ",publishable_key=pk_token_updated"
                  : ""),
            ),
          })),
        mode,
      );
      if (mode === "failed-update") {
        expect(response.error.type).toBe("update_intent_error");
      } else {
        expect(response.status).toBe("succeeded");
        await expect
          .poll(async () => {
            await flush();
            return rows.filter(
              (r) => r.event_name === "PAYMENT_METHODS_RENDERED",
            ).length;
          })
          .toBeGreaterThan(1);
      }
      const paymentFrame = page
        .frames()
        .find(
          (f) =>
            new URL(f.url()).searchParams.get("componentName") === "payment",
        )!;
      await paymentFrame.locator("body").click({ position: { x: 2, y: 2 } });
      await flush();
      await page.evaluate(() =>
        (window as any).auditHyper.confirmPayment({
          confirmParams: { return_url: location.origin + "/return" },
        }),
      );
      await flush();
    }
    expect(
      initial.some(
        (r) =>
          r.event_name === "ELEMENT_MOUNT_CALLED" &&
          r.payment_id === intent.paymentId,
      ),
    ).toBe(true);
    const expectedMerchant =
      mode === "token-only" ? "" : credentials.publishableKey;
    const initialEvents = initial.filter((r) =>
      [
        "PRE_MOUNT_LOADER_INIT",
        "SESSIONS_CALL",
        "SDK_CONFIGS_CALL",
        "CLIENT_LIST_CALL",
        "ELEMENT_MOUNT_CALLED",
        "ELEMENT_MOUNTED",
        "ELEMENT_RENDERED",
        "PAYMENT_METHODS_RENDERED",
        "PRE_MOUNT_LOADER_CLEANUP",
      ].includes(r.event_name),
    );
    expect(
      initialEvents.filter((r) => r.frameKind === "preMountLoader").length,
    ).toBeGreaterThanOrEqual(4);
    for (const row of initialEvents) {
      expect(row.payment_id, `${row.frameKind}/${row.event_name}`).toBe(
        intent.paymentId,
      );
      expect(row.merchant_id, `${row.frameKind}/${row.event_name}`).toBe(
        expectedMerchant,
      );
    }
    if (mode.endsWith("update")) {
      const updatedEvents =
        mode === "failed-update"
          ? ["USER_INTERACTED", "PAYMENT_CONFIRM_TRIGGERED"]
          : [
              "PAYMENT_METHODS_RENDERED",
              "USER_INTERACTED",
              "PRE_MOUNT_LOADER_CLEANUP",
              "PAYMENT_CONFIRM_TRIGGERED",
            ];
      const updated = rows
        .slice(initial.length)
        .filter((r) => updatedEvents.includes(r.event_name));
      expect(new Set(updated.map((r) => r.event_name))).toEqual(
        new Set(updatedEvents),
      );
      for (const row of updated) {
        expect(row.payment_id, `${row.frameKind}/${row.event_name}`).toBe(
          mode === "failed-update" ? intent.paymentId : "pay_audit_B",
        );
        expect(row.merchant_id, `${row.frameKind}/${row.event_name}`).toBe(
          mode === "token-key-update" ? "pk_token_updated" : expectedMerchant,
        );
      }
    }
  });
}

test("management logs use the payment-method session without overwriting payment logs", async ({
  context,
  page,
  hermetic,
}) => {
  const rows = await captureLogs(context);
  hermetic.use({
    name: "identityManagementList",
    path: "/v1/payment-method-sessions/pms_identity/list-payment-methods",
    body: { payment_methods: [] },
  });
  await openHost(page);
  await page.evaluate(() => {
    const hyper = (window as any).Hyper({}, { isPreloadEnabled: false });
    hyper.initPaymentSession({
      sdkAuthorization: btoa("payment_id=pay_A,publishable_key=pk_payment"),
    });
    hyper
      .paymentMethodsManagementElements({
        sdkAuthorization: btoa(
          "payment_method_session_id=pms_identity,publishable_key=pk_management",
        ),
      })
      .create("paymentMethodsManagement", {})
      .mount("#payment");
    (window as any).identityManagementHyper = hyper;
  });
  await hermetic.waitForCall("identityManagementList");
  await expect
    .poll(async () => {
      await flushLogs(page);
      return rows.some((r) => r.event_name === "PRE_MOUNT_LOADER_CLEANUP");
    })
    .toBe(true);
  const frame = page
    .frames()
    .find(
      (f) =>
        new URL(f.url()).searchParams.get("componentName") ===
        "paymentMethodsManagement",
    )!;
  await frame.locator("body").click({ position: { x: 2, y: 2 } });
  await page.evaluate(() => {
    (window as any).identityManagementHyper.confirmPayment({
      confirmParams: { return_url: location.origin + "/return" },
    });
  });
  await flushLogs(page);
  const events = [
    "PAYMENT_MANAGEMENT_ELEMENTS_CALLED",
    "PRE_MOUNT_LOADER_INIT",
    "PRE_MOUNT_LOADER_CLEANUP",
    "USER_INTERACTED",
  ];
  const managementRows = rows.filter((r) => events.includes(r.event_name));
  expect(new Set(managementRows.map((r) => r.event_name))).toEqual(
    new Set(events),
  );
  for (const row of managementRows) {
    expect(row.payment_id, `${row.frameKind}/${row.event_name}`).toBe(
      "pms_identity",
    );
    expect(row.merchant_id, `${row.frameKind}/${row.event_name}`).toBe(
      "pk_management",
    );
  }
  expect(
    rows.find((r) => r.event_name === "PAYMENT_CONFIRM_TRIGGERED"),
  ).toMatchObject({ payment_id: "pay_A", merchant_id: "pk_payment" });
  expect(hermetic.unmatched).toEqual([]);
});
