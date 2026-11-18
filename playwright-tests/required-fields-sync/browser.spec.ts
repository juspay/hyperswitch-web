import { test, expect, type Page } from "@playwright/test";
import { loadPack, verifyArtifacts } from "./contract.cjs";
const { pack } = loadPack();
verifyArtifacts(pack);
declare global {
  interface Window {
    rf: any;
  }
}

// Presentation fixtures are handwritten here; no seed or renderer is loaded.
function field(
  id: string,
  write: string,
  kind = "Generic",
  options?: string[],
  extra = {},
) {
  const key = `dynamic_fields.${id}`;
  return Object.fromEntries(
    Object.entries({
      is_required: true,
      field_render_type: kind,
      confirm_request_write_path: write,
      intent_data_read_path: write.replace(/^payment_method_data\./, ""),
      default_label_text: id,
      field_display_order: 1,
      render_when_prefilled: false,
      ...(options === undefined ? {} : { dropdown_options: options }),
      ...extra,
    }).map(([attribute, value]) => [`${key}._${attribute}`, value]),
  );
}
function input(
  defaults = {},
  connectors = ["adyen"],
  method = "card",
  type = "debit",
) {
  return {
    method,
    type,
    response: {
      raw_configs: { default_configs: defaults, contexts: [], overrides: {} },
      payment_methods: [
        {
          payment_method: method,
          payment_method_types: [
            {
              payment_method_type: type,
              criteria_rules: [
                { criteria_value: "default", eligible_connectors: connectors },
              ],
            },
          ],
        },
      ],
    },
  };
}
async function mount(page: Page, value: any) {
  await page.evaluate((value) => window.rf.mount(value), value);
  await expect(page.locator("#probe")).toBeVisible();
  return page.evaluate(() => window.rf.snapshot());
}
async function payload(page: Page) {
  const request = page.waitForRequest(
    (r) => new URL(r.url()).pathname === "/fixture-confirm",
  );
  await page.locator("#fixture-confirm").click();
  return (await request).postDataJSON();
}
test.beforeEach(async ({ page, context, baseURL, browser }) => {
  test.info().annotations.push({
    type: "browser-version",
    description: browser.version(),
  });
  // All non-fixture traffic is denied. Confirmation is observed and aborted;
  // the local server never receives a POST, and no payment can be submitted.
  await context.route("**/*", (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === "/fixture-confirm") return route.abort();
    if (url.origin !== baseURL || url.pathname.startsWith("/forbidden-"))
      return route.abort();
    return route.continue();
  });
  await page.goto("/");
  await page.waitForFunction(() => !!window.rf);
});

test("B-context-defaults actual W constructor and U casing", async ({
  page,
}) => {
  const value = await mount(page, input());
  expect(value.context).toEqual({
    payment_method: "card",
    payment_method_type: "debit",
    country: "US",
    mandate_type: "non_mandate",
    platform: "web",
    always_collect_billing_details_from_wallet_connector: true,
    always_collect_shipping_details_from_wallet_connector: false,
  });
  expect(
    await page.evaluate(() =>
      window.rf.labels([
        "bank_debit",
        "ach",
        "online_banking_fpx",
        "open_banking_uk",
      ]),
    ),
  ).toEqual(["BankDebit", "Ach", "OnlineBankingFpx", "OpenBankingUk"]);
});
test("B-context-collection-or profile always flags OR collect flags", async ({
  page,
}) => {
  const i: any = input();
  i.response.account_config = {
    profile: {
      collect_billing_details_from_wallet_connector: false,
      always_collect_billing_details_from_wallet_connector: true,
      collect_shipping_details_from_wallet_connector: true,
      always_collect_shipping_details_from_wallet_connector: false,
    },
  };
  const s = await mount(page, i);
  expect(s.context.always_collect_billing_details_from_wallet_connector).toBe(
    true,
  );
  expect(s.context.always_collect_shipping_details_from_wallet_connector).toBe(
    true,
  );
});
test("B-mandate-classification actual client parser", async ({ page }) => {
  for (const [payment_type, expected] of [
    ["normal", "non_mandate"],
    ["new_mandate", "mandate"],
    ["setup_mandate", "mandate"],
    ["recurring_mandate", "non_mandate"],
    ["unknown", "non_mandate"],
  ]) {
    const s = await mount(page, {
      ...input(),
      client: { intent_data: { payment_type } },
    });
    expect(s.context.mandate_type).toBe(expected);
  }
});
test("B-provider-currency-absent despite router response containing scope", async ({
  page,
}) => {
  const i: any = input();
  i.response.context_used = {
    profile_id: "profile_fixture",
    processor_merchant_id: "processor_fixture",
    organization_id: "org_fixture",
    provider_merchant_id: "provider_fixture",
    currency: "USD",
  };
  const s = await mount(page, i);
  expect(s.context.profile_id).toBe("profile_fixture");
  expect(s.context).not.toHaveProperty("provider_merchant_id");
  expect(s.context).not.toHaveProperty("currency");
});
test("B-eligibility-order flattens all criteria and preserves connector spelling/order", async ({
  page,
}) => {
  const i = input();
  i.response.payment_methods[0].payment_method_types[0].criteria_rules = [
    { criteria_value: "visa", eligible_connectors: ["Y", "x"] },
    { criteria_value: "mastercard", eligible_connectors: ["x", "z"] },
  ];
  expect((await mount(page, i)).connectors).toEqual(["Y", "x", "z"]);
});
test("B-credit-only does not feed a Debit request", async ({ page }) => {
  const i = input(field("fixture", "payment_method_data.fixture"));
  i.response.payment_methods[0].payment_method_types[0].payment_method_type =
    "credit";
  const s = await mount(page, i);
  expect(s.connectors).toEqual([]);
  expect(s.descriptors).toEqual([]);
});
test("B-ui-type-normalization uses the actual bank and Bancontact paths", async ({
  page,
}) => {
  for (const [method, type, expected] of [
    ["bank_debit", "ach_debit", "ach"],
    ["bank_debit", "sepa_debit", "sepa"],
    ["bank_transfer", "sepa_bank_transfer", "sepa_bank_transfer"],
    ["bank_redirect", "bancontact_card", "bancontact_card"],
  ]) {
    expect(
      await page.evaluate(
        ([m, t]) => window.rf.methodName(m, t),
        [method, type],
      ),
    ).toBe(expected);
  }
  const s = await mount(
    page,
    input(
      field("bancontact", "payment_method_data.bancontact"),
      ["adyen"],
      "bank_redirect",
      "bancontact_card",
    ),
  );
  expect(s.context.payment_method_type).toBe("bancontact_card");
  expect(s.connectors).toEqual(["adyen"]);
});
test("B-inheritance explicit mandate options cannot be removed when equal to defaults", async ({
  page,
}) => {
  for (const [explicit, expected] of [
    [true, ["A", "B"]],
    [false, ["A"]],
  ] as const) {
    const i: any = input(
      field("choice", "payment_method_data.choice", "Dropdown", ["A", "B"]),
    );
    i.client = { intent_data: { payment_type: "new_mandate" } };
    i.response.raw_configs.contexts = [
      { condition: { connector: "adyen" }, override_with_keys: ["common"] },
    ];
    i.response.raw_configs.overrides = {
      common: { "dynamic_fields.choice._dropdown_options": ["A"] },
    };
    if (explicit) {
      i.response.raw_configs.contexts.push({
        condition: { connector: "adyen", mandate_type: "mandate" },
        override_with_keys: ["mandate"],
      });
      i.response.raw_configs.overrides.mandate = {
        "dynamic_fields.choice._dropdown_options": ["A", "B"],
      };
    }
    await mount(page, i);
    expect(
      await page
        .locator("select option")
        .evaluateAll((options) =>
          options.map((o) => (o as HTMLOptionElement).value),
        ),
    ).toEqual(expected);
    expect(await payload(page)).toEqual({
      payment_method_data: { choice: "A" },
    });
  }
});
test("B-connector-orders first included options win; unique later field survives", async ({
  page,
}) => {
  for (const [connectors, expected] of [
    [["x", "y"], ["A"]],
    [["y", "x"], ["B"]],
  ] as const) {
    const i: any = input(
      {
        ...field("shared", "payment_method_data.shared", "Dropdown"),
        ...field("unique", "payment_method_data.unique", "Generic", undefined, {
          is_required: false,
        }),
      },
      [...connectors],
    );
    i.response.raw_configs.contexts = [
      { condition: { connector: "x" }, override_with_keys: ["x"] },
      { condition: { connector: "y" }, override_with_keys: ["y"] },
    ];
    i.response.raw_configs.overrides = {
      x: { "dynamic_fields.shared._dropdown_options": ["A"] },
      y: {
        "dynamic_fields.shared._dropdown_options": ["B"],
        "dynamic_fields.unique._is_required": true,
      },
    };
    const s = await mount(page, i);
    expect(
      s.descriptors.find((f: any) =>
        f.confirmRequestWritePath.endsWith(".shared"),
      ).dropdownOptions,
    ).toEqual(expected);
    expect(
      s.descriptors.some((f: any) =>
        f.confirmRequestWritePath.endsWith(".unique"),
      ),
    ).toBe(true);
  }
});
test("B-givex-alias-orders dedup occurs before display sorting", async ({
  page,
}) => {
  const first = field(
    "gift_card.number",
    "payment_method_data.gift_card.givex.number",
    "Generic",
    undefined,
    {
      default_label_text: "First alias",
      field_display_order: 99,
      layout_row_id: "first",
    },
  );
  const second = field(
    "gift_card.givex.number",
    "payment_method_data.gift_card.givex.number",
    "Generic",
    undefined,
    {
      default_label_text: "Second alias",
      field_display_order: 1,
      layout_row_id: "second",
    },
  );
  for (const [defaults, label] of [
    [{ ...first, ...second }, "First alias"],
    [{ ...second, ...first }, "Second alias"],
  ] as const) {
    const s = await mount(
      page,
      input(defaults, ["givex"], "gift_card", "givex"),
    );
    expect(s.descriptors).toHaveLength(1);
    expect(s.descriptors[0].defaultLabelText).toBe(label);
  }
});
test("B-forced-billing-orders optional line2 can win before later required line2", async ({
  page,
}) => {
  for (const [connectors, required] of [
    [["x", "y"], false],
    [["y", "x"], true],
  ] as const) {
    const i: any = input(
      field(
        "billing.line2",
        "payment_method_data.billing.address.line2",
        "Generic",
        undefined,
        { is_required: false },
      ),
      [...connectors],
    );
    i.forceBilling = true;
    i.response.raw_configs.contexts = [
      { condition: { connector: "y" }, override_with_keys: ["y"] },
    ];
    i.response.raw_configs.overrides = {
      y: { "dynamic_fields.billing.line2._is_required": true },
    };
    const s = await mount(page, i);
    expect(s.descriptors).toHaveLength(1);
    expect(s.descriptors[0].isRequired).toBe(required);
  }
});
test("B-connector-exception actual hook omits failed connector and retains healthy fields", async ({
  page,
}) => {
  const i: any = input(
    {
      ...field("failed", "payment_method_data.failed", "Generic", undefined, {
        is_required: false,
      }),
      ...field("healthy", "payment_method_data.healthy", "Generic", undefined, {
        is_required: false,
      }),
    },
    ["x", "y"],
  );
  i.failConnector = "x";
  i.response.raw_configs.contexts = [
    { condition: { connector: "x" }, override_with_keys: ["x"] },
    { condition: { connector: "y" }, override_with_keys: ["y"] },
  ];
  i.response.raw_configs.overrides = {
    x: { "dynamic_fields.failed._is_required": true },
    y: { "dynamic_fields.healthy._is_required": true },
  };
  const s = await mount(page, i);
  expect(s.descriptors.map((f: any) => f.confirmRequestWritePath)).toEqual([
    "payment_method_data.healthy",
  ]);
  expect(await page.evaluate(() => window.rf.injectedFaults())).toBeGreaterThan(
    0,
  );
  await expect(page.getByTestId("failed")).toHaveCount(0);
  await expect(page.getByTestId("healthy")).toBeVisible();
});
test("B-baseline-removal preserved baseline remains required until an explicit false wins", async ({
  page,
}) => {
  for (const [connector, countryFalse, expected] of [
    [true, false, 1],
    [false, false, 1],
    [false, true, 0],
  ] as const) {
    const i: any = input(
      field("fixture", "payment_method_data.fixture", "Generic", undefined, {
        is_required: false,
      }),
    );
    i.response.raw_configs.contexts = [
      {
        condition: { payment_method: "Card" },
        override_with_keys: ["baseline"],
      },
    ];
    i.response.raw_configs.overrides = {
      baseline: { "dynamic_fields.fixture._is_required": true },
    };
    if (connector) {
      i.response.raw_configs.contexts.push({
        condition: { connector: "adyen" },
        override_with_keys: ["managed"],
      });
      i.response.raw_configs.overrides.managed = {
        "dynamic_fields.fixture._is_required": true,
      };
    }
    if (countryFalse) {
      i.response.raw_configs.contexts.push({
        condition: { country: "US" },
        override_with_keys: ["country"],
      });
      i.response.raw_configs.overrides.country = {
        "dynamic_fields.fixture._is_required": false,
      };
    }
    expect((await mount(page, i)).descriptors).toHaveLength(expected);
    await expect(page.getByTestId("fixture")).toHaveCount(expected);
  }
});
test("B-render-kind-change options remain inherited when another group changes descriptor kind", async ({
  page,
}) => {
  const i: any = input(
    field("choice", "payment_method_data.choice", "Dropdown", ["A"]),
  );
  i.client = { intent_data: { payment_type: "new_mandate" } };
  i.response.raw_configs.contexts = [
    { condition: { mandate_type: "mandate" }, override_with_keys: ["mandate"] },
  ];
  i.response.raw_configs.overrides = {
    mandate: { "dynamic_fields.choice._field_render_type": "Generic" },
  };
  const s = await mount(page, i);
  expect(s.descriptors[0].fieldRenderType).toBe("Generic");
  expect(s.descriptors[0].dropdownOptions).toEqual(["A"]);
  await expect(page.locator("select")).toHaveCount(0);
  await page.getByTestId("choice").fill("fixture text");
  expect(await payload(page)).toEqual({
    payment_method_data: { choice: "fixture text" },
  });
});
for (const show of [false, true])
  test(`B-prefill-${show ? "visible" : "hidden"} read path differs from field ID`, async ({
    page,
  }) => {
    const i: any = input(
      field(
        "gift_card.number",
        "payment_method_data.gift_card.givex.number",
        "Generic",
        undefined,
        { render_when_prefilled: show },
      ),
      ["givex"],
      "gift_card",
      "givex",
    );
    i.client = {
      intent_data: {
        payment_type: "normal",
        gift_card: { givex: { number: "fixture-prefill" } },
      },
    };
    const s = await mount(page, i);
    expect(s.initial).toEqual({
      payment_method_data: {
        gift_card: { givex: { number: "fixture-prefill" } },
      },
    });
    expect(s.visible).toHaveLength(show ? 1 : 0);
    await expect(page.getByTestId("number")).toHaveCount(show ? 1 : 0);
    expect(await payload(page)).toEqual({
      payment_method_data: {
        gift_card: { givex: { number: "fixture-prefill" } },
      },
    });
  });
test("B-billing-force keeps line2 optional and can suppress prefill", async ({
  page,
}) => {
  const i: any = input({
    ...field(
      "billing.line1",
      "payment_method_data.billing.address.line1",
      "Generic",
      undefined,
      { is_required: false },
    ),
    ...field(
      "billing.line2",
      "payment_method_data.billing.address.line2",
      "Generic",
      undefined,
      { is_required: false },
    ),
  });
  i.forceBilling = true;
  i.suppressPrefill = true;
  i.client = {
    intent_data: {
      billing: {
        address: { line1: "fixture address", line2: "fixture suite" },
      },
    },
  };
  const s = await mount(page, i);
  expect(s.descriptors.map((f: any) => f.isRequired)).toEqual([true, false]);
  expect(s.initial).toEqual({});
  await expect(page.getByTestId("line1")).toBeVisible();
  await expect(page.getByTestId("line2")).toBeVisible();
});
test("B-missing-metadata exposes unsafe Generic fallback; not a valid mapping", async ({
  page,
}) => {
  const s = await mount(
    page,
    input({ "dynamic_fields.orphan._is_required": true }),
  );
  expect(s.descriptors[0].confirmRequestWritePath).toBe(
    "dynamic_fields.orphan",
  );
  expect(s.descriptors[0].fieldRenderType).toBe("Generic");
});
test("B-empty-config absence does not activate legacy fallback", async ({
  page,
}) => {
  const i: any = input();
  delete i.response.raw_configs;
  expect((await mount(page, i)).descriptors).toEqual([]);
});
test("B-empty-connectors suppress even required defaults", async ({ page }) => {
  expect(
    (
      await mount(
        page,
        input(field("fixture", "payment_method_data.fixture"), []),
      )
    ).descriptors,
  ).toEqual([]);
});
for (const [id, options] of [
  ["B-lowercase-bank-type", ["checking", "savings"]],
  ["B-capitalized-bank-type", ["Checking", "Savings"]],
] as const)
  test(id, async ({ page }) => {
    await mount(
      page,
      input(
        field(
          "bank_debit.ach.bank_type",
          "payment_method_data.bank_debit.ach.bank_type",
          "Dropdown",
          [...options],
        ),
        ["stripe"],
        "bank_debit",
        "ach",
      ),
    );
    await expect(page.locator("select")).toHaveValue(options[0]);
    const expected =
      id === "B-lowercase-bank-type"
        ? {
            payment_method_data: {
              bank_debit: { ach: { bank_type: "checking" } },
            },
          }
        : {
            payment_method_data: {
              bank_debit: { ach: { bank_type: "Checking" } },
            },
          };
    expect(await payload(page)).toEqual(expected); // Capitals are preserved, not repaired by SDK.
    if (id === "B-lowercase-bank-type") {
      await page.locator("select").selectOption("savings");
      expect(await payload(page)).toEqual({
        payment_method_data: { bank_debit: { ach: { bank_type: "savings" } } },
      });
    }
  });
test("B-ordered-dropdowns generic and bank options preserve order and duplicates", async ({
  page,
}) => {
  for (const kind of ["Dropdown", "BankNamesSelect"]) {
    await mount(
      page,
      input(
        field("choice", "payment_method_data.choice", kind, ["B", "A", "B"]),
      ),
    );
    expect(
      await page
        .locator("select option")
        .evaluateAll((options) =>
          options.map((o) => (o as HTMLOptionElement).value),
        ),
    ).toEqual(["B", "A", "B"]);
    expect(await payload(page)).toEqual({
      payment_method_data: { choice: "B" },
    });
  }
});
test("B-eft-bank-type lowercase choices reach the EFT wire path", async ({
  page,
}) => {
  await mount(
    page,
    input(
      field(
        "bank_debit.eft.bank_type",
        "payment_method_data.bank_debit.eft.bank_type",
        "Dropdown",
        ["checking", "savings"],
      ),
      ["adyen"],
      "bank_debit",
      "eft",
    ),
  );
  expect(await payload(page)).toEqual({
    payment_method_data: { bank_debit: { eft: { bank_type: "checking" } } },
  });
  await page.locator("select").selectOption("savings");
  expect(await payload(page)).toEqual({
    payment_method_data: { bank_debit: { eft: { bank_type: "savings" } } },
  });
});
test("B-prefill-select invalid prefilled selection is replaced by first choice", async ({
  page,
}) => {
  const i: any = input(
    field("choice", "payment_method_data.choice", "Dropdown", ["B", "A"], {
      render_when_prefilled: true,
    }),
  );
  i.client = { intent_data: { choice: "unlisted" } };
  await mount(page, i);
  await expect(page.locator("select")).toHaveValue("B");
  expect(await payload(page)).toEqual({ payment_method_data: { choice: "B" } });
});
test("B-core-language core card fields are excluded and language uses actual helper", async ({
  page,
}) => {
  // A visible field keeps FormBody mounted; its onFormChange computes language.
  const defaults = {
    ...field("fixture", "payment_method_data.fixture"),
    ...field(
      "card.card_number",
      "payment_method_data.card.card_number",
      "CardNumber",
    ),
    ...field("language", "payment_method_data.language", "LanguagePreference", [
      "en",
    ]),
  };
  const s = await mount(page, input(defaults));
  expect(s.descriptors).toHaveLength(3);
  await expect(page.getByTestId("fixture")).toBeVisible();
  await expect(page.getByTestId("card_number")).toHaveCount(0);
  await expect(page.locator("#form-values")).toContainText("en");
});
test("B-empty-render-types Country Dropdown BankNamesSelect remain unfillable", async ({
  page,
}) => {
  for (const kind of ["Country", "Dropdown", "BankNamesSelect"]) {
    for (const options of [undefined, []]) {
      const s = await mount(
        page,
        input(field("choice", "payment_method_data.choice", kind, options)),
      );
      expect(s.descriptors).toHaveLength(1);
      await expect(page.locator("select")).toHaveCount(0);
    }
  }
});
const states = {
  US: [
    { code: "CA", value: "California" },
    { code: "NY", value: "New York" },
  ],
  CA: [{ code: "ON", value: "Ontario" }],
};
for (const [id, options] of [
  ["B-state-missing", undefined],
  ["B-state-empty", []],
  ["B-state-invalid", ["XX"]],
  ["B-state-order", ["NY", "CA"]],
] as const)
  test(id, async ({ page }) => {
    await mount(page, {
      ...input(
        field(
          "billing.state",
          "payment_method_data.billing.address.state",
          "State",
          options ? [...options] : undefined,
        ),
      ),
      states,
    });
    await expect(page.locator("select option")).toHaveText([
      "California",
      "New York",
    ]);
    expect(await payload(page)).toEqual({
      payment_method_data: { billing: { address: { state: "CA" } } },
    });
  });
test("B-state-country-change actual country atom changes state choices", async ({
  page,
}) => {
  await mount(page, {
    ...input({
      ...field(
        "billing.country",
        "payment_method_data.billing.address.country",
        "Country",
        ["US", "CA"],
      ),
      ...field(
        "billing.state",
        "payment_method_data.billing.address.state",
        "State",
        [],
      ),
    }),
    states,
  });
  await page.locator("select").first().selectOption("Canada");
  await expect(page.locator("select").nth(1).locator("option")).toHaveText([
    "Ontario",
  ]);
  expect(await payload(page)).toEqual({
    payment_method_data: {
      billing: { address: { country: "CA", state: "ON" } },
    },
  });
});
test("B-country-cases sentinel/comma refuse display; explicit ordered expansion works", async ({
  page,
}) => {
  for (const c of pack.country_cases) {
    expect(
      await page.evaluate(
        (options) => window.rf.countryNames(options),
        c.options,
      ),
    ).toEqual(c.expected_names);
    await mount(
      page,
      input(
        field(
          "billing.country",
          "payment_method_data.billing.address.country",
          "Country",
          c.options,
        ),
      ),
    );
    await expect(page.locator("select option")).toHaveText(c.expected_names);
  }
});
test("B-alias-payloads exact Adyen bindings UK unchanged and Givex nested payload", async ({
  page,
}) => {
  for (const c of pack.mapping_cases) {
    expect(
      await page.evaluate((type) => window.rf.labels([type]), c.type),
    ).toEqual([c.sdk_type]);
    await mount(
      page,
      input(
        field(c.field_id, c.write_path, "Generic", undefined, {
          intent_data_read_path: c.read_path,
        }),
        [c.connector],
        c.method,
        c.type,
      ),
    );
    await page.getByTestId(c.write_path.split(".").at(-1)!).fill(c.value);
    expect(await payload(page)).toEqual(c.expected_payload);
  }
});
// S3 wire keys differ from the decoded Country.countryStateData record.
const assetWire = {
  country: [{ isoAlpha2: "DK", value: "Fixture Denmark", timeZones: [] }],
  states: { DK: [] },
};
const asset = {
  countries: [
    { isoAlpha2: "DK", countryName: "Fixture Denmark", timeZones: [] },
  ],
  states: { DK: [] },
};
test("B-assets-malformed object with missing wire keys decodes empty without fallback", async ({
  page,
  context,
}) => {
  const paths: string[] = [];
  await context.route("**/assets/v1/jsons/location/**", (route) => {
    paths.push(new URL(route.request().url()).pathname);
    return route.fulfill({ json: {} });
  });
  expect(await page.evaluate(() => window.rf.assets("fr"))).toEqual({
    countries: [],
    states: null,
  });
  expect(paths).toEqual(["/assets/v1/jsons/location/fr"]);
});
for (const tier of ["locale", "english", "bundled"])
  test(`B-assets-${tier}`, async ({ page, context }) => {
    const paths: string[] = [];
    await context.route("**/assets/v1/jsons/location/**", (route) => {
      const name = new URL(route.request().url()).pathname.split("/").at(-1)!;
      paths.push(name);
      return tier === "locale" || (tier === "english" && name === "en")
        ? route.fulfill({ json: assetWire })
        : route.fulfill({ status: 404, body: "fixture unavailable" });
    });
    const result = await page.evaluate(() => window.rf.assets("fr"));
    expect(paths).toEqual(tier === "locale" ? ["fr"] : ["fr", "en"]);
    if (tier === "bundled") {
      expect(result.countries.map((c: any) => c.isoAlpha2)).toContain("US");
      expect(result.countries.map((c: any) => c.isoAlpha2)).not.toContain("AC");
      expect(result.countries.map((c: any) => c.isoAlpha2)).not.toContain("TA");
      expect(result.states.US.length).toBeGreaterThan(0);
    } else expect(result).toEqual(asset);
  });
