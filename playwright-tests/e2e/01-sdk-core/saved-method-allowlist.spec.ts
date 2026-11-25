import { test, expect } from "../../fixtures";

for (const { method, type, allowed, label } of [
  {
    method: "bank_debit",
    type: "ach",
    allowed: "ach_debit",
    label: "ACH bank debit account ending in ",
  },
  {
    method: "bank_debit",
    type: "sepa",
    allowed: "sepa_debit",
    label: "SEPA bank debit account ending in ",
  },
  {
    method: "bank_transfer",
    type: "ach",
    allowed: "ach_transfer",
    label: "Ach",
  },
]) {
  test(`saved ${allowed} stays visible when explicitly allowed @hermetic-only`, async ({
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
            payment_method: method,
            payment_method_type: type,
            payment_experience: [],
          },
        ],
        customer_payment_methods: [
          {
            payment_token: `saved_${allowed}`,
            payment_method: method,
            payment_method_type: type,
            requires_cvv: false,
            recurring_enabled: true,
            last_used_at: "2026-09-01T00:00:00Z",
          },
        ],
      },
    }));
    await checkout.open({
      options: {
        displaySavedPaymentMethods: true,
        allowedPaymentMethods: [{ paymentMethod: method, paymentMethodTypes: [{ paymentMethodType: type }] }],
      },
    });
    await expect(
      sdk.paymentElement.getByLabel(label, { exact: true }),
    ).toBeVisible();
  });
}
