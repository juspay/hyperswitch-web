import { parseJson } from "../helpers/json";
import type { FixtureLoadable } from "../helpers/sdk-atoms";
import { sdkKeysAtom, sdkPaymentMethodListAtom } from "../helpers/sdk-atoms";
import React from "react";
import { describe, expect, it, vi } from "vitest";
import { initialValue, act, renderWithSdk } from "../helpers/render";
import * as Payment from "../../src/Utilities/PaymentHelpers.bs.js";
import * as Atoms from "../../src/Utilities/JotaiAtoms.bs.js";
import { defaultkeys } from "../../src/Hooks/CommonHooks.bs.js";
import { make as ThreeDSMethod } from "../../src/ThreeDSMethod.bs.js";
import { make as ThreeDSAuth } from "../../src/ThreeDSAuth.bs.js";
import { executionAuth, executionConfirm, executionLogger, executionResponse, executionSecret } from "../helpers/execution-fixtures";
vi.mock("../../src/libraries/ua-parser-js/ua-parser.js", async () => {
  const {
    createRequire
  } = await import("node:module");
  const require = createRequire(import.meta.url);
  return {
    UAParser: require("../../src/libraries/ua-parser-js/ua-parser.js").UAParser
  };
});
const executionLoadedList = {
  TAG: "Loaded",
  _0: {
    payment_methods_enabled: [{
      payment_method: "card",
      payment_method_type: "credit"
    }],
    intent_data: {
      payment_type: "normal",
      currency: "USD"
    }
  }
};
function executionCheckout(options: { secret?: string; auth?: string; list?: FixtureLoadable } = {}) {
  let confirm!: ReturnType<typeof Payment.usePaymentIntent>;
  const logger = executionLogger();
  const callback = vi.fn();
  const secret = "secret" in options ? options.secret : executionSecret;
  function Harness() {
    confirm = Payment.usePaymentIntent(logger, "Card");
    return null;
  }
  const view = renderWithSdk(<Harness />, {
    initialValues: [initialValue(sdkKeysAtom, {
      ...defaultkeys,
      clientSecret: secret,
      sdkAuthorization: options.auth,
      publishableKey: "pk_execution",
      iframeId: "execution-checkout",
      sdkHandleOneClickConfirmPayment: false
    }), initialValue(Atoms.customPodUri, "pod_execution"), initialValue(sdkPaymentMethodListAtom, options.list ?? executionLoadedList)]
  });
  return {
    ...view,
    logger,
    callback,
    submit: (manualRetry = false) => act(() => confirm(undefined, [["payment_method", "card"], ["payment_token", "execution_token"]], executionConfirm, undefined, undefined, callback, manualRetry))
  };
}
type ExecutionMessage = { submitSuccessful?: boolean; data?: unknown; url?: string; param?: string; metadata?: Record<string, string> };
function executionMessages(post: { mock: { calls: readonly (readonly unknown[])[] } }) {
  // Window messaging is an untyped generated-JS boundary; assertions below verify payloads.
  return post.mock.calls.map(([message]) => message as ExecutionMessage);
}
function executionWindowMessage(data: unknown, origin = "https://sdk.test") {
  act(() => window.dispatchEvent(new MessageEvent("message", {
    data: JSON.stringify(data),
    origin
  })));
}
async function executionFlush() {
  await act(() => vi.advanceTimersByTimeAsync(0));
}
describe("checkout payment-intent hook", () => {
  it.each([undefined, executionAuth])("constructs actual checkout request and success callback with auth %s", async auth => {
    vi.useFakeTimers();
    const data = {
      status: "succeeded",
      payment_id: auth ? "pay_authorized" : "pay_execution"
    };
    const fetch = vi.fn().mockResolvedValue(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const fixture = executionCheckout({
      auth
    });
    fixture.submit();
    await executionFlush();
    const [url, request] = fetch.mock.calls[0];
    expect(url).toBe(`https://api.sdk.test/payments/${data.payment_id}/confirm`);
    expect(request.method).toBe("POST");
    expect(request.headers.get("x-feature")).toBe("pod_execution");
    expect(request.headers.get(auth ? "Authorization" : "api-key")).toBe(auth || "pk_execution");
    expect(request.headers.has(auth ? "api-key" : "Authorization")).toBe(false);
    const body = parseJson(request.body) as { client_secret?: string };
    expect(body).toMatchObject({
      payment_method: "card",
      payment_token: "execution_token",
      payment_type: "normal",
      return_url: executionConfirm.return_url,
      browser_info: {
        user_agent: navigator.userAgent
      }
    });
    expect(body.client_secret).toBe(auth ? undefined : executionSecret);
    const callback = executionMessages(post).find(message => message.submitSuccessful);
    expect(callback!.data).toEqual(data);
    const returnUrl = new URL(callback!.url!);
    expect(returnUrl.origin + returnUrl.pathname).toBe(executionConfirm.return_url);
    expect(returnUrl.searchParams.get("status")).toBe("succeeded");
    expect(returnUrl.searchParams.get("payment_id")).toBe(data.payment_id);
    expect(returnUrl.searchParams.get("payment_intent_client_secret")).toBe(auth ? null : executionSecret);
    expect(fixture.store.get(Atoms.isManualRetryEnabled)).toBe(false);
  });
  it("maps declined checkout to host error and intent callback", async () => {
    vi.useFakeTimers();
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse({
      error: {
        type: "card_error",
        message: "Checkout declined"
      }
    }, 402)));
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const fixture = executionCheckout({
      auth: executionAuth
    });
    fixture.submit();
    await executionFlush();
    const error = {
      type: "card_error",
      message: "Checkout declined"
    };
    expect(executionMessages(post)).toContainEqual(expect.objectContaining({
      submitSuccessful: false,
      error
    }));
    expect(fixture.callback).toHaveBeenCalledExactlyOnceWith({
      error
    });
    expect(fixture.store.get(Atoms.isManualRetryEnabled)).toBe(false);
  });
  it("updates real manual-retry atom and sends retry action on failed checkout", async () => {
    vi.useFakeTimers();
    const data = {
      status: "failed",
      manual_retry_allowed: true
    };
    const fetch = vi.fn().mockResolvedValue(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const fixture = executionCheckout();
    fixture.submit(true);
    await executionFlush();
    expect((parseJson(fetch.mock.calls[0][1].body) as { retry_action?: string }).retry_action).toBe("manual_retry");
    expect(fixture.store.get(Atoms.isManualRetryEnabled)).toBe(true);
    expect(executionMessages(post)).toContainEqual(expect.objectContaining({
      data
    }));
  });
  it.each([[{
    list: "Loading"
  }, "payment_methods_loading", "Please wait. Try again!"], [{
    list: {
      TAG: "Loaded",
      _0: {
        payment_methods_enabled: []
      }
    }
  }, "payment_methods_empty", "Payment Failed. Try again!"], [{
    secret: undefined
  }, "confirm_payment_failed", "Payment failed. Try again!"]])("reports checkout prerequisites without fetching: %j", (options, type, message) => {
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const fixture = executionCheckout(options);
    fixture.submit();
    expect(fetch).not.toHaveBeenCalled();
    expect(executionMessages(post)).toContainEqual(expect.objectContaining({
      submitSuccessful: false,
      error: {
        type,
        message
      }
    }));
  });
  it("confirms from semiloaded checkout without inventing a payment type", async () => {
    vi.useFakeTimers();
    const fetch = vi.fn().mockResolvedValue(executionResponse({
      status: "processing"
    }));
    vi.stubGlobal("fetch", fetch);
    const fixture = executionCheckout({
      list: "SemiLoaded"
    });
    fixture.submit();
    await executionFlush();
    expect(parseJson(fetch.mock.calls[0][1].body)).not.toHaveProperty("payment_type");
    expect(fixture.callback).toHaveBeenCalledExactlyOnceWith({
      status: "processing"
    });
  });
});
async function executionThreeDsHandoff(options: { method?: boolean; auth?: string } = {}) {
  const method = options.method ?? true;
  const auth = "auth" in options ? options.auth : executionAuth;
  vi.useFakeTimers();
  const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
  const submit = vi.spyOn(HTMLFormElement.prototype, "submit").mockImplementation(() => {});
  const fetch = vi.fn().mockResolvedValueOnce(executionResponse({
    status: "requires_customer_action",
    next_action: {
      type: "three_ds_invoke",
      three_ds_data: {
        three_ds_authorize_url: "https://acs.test/authorize",
        three_ds_method_details: {
          three_ds_method_data_submission: method,
          consume_post_message_for_three_ds_method_completion: true,
          three_ds_method_url: "https://method.test/collect",
          three_ds_method_data: "method_execution_data",
          three_ds_method_key: "threeDSMethodData"
        }
      }
    }
  }));
  vi.stubGlobal("fetch", fetch);
  const checkout = executionCheckout({
    auth
  });
  checkout.submit();
  await executionFlush();
  const handoff = executionMessages(post).find(message => message.param === (method ? "3ds" : "3dsAuth"));
  expect(handoff).toMatchObject({
    fullscreen: true,
    iframeId: "execution-checkout",
    metadata: {
      paymentIntentId: executionSecret,
      sdkAuthorization: auth || "",
      publishableKey: "pk_execution",
      iframeId: "execution-checkout"
    }
  });
  return {
    checkout,
    post,
    submit,
    fetch,
    handoff
  };
}
describe("three_ds_invoke method and authorization contract", () => {
  it.each([undefined, executionAuth])("hands method completion to actual authentication component: %s", async auth => {
    const fixture = await executionThreeDsHandoff({
      auth
    });
    const remove = vi.spyOn(window, "removeEventListener");
    const timeout = vi.spyOn(globalThis, "setTimeout");
    const clearTimeout = vi.spyOn(globalThis, "clearTimeout");
    const methodView = renderWithSdk(<ThreeDSMethod />);
    executionWindowMessage({
      fullScreenIframeMounted: true,
      metadata: fixture.handoff!.metadata
    });
    const form = document.querySelector("#threeDsHiddenPostMethod")!;
    expect(form).toHaveAttribute("action", "https://method.test/collect");
    expect(form).toHaveAttribute("target", "threeDsInvisibleIframe");
    expect(form.querySelector("input")).toHaveValue("method_execution_data");
    expect(fixture.submit).toHaveBeenCalledOnce();
    executionWindowMessage({}, "https://unrelated.test");
    expect(executionMessages(fixture.post).filter(message => message.param === "3dsAuth")).toHaveLength(0);
    executionWindowMessage({}, "https://method.test");
    const completion = executionMessages(fixture.post).find(message => message.param === "3dsAuth");
    expect(completion!.metadata!["3dsMethodComp"]).toBe("Y");
    executionWindowMessage({}, "https://method.test");
    expect(executionMessages(fixture.post).filter(message => message.param === "3dsAuth")).toHaveLength(1);
    const timeoutIndex = timeout.mock.calls.findIndex(([, delay]) => delay === 15000);
    expect(timeoutIndex).toBeGreaterThanOrEqual(0);
    const methodTimeout = timeout.mock.results[timeoutIndex].value;
    methodView.unmount();
    expect(clearTimeout).toHaveBeenCalledWith(methodTimeout);
    expect(remove).toHaveBeenCalledWith("message", expect.any(Function));
    fixture.fetch.mockResolvedValueOnce(executionResponse({
      trans_status: "Y"
    }));
    const interval = vi.spyOn(globalThis, "setInterval");
    const clearInterval = vi.spyOn(globalThis, "clearInterval");
    const authView = renderWithSdk(<ThreeDSAuth />);
    executionWindowMessage({
      fullScreenIframeMounted: true,
      metadata: completion!.metadata
    });
    await executionFlush();
    const [url, request] = fixture.fetch.mock.calls[1];
    expect(url).toBe(`https://api.sdk.test/payments/${auth ? "pay_authorized" : "pay_execution"}/3ds/authentication`);
    expect(parseJson(request.body)).toMatchObject({
      device_channel: "BRW",
      threeds_method_comp_ind: "Y"
    });
    expect((parseJson(request.body) as { client_secret?: string }).client_secret).toBe(auth ? undefined : executionSecret);
    expect(request.headers.get(auth ? "Authorization" : "api-key")).toBe(auth || "pk_execution");
    expect(document.getElementById("3dsFrictionLess")).toHaveAttribute("action", "https://acs.test/authorize");
    expect(fixture.submit).toHaveBeenCalledTimes(2);
    authView.unmount();
    expect(clearInterval).toHaveBeenCalledWith(interval.mock.results[0].value);
    executionWindowMessage({
      fullScreenIframeMounted: true,
      metadata: completion!.metadata
    });
    await executionFlush();
    expect(fixture.fetch).toHaveBeenCalledTimes(2);
  });
  it("skips method collection with U and constructs the actual challenge form", async () => {
    const fixture = await executionThreeDsHandoff({
      method: false
    });
    expect(fixture.handoff!.metadata!["3dsMethodComp"]).toBe("U");
    fixture.fetch.mockResolvedValueOnce(executionResponse({
      trans_status: "C",
      acs_url: "https://acs.test/challenge",
      challenge_request: "execution_creq",
      challenge_request_key: "custom_creq"
    }));
    const authView = renderWithSdk(<ThreeDSAuth />);
    executionWindowMessage({
      fullScreenIframeMounted: true,
      metadata: fixture.handoff!.metadata
    });
    await executionFlush();
    const form = document.getElementById("3dsChallenge")!;
    expect(form).toHaveAttribute("action", "https://acs.test/challenge");
    expect(form).toHaveAttribute("target", "threeDsAuthFrame");
    expect(form.querySelector("input")).toHaveAttribute("name", "custom_creq");
    expect(form.querySelector("input")).toHaveValue("execution_creq");
    expect((parseJson(fixture.fetch.mock.calls[1][1].body) as { threeds_method_comp_ind?: string }).threeds_method_comp_ind).toBe("U");
    await act(() => vi.advanceTimersByTimeAsync(600000));
    expect(document.getElementById("3dsFrictionLess")).toHaveAttribute("action", "https://acs.test/authorize");
    expect(fixture.submit).toHaveBeenCalledTimes(2);
    authView.unmount();
    expect(document.querySelector("#threeDsAuthFrame")).toBeNull();
  });
  it("reports method timeout as N once and removes message handling on unmount", async () => {
    const fixture = await executionThreeDsHandoff();
    const methodView = renderWithSdk(<ThreeDSMethod />);
    executionWindowMessage({
      fullScreenIframeMounted: true,
      metadata: fixture.handoff!.metadata
    });
    await act(() => vi.advanceTimersByTimeAsync(15000));
    const completions = executionMessages(fixture.post).filter(message => message.param === "3dsAuth");
    expect(completions).toHaveLength(1);
    expect(completions[0].metadata!["3dsMethodComp"]).toBe("N");
    methodView.unmount();
    executionWindowMessage({}, "https://method.test");
    expect(executionMessages(fixture.post).filter(message => message.param === "3dsAuth")).toHaveLength(1);
  });
  it("ignores malformed mount messages and removes listeners before late requests", async () => {
    const fixture = await executionThreeDsHandoff({
      method: false
    });
    const view = renderWithSdk(<ThreeDSAuth />);
    act(() => window.dispatchEvent(new MessageEvent("message", {
      data: "{malformed"
    })));
    await executionFlush();
    expect(fixture.fetch).toHaveBeenCalledOnce();
    view.unmount();
    executionWindowMessage({
      fullScreenIframeMounted: true,
      metadata: fixture.handoff!.metadata
    });
    await executionFlush();
    expect(fixture.fetch).toHaveBeenCalledOnce();
  });
  it.each(["network", "malformed", "returned-error", "http"])("returns authentication %s failure without submitting challenge", async failure => {
    const fixture = await executionThreeDsHandoff({
      method: false
    });
    vi.spyOn(console, "error").mockImplementation(() => {});
    if (failure === "network") {
      fixture.fetch.mockRejectedValueOnce(new Error("execution authentication offline"));
    } else if (failure === "malformed") {
      fixture.fetch.mockResolvedValueOnce({
        ...executionResponse({}),
        json: vi.fn().mockRejectedValue(new SyntaxError("execution authentication malformed JSON"))
      });
    } else {
      fixture.fetch.mockResolvedValueOnce(executionResponse({
        error: {
          type: "authentication_error",
          message: "Authentication denied"
        }
      }, failure === "http" ? 402 : 200));
    }
    const view = renderWithSdk(<ThreeDSAuth />);
    executionWindowMessage({
      fullScreenIframeMounted: true,
      metadata: fixture.handoff!.metadata
    });
    await executionFlush();
    expect(executionMessages(fixture.post)).toContainEqual(expect.objectContaining({
      submitSuccessful: false,
      error: {
        type: failure === "network" || failure === "malformed" ? "server_error" : "authentication_error",
        message: failure === "network" || failure === "malformed" ? "Something went wrong" : "Authentication denied"
      }
    }));
    expect(fixture.submit).not.toHaveBeenCalled();
    expect(executionMessages(fixture.post).filter(message => message.submitSuccessful === false)).toHaveLength(1);
    await act(() => vi.advanceTimersByTimeAsync(600000));
    expect(fixture.submit).not.toHaveBeenCalled();
    expect(executionMessages(fixture.post).filter(message => message.submitSuccessful === false)).toHaveLength(1);
    view.unmount();
  });
});
