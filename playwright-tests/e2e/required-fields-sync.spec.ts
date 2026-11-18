// Full checkout layer, separate from the component harness and CacReader tests.
// Existing synthetic protocol fixtures supply scaffolding only; all dynamic
// rules and expected field presence below are independently authored.
import { test, expect, paymentBody } from "../fixtures";
import { SDK_URL, CLIENT_BASE_URL } from "../fixtures/env";
import {
  loadPack,
  verifyArtifacts,
} from "../required-fields-sync/contract.cjs";
verifyArtifacts(loadPack().pack);

const descriptor = (name: string) => ({
  [`dynamic_fields.${name}._is_required`]: false,
  [`dynamic_fields.${name}._field_render_type`]: "Generic",
  [`dynamic_fields.${name}._confirm_request_write_path`]: `payment_method_data.${name}`,
  [`dynamic_fields.${name}._default_label_text`]: name,
  [`dynamic_fields.${name}._field_display_order`]: 1,
});
function response(name: string) {
  return {
    raw_configs: {
      default_configs: { ...descriptor(name), ...descriptor("credit_only") },
      contexts: [
        {
          condition: {
            connector: "stripe",
            payment_method: "Card",
            payment_method_type: "Debit",
          },
          override_with_keys: ["debit"],
        },
        {
          condition: {
            connector: "stripe",
            payment_method: "Card",
            payment_method_type: "Credit",
          },
          override_with_keys: ["credit"],
        },
      ],
      overrides: {
        debit: { [`dynamic_fields.${name}._is_required`]: true },
        credit: { "dynamic_fields.credit_only._is_required": true },
      },
    },
    payment_methods: [
      {
        payment_method: "card",
        payment_method_types: ["credit", "debit"].map(
          (payment_method_type) => ({
            payment_method_type,
            criteria_rules: [
              { criteria_value: "default", eligible_connectors: ["stripe"] },
            ],
          }),
        ),
      },
    ],
  };
}
test.describe("required-fields sync @hermetic-only", () => {
  test.beforeEach(async ({ context, mode, browser }) => {
    test.info().annotations.push({
      type: "browser-version",
      description: browser.version(),
    });
    expect(mode).toBe("hermetic");
    for (const value of [SDK_URL, CLIENT_BASE_URL]) {
      const u = new URL(value);
      expect(u.protocol).toBe("http:");
      expect(["127.0.0.1", "localhost"]).toContain(u.hostname);
    }
    await context.route("**/*", (route) => {
      const u = new URL(route.request().url());
      if (
        route.request().method() === "POST" &&
        /\/confirm(?:\/|$)/.test(u.pathname)
      )
        return route.abort();
      if (u.pathname.startsWith("/assets/v1/jsons/location/"))
        return route.fulfill({
          status: 404,
          contentType: "text/plain",
          body: "synthetic asset unavailable",
        });
      // Never allow the dev-server's local /payments proxy to reach sandbox.
      if (
        ["127.0.0.1", "localhost"].includes(u.hostname) &&
        u.pathname.startsWith("/payments") &&
        !["/payments/config", "/payments/urls"].includes(u.pathname)
      )
        return route.abort();
      return route.fallback(); // the existing hermetic engine intercepts nonlocal traffic
    });
  });
  test("E-card-debit ordinary card form uses Debit even with Credit also eligible", async ({
    hermetic,
    checkout,
    sdk,
  }) => {
    hermetic.override("sdkConfigs", (route) => ({
      ...route,
      body: response("debit_probe"),
    }));
    await checkout.open({ body: paymentBody({ billing: undefined }) });
    await hermetic.waitForCall("sdkConfigs");
    await sdk.waitForReady();
    await expect(sdk.field("debit_probe")).toBeVisible();
    await expect(sdk.field("credit_only")).toHaveCount(0);
  });
  test("E-snapshot-retained open checkout keeps snapshot; reload acquires changed config", async ({
    hermetic,
    checkout,
    sdk,
    page,
  }) => {
    hermetic.override("sdkConfigs", (route) => ({
      ...route,
      body: response("snapshot_one"),
    }));
    await checkout.open({ body: paymentBody({ billing: undefined }) });
    await sdk.waitForReady();
    await expect(sdk.field("snapshot_one")).toBeVisible();
    hermetic.override("sdkConfigs", (route) => ({
      ...route,
      body: response("snapshot_two"),
    }));
    await sdk.field("snapshot_one").fill("fixture interaction");
    await expect(sdk.field("snapshot_one")).toHaveValue("fixture interaction");
    await expect(sdk.field("snapshot_two")).toHaveCount(0);
    await page.reload();
    await sdk.waitForReady();
    await expect(sdk.field("snapshot_two")).toBeVisible();
    await expect(sdk.field("snapshot_one")).toHaveCount(0);
    hermetic.override("sdkConfigs", (route) => ({
      ...route,
      body: response("snapshot_one"),
    }));
    await expect(sdk.field("snapshot_two")).toBeVisible();
    await page.reload();
    await sdk.waitForReady();
    await expect(sdk.field("snapshot_one")).toBeVisible();
    await expect(sdk.field("snapshot_two")).toHaveCount(0);
  });
  test("E-config-fetch-failure cannot be mistaken for required-fields verification", async ({
    hermetic,
    checkout,
    sdk,
  }) => {
    hermetic.override("sdkConfigs", (route) => ({
      ...route,
      status: 503,
      body: { error: "synthetic config unavailable" },
    }));
    await checkout.open({ body: paymentBody({ billing: undefined }) });
    const call = await hermetic.waitForCall("sdkConfigs");
    expect(call?.status).toBe(503);
    await expect(sdk.text("Oops, something went wrong!")).toBeVisible();
    await expect(sdk.field("debit_probe")).toHaveCount(0);
    await expect(
      sdk.find('iframe[src*="componentName=paymentMethodsSDK"]'),
    ).toHaveCount(0);
    // Actual PaymentElementRenderer gates the entire V1 form on LoadError.
  });
  test("E-confirm-body required validation gates actual card confirm and dynamic billing payload", async ({
    hermetic,
    checkout,
    sdk,
    page,
  }) => {
    hermetic.override("sdkConfigs", (route) => ({
      ...route,
      body: response("billing.address.line1"),
    }));
    await checkout.open({ body: paymentBody({ billing: undefined }) });
    await sdk.waitForReady();
    await sdk.enterCardDetails({
      cardNo: "4242424242424242",
      card_exp_month: "12",
      card_exp_year: "30",
      cvc: "123",
    });
    const confirms: any[] = [];
    page.on("request", (r) => {
      if (r.method() === "POST" && /\/confirm$/.test(new URL(r.url()).pathname))
        confirms.push(r.postDataJSON());
    });
    await sdk.field("line1").focus();
    await sdk.field("line1").blur();
    await expect(sdk.text("This field is mandatory")).toBeVisible();
    await sdk.submit();
    await expect(page.locator("#payment-message")).toHaveText(
      "Please enter valid details",
    );
    await expect(sdk.submitButton).toBeEnabled();
    expect(confirms).toEqual([]);
    await sdk.field("line1").fill("Fixture lane");
    const request = page.waitForRequest(
      (r) =>
        r.method() === "POST" && /\/confirm$/.test(new URL(r.url()).pathname),
    );
    await sdk.submit();
    const sent = (await request).postDataJSON();
    expect(sent.payment_method).toBe("card");
    expect(sent.payment_method_data).toEqual({
      card: {
        card_number: "4242424242424242",
        card_exp_month: "12",
        card_exp_year: "2030",
        card_cvc: "123",
        card_network: "Visa",
      },
      billing: { address: { line1: "Fixture lane" } },
    });
    expect(confirms).toHaveLength(1);
    expect(hermetic.calls("confirm")).toEqual([]); // aborted before the synthetic router too
  });
  test("E-inheritance actual checkout retains explicit mandate options equal to defaults", async ({
    hermetic,
    checkout,
    sdk,
  }) => {
    for (const [explicit, expected] of [
      [true, ["United States", "Canada"]],
      [false, ["United States"]],
    ] as const) {
      const config: any = response("billing.address.country");
      Object.assign(config.raw_configs.default_configs, {
        "dynamic_fields.billing.address.country._field_render_type": "Country",
        "dynamic_fields.billing.address.country._dropdown_options": [
          "US",
          "CA",
        ],
      });
      config.raw_configs.contexts.push({
        condition: { connector: "stripe" },
        override_with_keys: ["common"],
      });
      config.raw_configs.overrides.common = {
        "dynamic_fields.billing.address.country._dropdown_options": ["US"],
      };
      if (explicit) {
        config.raw_configs.contexts.push({
          condition: { connector: "stripe", mandate_type: "mandate" },
          override_with_keys: ["mandate"],
        });
        config.raw_configs.overrides.mandate = {
          "dynamic_fields.billing.address.country._dropdown_options": [
            "US",
            "CA",
          ],
        };
      }
      hermetic.override("sdkConfigs", (route) => ({ ...route, body: config }));
      hermetic.override("clientList", {
        intent_data: { payment_type: "new_mandate" },
      });
      await checkout.open({ body: paymentBody({ billing: undefined }) });
      await sdk.waitForReady();
      await expect(sdk.find("select option")).toHaveText([...expected]);
    }
  });
});
