import { describe, expect, it, vi } from "vitest";

// Acceptance is created at module evaluation; freeze before importing the SDK.
vi.useFakeTimers();
vi.setSystemTime(new Date("2026-10-16T12:00:00.000Z"));
const Body = await import("../../src/Utilities/PaymentBody.bs.js");
const Management =
  await import("../../src/Utilities/PaymentManagementBody.bs.js");
vi.useRealTimers();
const obj = Object.fromEntries;
const card = {
  card_number: "4111111111111111",
  card_exp_month: "10",
  card_exp_year: "2027",
  card_cvc: "123",
};
const acceptance = {
  acceptance_type: "online",
  accepted_at: "2026-10-16T12:00:00.000Z",
  online: { user_agent: navigator.userAgent },
};
const baseSaved = {
  payment_method: "card",
  payment_token: "saved-token",
  customer_id: "customer-test",
};

function payment(payment_method: string, payment_method_type: string, data: unknown, extra = {}) {
  return {
    payment_method,
    payment_method_type,
    payment_method_data: { [payment_method]: data },
    ...extra,
  };
}

describe("card credential payload boundaries", () => {
  it.each([false, true])(
    "includes optional cardholder and nickname only when supplied (%s)",
    (optional) => {
      const credentials = {
        ...card,
        ...(optional
          ? { card_holder_name: "Ada Lovelace", nick_name: "Travel" }
          : {}),
        card_network: "Visa",
      };
      const args = [
        "4111-1111 1111x1111",
        "10",
        "2027",
        optional ? "Ada Lovelace" : undefined,
        "123",
        [["card_network", "Visa"]],
        optional ? "Travel" : undefined,
      ];
      expect(obj(Body.cardPaymentBody(...args))).toEqual({
        payment_method: "card",
        payment_method_data: { card: credentials },
      });
      expect(obj(Management.saveCardBody(...args))).toEqual({
        payment_method_type: "card",
        payment_method_subtype: "card",
        payment_method_data: { card: credentials },
      });
      expect(
        obj(Body.cardTokenizationBody(args[0], "10", "2027", "123", args[3])),
      ).toEqual({
        payment_method_type: "card",
        payment_method_data: {
          card: {
            ...card,
            ...(optional ? { card_holder_name: "Ada Lovelace" } : {}),
          },
        },
      });
    },
  );

  it.each([
    [false, false],
    [true, false],
    [false, true],
    [true, true],
  ])(
    "sends saved card CVC=%s and acceptance=%s only as requested",
    (requiresCvv, consent) => {
      expect(
        obj(
          Body.savedCardBody(
            "saved-token",
            "customer-test",
            "123",
            requiresCvv,
            consent,
          ),
        ),
      ).toEqual({
        ...baseSaved,
        ...(requiresCvv
          ? { payment_method_data: { card_token: { card_cvc: "123" } } }
          : {}),
        ...(consent ? { customer_acceptance: acceptance } : {}),
      });
    },
  );

  it.each([false, true])(
    "keeps third-party and hosted vault CVC schemas separate (consent=%s)",
    (consent) => {
      const common = {
        ...baseSaved,
        ...(consent ? { customer_acceptance: acceptance } : {}),
      };
      expect(
        obj(
          Body.savedCardVaultCvcBody(
            "saved-token",
            "customer-test",
            "cvc-alias",
            consent,
          ),
        ),
      ).toEqual({
        ...common,
        payment_method_data: { card_token: { card_cvc_token: "cvc-alias" } },
      });
      expect(
        obj(
          Body.externalSavedCardVaultCvcBody(
            "saved-token",
            "customer-test",
            "cvc-alias",
            consent,
          ),
        ),
      ).toEqual({
        ...common,
        payment_method_data: { vault_card_token: { card_cvc: "cvc-alias" } },
      });
      expect(
        obj(
          Body.savedPaymentMethodBody(
            "wallet-token",
            "customer-test",
            "wallet",
            "paypal",
            consent,
          ),
        ),
      ).toEqual({
        payment_method: "wallet",
        payment_method_type: "paypal",
        payment_token: "wallet-token",
        customer_id: "customer-test",
        ...(consent ? { customer_acceptance: acceptance } : {}),
      });
    },
  );

  it("sends vault aliases without adding a raw-card object", () => {
    expect(obj(Body.vaultCardBody("vault-token"))).toEqual({
      payment_method: "card",
      payment_method_type: "debit",
      payment_token: "vault-token",
    });
    expect(
      obj(
        Body.vaultExternalCardBody(
          "vault-token",
          "1111",
          "411111",
          "10",
          "2027",
        ),
      ),
    ).toEqual({
      payment_method: "card",
      payment_method_type: "debit",
      payment_method_data: {
        vault_card: {
          card_number: "vault-token",
          card_cvc: "vault-token",
          card_exp_month: "10",
          card_exp_year: "2027",
          last_four: "1111",
          bin_number: "411111",
        },
      },
    });
    expect(
      obj(
        Body.vgsVaultCardBody(
          "pan-alias",
          "month-alias",
          "year-alias",
          "cvc-alias",
          "1111",
          "411111",
        ),
      ),
    ).toEqual({
      payment_method: "card",
      payment_method_type: "debit",
      payment_method_data: {
        vault_card: {
          card_number: "pan-alias",
          card_exp_month: "month-alias",
          card_exp_year: "year-alias",
          card_cvc: "cvc-alias",
          last_four: "1111",
          bin_number: "411111",
        },
      },
    });
  });

  it("limits card management updates and eligibility to their intended fields", () => {
    expect(
      obj(Management.updateCardBody("method-token", "Travel", "Ada")),
    ).toEqual({
      payment_method_token: "method-token",
      payment_method_data: {
        card: { card_holder_name: "Ada", nick_name: "Travel" },
      },
    });
    expect(obj(Management.updateCVVBody("method-token", "123"))).toEqual({
      payment_method_token: "method-token",
      payment_method_data: { card: { card_cvc: "123" } },
    });
    expect(obj(Management.vaultUpdateCVVBody("cvc-alias"))).toEqual({
      payment_method_data: { card: { card_cvc: "cvc-alias" } },
    });
    expect(
      obj(Body.cardPaymentMethodEligibilityBody("4111111111111111")),
    ).toEqual({
      payment_method_type: "card",
      payment_method_data: { card: { card_number: "4111111111111111" } },
    });
    expect(
      obj(Body.paymentMethodEligibilityBody("paypal", { wallet: {} })),
    ).toEqual({
      payment_method_type: "paypal",
      payment_method_data: { wallet: {} },
    });
  });
});

describe("optional payment and consent metadata", () => {
  it("omits absent offers, installments, and payment type", () => {
    expect(Body.offerDetailsBody([])).toEqual([]);
    expect(obj(Body.offerDetailsBody(["offer-a", "offer-b"]))).toEqual({
      offer_details: { offer_quote_ids: ["offer-a", "offer-b"] },
    });
    expect(Body.installmentBody(undefined)).toEqual([]);
    expect(
      obj(
        Body.installmentBody({
          number_of_installments: 3,
          billing_frequency: "monthly",
          ignored: true,
        }),
      ),
    ).toEqual({
      installment_data: {
        number_of_installments: 3,
        billing_frequency: "monthly",
      },
    });
    expect(Body.paymentTypeBody("")).toEqual([]);
    expect(obj(Body.paymentTypeBody("new_mandate"))).toEqual({
      payment_type: "new_mandate",
    });
    expect(obj(Body.mandateBody(""))).toEqual({
      mandate_data: { customer_acceptance: acceptance },
      customer_acceptance: acceptance,
      setup_future_usage: "off_session",
      payment_type: null,
    });
    expect(obj(Body.mandateBody("setup_mandate")).payment_type).toBe(
      "setup_mandate",
    );
    expect(
      Body.confirmPayloadForSDKButton({
        confirmParams: {
          return_url: "https://merchant.test/return",
          redirect: "if_required",
        },
      }),
    ).toEqual({
      confirmParams: {
        return_url: "https://merchant.test/return",
        redirect: "always",
      },
    });
  });

  it("serializes click-to-pay credentials for the selected provider", () => {
    expect(
      obj(Body.mastercardClickToPayBody("transaction", "correlation", "flow")),
    ).toEqual({
      payment_method: "card",
      ctp_service_details: {
        merchant_transaction_id: "transaction",
        correlation_id: "correlation",
        x_src_flow_id: "flow",
        provider: "mastercard",
      },
    });
    expect(
      obj(Body.visaClickToPayBody("encrypted", "ada@example.test")),
    ).toEqual({
      payment_method: "card",
      payment_method_type: "debit",
      email: "ada@example.test",
      ctp_service_details: { encrypted_payload: "encrypted", provider: "visa" },
    });
    expect(obj(Body.visaClickToPayAuthenticationBody("encrypted"))).toEqual({
      payment_method_details: {
        payment_method_type: "ctp",
        payment_method_data: {
          encrypted_payload: "encrypted",
          provider: "visa",
        },
      },
    });
  });
});

const billing = {
  email: "ada@example.test",
  address: {
    first_name: "Ada",
    last_name: "Lovelace",
    line1: "1 Example Road",
    line2: "Unit 2",
    city: "London",
    state: "LN",
    zip: "12345",
    country: "GB",
  },
};
const debitExpected = (type: string, bank_debit: unknown) => ({
  payment_method: "bank_debit",
  payment_method_type: type,
  setup_future_usage: "off_session",
  customer_acceptance: acceptance,
  payment_method_data: { billing, bank_debit },
});
describe("bank debit billing and account serialization", () => {
  it("serializes ACH, BACS, and BECS without mixing account identifiers", () => {
    const bank = {
      accountNumber: "12345678",
      routingNumber: "021000021",
      accountHolderName: "Ada Lovelace",
      accountType: "checking",
      sortCode: "123456",
    };
    expect(
      Body.billingDetailsTuple(
        "Ada Lovelace",
        "ada@example.test",
        "1 Example Road",
        "Unit 2",
        "London",
        "LN",
        "12345",
        "GB",
      ),
    ).toEqual(["billing", billing]);
    expect(
      obj(
        Body.achBankDebitBody(
          "ada@example.test",
          bank,
          "Ada Lovelace",
          "1 Example Road",
          "Unit 2",
          "GB",
          "London",
          "12345",
          "LN",
        ),
      ),
    ).toEqual(
      debitExpected("ach", {
        ach_bank_debit: {
          account_number: "12345678",
          routing_number: "021000021",
          bank_account_holder_name: "Ada Lovelace",
          bank_type: "checking",
        },
      }),
    );
    expect(
      obj(
        Body.bacsBankDebitBody(
          "ada@example.test",
          "12345678",
          "123456",
          "1 Example Road",
          "Unit 2",
          "London",
          "12345",
          "LN",
          "GB",
          "Ada Lovelace",
        ),
      ),
    ).toEqual(
      debitExpected("bacs", {
        bacs_bank_debit: {
          account_number: "12345678",
          sort_code: "123456",
          bank_account_holder_name: "Ada Lovelace",
        },
      }),
    );
    expect(
      obj(
        Body.becsBankDebitBody(
          "Ada Lovelace",
          "ada@example.test",
          bank,
          "1 Example Road",
          "Unit 2",
          "GB",
          "London",
          "12345",
          "LN",
        ),
      ),
    ).toEqual(
      debitExpected("becs", {
        becs_bank_debit: {
          account_number: "12345678",
          bsb_number: "123456",
          bank_account_holder_name: "Ada Lovelace",
        },
      }),
    );
  });
});

describe("wallet SDK and redirect serialization", () => {
  it.each([
    ["klarna", "pay_later", "klarnaSDKbody", "klarna_sdk"] as const,
    ["paypal", "wallet", "paypalSdkBody", "paypal_sdk"] as const,
  ])("serializes %s SDK token", (type, method, fn, key) => {
    expect(obj(Body[fn]("sdk-token", ["connector-test"]))).toEqual(
      payment(
        method,
        type,
        { [key]: { token: "sdk-token" } },
        {
          payment_experience: "invoke_sdk_client",
          connector: ["connector-test"],
        },
      ),
    );
  });
  it("serializes Klarna checkout and Samsung/Paze credential responses", () => {
    expect(obj(Body.klarnaCheckoutBody(["connector-test"]))).toEqual(
      payment(
        "pay_later",
        "klarna",
        { klarna_checkout: {} },
        {
          payment_experience: "redirect_to_url",
          connector: ["connector-test"],
        },
      ),
    );
    expect(obj(Body.samsungPayBody({ token: "samsung-token" }))).toEqual(
      payment("wallet", "samsung_pay", {
        samsung_pay: { payment_credential: { token: "samsung-token" } },
      }),
    );
    expect(obj(Body.pazeBody("encrypted-paze"))).toEqual(
      payment("wallet", "paze", {
        paze: { complete_response: "encrypted-paze" },
      }),
    );
  });
  it.each([[[]], [["connector-test"]]])(
    "transforms Google Pay data keys and conditionally sends connectors %j",
    (connectors) => {
      expect(
        obj(
          Body.gpayBody(
            {
              paymentMethodData: {
                type: "CARD",
                description: "Visa 1111",
                info: { cardNetwork: "VISA", cardDetails: "1111" },
                tokenizationData: {
                  type: "PAYMENT_GATEWAY",
                  token: "gpay-token",
                },
              },
            },
            connectors,
          ),
        ),
      ).toEqual(
        payment(
          "wallet",
          "google_pay",
          {
            google_pay: {
              type: "CARD",
              description: "Visa 1111",
              info: { card_network: "VISA", card_details: "1111" },
              tokenization_data: {
                type: "PAYMENT_GATEWAY",
                token: "gpay-token",
              },
            },
          },
          connectors.length ? { connector: connectors } : {},
        ),
      );
    },
  );
  it.each([[[]], [["connector-test"]]])(
    "base64 encodes Apple paymentData and conditionally sends connectors %j",
    (connectors) => {
      const paymentData = { version: "EC_v1", data: "encrypted-test-data" };
      expect(
        obj(
          Body.applePayBody(
            {
              paymentData,
              paymentMethod: { displayName: "Visa 1111" },
              transactionIdentifier: "transaction-test",
            },
            connectors,
          ),
        ),
      ).toEqual(
        payment(
          "wallet",
          "apple_pay",
          {
            apple_pay: {
              payment_data: btoa(JSON.stringify(paymentData)),
              payment_method: { display_name: "Visa 1111" },
              transaction_identifier: "transaction-test",
            },
          },
          connectors.length ? { connector: connectors } : {},
        ),
      );
    },
  );
  it.each([
    ["gpayRedirectBody", "google_pay", "google_pay_redirect"] as const,
    ["gPayThirdPartySdkBody", "google_pay", "google_pay_third_party_sdk"] as const,
    ["applePayRedirectBody", "apple_pay", "apple_pay_redirect"] as const,
  ])("serializes %s without SDK credentials", (fn, type, key) => {
    expect(obj(Body[fn](["connector-test"]))).toEqual(
      payment("wallet", type, { [key]: {} }, { connector: ["connector-test"] }),
    );
  });
  it.each([undefined, "apple-token"])(
    "includes optional third party Apple token %s",
    (token) => {
      expect(obj(Body.applePayThirdPartySdkBody([], token))).toEqual(
        payment(
          "wallet",
          "apple_pay",
          { apple_pay_third_party_sdk: token ? { token } : {} },
          { connector: [] },
        ),
      );
    },
  );
});

const routes: [string, string, unknown, Record<string, unknown>?][] = [
  [
    "pay_later",
    "afterpay_clearpay",
    { afterpay_clearpay_redirect: {} },
    { payment_experience: "redirect_to_url" },
  ],
  ["crypto", "crypto_currency", {}, { payment_experience: "redirect_to_url" }],
  [
    "bank_redirect",
    "sofort",
    {
      sofort: {
        country: "DE",
        preferred_language: "en",
        billing_details: { billing_name: "Ada", email: "ada@example.test" },
      },
    },
  ],
  ["bank_redirect", "ideal", { ideal: {} }],
  ["bank_redirect", "eps", { eps: {} }],
  ["bank_redirect", "blik", { blik: { blik_code: "123456" } }],
  [
    "bank_redirect",
    "giropay",
    {
      giropay: {
        billing_details: { billing_name: "Ada" },
        bank_account_iban: "",
      },
    },
  ],
  ...["poland", "czech_republic", "slovakia", "thailand"].map((country) => [
    "bank_redirect",
    `online_banking_${country}`,
    { [`online_banking_${country}`]: { issuer: "test-bank" } },
  ] as [string, string, unknown]),
  [
    "wallet",
    "mb_way",
    { mb_way_redirect: { telephone_number: "+12025550123" } },
  ],
  ["wallet", "revolut_pay", { revolut_pay: {} }],
  ["bank_redirect", "eft", { eft: { provider: "ozow" } }],
  [
    "wallet",
    "paypal",
    { paypal_redirect: {} },
    { payment_experience: "redirect_to_url" },
  ],
];
describe("payment route dispatch", () => {
  it.each(routes)("builds exact %s/%s route", (method, type, data, extra) => {
    expect(
      obj(
        Body.getPaymentBody(
          method,
          type,
          "Ada",
          "ada@example.test",
          "DE",
          "test-bank",
          "123456",
          undefined,
          "+12025550123",
        ),
      ),
    ).toEqual(payment(method, type, data, extra));
  });
  it.each(["ali_pay", "ali_pay_hk", "we_chat_pay", "duit_now"])(
    "selects redirect and QR shape for %s",
    (type) => {
      for (const flow of [undefined, "RedirectToURL", "InvokeSDK", "QrFlow"]) {
        const suffix =
          flow === "QrFlow" ? "_qr" : type === "duit_now" ? "" : "_redirect";
        expect(
          obj(
            Body.getPaymentBody("wallet", type, "", "", "", "", "", flow, ""),
          ),
        ).toEqual(payment("wallet", type, { [type + suffix]: {} }));
      }
    },
  );
  it("serializes billing outside bank_redirect for P24 and handles credential-free methods", () => {
    expect(
      obj(
        Body.getPaymentBody(
          "bank_redirect",
          "przelewy24",
          "",
          "ada@example.test",
          "",
          "",
          "",
          undefined,
          "",
        ),
      ),
    ).toEqual({
      payment_method: "bank_redirect",
      payment_method_type: "przelewy24",
      payment_method_data: {
        billing: { email: "ada@example.test" },
        bank_redirect: { przelewy24: {} },
      },
    });
    expect(
      obj(
        Body.getPaymentBody(
          "bank_redirect",
          "online_banking_fpx",
          "",
          "",
          "",
          "",
          "",
          undefined,
          "",
        ),
      ),
    ).toEqual({
      payment_method: "bank_redirect",
      payment_method_type: "online_banking_fpx",
    });
    expect(obj(Body.fpxOBBody())).toEqual({
      payment_method: "bank_redirect",
      payment_method_type: "online_banking_fpx",
    });
    for (const type of ["classic", "evoucher"])
      expect(
        obj(
          Body.getPaymentBody(
            "reward",
            type,
            "",
            "",
            "",
            "",
            "",
            undefined,
            "",
          ),
        ),
      ).toEqual({
        payment_method: "reward",
        payment_method_type: type,
        payment_method_data: "reward",
      });
    expect(obj(Body.bancontactBody())).toEqual(
      payment("bank_redirect", "bancontact_card", { bancontact_card: {} }),
    );
    expect(obj(Body.boletoBody("52998224725"))).toEqual(
      payment("voucher", "boleto", {
        boleto: { social_security_number: "52998224725" },
      }),
    );
    expect(obj(Body.giroPayBody("Ada", "DE89370400440532013000"))).toEqual(
      payment("bank_redirect", "giropay", {
        giropay: {
          billing_details: { billing_name: "Ada" },
          bank_account_iban: "DE89370400440532013000",
        },
      }),
    );
  });
  it.each([
    ["bank_debit", "sepa_debit", "sepa", "sepa_bank_debit"],
    ["bank_debit", "ach_debit", "ach", "ach"],
    ["bank_transfer", "ach_transfer", "ach", "ach_bank_transfer"],
    ["bank_transfer", "bacs_transfer", "bacs", "bacs_bank_transfer"],
    ["bank_transfer", "multibanco", "multibanco", "multibanco_bank_transfer"],
    [
      "bank_transfer",
      "sepa_bank_transfer",
      "sepa_bank_transfer",
      "sepa_bank_transfer",
    ],
    [
      "wallet",
      "unrecognized_wallet",
      "unrecognized_wallet",
      "unrecognized_wallet",
    ],
    ["pay_later", "affirm", "affirm", "affirm_redirect"],
  ])("normalizes %s/%s dispatch suffixes", (method, type, normalized, key) => {
    expect(obj(Body.dynamicPaymentBody(method, type))).toEqual(
      payment(
        method,
        normalized,
        { [key]: {} },
        normalized === "affirm"
          ? { payment_experience: "redirect_to_url" }
          : {},
      ),
    );
  });
});
