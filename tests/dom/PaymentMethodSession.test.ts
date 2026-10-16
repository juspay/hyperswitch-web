// Narrow only the observed command envelopes consumed below; posted() stays unknown[].
type CoordinatorCommand = { cardFormCoordinatorCommand?: string; confirmId: string };
import { afterEach, describe, expect, it, vi } from "vitest";
import * as Session from "../../src/hyper-loader/PaymentMethodSession.bs.js";
import * as Events from "../../src/Utilities/EventListenerManager.bs.js";
import { authorization, card, installChannels, installVgsCollect, logger, message, mountField, posted, response } from "../helpers/lifecycle-fixtures";
const sessions: ReturnType<typeof Session.make>[] = [];
function make(options = {}) {
  const log = logger();
  const session = Session.make({
    sdkAuthorization: authorization(),
    vaultDetails: {
      vaultType: "hyperswitch",
      vaultData: {
        sdkAuthorization: authorization()
      }
    },
    ...options
  }, "pk_test_unit", "sdk_unit", log);
  sessions.push(session);
  return {
    session,
    form: session.createCardForm(),
    log
  };
}
function coordinator() {
  const iframe = document.querySelector<HTMLIFrameElement>('iframe[src*="componentName=cardFormCoordinator"]')!;
  return {
    iframe,
    post: vi.spyOn(iframe.contentWindow!, "postMessage")
  };
}
afterEach(() => sessions.splice(0).forEach(session => session.deinit()));
const vgsOptions = {
  vaultDetails: {
    vaultType: "vgs",
    vaultData: {
      vaultId: "vault_unit",
      environment: "sandbox"
    }
  }
};
async function mountVgs(form: ReturnType<ReturnType<typeof Session.make>["createCardForm"]>, vendor: ReturnType<typeof installVgsCollect>, fieldType: string, vendorName: string) {
  const field = form.create(fieldType, {});
  const container = document.createElement("div");
  container.id = `lifecycle-vgs-${fieldType}`;
  document.body.appendChild(container);
  field.mount(`#${container.id}`);
  await vi.waitFor(() => expect(vendor.fields.has(vendorName)).toBe(true));
  return {
    field,
    ...vendor.fields.get(vendorName)!
  };
}
describe("PaymentMethodSession VGS vendor boundary", () => {
  it.each([["cardNumber", "card_number", "success"], ["cardNumber", "card_number", "failure"], ["cardCvc", "card_cvc", "success"], ["cardCvc", "card_cvc", "failure"]])("settles VGS %s tokenization on deinit and ignores late %s/%s callback", async (fieldType, vendorName, completion) => {
    const vendor = installVgsCollect();
    const {
      session,
      form,
      log
    } = make(vgsOptions);
    const mounted = await mountVgs(form, vendor, fieldType, vendorName);
    vendor.state({
      [vendorName]: {
        isEmpty: false,
        isValid: true
      }
    });
    const pending = form.tokenize();
    const settled = vi.fn();
    pending.then(settled);
    session.deinit();
    expect(mounted.handle.delete).toHaveBeenCalledOnce();
    try {
      await vi.waitFor(() => expect(settled).toHaveBeenCalled(), {
        timeout: 100
      });
      const result = await pending;
      expect(result).toMatchObject({
        error: {
          code: "tokenization_failed",
          message: expect.stringContaining("deinit()")
        }
      });
      const [,, success, failure] = vendor.form.submit.mock.calls[0];
      if (completion === "success") {
        success(200, {
          token: "tok_after_deinit"
        });
      } else {
        failure({
          [vendorName]: {
            errorMessages: ["synthetic late failure"]
          }
        });
      }
      await Promise.resolve();
      await Promise.resolve();
      session.deinit();
      expect(settled).toHaveBeenCalledOnce();
      await expect(pending).resolves.toBe(result);
      expect(mounted.handle.delete).toHaveBeenCalledOnce();
      expect(log.setLogError.mock.calls.filter(([, event]) => event === "PAYMENT_METHOD_SESSION_TOKENIZE")).toHaveLength(1);
      await expect(form.tokenize()).resolves.toMatchObject({
        error: {
          code: "session_consumed"
        }
      });
    } finally {
      vendor.form.submit.mock.calls[0][2](500, {
        error: "synthetic completion after cleanup"
      });
      await pending;
    }
  });
  it.each([["cardNumber", "card_number"], ["cardCvc", "card_cvc"]])("preserves deinit when the %s vendor result is queued before cleanup", async (fieldType, vendorName) => {
    const vendor = installVgsCollect();
    const {
      session,
      form
    } = make(vgsOptions);
    await mountVgs(form, vendor, fieldType, vendorName);
    vendor.state({
      [vendorName]: {
        isEmpty: false,
        isValid: true
      }
    });
    const pending = form.tokenize();
    vendor.form.submit.mock.calls[0][2](200, {
      token: "tok_queued_before_deinit"
    });
    // Let the submit wrapper run, then deinitialize before the flow's queued
    // promise callback can consume the vendor result.
    await Promise.resolve();
    session.deinit();
    await expect(pending).resolves.toMatchObject({
      error: {
        code: "tokenization_failed",
        message: expect.stringContaining("deinit()")
      }
    });
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "session_consumed"
      }
    });
  });
  it("requires a mounted field and valid vendor state, then consumes one successful tokenization", async () => {
    const vendor = installVgsCollect();
    const {
      form,
      log
    } = make(vgsOptions);
    form.create("cardNumber", {});
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "incomplete_field_set"
      }
    });
    const mounted = await mountVgs(form, vendor, "cardNumber", "card_number");
    await mountVgs(form, vendor, "cardExpiry", "card_exp");
    await mountVgs(form, vendor, "cardCvc", "card_cvc");
    expect(vendor.create).toHaveBeenCalledWith("vault_unit", "sandbox", expect.any(Function));
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "validation_error",
        message: expect.stringContaining("cardNumber is required")
      }
    });
    expect(vendor.form.submit).not.toHaveBeenCalled();
    const change = vi.fn();
    mounted.field.on("change", change);
    vendor.state({
      card_number: {
        isEmpty: false,
        isValid: true,
        cardBrand: "Visa",
        value: card.rawCardNumber
      },
      card_exp: {
        isEmpty: false,
        isValid: true
      },
      card_cvc: {
        isEmpty: false,
        isValid: true
      }
    });
    expect(change).toHaveBeenCalledWith({
      empty: false,
      complete: true,
      valid: true,
      elementType: "cardNumber",
      brand: "Visa"
    });
    const pending = form.tokenize();
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "tokenization_in_progress"
      }
    });
    expect(vendor.form.submit).toHaveBeenCalledOnce();
    const [path, payload, success] = vendor.form.submit.mock.calls[0];
    expect(path).toBe("/post");
    expect(payload).toEqual({});
    success(201, {
      token: "tok_vgs_unit",
      last4: "1111"
    });
    await expect(pending).resolves.toEqual({
      token: "tok_vgs_unit",
      last4: "1111"
    });
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "session_consumed"
      }
    });
    expect(vendor.form.submit).toHaveBeenCalledOnce();
    for (const spy of [log.setLogInfo, log.setLogError]) {
      expect(JSON.stringify(spy.mock.calls)).not.toContain(card.rawCardNumber);
      expect(JSON.stringify(spy.mock.calls)).not.toContain("tok_vgs_unit");
    }
  });
  it("allows retry after vendor callback error and rejected submit return", async () => {
    const vendor = installVgsCollect();
    const {
      form,
      log
    } = make(vgsOptions);
    await mountVgs(form, vendor, "cardNumber", "card_number");
    vendor.state({
      card_number: {
        isEmpty: false,
        isValid: true
      }
    });
    vendor.form.submit.mockImplementationOnce((_path, _payload, _success, failure) => {
      failure({
        card_number: {
          errorMessages: [`synthetic failure ${card.rawCardNumber}`]
        }
      });
    });
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "tokenization_failed",
        type: "api_error"
      }
    });
    expect(JSON.stringify(log.setLogError.mock.calls)).not.toContain(card.rawCardNumber);
    expect(JSON.stringify(log.setLogInfo.mock.calls)).not.toContain(card.rawCardNumber);
    vendor.form.submit.mockRejectedValueOnce(new Error("fields not loaded"));
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "tokenization_failed",
        message: "VGS submit rejected: fields not loaded"
      }
    });
    vendor.form.submit.mockImplementationOnce((_path, _payload, success) => success("200", {
      token: "tok_after_retry"
    }));
    await expect(form.tokenize()).resolves.toEqual({
      token: "tok_after_retry"
    });
    expect(vendor.form.submit).toHaveBeenCalledTimes(3);
  });
  it("rejects vendor transport failure routed through success and permits the next CVC-only attempt", async () => {
    const vendor = installVgsCollect();
    const {
      form
    } = make(vgsOptions);
    await mountVgs(form, vendor, "cardCvc", "card_cvc");
    vendor.state({
      card_cvc: {
        isEmpty: false,
        isValid: true
      }
    });
    vendor.form.submit.mockImplementationOnce((_path, _payload, success) => success(null, "Network Error"));
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "tokenization_failed",
        message: expect.stringContaining("Network Error")
      }
    });
    vendor.form.submit.mockImplementationOnce(() => {
      throw new Error("vendor synchronous failure");
    });
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "tokenization_failed",
        message: "vendor synchronous failure"
      }
    });
    vendor.form.submit.mockImplementationOnce((_path, _payload, success) => success(200, {
      token: "tok_cvc_retry"
    }));
    await expect(form.tokenize()).resolves.toEqual({
      token: "tok_cvc_retry"
    });
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "session_consumed"
      }
    });
  });
  it("forwards vendor handle controls and filtered updates and deletes handles once on repeated cleanup", async () => {
    const vendor = installVgsCollect();
    const {
      session,
      form
    } = make(vgsOptions);
    const mounted = await mountVgs(form, vendor, "cardNumber", "card_number");
    const focus = vi.fn();
    const blur = vi.fn();
    mounted.field.on("focus", focus);
    mounted.field.on("blur", blur);
    vendor.state({
      card_number: {
        isEmpty: false,
        isValid: true
      }
    });
    mounted.events.get("focus")!({});
    mounted.events.get("blur")!({});
    expect(focus).toHaveBeenCalledWith(expect.objectContaining({
      elementType: "cardNumber"
    }));
    expect(blur).toHaveBeenCalledOnce();
    mounted.field.focus();
    mounted.field.blur();
    mounted.field.clear();
    mounted.field.update({
      placeholder: "Synthetic card",
      disabled: true,
      value: card.rawCardNumber,
      name: "override"
    });
    expect(mounted.handle.focus).toHaveBeenCalledOnce();
    expect(mounted.handle.blur).toHaveBeenCalledOnce();
    expect(mounted.handle.clear).toHaveBeenCalledOnce();
    expect(mounted.handle.update).toHaveBeenCalledWith({
      placeholder: "Synthetic card",
      disabled: true
    });
    const expiry = await mountVgs(form, vendor, "cardExpiry", "card_exp");
    mounted.field.unmount();
    mounted.field.destroy();
    session.deinit();
    session.deinit();
    expect(mounted.handle.delete).toHaveBeenCalledOnce();
    expect(expiry.handle.delete).toHaveBeenCalledOnce();
    expect(mounted.container.querySelector("iframe")).toBeNull();
    expect(vendor.script.isConnected).toBe(false);
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "session_consumed"
      }
    });
  });
});
describe("PaymentMethodSession public lifecycle", () => {
  it("sanitizes mounted field callbacks and closes a pending channel on cleanup", () => {
    const channels = installChannels();
    const {
      form
    } = make();
    const field = form.create("cardNumber", {});
    const {
      iframe,
      post
    } = mountField(field, "vault-number");
    const ready = vi.fn();
    const focus = vi.fn();
    const blur = vi.fn();
    const change = vi.fn();
    field.on("ready", ready);
    field.on("focus", focus);
    field.on("blur", blur);
    field.on("change", change);
    message(iframe, {
      ready: true
    }, {
      source: window
    });
    message(iframe, {
      ready: true
    }, {
      origin: "https://attacker.test"
    });
    expect(ready).not.toHaveBeenCalled();
    message(iframe, {
      ready: true
    });
    message(iframe, {
      focus: true
    });
    message(iframe, {
      blur: true
    });
    expect(ready).toHaveBeenCalledWith(expect.objectContaining({
      elementType: "cardNumber"
    }));
    expect(focus).toHaveBeenCalledOnce();
    expect(blur).toHaveBeenCalledOnce();
    message(iframe, {
      cardStateUpdate: {
        ...card,
        fieldStatus: {
          complete: true,
          empty: false,
          isCardValid: true
        }
      }
    });
    expect(change).toHaveBeenCalledWith({
      elementType: "cardNumber",
      complete: true,
      empty: false,
      valid: true,
      brand: "Visa"
    });
    field.focus();
    field.blur();
    field.clear();
    expect(posted(post)).toContainEqual({
      doFocus: true
    });
    expect(posted(post)).toContainEqual({
      doBlur: true
    });
    expect(posted(post)).toContainEqual({
      doClearValues: true
    });
    field.update({
      savedCard: {
        paymentMethodData: {
          card: {
            cardNetwork: "Mastercard"
          }
        }
      }
    });
    expect(posted(post).at(-1)).toEqual({
      savedCardBrand: "Mastercard"
    });
    message(iframe, {
      iframeMounted: true
    });
    expect(channels).toHaveLength(1);
    expect(posted(post)).toContainEqual(expect.objectContaining({
      portEpoch: 1
    }));
    form.deinit();
    expect(channels[0].port1.close).toHaveBeenCalledOnce();
    expect(() => field.destroy()).not.toThrow();
    message(iframe, {
      cardStateUpdate: card
    });
    expect(change).toHaveBeenCalledOnce();
  });
  it("requires a supported field set and blocks use after repeated deinit", async () => {
    const {
      session,
      form
    } = make();
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "incomplete_field_set",
        type: "validation_error"
      }
    });
    form.create("cardExpiry", {});
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "incomplete_field_set"
      }
    });
    session.deinit();
    session.deinit();
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "session_consumed"
      }
    });
    expect(session.fields.contents).toEqual({});
    expect(document.querySelector('iframe[src*="cardFormCoordinator"]')).toBeNull();
  });
  it("queues tokenization until trusted coordinator readiness and prevents duplicates", async () => {
    const {
      form,
      log
    } = make();
    form.create("cardNumber", {
      subscriptionEvents: ["cardDetailsChange"]
    });
    const {
      iframe,
      post
    } = coordinator();
    const pending = form.tokenize();
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "tokenization_in_progress"
      }
    });
    message(iframe, {
      iframeMounted: true
    }, {
      origin: "https://attacker.test"
    });
    message(iframe, {
      iframeMounted: true
    }, {
      source: window
    });
    expect(post).not.toHaveBeenCalled();
    message(iframe, {
      iframeMounted: true
    });
    const command = (posted(post) as CoordinatorCommand[]).find(value => value.cardFormCoordinatorCommand)!;
    expect(command).toMatchObject({
      cardFormCoordinatorCommand: "initiateConfirm",
      flow: "save"
    });
    expect(posted(post)).toContainEqual(expect.objectContaining({
      sessions: expect.objectContaining({
        vault_details: expect.any(Object)
      })
    }));
    message(iframe, {
      confirmId: "wrong",
      confirmResult: {
        token: "wrong"
      }
    });
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "tokenization_in_progress"
      }
    });
    message(iframe, {
      confirmId: command.confirmId,
      confirmResult: {
        token: "tok_test"
      }
    }, {
      origin: "https://attacker.test"
    });
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "tokenization_in_progress"
      }
    });
    message(iframe, {
      confirmId: command.confirmId,
      confirmResult: {
        token: "tok_test"
      }
    });
    await expect(pending).resolves.toEqual({
      token: "tok_test"
    });
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "session_consumed"
      }
    });
    expect(JSON.stringify(log.setLogInfo.mock.calls)).not.toContain("tok_test");
    for (const raw of Object.values(card)) expect(JSON.stringify(log.setLogInfo.mock.calls)).not.toContain(raw);
  });
  it("allows retry after validation failure and keeps callbacks behind source and origin checks", async () => {
    const {
      form
    } = make();
    form.create("cardCvc", {
      savedCard: {
        paymentMethodData: {
          card: {
            cardNetwork: "Visa"
          }
        }
      }
    });
    const change = vi.fn();
    form.on("change", change);
    const {
      iframe,
      post
    } = coordinator();
    message(iframe, {
      iframeMounted: true
    });
    const first = form.tokenize();
    const command = posted(post).at(-1) as CoordinatorCommand;
    expect(command).toMatchObject({
      flow: "update",
      savedCardBrand: "Visa"
    });
    const error = {
      error: {
        code: "validation_error",
        type: "validation_error",
        message: "cardCvc is required"
      }
    };
    message(iframe, {
      confirmId: command.confirmId,
      confirmResult: error
    });
    await expect(first).resolves.toEqual(error);
    const second = form.tokenize();
    const retry = posted(post).at(-1) as CoordinatorCommand;
    expect(retry.confirmId).not.toBe(command.confirmId);
    message(iframe, {
      eventName: "cardDetailsChange"
    }, {
      source: window
    });
    expect(change).not.toHaveBeenCalled();
    message(iframe, {
      eventName: "cardDetailsChange",
      cardInfo: {
        last4: "1111"
      }
    });
    expect(change).toHaveBeenCalledWith({
      eventName: "cardDetailsChange",
      cardInfo: {
        last4: "1111"
      }
    });
    message(iframe, {
      confirmId: retry.confirmId,
      confirmResult: {
        token: "tok_retry"
      }
    });
    await expect(second).resolves.toEqual({
      token: "tok_retry"
    });
  });
  it("settles pending tokenization on deinit and removes coordinator listeners", async () => {
    const existingKeys = new Set(Object.keys(Events.eventListenerMap));
    const {
      session,
      form
    } = make();
    form.create("cardNumber", {});
    const listenerKeys = Object.keys(Events.eventListenerMap).filter(key => !existingKeys.has(key));
    const pending = form.tokenize();
    session.deinit();
    session.deinit();
    await expect(pending).resolves.toMatchObject({
      error: {
        code: "tokenization_failed",
        message: expect.stringContaining("deinit()")
      }
    });
    for (const key of listenerKeys.filter(key => /VaultCoordinator|VaultField|CoordinatorFullscreenAnswer/.test(key))) {
      expect(Events.eventListenerMap).not.toHaveProperty(key);
    }
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "session_consumed"
      }
    });
  });
  it("destroys a never-mounted field repeatedly without leaving its listener installed", () => {
    const {
      form
    } = make();
    const existingKeys = new Set(Object.keys(Events.eventListenerMap));
    const field = form.create("cardNumber", {});
    const fieldKey = Object.keys(Events.eventListenerMap).find(key => key.startsWith("onVaultField-") && !existingKeys.has(key));
    expect(fieldKey).toBeDefined();
    expect(() => field.destroy()).not.toThrow();
    expect(() => field.destroy()).not.toThrow();
    expect(Events.eventListenerMap).not.toHaveProperty(fieldKey!);
  });
  it("enforces expiry retrieved through the real fetch contract", async () => {
    const fetch = vi.fn().mockResolvedValue(response({
      payment_method_session_id: "pms_unit",
      expires_at: "2000-01-01T00:00:00Z"
    }));
    vi.stubGlobal("fetch", fetch);
    const {
      form
    } = make({
      vaultDetails: undefined
    });
    await vi.waitFor(() => expect(fetch).toHaveBeenCalledOnce());
    await vi.waitFor(async () => expect(await form.tokenize()).toMatchObject({
      error: {
        code: "session_expired"
      }
    }));
    expect(fetch.mock.calls[0][0]).toContain("/v1/payment-method-sessions/pms_unit");
    expect(Session.isExpired(Date.now() + 60_000)).toBe(false);
    expect(Session.isExpired(0)).toBe(false);
    expect(Session.parseExpiresAtMs("")).toBe(0);
    expect(Number.isNaN(Session.parseExpiresAtMs("not-a-date"))).toBe(true);
  });
  it("keeps tokenization unavailable when session retrieval returns an HTTP failure", async () => {
    const failedResponse = response({
      error: {
        message: "synthetic retrieval failure"
      }
    }, 500);
    const json = vi.fn(failedResponse.json);
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({
      ...failedResponse,
      json
    }));
    const {
      form
    } = make({
      vaultDetails: undefined
    });
    await vi.waitFor(() => expect(json).toHaveBeenCalledOnce());
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "incomplete_field_set"
      }
    });
    expect(document.querySelector('iframe[src*="cardFormCoordinator"]')).toBeNull();
  });
  it("handles a rejected retrieval promise without leaving an unhandled rejection or usable form", async () => {
    const error = vi.spyOn(console, "error").mockImplementation(() => {});
    const fetch = vi.fn().mockRejectedValue(new Error("synthetic retrieval rejection"));
    vi.stubGlobal("fetch", fetch);
    const {
      form
    } = make({
      vaultDetails: undefined
    });
    await vi.waitFor(() => expect(error).toHaveBeenCalled());
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "incomplete_field_set"
      }
    });
    expect(fetch).toHaveBeenCalledOnce();
  });
  it("keeps the session deinitialized when retrieval resolves after cleanup", async () => {
    let resolveRetrieval;
    const fetch = vi.fn(() => new Promise(resolve => {
      resolveRetrieval = resolve;
    }));
    vi.stubGlobal("fetch", fetch);
    const {
      session,
      form
    } = make({
      vaultDetails: undefined
    });
    const previousListeners = Object.keys(Events.eventListenerMap);
    session.deinit();
    const expiresAtRead = vi.fn(() => "2099-01-01T00:00:00Z");
    resolveRetrieval!(response({
      payment_method_session_id: "pms_unit",
      get expires_at() {
        return expiresAtRead();
      },
      external_vault_details: {
        external_vault_id: "vault_unit",
        sdk_env: "sandbox"
      }
    }));
    await vi.waitFor(() => expect(expiresAtRead).toHaveBeenCalled());
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "session_consumed"
      }
    });
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    form.create("cardNumber", {});
    expect(warn).toHaveBeenCalledWith(expect.stringContaining("consumed/deinitialized"));
    expect(session.fields.contents).toEqual({});
    expect(Object.keys(Events.eventListenerMap)).toEqual(previousListeners);
    expect(document.querySelector('iframe[src*="cardFormCoordinator"]')).toBeNull();
  });
  it("rejects lone name/expiry and name plus CVC field sets", async () => {
    const {
      form
    } = make();
    form.create("cardholderName", {});
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "incomplete_field_set"
      }
    });
    form.create("cardCvc", {});
    await expect(form.tokenize()).resolves.toMatchObject({
      error: {
        code: "incomplete_field_set"
      }
    });
  });
  it("keeps vault authorization fallback precedence and adapts external vault sessions", () => {
    const auth = authorization();
    expect(Session.resolveSdkAuthorization({
      sdkAuthorization: "",
      vaultDetails: {},
      vault_details: {
        vault_type: "hyperswitch",
        vault_data: {
          sdk_authorization: auth
        }
      }
    })).toBe(auth);
    expect(Session.resolveSdkAuthorization({
      sdkAuthorization: "top",
      vaultDetails: {
        vaultType: "hyperswitch",
        vaultData: {
          sdkAuthorization: auth
        }
      }
    })).toBe("top");
    expect(Session.resolveSdkAuthorization({
      vaultDetails: {
        vaultType: "vgs",
        vaultData: {
          sdkAuthorization: auth
        }
      }
    })).toBe("");
    expect(Session.adaptRetrievedSessionToVaultDetails({
      id: "session",
      external_vault_details: {
        external_vault_id: "vault_test",
        sdk_env: "sandbox"
      }
    }, auth)).toMatchObject({
      id: "session",
      vault_details: {
        vault_type: "vgs",
        vault_data: {
          vault_id: "vault_test",
          environment: "sandbox"
        }
      }
    });
    expect(Session.adaptRetrievedSessionToVaultDetails({
      id: "session"
    }, auth)).toMatchObject({
      vault_details: {
        vault_type: "hyperswitch",
        vault_data: {
          sdk_authorization: auth
        }
      }
    });
  });
});
