import { test, expect, testIds } from "../../fixtures";
import {
  openAnalyticsCheckout,
  savedCard,
} from "./payment-method-analytics-helpers";

test.use({
  launchOptions: { args: ["--disable-features=LocalNetworkAccessChecks"] },
});

test.describe("Payment method analytics @hermetic-only", () => {
  for (const saved of [false, true]) {
    test(`initial snapshot includes a delayed ${saved ? "saved wallet" : "wallet tab"}`, async ({
      context,
      page,
      api,
      credentials,
      hermetic,
    }) => {
      const fixtures = { context, page, api, credentials, hermetic };
      const r = await openAnalyticsCheckout(fixtures, {
        saved,
        savedWallet: saved,
      });
      await fixtures.page.waitForTimeout(150);
      await r.flush();
      expect(r.rendered()).toHaveLength(0);
      expect(r.methods()).toHaveLength(0);
      await r.resolveGoogle(true);
      await r.waitReady();
      await r.waitMethods(1);
      expect(
        saved ? r.methods()[0].saved_methods : r.methods()[0].payment_methods,
      ).toContain("google_pay");
      expect(JSON.parse(r.rendered()[0].value)).not.toHaveProperty(
        "payment_methods",
      );
      const names = r.events.map((event) => event.event_name);
      expect(names.indexOf("ELEMENT_RENDERED")).toBeLessThan(
        names.indexOf("PAYMENT_METHODS_RENDERED"),
      );
    });
  }

  for (const config of [
    { name: "progressive", progressive: true },
    { name: "timeout", progressive: false },
    {
      name: "saved timeout",
      progressive: false,
      saved: true,
      savedWallet: true,
    },
  ]) {
    test(`late wallet changes the snapshot without repeating readiness: ${config.name}`, async ({
      context,
      page,
      api,
      credentials,
      hermetic,
    }) => {
      const fixtures = { context, page, api, credentials, hermetic };
      const r = await openAnalyticsCheckout(fixtures, config);
      await r.waitReady();
      await r.waitMethods(1);
      expect(
        config.saved
          ? r.methods()[0].saved_methods
          : r.methods()[0].payment_methods,
      ).not.toContain("google_pay");
      await r.resolveGoogle(true);
      await expect(
        r.frame.getByText("Google Pay", { exact: true }),
      ).toBeVisible();
      await r.waitMethods(2);
      expect(
        config.saved
          ? r.methods()[1].saved_methods
          : r.methods()[1].payment_methods,
      ).toContain("google_pay");
      expect(r.rendered()).toHaveLength(1);
      expect(await r.readyCount()).toBe(1);
    });
  }

  test("unavailable wallet does not duplicate an unchanged snapshot", async ({
    context,
    page,
    api,
    credentials,
    hermetic,
  }) => {
    const fixtures = { context, page, api, credentials, hermetic };
    const r = await openAnalyticsCheckout(fixtures, { progressive: true });
    await r.waitReady();
    await r.waitMethods(1);
    await r.resolveGoogle(false);
    await fixtures.page.waitForTimeout(150);
    await r.flush();
    expect(r.methods()).toHaveLength(1);
    expect(await r.readyCount()).toBe(1);
  });

  test("typing and resizing do not duplicate snapshots or readiness", async ({
    context,
    page,
    api,
    credentials,
    hermetic,
  }) => {
    const fixtures = { context, page, api, credentials, hermetic };
    const r = await openAnalyticsCheckout(fixtures, { noGoogle: true });
    await r.waitReady();
    await r.waitMethods(1);
    const cardFrame = fixtures.page
      .frames()
      .find((frame) =>
        frame.url().includes("componentName=paymentMethodsSDK"),
      )!;
    await cardFrame
      .getByTestId(testIds.cardNoInputTestId)
      .pressSequentially("4242424242424242");
    await fixtures.page.setViewportSize({ width: 1000, height: 780 });
    await fixtures.page.waitForTimeout(150);
    await r.flush();
    expect(r.methods()).toHaveLength(1);
    expect(r.rendered()).toHaveLength(1);
    expect(await r.readyCount()).toBe(1);
  });

  test("switching screens preserves the SDK lists and logs the screen", async ({
    context,
    page,
    api,
    credentials,
    hermetic,
  }) => {
    const fixtures = { context, page, api, credentials, hermetic };
    const r = await openAnalyticsCheckout(fixtures, {
      saved: true,
      noGoogle: true,
    });
    await r.waitReady();
    await r.waitMethods(1);
    expect(r.methods()[0]).toMatchObject({
      screen: "saved_methods",
      payment_methods: ["card"],
      saved_methods: ["credit"],
    });
    await r.frame
      .getByRole("button", { name: "Click to use new payment methods" })
      .click();
    await r.waitMethods(2);
    expect(r.methods()[1]).toMatchObject({
      screen: "payment_methods",
      payment_methods: ["card"],
      saved_methods: ["credit"],
    });
    await r.frame
      .getByRole("button", { name: "Click to use existing payment methods" })
      .click();
    await r.waitMethods(3);
    expect(r.methods()[2]).toEqual(r.methods()[0]);
    expect(r.rendered()).toHaveLength(1);
    expect(await r.readyCount()).toBe(1);
  });

  test("updateIntent logs changed methods without duplicating an unchanged list", async ({
    context,
    page,
    api,
    credentials,
    hermetic,
  }) => {
    const fixtures = { context, page, api, credentials, hermetic };
    const r = await openAnalyticsCheckout(fixtures, { noGoogle: true });
    await r.waitReady();
    await r.waitMethods(1);
    fixtures.hermetic.override("clientList", (route) => ({
      ...route,
      body: {
        ...(route.body as object),
        customer_payment_methods: [savedCard],
      },
    }));
    for (let update = 1; update <= 2; update++) {
      const result = await fixtures.page.evaluate(
        (update) =>
          (window as any).analyticsElements.updateIntent(async () => ({
            sdkAuthorization: "analytics-test-" + update,
          })),
        update,
      );
      expect(result.status).toBe("succeeded");
      if (update === 1) await r.waitMethods(2);
      expect(await r.readyCount()).toBe(update + 1);
    }
    await fixtures.page.waitForTimeout(150);
    await r.flush();
    expect(r.methods()).toHaveLength(2);
    expect(r.methods()[1].saved_methods).toEqual(["credit"]);
    expect(r.rendered()).toHaveLength(1);
  });

  for (const saved of [false, true]) {
    test(`wallet readiness does not duplicate the existing SDK list: saved=${saved}`, async ({
      context,
      page,
      api,
      credentials,
      hermetic,
    }) => {
      const r = await openAnalyticsCheckout(
        { context, page, api, credentials, hermetic },
        { saved, progressive: !saved, layout: { type: "tabs" } },
      );
      await r.waitReady();
      await r.waitMethods(1);
      // The existing top-wallet list includes Google Pay before availability
      // resolves. This event reports that list, not individual button visibility.
      expect(r.methods()[0]).toMatchObject({
        payment_methods: ["card"],
        saved_methods: saved ? ["credit"] : [],
        wallets: ["google_pay"],
        screen: saved ? "saved_methods" : "payment_methods",
      });
      await r.resolveGoogle(true);
      if (!saved) {
        await expect(
          r.frame.getByRole("button", { name: "Test Google Pay" }),
        ).toBeVisible();
      }
      await page.waitForTimeout(150);
      await r.flush();
      expect(r.methods()).toHaveLength(1);
      expect(r.rendered()).toHaveLength(1);
      expect(await r.readyCount()).toBe(1);
    });
  }

  test("unmount before readiness prevents late analytics", async ({
    context,
    page,
    api,
    credentials,
    hermetic,
  }) => {
    const fixtures = { context, page, api, credentials, hermetic };
    const r = await openAnalyticsCheckout(fixtures);
    await fixtures.page.evaluate(() =>
      (window as any).analyticsElement.unmount(),
    );
    await expect(
      fixtures.page.locator("#orca-payment-element-iframeRef-payment"),
    ).toHaveCount(0);
    await r.resolveGoogle(true);
    await fixtures.page.waitForTimeout(150);
    expect(r.rendered()).toHaveLength(0);
    expect(r.methods()).toHaveLength(0);
  });

  test("remount starts fresh lifecycle and method reporting", async ({
    context,
    page,
    api,
    credentials,
    hermetic,
  }) => {
    const fixtures = { context, page, api, credentials, hermetic };
    const r = await openAnalyticsCheckout(fixtures, { noGoogle: true });
    await r.waitReady();
    await r.waitMethods(1);
    await fixtures.page.evaluate(() => {
      const element = (window as any).analyticsElement;
      element.unmount();
      element.mount("#payment");
    });
    await expect.poll(() => r.rendered().length).toBe(2);
    await expect.poll(() => r.methods().length).toBe(2);
    expect(r.methods()[1]).toEqual(r.methods()[0]);
  });
});

const readinessLayouts = [
  {
    name: "progressive",
    progressive: true,
    layout: { type: "tabs" },
    readyBeforeWallet: true,
  },
  {
    name: "saved screen with later wallet",
    saved: true,
    layout: { type: "tabs" },
    readyBeforeWallet: true,
  },
  { name: "top wallets", layout: { type: "tabs" }, readyBeforeWallet: false },
  {
    name: "wallet tabs",
    layout: { type: "tabs", displayOneClickPaymentMethodsOnTop: false },
    readyBeforeWallet: false,
  },
  {
    name: "separate saved tab",
    saved: true,
    layout: {
      type: "tabs",
      savedMethodCustomization: {
        groupingBehavior: {
          displayInSeparateScreen: false,
          groupByPaymentMethods: false,
        },
      },
    },
    readyBeforeWallet: false,
  },
  {
    name: "grouped saved accordion",
    saved: true,
    layout: {
      type: "accordion",
      savedMethodCustomization: {
        groupingBehavior: {
          displayInSeparateScreen: false,
          groupByPaymentMethods: true,
        },
      },
    },
    readyBeforeWallet: false,
  },
  {
    name: "saved wallet screen",
    saved: true,
    savedWallet: true,
    layout: { type: "tabs" },
    readyBeforeWallet: false,
  },
];

test.describe("Analytics preserves readiness gates @hermetic-only", () => {
  for (const layout of readinessLayouts) {
    for (const outcome of ["available", "unavailable", "timeout"] as const) {
      test(`${layout.name}: ${outcome}`, async ({
        context,
        page,
        api,
        credentials,
        hermetic,
      }) => {
        const r = await openAnalyticsCheckout(
          { context, page, api, credentials, hermetic },
          layout,
        );
        if (layout.readyBeforeWallet) {
          await r.waitReady();
        } else {
          // Longer than the readiness settle window, shorter than availability timeout.
          await page.waitForTimeout(150);
          expect(await r.readyCount()).toBe(0);
          expect(r.rendered()).toHaveLength(0);
        }
        if (outcome !== "timeout")
          await r.resolveGoogle(outcome === "available");
        await r.waitReady();
        await expect
          .poll(async () => {
            await r.flush();
            return r.methods().length;
          })
          .toBeGreaterThan(0);
        expect(r.rendered()).toHaveLength(1);
        expect(await r.readyCount()).toBe(1);
      });
    }
  }
});
