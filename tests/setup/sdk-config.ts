import { afterEach, beforeEach, expect, vi } from "vitest";

// ReScript externals access these globals directly, including during imports.
const sdkConfig = Object.freeze({
  repoName: "hyperswitch-web-unit-tests",
  repoVersion: "0.0.0-test",
  publicPath: "https://sdk.test/",
  backendEndPoint: "https://api.sdk.test",
  confirmEndPoint: "https://api.sdk.test",
  sdkUrl: "https://sdk.test/",
  logEndpoint: "https://logs.sdk.test",
  sentryDSN: "",
  sentryScriptUrl: "",
  enableLogging: false,
  loggingLevel: "error",
  maxLogsPushedPerEventName: 0,
  isIntegrationEnv: false,
  isSandboxEnv: false,
  isProductionEnv: false,
  isLocal: true,
  isPciCompliant: false,
});

declare global { var __SDK_CONFIG__: typeof sdkConfig; }
globalThis.__SDK_CONFIG__ = sdkConfig;

const unexpectedRequests: string[] = [];
const cleanups: (() => void)[] = [];

export function registerTestCleanup(cleanup: () => void) {
  cleanups.push(cleanup);
}

export function rejectUnexpectedRequest(kind: string, destination: unknown): never {
  const message = `Unexpected ${kind} request: ${String(destination)}`;
  unexpectedRequests.push(message);
  throw new Error(message);
}

function blockFetch() {
  vi.stubGlobal("fetch", vi.fn((input: RequestInfo | URL) => rejectUnexpectedRequest("fetch", input instanceof Request ? input.url : input)));
}

// Install before SDK imports as well as before each test. Even swallowed network
// errors are reported by the afterEach assertion.
blockFetch();
beforeEach(blockFetch);

afterEach(() => {
  // Run DOM/effect cleanup while network guards and test mocks still exist.
  for (const cleanup of cleanups) cleanup();
  const requests = unexpectedRequests.splice(0);
  vi.clearAllTimers();
  vi.useRealTimers();
  vi.restoreAllMocks();
  vi.clearAllMocks();
  vi.unstubAllGlobals();
  expect(requests, "Mock external I/O explicitly in the test that expects it").toEqual([]);
});
