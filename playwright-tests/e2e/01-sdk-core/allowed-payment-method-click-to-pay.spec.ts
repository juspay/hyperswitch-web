import { test, expect } from "../../fixtures/sdk-runtime";

for (const scenario of [
  { name: "omitted filter", options: {}, shown: true },
  {
    name: "reset filter",
    options: { allowedPaymentMethods: null },
    shown: true,
  },
  {
    name: "whole card group",
    options: { allowedPaymentMethods: [{ paymentMethod: "card" }] },
    shown: true,
  },
  {
    name: "credit restriction",
    options: {
      allowedPaymentMethods: [
        { paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: "credit" }] },
      ],
    },
    shown: false,
  },
  {
    name: "debit restriction",
    options: {
      allowedPaymentMethods: [
        { paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: "debit" }] },
      ],
    },
    shown: false,
  },
  {
    name: "synthetic type absent from backend",
    options: {
      allowedPaymentMethods: [
        { paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: "click_to_pay" }] },
      ],
    },
    shown: false,
  },
  {
    name: "empty filter",
    options: { allowedPaymentMethods: [] },
    shown: false,
  },
  {
    name: "empty nested card types",
    options: { allowedPaymentMethods: [{ paymentMethod: "card", paymentMethodTypes: [] }] },
    shown: false,
  },
  {
    name: "explicit credit and debit still exclude unclassified provider cards",
    options: { allowedPaymentMethods: [{ paymentMethod: "card", paymentMethodTypes: [{ paymentMethodType: "credit" }, { paymentMethodType: "debit" }] }] },
    shown: false,
  },
]) {
  test(`Click to Pay cannot bypass type restrictions: ${scenario.name} @hermetic-only`, async ({
    runtimePage,
  }) => {
    // Click to Pay exposes no credit/debit metadata, so a type-specific saved
    // card allowlist must not surface its unclassified cards.
    expect(
      await runtimePage.evaluate(
        (options) => window.sdkTest.canShowClickToPayForOptions(options),
        scenario.options,
      ),
    ).toBe(scenario.shown);
  });
}
