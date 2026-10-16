import { parseJson } from "../helpers/json";
import type { FixtureLoadable } from "../helpers/sdk-atoms";
import { sdkKeysAtom, sdkPaymentManagementListAtom } from "../helpers/sdk-atoms";
import { describe, expect, it, vi } from "vitest";
import * as Management from "../../src/Utilities/PaymentHelpersV2.bs.js";
import * as Utils from "../../src/Utilities/Utils.bs.js";
import { executionAuth, executionConfirm, executionLogger, executionResponse } from "../helpers/execution-fixtures";
import React from "react";
import { initialValue, act, renderWithSdk } from "../helpers/render";
import { customPodUri } from "../../src/Utilities/JotaiAtoms.bs.js";
import { defaultkeys } from "../../src/Hooks/CommonHooks.bs.js";
vi.mock("../../src/libraries/ua-parser-js/ua-parser.js", async () => {
  const {
    createRequire
  } = await import("node:module");
  const require = createRequire(import.meta.url);
  return {
    UAParser: require("../../src/libraries/ua-parser-js/ua-parser.js").UAParser
  };
});
const body = [["payment_method_token", "token_execution"]];
const cases = [{
  name: "save",
  method: "POST",
  path: "/confirm",
  call: (logger: ReturnType<typeof executionLogger>) => Management.savePaymentMethod(body, "pms_execution", executionAuth, logger)
}, {
  name: "update",
  method: "PUT",
  path: "/update-saved-payment-method",
  call: (logger: ReturnType<typeof executionLogger>) => Management.updatePaymentMethod(body, "pms_execution", logger, "pod_execution", executionAuth)
}, {
  name: "delete",
  method: "DELETE",
  path: "",
  call: (logger: ReturnType<typeof executionLogger>) => Management.deletePaymentMethodV2("token_execution", "pms_execution", logger, "pod_execution", executionAuth)
}, {
  name: "retrieve",
  method: "GET",
  path: "",
  call: (logger: ReturnType<typeof executionLogger>) => Management.retrievePaymentMethodSession("pms_execution", "https://api.sdk.test", "pod_execution", executionAuth, logger)
}, {
  name: "list",
  method: "GET",
  path: "/list-payment-methods",
  call: (logger: ReturnType<typeof executionLogger>) => Management.fetchPaymentManagementList("pms_execution", "https://api.sdk.test", logger, "pod_execution", executionAuth)
}];
describe("V2 management requests", () => {
  it.each(cases)("constructs $name request and returns API success", async ({
    name,
    method,
    path,
    call
  }) => {
    const data = {
      payment_method_id: "pm_execution",
      status: "active"
    };
    const fetch = vi.fn().mockResolvedValue(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    expect(await call(executionLogger())).toEqual(data);
    const [url, request] = fetch.mock.calls[0];
    expect(url).toBe(`https://api.sdk.test/v1/payment-method-sessions/pms_execution${path}`);
    expect(request.method).toBe(method);
    expect(request.headers.get("Authorization")).toBe(executionAuth);
    if (name !== "save") {
      expect(request.headers.get("x-feature")).toBe("pod_execution");
    }
    if (method === "GET") {
      expect(request.body).toBeUndefined();
    } else {
      expect(parseJson(request.body)).toEqual({
        payment_method_token: "token_execution"
      });
    }
  });
  for (const failure of [403, "network", "malformed"] as const) {
    it.each(cases)(`returns null for $name ${failure} failure`, async ({
      call
    }) => {
      vi.spyOn(console, "error").mockImplementation(() => {});
      const fetch = vi.fn();
      vi.stubGlobal("fetch", fetch);
      if (failure === "network") {
        fetch.mockRejectedValue(new Error("execution offline"));
      } else if (failure === "malformed") {
        fetch.mockResolvedValue({
          ...executionResponse({}),
          json: vi.fn().mockRejectedValue(new SyntaxError("execution malformed"))
        });
      } else {
        fetch.mockResolvedValue(executionResponse({
          error: {
            message: "Not allowed"
          }
        }, failure));
      }
      expect(await call(executionLogger())).toBeNull();
      expect(fetch).toHaveBeenCalledOnce();
    });
  }
});
function executionManagementIntent() {
  return Management.intentCall(Utils.fetchApi, "https://api.sdk.test/v1/payment-method-sessions/pms_execution/confirm", [["Authorization", executionAuth]], JSON.stringify(Object.fromEntries(body)), executionConfirm, executionLogger(), false, "Card", "POST", "pod_execution", false, true, undefined, {});
}
describe("V2 confirmation result and failure mapping", () => {
  it.each(["succeeded", "failed", "processing", ""])("returns confirmation data for %s", async status => {
    const data = {
      authentication_details: {
        status
      }
    };
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse(data)));
    expect(await executionManagementIntent()).toEqual(data);
  });
  it.each(["http", "network", "malformed"])("returns a concrete error for %s failure", async failure => {
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    if (failure === "network") {
      fetch.mockRejectedValue(new Error("offline"));
    } else if (failure === "malformed") {
      fetch.mockResolvedValue({
        ...executionResponse({}, 500),
        json: vi.fn().mockRejectedValue(new SyntaxError("malformed"))
      });
    } else {
      fetch.mockResolvedValue(executionResponse({
        error: {
          type: "card_error",
          message: "Invalid card"
        }
      }, 402));
    }
    expect(await executionManagementIntent()).toEqual({
      error: {
        type: failure === "http" ? "card_error" : "server_error",
        message: failure === "http" ? "Invalid card" : "Something went wrong"
      }
    });
  });
  it("rejects unsupported customer action with explicit error", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(executionResponse({
      authentication_details: {
        status: "requires_customer_action"
      },
      next_action: {
        type: "unknown"
      }
    })));
    expect(await executionManagementIntent()).toEqual({
      error: {
        type: "confirm_payment_failed",
        message: "Payment failed. Try again!"
      }
    });
  });
});
const executionHookCases = [{
  name: "save",
  hook: Management.useSaveCard,
  method: "POST",
  path: "/confirm"
}, {
  name: "update",
  hook: Management.useUpdateCard,
  method: "PUT",
  path: "/update-saved-payment-method"
}];
function executionManagementHarness(hook: typeof Management.useSaveCard, options: { session?: string; list?: FixtureLoadable } = {}) {
  const session = "session" in options ? options.session : "pms_execution";
  const list = options.list ?? {
    TAG: "LoadedV2",
    _0: {}
  };
  let submit!: ReturnType<typeof Management.useSaveCard>;
  function Harness() {
    submit = hook(executionLogger(), "Card");
    return null;
  }
  const view = renderWithSdk(React.createElement(Harness), {
    initialValues: [initialValue(sdkKeysAtom, {
      ...defaultkeys,
      pmSessionId: session,
      sdkAuthorization: executionAuth
    }), initialValue(customPodUri, "pod_execution"), initialValue(sdkPaymentManagementListAtom, list)]
  });
  return {
    ...view,
    submit: () => act(() => submit(undefined, body, executionConfirm))
  };
}
describe("V2 card hook request and callback integration", () => {
  it.each(executionHookCases)("runs $name through loaded management state and success callback", async ({
    hook,
    method,
    path
  }) => {
    vi.useFakeTimers();
    const data = {
      authentication_details: {
        status: "succeeded"
      }
    };
    const fetch = vi.fn().mockResolvedValue(executionResponse(data));
    vi.stubGlobal("fetch", fetch);
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const fixture = executionManagementHarness(hook);
    fixture.submit();
    await act(() => vi.advanceTimersByTimeAsync(0));
    const [url, request] = fetch.mock.calls[0];
    expect(url).toBe(`https://api.sdk.test/v1/payment-method-sessions/pms_execution${path}`);
    expect(request.method).toBe(method);
    expect(request.headers.get("Authorization")).toBe(executionAuth);
    expect(request.headers.get("x-feature")).toBe("pod_execution");
    expect(parseJson(request.body)).toMatchObject({
      payment_method_token: "token_execution",
      return_url: executionConfirm.return_url,
      browser_info: {
        user_agent: navigator.userAgent
      }
    });
    expect(post.mock.calls.map(([message]) => message)).toContainEqual(expect.objectContaining({
      submitSuccessful: true,
      data
    }));
  });
  it.each(executionHookCases)("reports missing session for $name without fetching", async ({
    hook
  }) => {
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    const post = vi.spyOn(window, "postMessage").mockImplementation(() => {});
    const fixture = executionManagementHarness(hook, {
      session: undefined
    });
    fixture.submit();
    expect(fetch).not.toHaveBeenCalled();
    expect(post.mock.calls.map(([message]) => message)).toContainEqual(expect.objectContaining({
      submitSuccessful: false,
      error: {
        type: "confirm_payment_failed",
        message: "Payment failed. Try again!"
      }
    }));
  });
  it.each(executionHookCases)("gates $name while management list is loading", ({
    hook
  }) => {
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    const fixture = executionManagementHarness(hook, {
      list: "LoadingV2"
    });
    fixture.submit();
    expect(fetch).not.toHaveBeenCalled();
  });
});
