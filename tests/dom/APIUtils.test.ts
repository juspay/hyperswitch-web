import { describe, expect, it } from "vitest";
import * as API from "../../src/Utilities/APIHelpers/APIUtils.bs.js";
import { executionAuth, executionSecret } from "../helpers/execution-fixtures";
const params = {
  clientSecret: executionSecret,
  publishableKey: "pk_execution",
  customBackendBaseUrl: "https://routing.test",
  pollId: "poll_execution",
  payoutId: "payout_execution",
  authenticationId: "auth_execution",
  merchantId: "merchant_execution"
};
describe("API routing", () => {
  it.each([["FetchSessions", "payments/session_tokens"], ["FetchThreeDsAuth", "payments/pay_execution/3ds/authentication"], ["CalculateTax", "payments/pay_execution/calculate_tax"], ["CreatePaymentMethod", "payment_methods"], ["CallAuthLink", "payment_methods/auth/link"], ["CallAuthExchange", "payment_methods/auth/exchange"], ["RetrieveStatus", "poll/status/poll_execution"], ["ConfirmPayout", "payouts/payout_execution/confirm"], ["FetchEnabledAuthnMethodsToken", "authentication/auth_execution/enabled_authn_methods_token"], ["FetchEligibilityCheck", "authentication/auth_execution/eligibility-check"], ["FetchAuthenticationSync", "authentication/merchant_execution/auth_execution/sync"], ["FetchPaymentMethodEligibility", "payments/pay_execution/eligibility"]])("routes %s without irrelevant query parameters", (type, path) => {
    expect(API.generateApiUrlV1({
      ...params,
      forceSync: "true"
    }, type)).toBe(`https://routing.test/${path}`);
  });
  it.each([["RetrievePaymentIntent", "payments/pay_execution"], ["FetchSdkConfigs", "v1/sdk/configs/web/sdk_config.json"], ["FetchClientList", "payments/pay_execution/client"]])("adds legacy secret to %s", (type, path) => {
    expect(API.generateApiUrlV1(params, type)).toBe(`https://routing.test/${path}?client_secret=${executionSecret}`);
  });
  it("uses SDK payment id, removes secret, and applies force sync only to retrieval", () => {
    expect(API.generateApiUrlV1({
      ...params,
      sdkAuthorization: executionAuth,
      forceSync: "true"
    }, "RetrievePaymentIntent")).toBe("https://routing.test/payments/pay_authorized?force_sync=true");
    expect(API.generateApiUrlV1({
      ...params,
      sdkAuthorization: executionAuth,
      forceSync: "true"
    }, "FetchClientList")).toBe("https://routing.test/payments/pay_authorized/client");
    expect(API.generateApiUrlV1({
      ...params,
      sdkAuthorization: "",
      forceSync: "true"
    }, "RetrievePaymentIntent")).toContain(`?client_secret=${executionSecret}&force_sync=true`);
  });
  it("falls back to configured endpoint and empty optional identifiers", () => {
    expect(API.generateApiUrlV1({}, "RetrieveStatus")).toBe("https://api.sdk.test/poll/status/");
    expect(API.generateApiUrlV1({}, "RetrievePaymentIntent")).toBe("https://api.sdk.test/payments/");
    expect(API.generateApiUrlV1({
      ...params,
      sdkAuthorization: "invalid"
    }, "FetchThreeDsAuth")).toBe("https://routing.test/payments/pay_execution/3ds/authentication");
  });
});
