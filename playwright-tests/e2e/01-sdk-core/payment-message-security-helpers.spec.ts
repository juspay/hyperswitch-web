// Pure helper checks use the existing Playwright runner without browser fixtures.
import { test, expect } from "@playwright/test";
// Compiled ReScript, produced by the suite's existing re:build step.
import {
  isExpectedSender,
  httpUrl,
  isReturnDestination,
} from "../../../src/Utilities/PaymentMessageSecurity.bs.js";

test.describe("Payment message security helpers @hermetic-only", () => {
  test("a trusted origin cannot authenticate a different window", () => {
    const expectedWindow = {};
    expect(
      isExpectedSender(
        expectedWindow,
        "https://sdk.example",
        {},
        "https://sdk.example",
      ),
    ).toBe(false);
    expect(
      isExpectedSender(
        expectedWindow,
        "https://sdk.example",
        expectedWindow,
        "https://attacker.example",
      ),
    ).toBe(false);
    expect(
      isExpectedSender(
        expectedWindow,
        "https://sdk.example",
        expectedWindow,
        "https://sdk.example",
      ),
    ).toBe(true);
  });

  test("uninitialized, wildcard and opaque origins fail closed", () => {
    const source = {};
    for (const origin of ["", "*", "null"]) {
      expect(isExpectedSender(source, origin, source, origin), origin).toBe(
        false,
      );
    }
  });

  test("redirects reject executable schemes, relative URLs and embedded credentials", () => {
    for (const url of [
      "javascript:alert(1)",
      "data:text/html,hello",
      "//merchant.example/return",
      "/return",
      "https://merchant.example@attacker.example/return",
      "https://user:password@merchant.example/return",
      "not a URL",
    ]) {
      expect(httpUrl(url), url).toBeUndefined();
    }
    expect(httpUrl("https://merchant.example/return")?.href).toBe(
      "https://merchant.example/return",
    );
    expect(httpUrl("http://localhost:9160/return")?.origin).toBe(
      "http://localhost:9160",
    );
  });

  test("CVC completion preserves the configured destination while allowing payment query parameters", () => {
    const configured = "https://merchant.example/order/return?order=123";
    expect(
      isReturnDestination(
        "https://merchant.example/order/return?order=123&status=succeeded",
        configured,
      ),
    ).toBe(true);
    for (const url of [
      "https://attacker.example/order/return",
      "https://merchant.example.attacker.example/order/return",
      "http://merchant.example/order/return",
      "https://merchant.example:8443/order/return",
      "https://merchant.example/other",
      "javascript:alert(1)",
      "https://merchant.example/order/return?order=999",
      "https://merchant.example/order/return?status=succeeded",
      "https://merchant.example/order/return?order=123&next=https://attacker.example",
      "https://merchant.example/order/return?order=123#changed",
    ]) {
      expect(isReturnDestination(url, configured), url).toBe(false);
    }
    expect(
      isReturnDestination(
        "https://merchant.example/order/return?order=123&status=succeeded#receipt",
        `${configured}#receipt`,
      ),
    ).toBe(true);
  });
});
