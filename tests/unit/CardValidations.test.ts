import { describe, expect, it } from "vitest";
import {
  formatCardNumber,
  formatCardExpiryNumber,
  formatCVCNumber,
  splitExpiryDates,
} from "../../shared-code/sdk-utils/validation/CardValidations.bs.js";

describe("card formatters", () => {
  it.each([
    ["4111-1111 1111x1111", "VISA", "4111 1111 1111 1111"],
    ["378282246310005999", "AMEX", "3782 822463 10005"],
    ["30569309025904", "DINERSCLUB", "3056 930902 5904"],
    ["411", "VISA", "411"],
    ["", "VISA", ""],
  ])("formats pasted or partial %s for %s", (input, brand, expected) => {
    expect(formatCardNumber(input, brand)).toBe(expected);
  });

  it.each([
    ["", ""],
    ["1", "1"],
    ["2", "02 / "],
    ["12/30", "12 / 30"],
    ["12 / 3099", "12 / 30"],
  ])("formats expiry input %s", (input, expected) => {
    expect(formatCardExpiryNumber(input)).toBe(expected);
  });

  it("strips pasted separators and respects brand CVC lengths", () => {
    expect(formatCVCNumber("1a2-345", "Visa")).toBe("123");
    expect(formatCVCNumber("1a2-345", "AmericanExpress")).toBe("1234");
  });

  it("keeps incomplete expiry fields distinct", () => {
    expect(splitExpiryDates(" 12 / ")).toEqual(["12", ""]);
    expect(splitExpiryDates("")).toEqual(["", ""]);
  });
});

describe("card scheme and formatting boundaries", () => {
  it.each([
    ["13", "01 / 3"],
    ["99", "09 / 9"],
    ["0", "0"],
    ["01", "01"],
    ["a12--30", "12 / 30"],
    ["9", "09 / "],
  ])("formats month boundary %s", async (value, expected) => {
    expect(formatCardExpiryNumber(value)).toBe(expected);
  });
  it.each([
    ["3056930902590412345", "DINERSCLUB", "3056 9309 0259 0412   345"],
    ["12345678901234567890", "NOTFOUND", "1234 5678 9012 3456789"],
    ["55555555555544449999", "MASTERCARD", "5555 5555 5555 4444 999"],
    ["4111111111111111111", "VISA", "4111 1111 1111 1111 111"],
  ])("formats full-length %s for %s", (value, brand, expected) =>
    expect(formatCardNumber(value, brand)).toBe(expected),
  );
});

it("matches co-badged schemes, selects enabled brands, and maps formatter types", async () => {
  const Card =
    await import("../../shared-code/sdk-utils/validation/CardValidations.bs.js");
  expect(Card.getAllMatchedCardSchemes("4010050000000000")).toEqual([
    "Visa",
    "CartesBancaires",
  ]);
  expect(Card.getAllMatchedCardSchemes("invalid")).toEqual([]);
  expect(Card.isCardSchemeEnabled("Visa", ["Visa"])).toBe(true);
  expect(Card.isCardSchemeEnabled("Visa", ["Mastercard"])).toBe(false);
  for (const brand of [
    "VISA",
    "MASTERCARD",
    "AMEX",
    "MAESTRO",
    "DINERSCLUB",
    "DISCOVER",
    "BAJAJ",
    "SODEXO",
    "RUPAY",
    "JCB",
    "CARTESBANCAIRES",
  ])
    expect(Card.cardType(brand.toLowerCase())).toBe(brand);
  expect(Card.cardType("invalid")).toBe("NOTFOUND");
  expect(Card.slice("123456", 1, 3)).toBe("23");
  expect(Card.getStrFromIndex([], 0)).toBe("");
});
