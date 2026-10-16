import { parseJson } from "../helpers/json";
import { sdkOptionsAtom, sdkPaymentMethodListAtom, sdkConfigsAtom } from "../helpers/sdk-atoms";
import type { InitialValue } from "../helpers/render";
import React from "react";
import { describe, expect, it } from "vitest";
import { initialValue, act, renderWithSdk, screen } from "../helpers/render";
import * as Atoms from "../../src/Utilities/JotaiAtoms.bs.js";
import * as PaymentUtils from "../../src/Utilities/PaymentUtils.bs.js";
import * as Methods from "../../src/Payments/PaymentMethodsRecord.bs.js";
import { defaultSdkConfigValue } from "../../shared-code/sdk-utils/types/SdkConfigTypes.bs.js";
import { defaultOptions } from "../../src/Types/PaymentType.bs.js";

const noSessions = {};

function Availability({ sessions = noSessions, paypalPrefilled = true }) {
  const [wallets, available, candidates] = PaymentUtils.useGetPaymentMethodList(
    "Payment",
    sessions,
    true,
    true,
    paypalPrefilled,
  );
  return (
    <output data-testid="availability">
      {JSON.stringify({ wallets, available, candidates })}
    </output>
  );
}

function result(): unknown {
  return parseJson(screen.getByTestId("availability").textContent!);
}

function loadedValues(paymentMethods: { payment_method: string; payment_method_type: string; payment_experience?: string[] }[], options = {}): InitialValue[] {
  const paymentList = {
    payment_methods_enabled: paymentMethods,
    intent_data: { currency: "USD", payment_type: "normal" },
  };
  return [
    initialValue(sdkPaymentMethodListAtom, { TAG: "Loaded", _0: paymentList }),
    initialValue(PaymentUtils.paymentMethodListValue, Methods.itemToObjMapperFromClientList(paymentList)),
    initialValue(sdkOptionsAtom, {
        ...defaultOptions,
        customerPaymentMethods: { TAG: "NoResult", _0: false },
        ...options,
      }),
  ];
}

describe("final payment method availability", () => {
  it("removes and restores card as VGS readiness changes while preserving ideal", () => {
    const initialValues = loadedValues([
      { payment_method: "card", payment_method_type: "credit" },
      { payment_method: "bank_redirect", payment_method_type: "ideal" },
    ]);
    const { store } = renderWithSdk(<Availability />, {
      initialValues: [...initialValues, initialValue(Atoms.isVgsScriptReady, false)],
    });

    expect(result()).toEqual({
      wallets: [],
      available: ["ideal"],
      candidates: ["card", "ideal"],
    });

    act(() => store.set(Atoms.isVgsScriptReady, true));
    expect(result()).toEqual({
      wallets: [],
      available: ["card", "ideal"],
      candidates: ["card", "ideal"],
    });

    act(() => store.set(Atoms.isVgsScriptReady, false));
    expect(result()).toEqual({
      wallets: [],
      available: ["ideal"],
      candidates: ["card", "ideal"],
    });
  });

  it("combines PayPal session eligibility and Klarna final filtering as sessions change", () => {
    const initialValues = loadedValues(
      [
        { payment_method: "bank_redirect", payment_method_type: "ideal" },
        {
          payment_method: "wallet",
          payment_method_type: "paypal",
          payment_experience: ["invoke_sdk_client", "redirect_to_url"],
        },
        {
          payment_method: "pay_later",
          payment_method_type: "klarna",
          payment_experience: ["invoke_sdk_client", "redirect_to_url"],
        },
      ],
      {
        wallets: { ...defaultOptions.wallets, klarna: "Never" },
      },
    );
    initialValues.push(initialValue(sdkConfigsAtom, {
        ...defaultSdkConfigValue,
        account_config: {
          profile: {
            vaulting_action: "Skip",
            collect_shipping_details_from_wallet_connector: false,
            collect_billing_details_from_wallet_connector: false,
            always_collect_shipping_details_from_wallet_connector: false,
            always_collect_billing_details_from_wallet_connector: false,
          },
        },
      }));
    const { rerender, store } = renderWithSdk(
      <Availability paypalPrefilled={false} />,
      {
        initialValues,
      },
    );

    // Without SDK sessions both configured redirect methods remain available.
    expect(result()).toEqual({
      wallets: [],
      available: ["paypal", "klarna", "ideal"],
      candidates: ["paypal", "klarna", "ideal"],
    });

    rerender(
      <Availability
        paypalPrefilled={false}
        sessions={{
          session_token: [
            { wallet_name: "paypal", session_token: "paypal-session-test" },
            { wallet_name: "klarna", session_token: "klarna-session-test" },
          ],
        }}
      />,
    );

    // PayPal now has an eligible SDK wallet slot. Klarna is a raw redirect candidate,
    // but its active SDK session excludes that candidate from the final list.
    expect(result()).toEqual({
      wallets: ["paypal"],
      available: ["ideal"],
      candidates: ["klarna", "ideal"],
    });

    rerender(<Availability paypalPrefilled={false} />);
    expect(result()).toEqual({
      wallets: [],
      available: ["paypal", "klarna", "ideal"],
      candidates: ["paypal", "klarna", "ideal"],
    });

    act(() => {
      const options = store.get(Atoms.optionAtom);
      store.set(Atoms.optionAtom, {
        ...options,
        wallets: {
          ...options.wallets,
          payPal: { TAG: "PaypalConfigString", _0: "Never" },
        },
      });
    });
    expect(result()).toEqual({
      wallets: [],
      available: ["klarna", "ideal"],
      candidates: ["klarna", "ideal"],
    });
  });
});
