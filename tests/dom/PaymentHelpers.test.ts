import { parseJson } from "../helpers/json";
import { describe, expect, it, vi } from "vitest";
import * as Payment from "../../src/Utilities/PaymentHelpers.bs.js";
import * as Utils from "../../src/Utilities/Utils.bs.js";
import { executionAuth, executionConfirm, executionLogger, executionResponse, executionSecret } from "../helpers/execution-fixtures";

// Vite does not expose this vendored UMD module's CommonJS named export.
// Adapt its module shape while retaining the actual UA parser and BrowserSpec.
vi.mock("../../src/libraries/ua-parser-js/ua-parser.js", async () => {
  const {
    createRequire
  } = await import("node:module");
  const require = createRequire(import.meta.url);
  return {
    UAParser: require("../../src/libraries/ua-parser-js/ua-parser.js").UAParser
  };
});
function executionIntent({
  counter = 0,
  session = true,
  auth,
  paymentType = "Card",
  mode,
  logger = executionLogger(),
  retry = vi.fn(),
  uri = "https://api.sdk.test/payments/pay_execution/confirm"
}: { counter?: number; session?: boolean; auth?: string; paymentType?: string; mode?: string; logger?: ReturnType<typeof executionLogger>; retry?: ReturnType<typeof vi.fn>; uri?: string } = {}) {
  return Payment.intentCall(Utils.fetchApi, uri, auth ? [["Authorization", auth]] : [["api-key", "pk_execution"]], '{"payment_method_type":"credit"}', executionConfirm, executionSecret, logger, false, paymentType, "execution-frame", "POST", retry, "pod_execution", false, counter, session, undefined, undefined, {}, auth, mode);
}
function executionSubmit(auth: string | undefined) {
  return Payment.paymentIntentForPaymentSession([["payment_method", "card"], ["payment_token", "token_execution"]], "Card", {
    confirmParams: executionConfirm
  }, "pk_execution", executionSecret, executionLogger(), "pod_execution", {}, true, auth);
}
describe("payment confirmation and recovery through real fetch", () => {
  it.each([undefined, executionAuth, ""])("constructs confirm auth/body and returns succeeded payment: %s", async auth => {
    const data = {
      status: "succeeded",
      payment_id: "pay_execution"
    };
    const fetch = vi.fn().mockResolvedValue(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    expect(await executionSubmit(auth)).toEqual(data);
    const [url, request] = fetch.mock.calls[0];
    expect(url).toBe(`https://api.sdk.test/payments/${auth ? "pay_authorized" : "pay_execution"}/confirm`);
    expect(request.method).toBe("POST");
    expect(request.headers.get("x-feature")).toBe("pod_execution");
    expect(request.headers.get("Content-Type")).toBe("application/json");
    expect(parseJson(request.body)).toMatchObject({
      payment_method: "card",
      payment_token: "token_execution",
      return_url: executionConfirm.return_url
    });
    if (auth) {
      expect(request.headers.get("Authorization")).toBe(auth);
      expect(request.headers.has("api-key")).toBe(false);
      expect(parseJson(request.body)).not.toHaveProperty("client_secret");
    } else {
      expect(request.headers.get("api-key")).toBe("pk_execution");
      expect((parseJson(request.body) as { client_secret?: string }).client_secret).toBe(executionSecret);
    }
  });
  it.each(["processing", "failed"])("returns %s status and updates manual retry only for failed", async status => {
    const retry = vi.fn();
    const data = {
      status,
      manual_retry_allowed: true
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(data)));
    expect(await executionIntent({
      retry
    })).toEqual(data);
    expect(retry).toHaveBeenCalledTimes(status === "failed" ? 1 : 0);
    if (status === "failed") {
      expect(retry.mock.calls[0][0](false)).toBe(true);
    }
  });
  it.each([undefined, executionAuth])("posts processing callback with correct redirect metadata: %s", async auth => {
    const data = {
      status: "processing"
    };
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(data)));
    expect(await executionIntent({
      session: false,
      auth
    })).toEqual(data);
    const callback = post.mock.calls.map(([message]) => message).find(message => message.submitSuccessful);
    expect(callback.data).toEqual(data);
    const url = new URL(callback.url);
    expect(url.searchParams.get("status")).toBe("processing");
    expect(url.searchParams.get("payment_id")).toBe(auth ? "pay_authorized" : "pay_execution");
    expect(url.searchParams.get("payment_intent_client_secret")).toBe(auth ? null : executionSecret);
  });
  it("returns CVC element result and return URL for external payment types", async () => {
    const data = {
      status: "succeeded"
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(data)));
    const result = await executionIntent({
      paymentType: "Other",
      mode: "CardCVCElement",
      auth: executionAuth
    });
    expect(result.data).toEqual(data);
    expect(new URL(result.returnUrl).searchParams.get("status")).toBe("succeeded");
    expect(new URL(result.returnUrl).searchParams.has("payment_intent_client_secret")).toBe(false);
  });
  it("maps declined HTTP response and posts failed-submit callback", async () => {
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const error = {
      error: {
        type: "card_error",
        message: "Card declined",
        code: "declined"
      }
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(error, 402)));
    expect(await executionIntent({
      session: false
    })).toEqual({
      error: {
        type: "card_error",
        message: "Card declined"
      }
    });
    expect(post.mock.calls.map(([data]) => data)).toContainEqual(expect.objectContaining({
      submitSuccessful: false,
      error: {
        type: "card_error",
        message: "Card declined"
      }
    }));
  });
  it.each(["network", "malformed"])("recovers from %s confirmation by retrieving payment", async failure => {
    const fetch = vi.fn();
    if (failure === "network") {
      fetch.mockRejectedValueOnce(new Error("execution offline"));
    } else {
      fetch.mockResolvedValueOnce({
        ...executionResponse({}, 500),
        json: vi.fn().mockRejectedValue(new SyntaxError("execution json"))
      });
    }
    fetch.mockResolvedValueOnce(executionResponse({
      status: "processing"
    }));
    vi.stubGlobal("fetch", fetch);
    expect(await executionIntent()).toEqual({
      status: "processing"
    });
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(fetch.mock.calls[1][0]).toBe(`https://api.sdk.test/payments/pay_execution?client_secret=${executionSecret}`);
    expect(fetch.mock.calls[1][1]).toMatchObject({
      method: "GET",
      body: undefined
    });
  });
  it("recovery uses SDK auth payment id without leaking legacy secret", async () => {
    const fetch = vi.fn().mockRejectedValueOnce(new Error("offline")).mockResolvedValueOnce(executionResponse({
      status: "processing"
    }));
    vi.stubGlobal("fetch", fetch);
    expect(await executionIntent({
      auth: executionAuth
    })).toEqual({
      status: "processing"
    });
    expect(fetch.mock.calls[1][0]).toBe("https://api.sdk.test/payments/pay_authorized");
    expect(fetch.mock.calls[1][1].headers.get("Authorization")).toBe(executionAuth);
  });
  it("preserves payment-session completion during malformed HTTP recovery", async () => {
    vi.useFakeTimers();
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const data = {
      status: "succeeded"
    };
    const fetch = vi.fn().mockResolvedValueOnce({
      ...executionResponse({}, 500),
      json: vi.fn().mockRejectedValue(new SyntaxError("malformed HTTP response"))
    }).mockResolvedValueOnce(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    const result = executionIntent();
    const boundedResult = Promise.race([result, new Promise(resolve => setTimeout(() => resolve("execution did not settle"), 1))]);
    await vi.advanceTimersByTimeAsync(1);
    expect(await boundedResult).toEqual(data);
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(post.mock.calls.map(([message]) => message).filter(message => message.submitSuccessful !== undefined || message.openurl !== undefined)).toEqual([]);
  });
  it("bounds network retries and returns server error after six attempts", async () => {
    const fetch = vi.fn().mockRejectedValue(new Error("execution offline"));
    vi.stubGlobal("fetch", fetch);
    expect(await executionIntent()).toEqual({
      error: {
        type: "server_error",
        message: "Something went wrong"
      }
    });
    expect(fetch).toHaveBeenCalledTimes(6);
  });
  it.each([200, 503])("handles malformed response at terminal retry (%s)", async status => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({
      ...executionResponse({}, status),
      json: vi.fn().mockRejectedValue(new SyntaxError("execution malformed"))
    }));
    expect(await executionIntent({
      counter: 5
    })).toEqual({
      error: {
        type: "server_error",
        message: "Something went wrong"
      }
    });
  });
  it("rejects unsupported next action with a concrete failure", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse({
      status: "requires_customer_action",
      next_action: {
        type: "unsupported"
      }
    })));
    expect(await executionIntent()).toEqual({
      error: {
        type: "confirm_payment_failed",
        message: "Payment failed. Try again!"
      }
    });
  });
  it("returns QR next-action data and posts merchant display metadata", async () => {
    const data = {
      status: "requires_customer_action",
      payment_method_type: "upi",
      next_action: {
        type: "qr_code_information",
        image_data_url: "data:image/png;base64,execution",
        raw_qr_data: "upi://execution",
        display_text: "Scan to pay",
        border_color: "#fff",
        display_to_timestamp: 123
      }
    };
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(data)));
    expect(await executionIntent({
      session: false,
      auth: executionAuth
    })).toEqual(data);
    const message = post.mock.calls.map(([value]) => value).find(value => value.param === "qrData");
    expect(message).toMatchObject({
      fullscreen: true,
      iframeId: "execution-frame",
      metadata: {
        qrData: data.next_action.image_data_url,
        rawQrData: "upi://execution",
        sdkAuthorization: executionAuth,
        publishableKey: "pk_execution",
        expiryTime: "123",
        display_text: "Scan to pay",
        border_color: "#fff"
      }
    });
  });
  it("returns bank-transfer instructions and posts copied instruction metadata", async () => {
    const data = {
      status: "requires_customer_action",
      payment_method_type: "ach",
      next_action: {
        type: "display_bank_transfer_information",
        bank_transfer_steps_and_charges_details: {
          account: "execution_account"
        }
      }
    };
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(data)));
    expect(await executionIntent({
      session: false
    })).toEqual(data);
    expect(post.mock.calls.map(([value]) => value)).toContainEqual(expect.objectContaining({
      param: "achBankTransfer",
      metadata: expect.objectContaining({
        account: "execution_account",
        data
      })
    }));
    expect(data.next_action.bank_transfer_steps_and_charges_details).toEqual({
      account: "execution_account"
    });
  });
  it.each(["requires_customer_action", "processing"])("returns wallet SDK handoff from %s and posts token to parent", async status => {
    const token = {
      wallet_name: "google_pay",
      session_token_data: {
        token: "execution_wallet_token"
      }
    };
    const data = {
      status,
      next_action: {
        type: "third_party_sdk_session_token",
        session_token: token
      }
    };
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(data)));
    expect(await executionIntent({
      session: false
    })).toEqual(data);
    expect(post).toHaveBeenCalledWith({
      googlePayThirdPartyFlow: token
    }, "*");
  });
  it("returns external SDK invocation data", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse({
      status: "requires_payment_method",
      connector_transaction_id: "order_execution",
      next_action: {
        type: "invoke_sdk_client",
        next_action_data: {
          challenge: "execution"
        }
      }
    })));
    expect(await executionIntent()).toEqual({
      orderId: "order_execution",
      nextActionData: {
        challenge: "execution"
      }
    });
  });
  it("handles DDC next-action completion and cleans its browser boundary", async () => {
    vi.useFakeTimers();
    vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const data = {
      status: "requires_customer_action",
      next_action: {
        type: "invoke_ddc",
        ddc_data: {
          iframe_url: "https://ddc.test/execution",
          timeout_ms: 1000
        }
      }
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(data)));
    const result = executionIntent();
    await vi.advanceTimersByTimeAsync(0);
    expect(document.querySelector("#ddc-iframe")).toHaveAttribute("src", "https://ddc.test/execution");
    window.dispatchEvent(new MessageEvent("message", {
      data: {
        next_action: {
          type: "redirect_to_url",
          url: "https://merchant.test/complete",
          redirect_mode: "if_required"
        }
      }
    }));
    expect(await result).toEqual(data);
    expect(document.querySelector("#ddc-iframe")).toBeNull();
    expect(vi.getTimerCount()).toBe(0);
  });
  it("returns empty-confirmation failure for malformed successful data", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(null)));
    expect(await executionIntent()).toEqual({
      error: {
        type: "confirm_payment_failed",
        message: "Payment failed. Try again!"
      }
    });
  });
});
describe("payment retrieval, eligibility, polling, and masking", () => {
  it.each([undefined, executionAuth])("constructs wallet sessions with auth credential omission: %s", async auth => {
    const data = {
      session_token: [{
        wallet_name: "google_pay",
        token: "execution_wallet"
      }]
    };
    const fetch = vi.fn().mockResolvedValue(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    expect(await Payment.fetchSessions(executionSecret, "pk_execution", ["google_pay"], true, executionLogger(), "pod_execution", "https://sessions.test", true, "merchant.test", auth)).toEqual(data);
    const [url, request] = fetch.mock.calls[0];
    expect(url).toBe("https://sessions.test/payments/session_tokens");
    expect(request.method).toBe("POST");
    expect(request.headers.get("X-Merchant-Domain")).toBe("merchant.test");
    expect(request.headers.get("x-feature")).toBe("pod_execution");
    expect(request.headers.get(auth ? "Authorization" : "api-key")).toBe(auth || "pk_execution");
    expect(request.headers.has(auth ? "api-key" : "Authorization")).toBe(false);
    const body = parseJson(request.body) as { client_secret?: string };
    expect(body).toMatchObject({
      payment_id: auth ? "pay_authorized" : "pay_execution",
      wallets: ["google_pay"],
      delayed_session_token: true
    });
    expect(body.client_secret).toBe(auth ? undefined : executionSecret);
  });
  it.each(["http", "network", "malformed"])("maps wallet sessions %s failure to null", async failure => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    if (failure === "network") {
      fetch.mockRejectedValue(new Error("execution sessions offline"));
    } else if (failure === "malformed") {
      fetch.mockResolvedValue({
        ...executionResponse({}),
        json: vi.fn().mockRejectedValue(new SyntaxError("execution sessions JSON"))
      });
    } else {
      fetch.mockResolvedValue(executionResponse({
        error: {
          message: "Sessions unavailable"
        }
      }, 503));
    }
    expect(await Payment.fetchSessions(executionSecret, "pk_execution", undefined, undefined, executionLogger(), undefined, "https://sessions.test", undefined, "merchant.test", executionAuth)).toBeNull();
    expect(fetch).toHaveBeenCalledOnce();
  });
  it.each([undefined, executionAuth])("posts real 3DS authentication browser data: %s", async auth => {
    const data = {
      status: "authenticated"
    };
    const fetch = vi.fn().mockResolvedValue(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    expect(await Payment.threeDsAuth(executionSecret, executionLogger(), "Y", {
      "x-execution": "fixture"
    }, auth)).toEqual(data);
    const [url, request] = fetch.mock.calls[0];
    expect(url).toBe(`https://api.sdk.test/payments/${auth ? "pay_authorized" : "pay_execution"}/3ds/authentication`);
    expect(parseJson(request.body)).toMatchObject({
      device_channel: "BRW",
      threeds_method_comp_ind: "Y",
      browser_info: {
        user_agent: navigator.userAgent,
        java_script_enabled: true
      }
    });
    expect(request.headers.get("x-execution")).toBe("fixture");
    if (auth) {
      expect(parseJson(request.body)).not.toHaveProperty("client_secret");
    } else {
      expect((parseJson(request.body) as { client_secret?: string }).client_secret).toBe(executionSecret);
    }
  });
  it("maps 3DS HTTP failure to merchant error and closes loader", async () => {
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse({
      error: {
        type: "authentication_error",
        message: "Challenge failed"
      }
    }, 400)));
    expect(await Payment.threeDsAuth(executionSecret, executionLogger(), "N", {})).toBeNull();
    expect(post.mock.calls.map(([data]) => data)).toContainEqual(expect.objectContaining({
      submitSuccessful: false,
      error: {
        type: "authentication_error",
        message: "Challenge failed"
      }
    }));
  });
  it("rejects network 3DS failure after closing loader", async () => {
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    vi.spyOn(console, "error").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("execution offline")));
    await expect(Payment.threeDsAuth(executionSecret, executionLogger(), "U", {})).rejects.toThrow("execution offline");
    expect(post.mock.calls.map(([data]) => data)).toContainEqual({
      fullscreen: false
    });
  });
  it.each([undefined, executionAuth])("constructs eligibility body, auth, abort signal: %s", async auth => {
    const data = {
      sdk_next_action: {
        next_action: "deny"
      }
    };
    const fetch = vi.fn().mockResolvedValue(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    const signal = new AbortController().signal;
    expect(await Payment.fetchPaymentMethodEligibility(executionSecret, "pk_execution", executionLogger(), "pod_execution", [["payment_method", "card"]], auth, "https://eligibility.test", signal)).toEqual(data);
    const [url, request] = fetch.mock.calls[0];
    expect(url).toBe(`https://eligibility.test/payments/${auth ? "pay_authorized" : "pay_execution"}/eligibility`);
    expect(request.signal).toBe(signal);
    expect(request.method).toBe("POST");
    expect(parseJson(request.body)).toEqual(auth ? {
      payment_method: "card"
    } : {
      payment_method: "card",
      client_secret: executionSecret
    });
    expect(request.headers.get(auth ? "Authorization" : "api-key")).toBe(auth || "pk_execution");
  });
  it.each([402, "network", "malformed"] as const)("returns null on eligibility failure: %s", async failure => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    if (failure === "network") {
      fetch.mockRejectedValue(new Error("offline"));
    } else if (failure === "malformed") {
      fetch.mockResolvedValue({
        ...executionResponse({}),
        json: vi.fn().mockRejectedValue(new SyntaxError("bad json"))
      });
    } else {
      fetch.mockResolvedValue(executionResponse({
        error: {
          message: "declined"
        }
      }, failure));
    }
    expect(await Payment.fetchPaymentMethodEligibility(executionSecret, "pk_execution", executionLogger(), "", [], undefined, "https://eligibility.test")).toBeNull();
  });
  it.each(["succeeded", "failed"])("polls processing to terminal %s after 2 seconds", async status => {
    vi.useFakeTimers();
    const fetch = vi.fn().mockResolvedValueOnce(executionResponse({
      status: "processing"
    })).mockResolvedValueOnce(executionResponse({
      status
    }));
    vi.stubGlobal("fetch", fetch);
    const promise = Payment.pollRetrievePaymentIntent(executionSecret, {}, "pk_execution", executionLogger(), "pod_execution", true);
    await vi.advanceTimersByTimeAsync(1999);
    expect(fetch).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(1);
    expect(await promise).toEqual({
      status
    });
    expect(fetch.mock.calls[1][0]).toContain("force_sync=true");
    expect(vi.getTimerCount()).toBe(0);
  });
  it("polls status to completed with supplied interval and SDK auth", async () => {
    vi.useFakeTimers();
    const data = {
      status: "completed",
      payment_id: "pay_execution"
    };
    const fetch = vi.fn().mockResolvedValueOnce(executionResponse({
      status: "pending"
    })).mockResolvedValueOnce(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    const promise = Payment.pollStatus("pk_execution", "pod_execution", "poll_execution", 250, 2, executionConfirm.return_url, executionLogger(), executionAuth);
    await vi.advanceTimersByTimeAsync(249);
    expect(fetch).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(1);
    expect(await promise).toEqual(data);
    expect(fetch.mock.calls[1][0]).toBe("https://api.sdk.test/poll/status/poll_execution");
    expect(fetch.mock.calls[1][1].method).toBe("GET");
    expect(fetch.mock.calls[1][1].headers.get("Authorization")).toBe(executionAuth);
    expect(vi.getTimerCount()).toBe(0);
  });
  it("redirects on poll exhaustion and stops scheduling requests", async () => {
    vi.useFakeTimers();
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const fetch = vi.fn().mockResolvedValue(executionResponse({
      status: "pending"
    }));
    vi.stubGlobal("fetch", fetch);
    // Navigation owns completion in this branch; pollStatus intentionally leaves
    // its promise pending after posting the redirect to the parent window.
    void Payment.pollStatus("pk_execution", "", "poll_execution", 250, 1, executionConfirm.return_url, executionLogger(), undefined);
    await vi.advanceTimersByTimeAsync(250);
    expect(fetch).toHaveBeenCalledTimes(2);
    expect(post).toHaveBeenCalledWith({
      openurl: executionConfirm.return_url
    }, "*");
    expect(post).toHaveBeenCalledWith({
      fullscreen: false
    }, "*");
    expect(vi.getTimerCount()).toBe(0);
    await vi.advanceTimersByTimeAsync(5000);
    expect(fetch).toHaveBeenCalledTimes(2);
  });
  it("recursively masks sensitive strings/numbers while retaining structure", () => {
    const payload = {
      card_number: "4111 1111",
      cvc: 123,
      nested: [{
        token: "sensitive"
      }, null, true, false]
    };
    expect(Payment.maskPayload(payload)).toEqual({
      card_number: "xxxx xxxx",
      cvc: "xxx",
      nested: [{
        token: "xxxxxxxxx"
      }, "null", "true", "false"]
    });
    expect(payload.card_number).toBe("4111 1111");
  });
});
