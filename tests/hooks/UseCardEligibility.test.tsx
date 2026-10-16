import { parseJson } from "../helpers/json";
import { sdkKeysAtom, sdkMethodListValueAtom } from "../helpers/sdk-atoms";
import React from "react";
import { describe, expect, it, vi } from "vitest";
import { initialValue, act, renderWithSdk } from "../helpers/render";
import { useCardEligibility } from "../../src/Hooks/UseCardEligibility.bs.js";
import { defaultkeys } from "../../src/Hooks/CommonHooks.bs.js";
import { defaultList } from "../../src/Payments/PaymentMethodsRecord.bs.js";
import { executionDeferred, executionLogger, executionResponse, executionSecret } from "../helpers/execution-fixtures";
function executionHarness(options: { enabled?: boolean; nextAction?: string; secret?: string } = {}) {
  const enabled = "enabled" in options ? options.enabled : true;
  const nextAction = "nextAction" in options ? options.nextAction : "eligibility_check";
  const secret = "secret" in options ? options.secret : executionSecret;
  let state!: ReturnType<typeof useCardEligibility>;
  const logger = executionLogger();
  function Harness() {
    state = useCardEligibility(logger, enabled);
    return <output>{state.isEligibilityPending ? "pending" : "ready"}</output>;
  }
  const view = renderWithSdk(<Harness />, {
    initialValues: [initialValue(sdkKeysAtom, {
      ...defaultkeys,
      clientSecret: secret,
      publishableKey: "pk_execution"
    }), initialValue(sdkMethodListValueAtom, {
      ...defaultList,
      sdk_next_action: nextAction
    })]
  });
  return {
    ...view,
    logger,
    get state() {
      return state;
    },
    change: (number = "4111111111111111", valid = true) => act(() => state.triggerOnCardNumberChange(number, valid))
  };
}
describe("card eligibility lifecycle", () => {
  it("uses default-enabled behavior when the optional run flag is absent", async () => {
    vi.useFakeTimers();
    const fetch = vi.fn().mockResolvedValue(executionResponse({}));
    vi.stubGlobal("fetch", fetch);
    const fixture = executionHarness({
      enabled: undefined
    });
    fixture.change();
    await act(() => vi.advanceTimersByTimeAsync(300));
    expect(fetch).toHaveBeenCalledOnce();
    expect(fixture.state.isEligibilityPending).toBe(false);
  });
  it("settles pending after an HTTP eligibility failure", async () => {
    vi.useFakeTimers();
    const fetch = vi.fn().mockResolvedValue(executionResponse({
      error: {
        message: "Unavailable"
      }
    }, 500));
    vi.stubGlobal("fetch", fetch);
    const fixture = executionHarness();
    fixture.change();
    await act(() => vi.advanceTimersByTimeAsync(300));
    expect(fixture.state.isEligibilityPending).toBe(false);
    expect(fixture.state.cardEligibilityError).toBeUndefined();
    expect(fixture.logger.setLogApi).toHaveBeenCalledTimes(2);
  });
  it("debounces rapid edits into the final card request and exposes result/pending state", async () => {
    vi.useFakeTimers();
    const deferred = executionDeferred<ReturnType<typeof executionResponse>>();
    const fetch = vi.fn((_input: string, _init: { body: string; signal: AbortSignal }) => deferred.promise);
    vi.stubGlobal("fetch", fetch);
    const fixture = executionHarness();
    fixture.change("4111111111111111");
    await act(() => vi.advanceTimersByTimeAsync(200));
    fixture.change("5555555555554444");
    await act(() => vi.advanceTimersByTimeAsync(299));
    expect(fetch).not.toHaveBeenCalled();
    await act(() => vi.advanceTimersByTimeAsync(1));
    expect(fetch).toHaveBeenCalledOnce();
    expect(fixture.state.isEligibilityPending).toBe(true);
    expect(parseJson(fetch.mock.calls[0][1].body)).toMatchObject({
      payment_method_data: {
        card: {
          card_number: "5555555555554444"
        }
      }
    });
    await act(async () => deferred.resolve(executionResponse({
      sdk_next_action: {
        next_action: {
          deny: {
            message: "Issuer restriction"
          }
        }
      }
    })));
    expect(fixture.state.cardEligibilityError).toBe("Issuer restriction");
    expect(fixture.state.isEligibilityPending).toBe(false);
    act(() => fixture.state.resetEligibilityState!());
    expect(fixture.state.cardEligibilityError).toBeUndefined();
    act(() => fixture.state.updateCardEligibilityError!("Custom error"));
    expect(fixture.state.cardEligibilityError).toBe("Custom error");
  });
  it.each([{
    enabled: false
  }, {
    nextAction: undefined
  }, {
    secret: undefined
  }])("avoids requests when disabled or missing eligibility prerequisites: %j", async options => {
    vi.useFakeTimers();
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    const fixture = executionHarness(options);
    fixture.change();
    await act(() => vi.advanceTimersByTimeAsync(300));
    expect(fetch).not.toHaveBeenCalled();
    expect(fixture.state.isEligibilityPending).toBe(false);
  });
  it("cancels scheduled requests on invalid input and unmount", async () => {
    vi.useFakeTimers();
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);
    const fixture = executionHarness();
    fixture.change();
    fixture.change("411", false);
    await act(() => vi.advanceTimersByTimeAsync(300));
    expect(fetch).not.toHaveBeenCalled();
    fixture.change();
    fixture.unmount();
    await act(() => vi.advanceTimersByTimeAsync(300));
    expect(fetch).not.toHaveBeenCalled();
    expect(vi.getTimerCount()).toBe(0);
  });
  it("aborts active request immediately on a new valid edit and ignores its late response", async () => {
    vi.useFakeTimers();
    const old = executionDeferred<ReturnType<typeof executionResponse>>(),
      current = executionDeferred<ReturnType<typeof executionResponse>>();
    const fetch = vi.fn().mockReturnValueOnce(old.promise).mockReturnValueOnce(current.promise);
    vi.stubGlobal("fetch", fetch);
    const fixture = executionHarness();
    fixture.change();
    await act(() => vi.advanceTimersByTimeAsync(300));
    const signal = fetch.mock.calls[0][1].signal;
    fixture.change("5555555555554444");
    expect(signal.aborted).toBe(true);
    await act(() => vi.advanceTimersByTimeAsync(300));
    await act(async () => current.resolve(executionResponse({
      sdk_next_action: {
        next_action: {
          deny: {
            message: "Current card"
          }
        }
      }
    })));
    await act(async () => old.resolve(executionResponse({
      sdk_next_action: {
        next_action: {
          deny: {
            message: "Stale card"
          }
        }
      }
    })));
    expect(fixture.state.cardEligibilityError).toBe("Current card");
    expect(fixture.state.isEligibilityPending).toBe(false);
  });
  it("aborts active transport on invalid input and unmount", async () => {
    vi.useFakeTimers();
    const old = executionDeferred<ReturnType<typeof executionResponse>>(),
      current = executionDeferred<ReturnType<typeof executionResponse>>();
    const fetch = vi.fn().mockReturnValueOnce(old.promise).mockReturnValueOnce(current.promise);
    vi.stubGlobal("fetch", fetch);
    const fixture = executionHarness();
    fixture.change();
    await act(() => vi.advanceTimersByTimeAsync(300));
    fixture.change("bad", false);
    expect(fetch.mock.calls[0][1].signal.aborted).toBe(true);
    expect(fixture.state.isEligibilityPending).toBe(false);
    await act(async () => old.resolve(executionResponse({
      sdk_next_action: {
        next_action: "deny"
      }
    })));
    expect(fixture.state.cardEligibilityError).toBeUndefined();
    fixture.change();
    await act(() => vi.advanceTimersByTimeAsync(300));
    fixture.unmount();
    expect(fetch.mock.calls[1][1].signal.aborted).toBe(true);
    await act(async () => current.resolve(executionResponse({})));
    expect(vi.getTimerCount()).toBe(0);
  });
});
