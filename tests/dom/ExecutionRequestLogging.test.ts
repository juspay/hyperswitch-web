import { describe, expect, it, vi } from "vitest";
import { fetchApiWithLogging } from "../../src/Utilities/Utils.bs.js";
import { executionAuth, executionLogger, executionResponse } from "../helpers/execution-fixtures";
describe("fetchApiWithLogging boundary", () => {
  it.each([200, 403])("routes parsed response to the matching callback and logs status %s", async status => {
    const data = status === 200 ? {
      status: "succeeded"
    } : {
      error: {
        type: "card_error",
        message: "Declined"
      }
    };
    const logger = executionLogger();
    const success = vi.fn(value => ({
      success: value
    }));
    const failure = vi.fn(value => ({
      failure: value
    }));
    const fetch = vi.fn().mockResolvedValue(executionResponse(data, status));
    vi.stubGlobal("fetch", fetch);
    const signal = new AbortController().signal;
    expect(await fetchApiWithLogging("https://api.sdk.test/execution", "RETRIEVE_CALL", logger, success, failure, "payload_execution", {
      "x-execution": "fixture"
    }, "POST", "pod_execution", "pk_execution", true, undefined, executionAuth, signal)).toEqual(status === 200 ? {
      success: data
    } : {
      failure: data
    });
    const [url, request] = fetch.mock.calls[0];
    expect(url).toBe("https://api.sdk.test/execution");
    expect(request).toMatchObject({
      method: "POST",
      body: "payload_execution",
      signal
    });
    expect(Object.fromEntries(request.headers)).toMatchObject({
      authorization: executionAuth,
      "x-feature": "pod_execution",
      "x-execution": "fixture"
    });
    expect(request.headers.has("api-key")).toBe(false);
    expect(success).toHaveBeenCalledTimes(status === 200 ? 1 : 0);
    expect(failure).toHaveBeenCalledTimes(status === 200 ? 0 : 1);
    expect(logger.setLogApi).toHaveBeenCalledTimes(2);
    expect(JSON.stringify(logger.setLogApi.mock.calls[1])).toContain(String(status));
  });
  it.each(["network", "malformed", "http-malformed"])("returns callback-mapped exception for %s", async reason => {
    const error = new Error(`execution ${reason}`);
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    const consoleError = vi.spyOn(console, "error").mockImplementation(() => {});
    if (reason === "network") {
      fetch.mockRejectedValue(error);
    } else {
      fetch.mockResolvedValue({
        ...executionResponse({}, reason === "http-malformed" ? 500 : 200),
        json: vi.fn().mockRejectedValue(error)
      });
    }
    const failure = vi.fn(exception => ({
      caught: exception.message
    }));
    const logger = executionLogger();
    expect(await fetchApiWithLogging("https://api.sdk.test/execution", "RETRIEVE_CALL", logger, vi.fn(), failure, undefined, undefined, "GET", undefined, "pk_execution")).toEqual({
      caught: `execution ${reason}`
    });
    expect(fetch.mock.calls[0][1].body).toBeUndefined();
    expect(fetch.mock.calls[0][1].headers.get("api-key")).toBe("pk_execution");
    expect(failure).toHaveBeenCalledOnce();
    expect(logger.setLogApi).toHaveBeenCalledTimes(2);
    expect(consoleError).toHaveBeenCalledOnce();
  });
  it("uses explicit catch callback instead of HTTP failure callback for thrown requests", async () => {
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("execution offline")));
    vi.spyOn(console, "error").mockImplementation(() => {});
    const failure = vi.fn();
    const caught = vi.fn(error => error.message);
    expect(await fetchApiWithLogging("https://api.sdk.test/execution", "RETRIEVE_CALL", executionLogger(), vi.fn(), failure, undefined, undefined, "GET", undefined, undefined, undefined, caught)).toBe("execution offline");
    expect(caught).toHaveBeenCalledOnce();
    expect(failure).not.toHaveBeenCalled();
  });
});
