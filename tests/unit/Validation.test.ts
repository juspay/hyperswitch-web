import {
  cardNumber,
  cardLengthContracts,
} from "../helpers/validation-cards";
import { afterEach, describe, expect, it, vi } from "vitest";
import * as Validation from "../../shared-code/sdk-utils/validation/Validation.bs.js";

afterEach(() => vi.useRealTimers());

describe("shared card validation", () => {
  it.each([
    ["4111 1111 1111 1111", "Visa", true],
    ["4111111111111112", "Visa", false],
    ["378282246310005", "AmericanExpress", true],
    ["5555555555554444", "Mastercard", true],
    // Valid Luhn checksum alone is insufficient for a supported card length.
    ["0", "Visa", false],
    ["00000000000000000000", "Visa", false],
  ])("validates %s for %s", (number, brand, valid) => {
    expect(Validation.cardValid(number, brand)).toBe(valid);
  });

  it("distinguishes invalid Luhn checksums from invalid lengths", () => {
    expect(Validation.calculateLuhn("4111111111111111")).toBe(true);
    expect(Validation.calculateLuhn("4111111111111112")).toBe(false);
    expect(Validation.calculateLuhn("0")).toBe(true);
    expect(Validation.cardValid("0", "Visa")).toBe(false);
  });

  it.each([
    ["123", "Visa", true],
    ["1234", "Visa", false],
    ["123", "AmericanExpress", false],
    ["1234", "AmericanExpress", true],
    ["123", "Maestro", true],
    ["1234", "Maestro", true],
    ["", "Visa", false],
    ["12", "Mastercard", false],
  ])("checks CVC %s for %s", (value, brand, valid) => {
    expect(Validation.checkCardCVC(value, brand)).toBe(valid);
  });

  it("accepts the current expiry month and rejects the previous month", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-10-16T12:00:00Z"));
    expect(Validation.checkCardExpiry("10 / 26")).toBe(true);
    expect(Validation.checkCardExpiry("09 / 26")).toBe(false);
    expect(Validation.checkCardExpiry("11 / 26")).toBe(true);
  });

  it.each(["", "1", "12 /", "00 / 27", "13 / 27", "12 / 25"])(
    "rejects incomplete or invalid expiry %s",
    (expiry) => {
      vi.useFakeTimers();
      vi.setSystemTime(new Date("2026-10-16T12:00:00Z"));
      expect(Validation.checkCardExpiry(expiry)).toBe(false);
    },
  );

  it("handles December to January year rollover", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-12-31T23:59:00Z"));
    expect(Validation.checkCardExpiry("12 / 26")).toBe(true);
    expect(Validation.checkCardExpiry("01 / 27")).toBe(true);
    vi.setSystemTime(new Date("2027-01-01T00:01:00Z"));
    expect(Validation.checkCardExpiry("12 / 26")).toBe(false);
    expect(Validation.checkCardExpiry("01 / 27")).toBe(true);
  });
});

const locale = new Proxy({}, { get: (_target, key) => String(key) });
const rule = (TAG: string, _0: unknown) => ({ TAG, _0 });
const field = (value: string, rules: unknown) =>
  Validation.validateField(value, rules, ["Visa", "CartesBancaires"], locale);

describe("checkout field validation contracts", () => {
  it.each([
    ["", rule("Required", undefined), "mandatoryFieldText"],
    ["  ", rule("Required", "Enter billing address"), "Enter billing address"],
    ["Paris", rule("Required", undefined), undefined],
    ["ab", rule("MinLength", 3), "Minimum 3 characters required"],
    ["abc", rule("MinLength", 3), undefined],
    ["abcd", rule("MaxLength", 3), "Maximum 3 characters allowed"],
    ["abc", rule("MaxLength", 3), undefined],
    ["", "CardNumber", "cardNumberEmptyText"],
    ["4111111111111111", "CardNumber", undefined],
    ["4111111111111112", "CardNumber", "inValidCardErrorText"],
    ["5555555555554444", "CardNumber", undefined],
    ["", rule("CardExpiry", ""), "cardExpiryDateEmptyText"],
    ["ignored", rule("CardExpiry", "10 / 26"), undefined],
    ["ignored", rule("CardExpiry", "09 / 26"), "inValidExpiryErrorText"],
    ["", rule("CardCVC", "Visa"), "cvcNumberEmptyText"],
    ["12", rule("CardCVC", "Visa"), "inValidCVCErrorText"],
    ["123", rule("CardCVC", "Visa"), undefined],
    ["Visa", rule("CardNetwork", ["Visa"]), undefined],
    ["Mastercard", rule("CardNetwork", ["Visa"]), "unsupportedCardErrorText"],
    ["", "Email", "emailEmptyText"],
    ["a@b", "Email", "emailInvalidText"],
    ["ada+checkout@example.test", "Email", undefined],
    [" ", "FirstName", "cardHolderNameRequiredText"],
    ["Ada1", "FirstName", "invalidDigitsCardHolderNameError"],
    [" Ada ", "FirstName", undefined],
    [" ", "LastName", "lastNameRequiredText"],
    ["Lovelace2", "LastName", "invalidDigitsCardHolderNameError"],
    [" O'Neill ", "LastName", undefined],
    ["123456789", "Phone", "phoneInvalidText"],
    ["+1 (202) 555-0123", "Phone", undefined],
    ["", "BankAccountNumber", "mandatoryFieldText"],
    ["123456789012345678", "BankAccountNumber", "accountNumberInvalidText"],
    ["12345678901234567", "BankAccountNumber", undefined],
    ["  ", "IBAN", "ibanEmptyText"],
    ["DE89370400440532013000", "IBAN", undefined],
    ["", "BlikCode", "mandatoryFieldText"],
    ["12345", "BlikCode", "blikCodeInvalidText"],
    ["123 456", "BlikCode", undefined],
    ["", "GiftCardNumber", "mandatoryFieldText"],
    ["gift-token", "GiftCardNumber", undefined],
    ["", "GiftCardPin", "mandatoryFieldText"],
    ["1234", "GiftCardPin", undefined],
    ["Travel", "Nickname", undefined],
    ["Travel12", "Nickname", undefined],
    ["Travel123", "Nickname", "invalidNickNameError"],
    ["", "PixKey", "pixKeyEmptyText"],
    ["pix@example.test", "PixKey", undefined],
    ["", "PixCPF", "pixCPFEmptyText"],
    ["11111111111", "PixCPF", "pixCPFInvalidText"],
    ["52998224725", "PixCPF", undefined],
    ["", "PixCNPJ", "pixCNPJEmptyText"],
    ["11111111111111", "PixCNPJ", "pixCNPJInvalidText"],
    ["11222333000181", "PixCNPJ", undefined],
    ["", "RoutingNumber", "mandatoryFieldText"],
    ["123", "RoutingNumber", "formFieldInvalidRoutingNumber"],
    ["021000022", "RoutingNumber", "formFieldInvalidRoutingNumber"],
    ["021000021", "RoutingNumber", undefined],
    ["", "DateOfBirth", "dateofBirthRequiredText"],
    ["2008-10-16", "DateOfBirth", undefined],
    ["2008-10-17", "DateOfBirth", "dateOfBirthInvalidText"],
    ["invalid", "DateOfBirth", "dateOfBirthInvalidText"],
    ["", rule("Generic", "^A+$"), undefined],
    ["AAA", rule("Generic", "^A+$"), undefined],
    ["BBB", rule("Generic", "^A+$"), "enterValidDetailsText"],
    ["", rule("PostalCode", "US"), "postalCodeInvalidText"],
  ])("validates %s against %j", (value, validation, expected) => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-10-16T12:00:00Z"));
    expect(field(value, [validation])).toBe(expected);
  });

  it("preserves the first failure and handles absent form values", () => {
    expect(
      field("", [rule("Required", "Required first"), rule("MinLength", 2)]),
    ).toBe("Required first");
    expect(
      Validation.createFieldValidator(
        [rule("Required", undefined)],
        [],
        locale,
      )(undefined),
    ).toBe("mandatoryFieldText");
    expect(
      Validation.createFieldValidator(
        [rule("Required", undefined)],
        [],
        locale,
      )("Ada"),
    ).toBeUndefined();
  });

  it("warns and safely ignores invalid merchant regular expressions", () => {
    const warning = vi.spyOn(console, "warn").mockImplementation(() => {});
    expect(field("value", [rule("Generic", "[")])).toBeUndefined();
    expect(warning).toHaveBeenCalledWith(
      expect.stringContaining("Invalid regex pattern"),
    );
  });
});

describe("card network choice and input contracts", () => {
  it("intersects co-badged schemes and follows pattern precedence among enabled brands", () => {
    const matches = Validation.getAllMatchedCardSchemes("4010050000000000");
    expect(matches).toEqual(["Visa", "CartesBancaires"]);
    expect(
      Validation.getFirstValidCardScheme("4010 0500 0000 0000", [
        "CartesBancaires",
      ]),
    ).toBe("CartesBancaires");
    expect(
      Validation.getFirstValidCardScheme("4010050000000000", [
        "CartesBancaires",
        "Visa",
      ]),
    ).toBe("Visa");
    expect(
      Validation.getFirstValidCardScheme("4010050000000000", ["Mastercard"]),
    ).toBe("");
    expect(
      Validation.getEligibleCoBadgedCardSchemes(matches, ["CartesBancaires"]),
    ).toEqual(["CartesBancaires"]);
    expect(Validation.isCardSchemeEnabled("visa", ["Visa"])).toBe(false);
  });

  it.each([
    ["4111 1111", "Visa"],
    ["2221000000000000", "MASTERCARD"],
    ["2720990000000000", "MASTERCARD"],
    ["2220990000000000", ""],
    ["5082270000000000", "RUPAY"],
    ["378282", "AmericanExpress"],
    ["not-a-number", ""],
  ])("detects issuer of %s", (number, expected) =>
    expect(Validation.getCardBrand(number)).toBe(expected),
  );

  it("keeps CVC and card completion separate from validity", () => {
    expect(Validation.maxCardLength("Visa")).toBe(19);
    expect(Validation.maxCardLength("unknown")).toBe(19);
    expect(Validation.isCardNumberEqualsMax("4111111111111111", "Visa")).toBe(
      true,
    );
    expect(Validation.isCardNumberEqualsMax("411", "Visa")).toBe(false);
    expect(Validation.isCardNumberEqualsMax("4".repeat(19), "Visa")).toBe(true);
    expect(Validation.checkMaxCardCvv("123", "Maestro")).toBe(false);
    expect(Validation.checkMaxCardCvv("1234", "Maestro")).toBe(true);
    expect(Validation.checkMaxCardCvv("", "Visa")).toBe(false);
    expect(Validation.containsOnlyDigits("123")).toBe(true);
    expect(Validation.containsOnlyDigits("1x")).toBe(false);
    expect(Validation.containsMoreThanTwoDigits("name12")).toBe(false);
    expect(Validation.containsMoreThanTwoDigits("name123")).toBe(true);
    expect(Validation.containsMoreThanTwoDigits("name")).toBe(false);
    expect(Validation.clearAlphas("ab12 34-5")).toBe("12 345");
  });

  it.each([
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
    "UNIONPAY",
    "INTERAC",
  ])("maps card type %s case-insensitively", (brand) => {
    expect(Validation.cardType(brand.toLowerCase())).toBe(brand);
  });

  it("formats numeric inputs and supplies keyboard/privacy hints", () => {
    expect(Validation.cardType("unknown")).toBe("NOTFOUND");
    expect(Validation.format("4111111111111111", "CardNumber")).toBe(
      "4111 1111 1111 1111",
    );
    expect(Validation.format("123456", rule("CardExpiry", "123456"))).toBe(
      "1234",
    );
    expect(Validation.format("unused", rule("CardExpiry", "12/30"))).toBe(
      "12 / 30",
    );
    expect(Validation.format("unchanged", "FirstName")).toBe("unchanged");
    expect(
      Validation.formatValue("CardNumber")(undefined, "card"),
    ).toBeUndefined();
    expect(
      Validation.formatValue("CardNumber")("4111111111111111", "card"),
    ).toBe("4111 1111 1111 1111");
    for (const validation of [
      "CardNumber",
      rule("CardExpiry", ""),
      rule("CardCVC", "Visa"),
    ])
      expect(Validation.getKeyboardType(validation)).toBe("numeric");
    expect(Validation.getKeyboardType("Email")).toBe("email-address");
    expect(Validation.getKeyboardType("Phone")).toBe("phone-pad");
    expect(Validation.getKeyboardType("FirstName")).toBe("default");
    expect(Validation.getSecureTextEntry(rule("CardCVC", "Visa"))).toBe(true);
    expect(Validation.getSecureTextEntry("Email")).toBe(false);
  });

  it("checks future expiry year limits using a fixed UTC clock", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-10-16T12:00:00Z"));
    expect(Validation.getExpiryDates(" 01 / 27 ")).toEqual(["01", "2027"]);
    expect(Validation.checkCardExpiry("01 / 98")).toBe(true);
    expect(Validation.checkCardExpiry("01 / 99")).toBe(false);
    expect(Validation.getCurrentMonthAndYear("bad")).toEqual([0, 0]);
  });
});

it("formats supported card patterns and normalizes expiry keystrokes", () => {
  expect(Validation.formatCardNumber("378282246310005", "AMEX")).toBe(
    "3782 822463 10005",
  );
  expect(Validation.formatCardNumber("30569309025904", "DINERSCLUB")).toBe(
    "3056 930902 5904",
  );
  expect(Validation.formatCardNumber("30569309025904123", "DINERSCLUB")).toBe(
    "3056 9309 0259 0412   3",
  );
  expect(Validation.formatCardNumber("1234567890123456789", "NOTFOUND")).toBe(
    "1234 5678 9012 3456789",
  );
  expect(Validation.formatCardExpiryNumber("9")).toBe("09 / ");
  expect(Validation.formatCardExpiryNumber("13")).toBe("01 / 3");
  expect(Validation.formatCardExpiryNumber("12 / 30")).toBe("12 / 30");
  expect(Validation.formatCVCNumber("1a2-345", "AmericanExpress")).toBe("1234");
  expect(
    Validation.format("378282", { TAG: "CardCVC", _0: "AmericanExpress" }),
  ).toBe("3782");
  expect(Validation.getKeyboardType({ TAG: "Required", _0: undefined })).toBe(
    "default",
  );
  expect(
    Validation.getSecureTextEntry({ TAG: "Required", _0: undefined }),
  ).toBe(false);
  expect(Validation.isEmailValid("")).toBeUndefined();
  expect(Validation.toInt("bad")).toBe(0);
});

describe("configured card lengths and CVC contracts for every supported issuer", () => {
  it.each(cardLengthContracts)(
    "enforces %s lengths and checksums",
    (brand, prefix, lengths, cvcLengths) => {
      for (const length of lengths) {
        const number = cardNumber(prefix, length);
        expect(Validation.cardValid(number, brand)).toBe(true);
        expect(
          Validation.cardValid(
            number.slice(0, -1) + ((Number(number.at(-1)) + 1) % 10),
            brand,
          ),
        ).toBe(false);
      }
      for (const length of [lengths[0] - 1, lengths.at(-1)! + 1])
        expect(Validation.cardValid(cardNumber(prefix, length), brand)).toBe(
          false,
        );
      for (const length of [2, 3, 4, 5])
        expect(Validation.checkCardCVC("1".repeat(length), brand)).toBe(
          cvcLengths.includes(length),
        );
    },
  );
});
