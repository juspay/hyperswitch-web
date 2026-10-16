import { parseJson } from "../helpers/json";
import { sdkKeysAtom, sdkOptionsAtom, sdkSessionsAtom } from "../helpers/sdk-atoms";
import React from "react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { initialValue, act, renderWithSdk } from "../helpers/render";
import { make as CardFormCoordinator } from "../../src/Payments/CardFormCoordinator.bs.js";
import * as Registry from "../../src/Payments/SadPortRegistry.bs.js";
import * as Protocol from "../../src/Payments/CardFormPortProtocol.bs.js";
import * as Atoms from "../../src/Utilities/JotaiAtoms.bs.js";
import { defaultkeys } from "../../src/Hooks/CommonHooks.bs.js";
import { defaultOptions } from "../../src/Types/PaymentType.bs.js";
import { authorization, card, logger, port, response } from "../helpers/lifecycle-fixtures";
function renderCoordinator({
  family = "vault",
  credentials = false,
  subscription = false
} = {}) {
  window.history.replaceState(null, "", `/checkout?componentName=cardFormCoordinator&surfaceFamily=${family}&groupId=lifecycle`);
  return renderWithSdk(<CardFormCoordinator />, {
    initialValues: [initialValue(sdkKeysAtom, {
      ...defaultkeys,
      parentURL: "https://merchant.test",
      iframeId: "coordinator",
      publishableKey: "pk_test_unit"
    }), initialValue(Atoms.loggerAtom, logger()), initialValue(sdkOptionsAtom, {
      ...defaultOptions,
      subscriptionEvents: subscription ? ["CardDetailsChange"] : []
    }), initialValue(sdkSessionsAtom, credentials ? {
      TAG: "Loaded",
      _0: {
        vault_details: {
          vault_type: "hyperswitch",
          vault_data: {
            sdk_authorization: authorization()
          }
        }
      }
    } : "Loading")]
  });
}
function command(data: Record<string, unknown>, {
  origin = "https://merchant.test",
  source = window
}: { origin?: string; source?: MessageEventSource | null } = {}) {
  act(() => window.dispatchEvent(new MessageEvent("message", {
    data: JSON.stringify({
      cardFormCoordinatorCommand: "initiateConfirm",
      confirmId: "confirm_unit",
      flow: "save",
      ...data
    }),
    origin,
    source
  })));
}
function field(name: string) {
  const channel = port();
  Registry.installPort(`lifecycle:${name}`, 1, channel);
  return channel;
}
function update(channel: ReturnType<typeof port>, payload: unknown) {
  act(() => channel.onmessage!({
    data: Protocol.makePortFrame("fieldStateUpdate", payload)
  }));
}
function results(spy: { mock: { calls: readonly (readonly unknown[])[] } }): unknown[] {
  return spy.mock.calls.map(([value]) => typeof value === "string" ? parseJson(value) : value);
}
afterEach(() => Object.keys(Registry.registry).forEach(Registry.closePort));
describe("CardFormCoordinator real port and command handlers", () => {
  it("relays brand, rising focus readiness, and dependent clears without forwarding raw fields", () => {
    const number = field("cardNumber"),
      expiry = field("cardExpiry"),
      cvc = field("cardCvc");
    const screen = renderCoordinator();
    const parent = vi.spyOn(window, "postMessage");
    update(number, {
      ...card,
      fieldStatus: {
        empty: false
      },
      focusReady: true
    });
    expect(cvc.postMessage).toHaveBeenCalledWith(Protocol.makePortFrame("detectedCardBrand", "Visa"));
    expect(expiry.postMessage).toHaveBeenCalledWith(Protocol.makePortFrame("doFocus", true));
    update(number, {
      ...card,
      focusReady: true
    });
    expect(expiry.postMessage).toHaveBeenCalledTimes(1);
    update(number, {
      focusReady: false
    });
    update(number, {
      ...card,
      focusReady: true
    });
    expect(expiry.postMessage).toHaveBeenCalledTimes(2);
    update(expiry, {
      rawCardExpiry: "10/29",
      focusReady: true
    });
    expect(cvc.postMessage).toHaveBeenCalledWith(Protocol.makePortFrame("doFocus", true));
    update(number, {
      fieldStatus: {
        empty: true
      },
      cardBrand: ""
    });
    expect(expiry.postMessage).toHaveBeenCalledWith(Protocol.makePortFrame("clearField", true));
    expect(cvc.postMessage).toHaveBeenCalledWith(Protocol.makePortFrame("clearField", true));
    expect(parent).not.toHaveBeenCalled();
    screen.unmount();
  });
  it("drops malformed and unknown port frames and reports missing/invalid fields through command results", () => {
    const number = field("cardNumber");
    renderCoordinator();
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    act(() => number.onmessage!({
      data: null
    }));
    act(() => number.onmessage!({
      data: Protocol.makePortFrame("unknown", card)
    }));
    expect(warn).toHaveBeenCalledTimes(2);
    const parent = vi.spyOn(window, "postMessage");
    command({});
    expect(results(parent).at(-1)).toMatchObject({
      confirmId: "confirm_unit",
      confirmResult: {
        error: {
          code: "validation_error",
          message: "cardNumber is required, cardExpiry is required, cardCvc is required"
        }
      }
    });
    update(number, {
      ...card,
      fieldStatus: {
        hasCardValidationStatus: true,
        isCardValid: false
      }
    });
    command({});
    // This command produces the validation-error envelope asserted here.
    expect((results(parent).at(-1) as { confirmResult: { error: { message: string } } }).confirmResult.error.message).toBe("cardNumber is invalid");
  });
  it("rejects commands from the wrong origin or source and exposes no raw data in subscribed events", () => {
    const number = field("cardNumber");
    renderCoordinator({
      subscription: true
    });
    const parent = vi.spyOn(window, "postMessage");
    const other = document.body.appendChild(document.createElement("iframe"));
    command({}, {
      origin: "https://attacker.test"
    });
    command({}, {
      source: other.contentWindow
    });
    expect(parent).not.toHaveBeenCalled();
    update(number, {
      ...card,
      fieldStatus: {
        complete: true
      }
    });
    const event = results(parent).at(-1);
    expect(event).toMatchObject({
      eventName: "cardDetailsChange"
    });
    expect(JSON.stringify(event)).not.toContain(card.rawCardNumber);
    expect(JSON.stringify(event)).not.toContain(card.rawCardholderName);
    for (const raw of ["rawCardNumber", "rawCardExpiry", "rawCvc", "rawCardholderName"]) expect(JSON.stringify(event)).not.toContain(raw);
    const count = parent.mock.calls.length;
    update(number, {
      ...card,
      fieldStatus: {
        complete: true
      }
    });
    expect(parent).toHaveBeenCalledTimes(count);
  });
  it("validates coordinator family and required credentials before issuing a vault request", () => {
    const number = field("cardNumber");
    renderCoordinator();
    update(number, card);
    const parent = vi.spyOn(window, "postMessage");
    command({});
    expect(results(parent).at(-1)).toMatchObject({
      confirmResult: {
        error: {
          code: "tokenization_failed",
          message: expect.stringContaining("credentials")
        }
      }
    });
    command({
      flow: "payments"
    });
    expect(results(parent).at(-1)).toMatchObject({
      paymentConfirmFail: true,
      errorMessage: expect.stringContaining("misrouted")
    });
  });
  it("sends card data only to the vault fetch, suppresses duplicate requests, and retries after HTTP failure", async () => {
    const number = field("cardNumber");
    renderCoordinator({
      credentials: true
    });
    update(number, card);
    let settle!: (value: ReturnType<typeof response>) => void;
    const fetch = vi.fn().mockImplementationOnce(() => new Promise(resolve => {
      settle = resolve;
    })).mockResolvedValueOnce(response({
      token: "tok_unit"
    }));
    vi.stubGlobal("fetch", fetch);
    const parent = vi.spyOn(window, "postMessage");
    command({});
    command({
      confirmId: "duplicate"
    });
    expect(fetch).toHaveBeenCalledOnce();
    const [url, options] = fetch.mock.calls[0];
    expect(url).toContain("pms_unit");
    expect(options.method).toBe("POST");
    expect(options.body).toContain(card.rawCardNumber);
    expect(options.body).toContain(card.rawCvc);
    expect(parent).not.toHaveBeenCalled();
    await act(async () => settle(response({
      error: "synthetic failure"
    }, 500)));
    expect(results(parent).at(-1)).toMatchObject({
      confirmResult: {
        error: {
          code: "tokenization_failed"
        }
      }
    });
    command({
      confirmId: "retry"
    });
    await vi.waitFor(() => expect(results(parent).at(-1)).toMatchObject({
      confirmId: "retry",
      confirmResult: {
        token: "tok_unit"
      }
    }));
    expect(fetch).toHaveBeenCalledTimes(2);
    for (const result of results(parent)) {
      expect(JSON.stringify(result)).not.toContain(card.rawCardNumber);
      expect(JSON.stringify(result)).not.toContain("rawCvc");
    }
  });
  it("observes subscription changes on an installed port and seeds a newly registered CVC port with the current brand", () => {
    const number = field("cardNumber");
    const {
      store
    } = renderCoordinator();
    const parent = vi.spyOn(window, "postMessage");
    update(number, card);
    expect(parent).not.toHaveBeenCalled();
    act(() => store.set(sdkOptionsAtom, {
      ...defaultOptions,
      subscriptionEvents: ["CardDetailsChange"]
    }));
    update(number, card);
    expect(results(parent).at(-1)).toMatchObject({
      eventName: "cardDetailsChange"
    });
    let cvc!: ReturnType<typeof field>;
    act(() => {
      cvc = field("cardCvc");
    });
    expect(cvc.postMessage).toHaveBeenCalledWith(Protocol.makePortFrame("detectedCardBrand", "Visa"));
    const replacement = port();
    act(() => Registry.installPort("lifecycle:cardCvc", 2, replacement));
    expect(cvc.close).toHaveBeenCalledOnce();
    expect(typeof replacement.onmessage).toBe("function");
    expect(replacement.postMessage).toHaveBeenCalledWith(Protocol.makePortFrame("detectedCardBrand", "Visa"));
  });
  it.each(["unknown", "payments"])("rejects vault commands routed to a %s coordinator", family => {
    renderCoordinator({
      family
    });
    const parent = vi.spyOn(window, "postMessage");
    command({});
    expect(results(parent).at(-1)).toMatchObject({
      confirmResult: {
        error: {
          code: "tokenization_failed"
        }
      }
    });
    expect(fetch).not.toHaveBeenCalled();
  });
  it("uses the CVC-only update path and recovers after a rejected request", async () => {
    const cvc = field("cardCvc");
    renderCoordinator({
      credentials: true
    });
    update(cvc, {
      rawCvc: "123"
    });
    const errorLog = vi.spyOn(console, "error").mockImplementation(() => {});
    const fetch = vi.fn().mockRejectedValueOnce(new Error("synthetic connection failure")).mockResolvedValueOnce(response({
      token: "tok_updated"
    }));
    vi.stubGlobal("fetch", fetch);
    const parent = vi.spyOn(window, "postMessage");
    command({
      flow: "update"
    });
    await vi.waitFor(() => expect(results(parent).at(-1)).toMatchObject({
      confirmResult: {
        error: {
          code: "tokenization_failed"
        }
      }
    }));
    expect(errorLog).toHaveBeenCalled();
    command({
      flow: "update",
      confirmId: "update_retry"
    });
    await vi.waitFor(() => expect(results(parent).at(-1)).toMatchObject({
      confirmId: "update_retry",
      confirmResult: {
        token: "tok_updated"
      }
    }));
    const [, options] = fetch.mock.calls[1];
    expect(options.method).toBe("PUT");
    expect(parseJson(options.body)).toEqual({
      payment_method_data: {
        card: {
          card_cvc: "123"
        }
      }
    });
    expect(new Headers(options.headers).get("Authorization")).toBe(authorization());
    expect(options.body).not.toContain(card.rawCardNumber);
  });
});
