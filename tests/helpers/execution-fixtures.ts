import { vi } from "vitest";
import { defaultLoggerConfig } from "../../src/Utilities/LoggerUtils.bs.js";
export const executionSecret = "pay_execution_secret_fixture";
export const executionAuth = btoa("payment_id=pay_authorized,publishable_key=pk_execution");
export const executionConfirm = {
  return_url: "https://merchant.test/complete",
  publishableKey: "pk_execution",
  redirect: "if_required"
};
export function executionLogger() {
  return {
    ...defaultLoggerConfig,
    setLogApi: vi.fn(),
    setLogInfo: vi.fn(),
    setLogError: vi.fn()
  };
}
export function executionResponse<T>(data: T, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: vi.fn(async () => data)
  };
}
export function executionDeferred<T = unknown>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return {
    promise,
    resolve,
    reject
  };
}
export function executionState<T = unknown>(initial?: T) {
  const state = {
    value: initial,
    history: [] as (T | undefined)[],
    set: vi.fn((update: (value: T | undefined) => T | undefined) => {
      state.value = update(state.value);
      state.history.push(state.value);
    })
  };
  return state;
}
