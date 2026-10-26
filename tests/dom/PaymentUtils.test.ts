import { describe, expect, it, vi } from "vitest";
vi.useFakeTimers();
vi.setSystemTime(new Date("2026-10-16T12:00:00.000Z"));
const Utils = await import("../../src/Utilities/PaymentUtils.bs.js");
const Methods = await import("../../src/Payments/PaymentMethodsRecord.bs.js");
vi.useRealTimers();

type MethodType = Partial<typeof Methods.defaultPaymentMethodType>;
const method = (payment_method: string, types: (string | MethodType)[]) => ({
  payment_method,
  payment_method_types: types.map((type) =>
    typeof type === "string"
      ? { ...Methods.defaultPaymentMethodType, payment_method_type: type }
      : { ...Methods.defaultPaymentMethodType, ...type },
  ),
});
const list = (...methods: ReturnType<typeof method>[]) => ({
  ...Methods.defaultList,
  payment_methods: methods,
});
const saved = (
  id: string,
  paymentMethod: string,
  paymentMethodType: string | undefined,
  defaultPaymentMethodSet = false,
) => ({ id, paymentMethod, paymentMethodType, defaultPaymentMethodSet });
const ids = (values: { id: string }[]) => values.map((value) => value.id);

function lookup(pml: ReturnType<typeof list>, options = {}) {
  const defaults = {
    order: [],
    paypal: true,
    klarna: false,
    klarnaSdk: false,
    googlePrefilled: true,
    collectWallet: true,
    googleReady: true,
    appleTabs: false,
    paypalTabs: false,
    walletsInTabs: false,
    grouped: false,
    ...options,
  };
  return Utils.paymentListLookupNew(
    pml,
    defaults.order,
    defaults.paypal,
    defaults.klarna,
    defaults.klarnaSdk,
    pml,
    defaults.googlePrefilled,
    defaults.collectWallet,
    defaults.googleReady,
    defaults.appleTabs,
    defaults.paypalTabs,
    defaults.walletsInTabs,
    defaults.grouped,
  );
}

describe("customer acceptance decisions", () => {
  it.each([
    [true, "NEW_MANDATE", undefined, false],
    [true, "SETUP_MANDATE", true, false],
    [false, "NEW_MANDATE", undefined, true],
    [false, "SETUP_MANDATE", undefined, true],
    [false, "NORMAL_PAYMENT", undefined, false],
    [false, "NONE", false, false],
    [false, "NORMAL_PAYMENT", true, true],
  ])("guest=%s type=%s override=%s", (guest, type, override, expected) => {
    const body = [["payment_method", "card"]];
    expect(Utils.isAppendingCustomerAcceptance(guest, type, override)).toBe(
      expected,
    );
    const result = Utils.appendedCustomerAcceptance(
      guest,
      type,
      body,
      override,
    );
    expect(body).toEqual([["payment_method", "card"]]);
    if (expected) {
      expect(result).toHaveLength(2);
      expect(result[1][0]).toBe("customer_acceptance");
      expect(result[1][1]).toEqual({
        acceptance_type: "online",
        accepted_at: "2026-10-16T12:00:00.000Z",
        online: { user_agent: navigator.userAgent },
      });
    } else expect(result).toBe(body);
  });
});

describe("saved method filtering and priority", () => {
  const methods = [
    saved("credit", "card", "credit"),
    saved("debit", "card", "debit"),
    saved("apple", "wallet", "apple_pay"),
    saved("google", "wallet", "google_pay"),
    saved("paypal", "wallet", "paypal"),
    saved("unknown", "wallet", undefined),
  ];
  it("matches hidden type case-insensitively, hides card as a group, and preserves wallet types", () => {
    expect(Utils.filterSavedMethodsByHiddenList(methods, [])).toBe(methods);
    expect(
      ids(
        Utils.filterSavedMethodsByHiddenList(methods, ["CrEdIt", "APPLE_PAY"]),
      ),
    ).toEqual(["debit", "google", "paypal", "unknown"]);
    expect(
      ids(Utils.filterSavedMethodsByHiddenList(methods, ["CARD"])),
    ).toEqual(["apple", "google", "paypal", "unknown"]);
    expect(Utils.filterSavedMethodsByHiddenList(methods, ["wallet"])).toEqual(
      methods,
    );
    expect(Utils.filterSavedMethodsByHiddenList(methods, ["missing"])).toEqual(
      methods,
    );
  });
  it.each([
    [false, false, ["credit", "debit", "paypal", "unknown"]],
    [true, false, ["credit", "debit", "apple", "paypal", "unknown"]],
    [false, true, ["credit", "debit", "google", "paypal", "unknown"]],
    [true, true, ["credit", "debit", "apple", "google", "paypal", "unknown"]],
  ])("filters unavailable Apple=%s Google=%s", (apple, google, expected) => {
    expect(
      ids(Utils.filterSavedMethodsByWalletReadiness(methods, apple, google)),
    ).toEqual(expected);
  });
  it("sorts defaults first, respects explicit priority, and preserves ties", () => {
    const values = [
      saved("unknown", "bank_redirect", undefined),
      saved("card1", "card", "credit"),
      saved("paypal", "wallet", "paypal"),
      saved("default", "wallet", "apple_pay", true),
      saved("card2", "card", "debit"),
    ];
    expect(Utils.sortCustomerMethodsBasedOnPriority(values, [])).toBe(values);
    expect(
      ids(Utils.sortCustomerMethodsBasedOnPriority(values, ["paypal", "card"])),
    ).toEqual(["default", "paypal", "card1", "card2", "unknown"]);
    expect(
      ids(
        Utils.sortCustomerMethodsBasedOnPriority(
          values,
          ["paypal", "card"],
          false,
        ),
      ),
    ).toEqual(["paypal", "card1", "card2", "unknown", "default"]);
    expect(ids(values)).toEqual([
      "unknown",
      "card1",
      "paypal",
      "default",
      "card2",
    ]);
  });
});

describe("card support decisions", () => {
  it("flattens and deduplicates configured networks across card types", () => {
    expect(
      Utils.getSupportedCardBrands(list(method("wallet", ["paypal"]))),
    ).toBeUndefined();
    expect(
      Utils.getSupportedCardBrands(list(method("card", ["credit"]))),
    ).toEqual([]);
    expect(
      Utils.getSupportedCardBrands(
        list(
          method("card", [
            {
              payment_method_type: "credit",
              card_networks: [
                { card_network: "VISA" },
                { card_network: "AMEX" },
              ],
            },
            {
              payment_method_type: "debit",
              card_networks: [
                { card_network: "VISA" },
                { card_network: "MASTERCARD" },
              ],
            },
          ]),
        ),
      ),
    ).toEqual(["visa", "americanexpress", "mastercard"]);
  });
  it.each([
    ["4111 1111 1111 1111", "Visa", ["visa"], true],
    ["4111111111111111", "Visa", ["mastercard"], false],
    ["4111111111111111", "Visa", [], false],
    ["4111111111111111", "Visa", undefined, true],
    ["4111111111111112", "Visa", ["visa"], undefined],
    ["4111111111111111", "", undefined, true],
    ["411", "", undefined, false],
  ])("checks %s / %s against %j", (number, brand, supported, expected) =>
    expect(Utils.checkIsCardSupported(number, brand, supported)).toBe(expected),
  );
});

describe("payment method presentation list", () => {
  it("deduplicates card types, separates wallets, normalizes banks, and honors order", () => {
    const pml = list(
      method("card", ["credit", "debit"]),
      method("wallet", ["paypal", "google_pay", "mb_way"]),
      method("bank_debit", ["ach"]),
      method("bank_transfer", ["ach", "sepa_bank_transfer"]),
      method("reward", ["classic"]),
      method("voucher", ["boleto"]),
    );
    expect(
      lookup(pml, { order: ["google_pay", "paypal", "boleto", "card"] }),
    ).toEqual([
      ["google_pay", "paypal"],
      [
        "boleto",
        "card",
        "mb_way",
        "ach_debit",
        "ach_transfer",
        "sepa_bank_transfer",
        "classic",
      ],
    ]);
    expect(lookup(pml, { paypal: false })[0]).toEqual(["google_pay"]);
  });
  it("moves ready wallets into tabs and inserts grouped saved methods", () => {
    const pml = list(method("wallet", ["apple_pay", "paypal", "google_pay"]));
    expect(
      lookup(pml, {
        appleTabs: true,
        paypalTabs: true,
        walletsInTabs: true,
        grouped: true,
      }),
    ).toEqual([[], ["saved_methods", "apple_pay", "paypal", "google_pay"]]);
    expect(
      lookup(pml, { collectWallet: false, googlePrefilled: false }),
    ).toEqual([["apple_pay", "paypal"], ["google_pay"]]);
    expect(
      lookup(pml, {
        collectWallet: false,
        googlePrefilled: false,
        googleReady: false,
      }),
    ).toEqual([["apple_pay", "paypal", "google_pay"], []]);
    expect(
      lookup(pml, { collectWallet: false, googlePrefilled: true }),
    ).toEqual([["apple_pay", "paypal", "google_pay"], []]);
  });
  it("shows Klarna in the SDK wallet slot only when configured and otherwise uses redirect eligibility", () => {
    const klarna = (experiences: string[]) =>
      list(
        method("pay_later", [
          {
            payment_method_type: "klarna",
            payment_experience: experiences.map((payment_experience_type) => ({
              payment_experience_type,
              eligible_connectors: [],
            })),
          },
          "affirm",
        ]),
      );
    expect(
      lookup(klarna(["InvokeSDK"]), { klarna: true, klarnaSdk: true }),
    ).toEqual([["klarna"], ["affirm"]]);
    expect(
      lookup(klarna(["InvokeSDK"]), { klarna: false, klarnaSdk: true }),
    ).toEqual([[], ["affirm"]]);
    expect(lookup(klarna(["RedirectToURL", "InvokeSDK"]))).toEqual([
      [],
      ["klarna", "affirm"],
    ]);
    expect(lookup(klarna([]))).toEqual([[], ["affirm"]]);
  });
  it.each([
    ["bank_debit", "sepa_debit", "sepa"],
    ["bank_transfer", "ach_transfer", "ach"],
    ["bank_transfer", "sepa_bank_transfer", "sepa_bank_transfer"],
    ["wallet", "google_pay", "google_pay"],
  ])("normalizes display name %s/%s", (method, name, expected) =>
    expect(Utils.getPaymentMethodName(method, name)).toBe(expected),
  );
  it("selects installment plans only for the requested method", () => {
    const plans = [{ id: "plan-test" }];
    expect(
      Utils.filterInstallmentPlansByPaymentMethod(
        [{ payment_method: "card", available_plans: plans }],
        "card",
      ),
    ).toBe(plans);
    expect(
      Utils.filterInstallmentPlansByPaymentMethod(
        [{ payment_method: "card", available_plans: plans }],
        "paypal",
      ),
    ).toEqual([]);
  });
  it.each([
    [[], false, undefined, false],
    [["paypal"], false, undefined, true],
    [[], true, undefined, true],
    [[], false, true, true],
  ])(
    "decides wallet separator visibility %j/%s/%s",
    (wallets, show, loading, expected) =>
      expect(Utils.checkRenderOrComp(wallets, show, loading)).toBe(expected),
  );
});

describe("payment method information emitted to merchants", () => {
  it("emits masked card details and keeps boolean states even when optional fields are empty", () => {
    const post = vi
      .spyOn(window.parent, "postMessage")
      .mockImplementation(() => {});
    Utils.emitPaymentMethodInfo(
      "card",
      "debit",
      "VISA",
      "1111",
      "411111",
      "10",
      "2027",
      "US",
      "CA",
      "94105",
      true,
      false,
    );
    expect(post).toHaveBeenCalledWith(
      {
        paymentMethodInfo: {
          paymentMethod: "card",
          cardBrand: "Visa",
          cardLast4: "1111",
          cardBin: "411111",
          cardExpiryMonth: "10",
          cardExpiryYear: "2027",
          country: "US",
          state: "CA",
          pincode: "94105",
          isSavedPaymentMethod: true,
          isCvcEmpty: false,
        },
      },
      "*",
    );
    post.mockClear();
    Utils.emitPaymentMethodInfo("card", "credit");
    expect(post).toHaveBeenCalledWith(
      {
        paymentMethodInfo: {
          paymentMethod: "card",
          cardBrand: "Unknown",
          isSavedPaymentMethod: false,
          isCvcEmpty: true,
        },
      },
      "*",
    );
  });
  it("omits card fields for wallets and omits blank billing address fields", () => {
    const post = vi
      .spyOn(window.parent, "postMessage")
      .mockImplementation(() => {});
    Utils.emitPaymentMethodInfo(
      "wallet",
      "paypal",
      "VISA",
      "1111",
      "411111",
      "10",
      "2027",
      "US",
    );
    expect(post).toHaveBeenCalledWith(
      {
        paymentMethodInfo: {
          paymentMethod: "wallet",
          paymentMethodType: "paypal",
          country: "US",
          isSavedPaymentMethod: false,
        },
      },
      "*",
    );
  });
  it("detects Klarna SDK sessions without requiring any remote requests", () => {
    expect(Utils.getIsKlarnaSDKFlow({})).toBe(false);
    expect(
      Utils.getIsKlarnaSDKFlow({
        session_token: [
          { wallet_name: "paypal", session_token: "paypal-session" },
        ],
      }),
    ).toBe(false);
    expect(
      Utils.getIsKlarnaSDKFlow({
        session_token: [
          { wallet_name: "klarna", session_token: "klarna-session" },
        ],
      }),
    ).toBe(true);
  });
});

it("applies merchant aliases only to supported reward methods", () => {
  const aliases = [
    { paymentMethodName: "classic", aliasName: "Acme Points" },
    { paymentMethodName: "evoucher", aliasName: "" },
    { paymentMethodName: "paypal", aliasName: "Merchant Wallet" },
  ];
  const reward = Utils.getDisplayNameAndIcon(
    aliases,
    "classic",
    "Rewards",
    "default-icon",
  );
  expect(reward[0]).toBe("Acme Points");
  expect(reward[1].props.name).toBe("Acme");
  expect(
    Utils.getDisplayNameAndIcon(aliases, "evoucher", "Voucher", "voucher-icon"),
  ).toEqual(["Voucher", "voucher-icon"]);
  expect(
    Utils.getDisplayNameAndIcon(aliases, "paypal", "PayPal", "paypal-icon"),
  ).toEqual(["PayPal", "paypal-icon"]);
  expect(
    Utils.getDisplayNameAndIcon(aliases, "card", "Card", "card-icon"),
  ).toEqual(["Card", "card-icon"]);
});
