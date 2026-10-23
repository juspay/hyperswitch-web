import { describe, expect, it } from "vitest";
import * as Shared from "../../src/Utilities/CardFormShared.bs.js";
import { card } from "../helpers/lifecycle-fixtures";
describe("CardFormShared merchant-facing changes", () => {
  it.each(["cardNumber", "cardExpiry", "cardCvc", "cardholderName"])("maps %s without exposing card values", field => {
    expect(Shared.mapFieldTypeToInternalFieldName(field)).toBe(field);
    expect(Shared.reshapeCardStateUpdateToChangePayload(field, {
      ...card,
      fieldStatus: {
        complete: true,
        empty: false,
        isCardValid: true,
        isExpiryValid: true,
        isCvcValid: true
      },
      error: "Invalid test field"
    })).toEqual({
      empty: false,
      complete: true,
      valid: true,
      elementType: field,
      brand: "Visa",
      error: "Invalid test field"
    });
  });

  it.each([
    ["cardNumber", "isCardValid", true],
    ["cardNumber", "isCardValid", false],
    ["cardExpiry", "isExpiryValid", true],
    ["cardExpiry", "isExpiryValid", false],
    ["cardCvc", "isCvcValid", true],
    ["cardCvc", "isCvcValid", false],
  ])("reads %s validity from %s when it is %s", (field, validityKey, valid) => {
    const fieldStatus = {
      complete: true,
      empty: false,
      isCardValid: !valid,
      isExpiryValid: !valid,
      isCvcValid: !valid,
      [validityKey]: valid,
    };
    expect(Shared.reshapeCardStateUpdateToChangePayload(field, { fieldStatus }))
      .toEqual({ empty: false, complete: true, valid, elementType: field });
  });

  it.each([
    ["cardExpiry", "isExpiryValid"],
    ["cardCvc", "isCvcValid"],
  ])("defaults missing or malformed %s validity to false", (field, validityKey) => {
    for (const fieldStatus of [undefined, {}, "bad", { [validityKey]: "true" }, { [validityKey]: 1 }, { [validityKey]: null }]) {
      expect(Shared.reshapeCardStateUpdateToChangePayload(field, { fieldStatus }))
        .toEqual({ empty: true, complete: false, valid: false, elementType: field });
    }
  });

  it("treats cardholder-name validity independently from card, expiry, and CVC flags", () => {
    for (const fieldStatus of [
      undefined,
      "bad",
      { complete: false, empty: true, isCardValid: false, isExpiryValid: false, isCvcValid: false },
      { complete: false, empty: true, isCardValid: true, isExpiryValid: true, isCvcValid: true },
    ]) {
      expect(Shared.reshapeCardStateUpdateToChangePayload("cardholderName", { fieldStatus }))
        .toEqual({ empty: true, complete: false, valid: true, elementType: "cardholderName" });
    }
  });

  it("rejects unknown field names and limits the automatic focus chain", () => {
    expect(Shared.mapFieldTypeToInternalFieldName("cardnumber")).toBe("");
    expect(Shared.nextFieldFor("cardNumber")).toBe("cardExpiry");
    expect(Shared.nextFieldFor("cardExpiry")).toBe("cardCvc");
    for (const field of ["cardCvc", "cardholderName", "unknown"]) expect(Shared.nextFieldFor(field)).toBeUndefined();
  });
  it.each([null, {}, {
    fieldStatus: "bad",
    cardBrand: false,
    error: 42
  }])("defaults incomplete or malformed snapshots: %j", snapshot => {
    expect(Shared.reshapeCardStateUpdateToChangePayload("cardNumber", snapshot)).toEqual({
      empty: true,
      complete: false,
      valid: false,
      elementType: "cardNumber"
    });
    expect(Shared.reshapeCardStateUpdateToChangePayload("unknown", snapshot).valid).toBe(false);
  });
});
