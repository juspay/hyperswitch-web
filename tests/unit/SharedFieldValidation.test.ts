import { describe, expect, it } from "vitest";
import * as Email from "../../shared-code/sdk-utils/validation/EmailValidation.bs.js";
import * as Phone from "../../shared-code/sdk-utils/validation/PhoneNumberValidation.bs.js";
import * as CPF from "../../shared-code/sdk-utils/validation/CpfValidation.bs.js";
import * as CNPJ from "../../shared-code/sdk-utils/validation/CnpjValidation.bs.js";

describe("email optional validation", () => {
  it.each([
    ["", undefined],
    ["ada@example.test", true],
    ["ada+pay@example.co.uk", true],
    ["x y@example.test", false],
    ["a@b", false],
    ["a@@example.test", false],
  ])("checks %s", (value, expected) =>
    expect(Email.isEmailValid(value)).toBe(expected),
  );
});

describe("phone country-code extraction", () => {
  const countries = [
    { phone_number_code: "+1" },
    { phone_number_code: "+44" },
    { phone_number_code: "+358" },
  ];
  it.each([
    ["", ["", ""]],
    ["call me", ["", "call me"]],
    ["+", ["", "+"]],
    ["1", ["", "1"]],
    ["١٢", ["", "١٢"]],
    ["tel:+1 2025550123!", ["+1", "2025550123"]],
    ["+44 20 7946 0958", ["+44", "2079460958"]],
    ["+358 40 1234567", ["+358", "401234567"]],
    ["202-555-0123", ["", "2025550123"]],
    ["+999 1234567", ["", "+999 1234567"]],
    ["123456789012345678901", ["", "123456789012345678901"]],
    ["+9", ["", "+9"]],
  ])("extracts %s", (value, expected) =>
    expect(Phone.formatPhoneNumber(value, countries)).toEqual(expected),
  );
});

describe("Brazilian tax identifiers", () => {
  it.each(["52998224725", "11144477735"])("accepts valid CPF %s", (value) =>
    expect(CPF.isValidCPF(value)).toBe(true),
  );
  it.each([
    "",
    "529.982.247-25",
    "52998224724",
    "52998224715",
    "5299822472A",
    "123",
    ...Array.from({ length: 10 }, (_, i) => String(i).repeat(11)),
  ])("rejects invalid CPF %s", (value) =>
    expect(CPF.isValidCPF(value)).toBe(false),
  );
  it.each(["11222333000181", "04252011000110", "12ABC34501DE35"])(
    "accepts numeric or uppercase alphanumeric CNPJ %s",
    (value) => expect(CNPJ.isValidCNPJ(value)).toBe(true),
  );
  it.each([
    "",
    "11.222.333/0001-81",
    "11222333000180",
    "11222333000171",
    "12abc34501DE35",
    "12ABC34501DEAA",
    "12ABC34501D_35",
    ...Array.from({ length: 10 }, (_, i) => String(i).repeat(14)),
  ])("rejects invalid CNPJ %s", (value) =>
    expect(CNPJ.isValidCNPJ(value)).toBe(false),
  );
  it("maps CNPJ characters and handles zero check digits", () => {
    expect(CNPJ.charToValue("0")).toBe(0);
    expect(CNPJ.charToValue("9")).toBe(9);
    expect(CNPJ.charToValue("A")).toBe(17);
    expect(CNPJ.charToValue("Z")).toBe(42);
    expect(CNPJ.charToValue("?")).toBe(0);
    expect(CNPJ.calculateCheckDigit([0], [2])).toBe(0);
    expect(CNPJ.calculateCheckDigit([1], [])).toBe(0);
    expect(CPF.calculateCheckDigit([0])).toBe(0);
  });
});
