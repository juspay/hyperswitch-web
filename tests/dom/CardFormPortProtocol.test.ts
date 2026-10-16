import { describe, expect, it, vi } from "vitest";
import * as Protocol from "../../src/Payments/CardFormPortProtocol.bs.js";

describe("CardFormPortProtocol", () => {
  it("keeps raw card fields off the window plane and includes them on the port plane", () => {
    const snapshot = {
      cardBrand: "Visa", fieldStatus: { complete: true }, cardInfo: { last4: "1111" },
      focusReady: true, rawCardNumber: "4111111111111111", rawCardExpiry: "10/29",
      rawCvc: "123", rawCardholderName: "Test Cardholder",
    };
    const { windowPayload, portPayload } = Protocol.encodeFieldStateUpdate(snapshot);
    expect(windowPayload).toEqual({
      cardBrand: "Visa", fieldStatus: { complete: true }, cardInfo: { last4: "1111" }, focusReady: true,
    });
    for (const field of ["rawCardNumber", "rawCardExpiry", "rawCvc", "rawCardholderName"] as const) {
      expect(windowPayload).not.toHaveProperty(field);
      expect(portPayload.payload[field]).toBe(snapshot[field]);
    }
    expect(portPayload).toMatchObject({ cardFormPortV: 1, kind: "fieldStateUpdate" });
  });

  it("omits absent optional fields and false focus readiness", () => {
    const { windowPayload, portPayload } = Protocol.encodeFieldStateUpdate({
      cardBrand: "", fieldStatus: {}, cardInfo: {}, focusReady: false,
    });
    expect(windowPayload).toEqual({ cardBrand: "", fieldStatus: {}, cardInfo: {} });
    expect(portPayload.payload).toEqual(windowPayload);
  });

  it("round trips frames and ignores unversioned window messages", () => {
    const frame = Protocol.makePortFrame("doFocus", { field: "cvc" });
    expect(Protocol.decodePortFrame(frame)).toEqual({ kind: "doFocus", payload: { field: "cvc" } });
    expect(Protocol.decodePortFrame({ kind: "doFocus", payload: {} })).toBeUndefined();
    expect(Protocol.decodePortFrame(null)).toBeUndefined();
  });

  it("warns but decodes other versions for forward compatibility", () => {
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    expect(Protocol.decodePortFrame({ cardFormPortV: 2, kind: "clearField", payload: {} }))
      .toEqual({ kind: "clearField", payload: {} });
    expect(warn).toHaveBeenCalledOnce();
    warn.mockRestore();
  });

  it("defaults a malformed kind and missing payload on versioned frames", () => {
    expect(Protocol.decodePortFrame({ cardFormPortV: 1, kind: false }))
      .toEqual({ kind: "", payload: {} });
  });
});
