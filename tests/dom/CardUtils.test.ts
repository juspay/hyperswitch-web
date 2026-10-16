import { describe, expect, it, vi } from "vitest";
import * as Card from "../../src/CardUtils.bs.js";

const brands = [
  ["Visa", "VISA"],
  ["Mastercard", "MASTERCARD"],
  ["AmericanExpress", "AMEX"],
  ["Maestro", "MAESTRO"],
  ["DinersClub", "DINERSCLUB"],
  ["Discover", "DISCOVER"],
  ["BAJAJ", "BAJAJ"],
  ["SODEXO", "SODEXO"],
  ["RuPay", "RUPAY"],
  ["JCB", "JCB"],
  ["CartesBancaires", "CARTESBANCAIRES"],
  ["UnionPay", "UNIONPAY"],
  ["Interac", "INTERAC"],
];

describe("SDK card issuer and co-badged selection", () => {
  it.each(brands)("round-trips issuer %s", (name, type) => {
    expect(Card.getCardType(name)).toBe(type);
    expect(Card.getCardStringFromType(type)).toBe(name);
    expect(Card.getCardBrandDisplayName(type)).toBe(name);
    expect(Card.normalizeCardBrand(name.toUpperCase())).toBe(name);
  });
  it.each([
    ["american-express", "AmericanExpress"],
    ["AMEX", "AmericanExpress"],
    ["diners", "DinersClub"],
    ["diners_club", "DinersClub"],
    ["cartes bancaires", "CartesBancaires"],
    ["unknown-brand", "unknown-brand"],
  ])("normalizes %s", (value, expected) =>
    expect(Card.normalizeCardBrand(value)).toBe(expected),
  );
  it("preserves unsupported type state and display", () => {
    expect(Card.getCardType("Unknown")).toBe("NOTFOUND");
    expect(Card.getCardStringFromType("NOTFOUND")).toBe("NOTFOUND");
    expect(Card.getCardBrandDisplayName("NOTFOUND")).toBe("Unknown");
    expect(Card.getCardBrandFromStates("Visa", "CartesBancaires", true)).toBe(
      "Visa",
    );
    expect(Card.getCardBrandFromStates("Visa", "CartesBancaires", false)).toBe(
      "CartesBancaires",
    );
  });
  it.each([
    ["4111 1111 1111 1111", "Visa"],
    ["378282246310005", "AmericanExpress"],
    ["5555555555554444", "Mastercard"],
    ["2221000000000000", "Mastercard"],
    ["2720990000000000", "Mastercard"],
    ["2220990000000000", ""],
    ["5082270000000000", "RuPay"],
    ["6521500000000000", "RuPay"],
    ["6212340000000000", "UnionPay"],
    ["abc", ""],
  ])("detects issuer %s", (number, expected) =>
    expect(Card.getCardBrand(number)).toBe(expected),
  );
  it("selects only configured co-badged schemes using lowercase PML names", () => {
    expect(
      Card.getFirstValidCardSchemeFromPML("4010 0500 0000 0000", [
        "cartesbancaires",
      ]),
    ).toBe("CartesBancaires");
    expect(
      Card.getFirstValidCardSchemeFromPML("4010050000000000", [
        "cartesbancaires",
        "visa",
      ]),
    ).toBe("Visa");
    expect(
      Card.getFirstValidCardSchemeFromPML("4010050000000000", ["mastercard"]),
    ).toBeUndefined();
    expect(
      Card.getEligibleCoBadgedCardSchemes(
        ["Visa", "CartesBancaires"],
        ["cartesbancaires"],
      ),
    ).toEqual(["CartesBancaires"]);
  });
});

describe("SDK card validity and form completion", () => {
  it.each([
    ["4111111111111111", "Visa", true],
    ["378282246310005", "AmericanExpress", true],
    ["5555555555554444", "Mastercard", true],
    ["4111111111111112", "Visa", false],
    ["0", "Visa", false],
    ["41111111111111111111", "Visa", false],
  ])("validates %s for %s", (number, brand, expected) =>
    expect(Card.cardValid(number, brand)).toBe(expected),
  );
  it("supports the documented synthetic test cards while preserving checksum failures", () => {
    expect(Card.calculateLuhn("3000100811111072")).toBe(true);
    expect(Card.calculateLuhn("4000100511112003")).toBe(true);
    expect(Card.calculateLuhn("4111111111111112")).toBe(false);
  });
  it("checks completion lengths independently of card validity", () => {
    expect(Card.maxCardLength("Visa")).toBe(19);
    expect(Card.isCardLengthValid("AmericanExpress", 15)).toBe(true);
    expect(Card.isCardLengthValid("AmericanExpress", 16)).toBe(false);
    expect(Card.getMaxLength("AmericanExpress")).toBe(18);
    expect(Card.getMaxLength("Visa")).toBe(23);
    expect(Card.focusCardValid("4111111111111111", "Visa")).toBe(true);
    expect(Card.focusCardValid("378282246310005", "AmericanExpress")).toBe(
      true,
    );
    expect(Card.focusCardValid("4111111111111", "Visa")).toBe(false);
    expect(Card.focusCardValid("4111111111111112", "Visa")).toBe(false);
    expect(Card.focusCardValid("0000000000000000000", "")).toBe(true);
    expect(Card.focusCardValid("4111111111111111", "")).toBe(false);
    expect(
      Card.cardNumberInRange("378282246310005", "AmericanExpress"),
    ).toEqual([false, true]);
  });
  it.each([
    ["", "Visa", false],
    ["123", "Visa", true],
    ["1234", "Visa", false],
    ["1234", "AmericanExpress", true],
    ["123", "AmericanExpress", false],
    ["1234", "Maestro", true],
  ])("validates CVC %s for %s", (value, brand, expected) =>
    expect(Card.checkCardCVC(value, brand)).toBe(expected),
  );
  it.each([
    ["4111", "Visa", undefined],
    ["4111111111111111", "Visa", true],
    ["378282246310004", "AmericanExpress", false],
  ])("emits card validity state for %s", (number, brand, expected) => {
    const setter = vi.fn();
    Card.setCardValid(number, brand, setter);
    expect(setter).toHaveBeenCalledOnce();
    expect(setter.mock.calls[0][0](undefined)).toBe(expected);
  });
  it("returns validation status and required postal-code flags", () => {
    expect(Card.getBoolOptionVal(undefined)).toBe("");
    expect(Card.getBoolOptionVal(true)).toBe("valid");
    expect(Card.getBoolOptionVal(false)).toBe("invalid");
    expect(Card.pincodeVisibility("Visa")).toBe(true);
    expect(Card.pincodeVisibility("RuPay")).toBe(false);
    expect(Card.pincodeVisibility("unknown")).toBe(false);
  });
});

describe("SDK expiry parsing with a fixed clock", () => {
  it.each([
    ["10 / 26", true],
    ["09 / 26", false],
    ["01 / 27", true],
    ["00 / 27", false],
    ["13 / 27", false],
    ["10 / 25", false],
    ["", false],
  ])("validates %s", (expiry, expected) => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-10-16T12:00:00Z"));
    expect(Card.checkCardExpiry(expiry)).toBe(expected);
    expect(Card.isExipryValid(expiry)).toBe(expected);
    const setter = vi.fn();
    Card.setExpiryValid(expiry, setter);
    expect(setter.mock.calls[0][0](undefined)).toBe(
      expiry === "" ? undefined : expected,
    );
  });
  it("handles year rollover and requires complete input before submission", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2027-01-01T00:01:00Z"));
    expect(Card.checkCardExpiry("12 / 26")).toBe(false);
    expect(Card.checkCardExpiry("01 / 27")).toBe(true);
    expect(Card.isExpiryComplete("1 / 27")).toBe(false);
    expect(Card.isExipryValid("1 / 27")).toBe(false);
    expect(Card.isExpiryComplete("01 / 2027")).toBe(false);
    expect(Card.getExpiryDates("01 / 27")).toEqual(["01", "2027"]);
    expect(Card.formatExpiryToTwoDigit("2027")).toBe("27");
    expect(Card.formatExpiryToTwoDigit("27")).toBe("27");
    expect(Card.getCurrentMonthAndYear("bad")).toEqual([0, 0]);
    const setter = vi.fn();
    Card.setExpiryValid("1 / 27", setter);
    expect(setter.mock.calls[0][0](true)).toBeUndefined();
  });
});

describe("card input helpers", () => {
  it("formats card numbers and limits masked card metadata", () => {
    expect(Card.formatCardNumber("378282246310005999", "AMEX")).toBe(
      "3782 822463 10005",
    );
    expect(Card.formatCardNumber("4111-1111x11111111", "VISA")).toBe(
      "4111 1111 1111 1111",
    );
    expect(Card.formatCardNumber("12345678901234567890", "NOTFOUND")).toBe(
      "1234 5678 9012 3456 789",
    );
    expect(Card.getCardBin("4111-1111 1111 1111")).toBe("411111");
    expect(Card.getCardLast4("4111-1111 1111 1111")).toBe("1111");
    expect(Card.getCardLast4("12")).toBe("12");
    expect(Card.getCardLast4("")).toBe("");
    expect(
      Card.getQueryParamsDictforKey(
        "ignored&token=first&token=second=part",
        "token",
      ),
    ).toBe("second=part");
    expect(Card.getQueryParamsDictforKey("a=b", "missing")).toBe("");
  });
  it("selects card visibility and gives brand-specific errors", () => {
    expect(Card.getCardBrandIconVisibility("Standard", "NOTFOUND")).toBe(true);
    expect(Card.getCardBrandIconVisibility("Animated", "NOTFOUND")).toBe(true);
    expect(Card.getCardBrandIconVisibility("Hidden", "VISA")).toBe(false);
    expect(Card.getCardBrandIconVisibility("HideGeneric", "NOTFOUND")).toBe(
      false,
    );
    expect(Card.getCardBrandIconVisibility("HideGeneric", "VISA")).toBe(true);
    const locale = {
      enterValidCardNumberErrorText: "Enter card number",
      cardBrandConfiguredErrorText: (brand: string) => `${brand} unsupported`,
    };
    expect(Card.getCardBrandInvalidError("", locale)).toBe("Enter card number");
    expect(Card.getCardBrandInvalidError("Visa", locale)).toBe(
      "Visa unsupported",
    );
  });
  it("swaps selected schemes without keeping duplicate dropdown entries", () => {
    expect(
      Card.swapCardOption(
        ["Visa"],
        ["CartesBancaires", "Mastercard"],
        "CartesBancaires",
      ),
    ).toEqual([["CartesBancaires"], ["Mastercard", "Visa"]]);
  });
});
