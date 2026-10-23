import { describe, expect, it } from "vitest";
import * as Protocol from "../../src/Payments/CardIframeProtocol.bs.js";

describe("CardIframeProtocol", () => {
  it("defaults missing and malformed field status and card information", () => {
    expect(Protocol.decodeFieldStatus({ complete: "true", empty: false, isCvcEmpty: 0 }))
      .toMatchObject({ complete: false, empty: false, isCvcEmpty: true, isCardValid: false });
    expect(Protocol.decodeCardInfo({ bin: 411111, last4: "1111", isExpiryValid: "true" }))
      .toMatchObject({ bin: undefined, last4: "1111", brand: undefined, isExpiryValid: false });
    expect(Protocol.decodeIframeHeight({ iframeHeight: "not-a-height" })).toBe(0);
    expect(Protocol.decodeIframeHeight({ iframeHeight: "100" })).toBe(100);
    expect(Protocol.decodeIframeHeight({ iframeHeight: 100 })).toBe(100);
    expect(Protocol.decodeStateUpdate({}, true, true)).toBeUndefined();
  });

  it("requires full-state permission and independently gates raw card numbers", () => {
    const payload = { cardStateUpdate: {
      cardBrand: "Visa", rawCardNumber: "4111111111111111",
      fieldStatus: { complete: true, empty: false }, cardInfo: { last4: "1111" },
    } };
    expect(Protocol.decodeStateUpdate(payload, true, false)).toBeUndefined();
    expect(Protocol.decodeStateUpdate(payload, false, true)).toMatchObject({
      TAG: "CardSnapshot", _0: { cardBrand: "Visa", rawCardNumber: undefined, cardInfo: { last4: "1111" } },
    });
    // Literal permissions select CardSnapshot, but generated JS does not preserve that correlation.
    expect((Protocol.decodeStateUpdate(payload, true, true)!._0 as { rawCardNumber: string }).rawCardNumber).toBe("4111111111111111");
  });

  it("applies partial status updates without overwriting card identity or raw state", () => {
    const original = { ...Protocol.initialState,
      cardBrand: "Visa", rawCardNumber: "4111111111111111", cardInfo: { last4: "1111" },
    };
    const payload = { cardFieldStatus: { complete: true, empty: false, isCardValid: true } };
    expect(Protocol.decodeStateUpdate(payload, true, false)).toBeUndefined();
    const result = Protocol.applyStateUpdate(original, Protocol.decodeStateUpdate(payload, false, true));
    expect(result).toMatchObject({
      cardBrand: "Visa", rawCardNumber: original.rawCardNumber, cardInfo: original.cardInfo,
      hasCardFieldStatus: true, cardFieldsComplete: true, cardFieldsEmpty: false, isCardValid: true,
    });
    expect(original.hasCardFieldStatus).toBe(false);
  });

  it("preserves the previous raw number when a snapshot cannot include it", () => {
    const original = { ...Protocol.initialState, rawCardNumber: "4111111111111111" };
    const update = Protocol.decodeStateUpdate({ cardStateUpdate: {
      cardBrand: "Visa", fieldStatus: { complete: true }, cardInfo: { last4: "1111" },
    } }, false, true);
    expect(Protocol.applyStateUpdate(original, update)).toMatchObject({
      rawCardNumber: original.rawCardNumber, cardBrand: "Visa", hasCardFieldStatus: true,
      cardInfo: { last4: "1111" },
    });
  });

  it("decodes malformed updates safely and handles saved-card CVC defaults", () => {
    expect(Protocol.decodeStateUpdate({ cardStateUpdate: "bad" }, true, true))
      .toMatchObject({ TAG: "CardSnapshot", _0: { cardBrand: "", rawCardNumber: undefined } });
    expect(Protocol.decodeSavedCardCvcState({})).toBeUndefined();
    expect(Protocol.decodeSavedCardCvcState({ savedCardCvcStatus: { valid: true, error: 42 } }))
      .toEqual({ ready: true, empty: true, complete: false, valid: true, error: "" });
  });
});
