import { test, expect, CARD_FIELDS_IFRAME, testIds } from "../../fixtures";
import { CLIENT_BASE_URL } from "../../fixtures/env";

for (const scenario of [
  {
    name: "matching credit pair",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: "credit" }] }],
    shown: true,
  },
  {
    name: "whole card group",
    allowed: [{ paymentMethod: "card" }],
    shown: true,
  },
  {
    name: "wrong method with matching type",
    allowed: [{ paymentMethod: "wallet", paymentMethodTypes: [{ paymentMethodType: "credit" }] }],
    shown: false,
  },
  {
    name: "type absent from backend",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: "debit" }] }],
    shown: false,
  },
  {
    name: "invalid type cannot widen to whole group",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: 42 }] }],
    shown: false,
  },
  {
    name: "multiple types include an available backend type",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: "debit" }, { paymentMethodType: "credit" }] }],
    shown: true,
  },
  {
    name: "empty nested types exclude the family",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: [] }],
    shown: false,
  },
  {
    name: "null nested types cannot widen to whole group",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: null }],
    shown: false,
  },
  {
    name: "non-array nested types cannot widen to whole group",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: "credit" }],
    shown: false,
  },
  {
    name: "missing or empty nested type cannot widen to whole group",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: [{}, { paymentMethodType: "" }] }],
    shown: false,
  },
  {
    name: "valid nested types survive malformed sibling entries",
    allowed: [{ paymentMethod: "card", paymentMethodTypes: ["debit", { paymentMethodType: 42 }, { paymentMethodType: "credit" }] }],
    shown: true,
  },
  {
    name: "flat type entries cannot widen to whole group",
    allowed: [{ paymentMethod: "card", paymentMethodType: "credit" }],
    shown: false,
  },
  { name: "old string entries", allowed: ["card"], shown: false },
]) {
  test(`allowed method pairs: ${scenario.name} @hermetic-only`, async ({
    checkout,
    sdk,
    hermetic,
    page,
  }) => {
    const warnings: string[] = [];
    page.on("console", (message) => {
      if (message.type() === "warning" && message.text().startsWith("Invalid options.allowedPaymentMethods:"))
        warnings.push(message.text());
    });
    hermetic.override("clientList", (route) => {
      const body = route.body as {
        payment_methods_enabled: { payment_method_type: string }[];
      };
      return {
        ...route,
        body: {
          ...body,
          payment_methods_enabled: body.payment_methods_enabled.filter(
            (method) => method.payment_method_type === "credit",
          ),
        },
      };
    });
    await checkout.open({
      options: { allowedPaymentMethods: scenario.allowed },
    });
    if (scenario.shown) {
      await expect(
        sdk.paymentElement
          .frameLocator(CARD_FIELDS_IFRAME)
          .getByTestId(testIds.cardNoInputTestId),
      ).toBeVisible();
    } else {
      await expect(sdk.paymentElement.locator(CARD_FIELDS_IFRAME)).toHaveCount(
        0,
      );
      await expect(
        sdk.paymentElement.getByText("Oops, something went wrong!", {
          exact: true,
        }),
      ).toBeVisible();
    }
    const malformed = /invalid|null nested|non-array|missing or empty|malformed|flat type|old string/.test(scenario.name);
    expect(warnings.length > 0).toBe(malformed);
  });
}

test("saved debit and transfer accounts with the same type stay distinct @hermetic-only", async ({
  checkout,
  sdk,
  hermetic,
}) => {
  hermetic.override("clientList", (route) => ({
    ...route,
    body: {
      ...(route.body as object),
      payment_methods_enabled: [
        {
          payment_method: "bank_debit",
          payment_method_type: "ach",
          payment_experience: [],
        },
        {
          payment_method: "bank_transfer",
          payment_method_type: "ach",
          payment_experience: [],
        },
      ],
      customer_payment_methods: ["bank_debit", "bank_transfer"].map(
        (method) => ({
          payment_token: `saved_${method}`,
          payment_method: method,
          payment_method_type: "ach",
          requires_cvv: false,
          recurring_enabled: true,
          last_used_at: "2026-09-01T00:00:00Z",
        }),
      ),
    },
  }));
  await checkout.open({
    options: {
      displaySavedPaymentMethods: true,
      allowedPaymentMethods: [
        { paymentMethod: "bank_debit", paymentMethodTypes: [{ paymentMethodType: "ach" }] },
      ],
    },
  });
  await expect(
    sdk.paymentElement.getByLabel("ACH bank debit account ending in ", {
      exact: true,
    }),
  ).toBeVisible();
  await expect(
    sdk.paymentElement.getByLabel("Ach", { exact: true }),
  ).toHaveCount(0);
});

test("wallet-only pairs render the available wallet without a card form @hermetic-only", async ({
  checkout,
  sdk,
  hermetic,
  context,
}) => {
  await context.route("https://pay.google.com/gp/p/js/pay.js", (route) =>
    route.fulfill({
      contentType: "application/javascript",
      body: `window.google = {payments: {api: {PaymentsClient: class {
      isReadyToPay() { return Promise.resolve({result: true}); }
      createButton() { const button = document.createElement('button'); button.textContent = 'Test Google Pay'; return button; }
    }}}};`,
    }),
  );
  hermetic.override("clientList", (route) => {
    const body = route.body as { payment_methods_enabled: object[] };
    return {
      ...route,
      body: {
        ...body,
        payment_methods_enabled: [
          ...body.payment_methods_enabled,
          {
            payment_method: "wallet",
            payment_method_type: "google_pay",
            payment_experience: ["invoke_sdk_client"],
          },
        ],
      },
    };
  });
  hermetic.override("sessionTokens", {
    session_token: [
      {
        wallet_name: "google_pay",
        connector: "stripe",
        allowed_payment_methods: [],
        transaction_info: { currency_code: "USD", total_price: "10" },
        merchant_info: { merchant_name: "Wallet pair test" },
      },
    ],
  });
  await checkout.open({
    options: {
      allowedPaymentMethods: [
        {
          paymentMethod: "wallet",
          paymentMethodTypes: [
            { paymentMethodType: "google_pay" },
            { paymentMethodType: "apple_pay" },
            { paymentMethodType: "paypal" },
          ],
        },
      ],
      wallets: {
        walletReturnUrl: `${CLIENT_BASE_URL}/return`,
        googlePay: "auto",
        applePay: "never",
        payPal: "never",
      },
    },
  });
  await expect(
    sdk.paymentElement.getByRole("button", { name: "Test Google Pay" }),
  ).toBeVisible();
  await expect(sdk.paymentElement.locator(CARD_FIELDS_IFRAME)).toHaveCount(0);
});

test.describe("saved card type pairs @hermetic-only", () => {
  test.use({ hermeticFixtures: ["02-cards/07-saved-cards.json"] });
  for (const type of ["credit", "debit"]) {
    test(`only saved cards of the allowed ${type} type render`, async ({
      checkout,
      sdk,
    }) => {
      await checkout.open({
        options: {
          displaySavedPaymentMethods: true,
          allowedPaymentMethods: [
            { paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: type }] },
          ],
        },
      });
      const savedCreditCard = sdk.paymentElement
        .getByText("4 digit", { exact: true })
        .first();
      if (type === "credit") await expect(savedCreditCard).toBeVisible();
      else {
        await expect(
          sdk.paymentElement
            .frameLocator(CARD_FIELDS_IFRAME)
            .getByTestId(testIds.cardNoInputTestId),
        ).toBeVisible();
        await expect(savedCreditCard).toHaveCount(0);
      }
    });
  }
});
