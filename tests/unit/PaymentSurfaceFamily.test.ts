import { describe, expect, it } from "vitest";
import {
  classifyFromUrlParams,
  classifyCoordinatorFromUrl,
} from "../../src/Utilities/PaymentSurfaceFamily.bs.js";

describe("payment surface classification", () => {
  it.each([
    ["payments", "PaymentsFamily"],
    ["vault", "VaultFamily"],
    [undefined, "OtherFamily"],
    ["", "OtherFamily"],
    ["unknown", "OtherFamily"],
  ])("classifies paymentMethodsSDK family %s", (family, expected) => {
    expect(classifyFromUrlParams("paymentMethodsSDK", family)).toBe(expected);
  });

  it.each([undefined, "", "cardFormCoordinator", "unknown"])(
    "rejects mismatched component %s even for a known family",
    (component) => {
      expect(classifyFromUrlParams(component, "payments")).toBe("OtherFamily");
      expect(classifyFromUrlParams(component, "vault")).toBe("OtherFamily");
    },
  );

  it.each([
    ["payments", "PaymentsCoordinator"],
    ["vault", "VaultCoordinator"],
    [undefined, "OtherCoordinatorFamily"],
    ["unknown", "OtherCoordinatorFamily"],
  ])("classifies coordinator family %s", (family, expected) => {
    expect(classifyCoordinatorFromUrl("cardFormCoordinator", family)).toBe(expected);
  });

  it("does not classify the payment surface as a coordinator", () => {
    expect(classifyCoordinatorFromUrl("paymentMethodsSDK", "payments"))
      .toBe("OtherCoordinatorFamily");
  });
});
