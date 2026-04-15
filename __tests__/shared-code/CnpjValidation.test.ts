import {
  cnpjLength,
  invalidCNPJs,
  isNumeric,
  isUppercaseAlphanumeric,
  isCNPJValidFormat,
  charToValue,
  calculateCheckDigit,
  validateCNPJ,
  isValidCNPJ,
} from '../../shared-code/sdk-utils/validation/CnpjValidation.bs.js';

describe('CnpjValidation', () => {
  describe('cnpjLength', () => {
    it('should be 14', () => {
      expect(cnpjLength).toBe(14);
    });
  });

  describe('invalidCNPJs', () => {
    it('should contain known invalid CNPJs', () => {
      expect(invalidCNPJs).toContain('00000000000000');
      expect(invalidCNPJs).toContain('11111111111111');
      expect(invalidCNPJs).toContain('99999999999999');
    });

    it('should have 10 entries', () => {
      expect(invalidCNPJs).toHaveLength(10);
    });
  });

  describe('isNumeric', () => {
    it('should return true for digits only', () => {
      expect(isNumeric('1234567890')).toBe(true);
    });

    it('should return true for empty string', () => {
      expect(isNumeric('')).toBe(true);
    });

    it('should return false for string with letters', () => {
      expect(isNumeric('123ABC')).toBe(false);
    });

    it('should return false for string with special characters', () => {
      expect(isNumeric('123-456')).toBe(false);
    });
  });

  describe('isUppercaseAlphanumeric', () => {
    it('should return true for uppercase letters and digits', () => {
      expect(isUppercaseAlphanumeric('ABC123')).toBe(true);
    });

    it('should return true for empty string', () => {
      expect(isUppercaseAlphanumeric('')).toBe(true);
    });

    it('should return false for lowercase letters', () => {
      expect(isUppercaseAlphanumeric('abc123')).toBe(false);
    });

    it('should return false for special characters', () => {
      expect(isUppercaseAlphanumeric('ABC-123')).toBe(false);
    });
  });

  describe('isCNPJValidFormat', () => {
    it('should return true for valid CNPJ format with all digits', () => {
      expect(isCNPJValidFormat('11222333000181')).toBe(true);
    });

    it('should return true for valid CNPJ format with alphanumeric base', () => {
      expect(isCNPJValidFormat('ABC12345678901')).toBe(true);
    });

    it('should return false for CNPJ with letters in check digits', () => {
      expect(isCNPJValidFormat('112223330001AB')).toBe(false);
    });

    it('should return false for CNPJ with lowercase letters', () => {
      expect(isCNPJValidFormat('abc12345678901')).toBe(false);
    });

    it('should return true for valid format even if check digits section is short', () => {
      expect(isCNPJValidFormat('1234567890123')).toBe(true);
    });

    it('should return false for CNPJ with special characters in base', () => {
      expect(isCNPJValidFormat('ABC-1234567891')).toBe(false);
    });
  });

  describe('charToValue', () => {
    it('should return correct value for digit 0', () => {
      expect(charToValue('0')).toBe(0);
    });

    it('should return correct value for digit 9', () => {
      expect(charToValue('9')).toBe(9);
    });

    it('should return correct value for uppercase A', () => {
      expect(charToValue('A')).toBe(17);
    });

    it('should return correct value for uppercase Z', () => {
      expect(charToValue('Z')).toBe(42);
    });

    it('should return 0 for lowercase letters', () => {
      expect(charToValue('a')).toBe(0);
    });

    it('should return 0 for special characters', () => {
      expect(charToValue('-')).toBe(0);
    });
  });

  describe('calculateCheckDigit', () => {
    it('should calculate correct check digit for first digit', () => {
      const values = [1, 1, 2, 2, 2, 3, 3, 3, 0, 0, 0, 1];
      const weights = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      expect(calculateCheckDigit(values, weights)).toBe(8);
    });

    it('should return 0 when remainder is less than 2', () => {
      const values = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      const weights = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      expect(calculateCheckDigit(values, weights)).toBe(0);
    });

    it('should handle empty values array', () => {
      expect(calculateCheckDigit([], [])).toBe(0);
    });
  });

  describe('validateCNPJ', () => {
    it('should return true for valid CNPJ', () => {
      expect(validateCNPJ('11222333000181')).toBe(true);
    });

    it('should return false for invalid check digits', () => {
      expect(validateCNPJ('11222333000182')).toBe(false);
    });

    it('should return false for CNPJ with wrong length', () => {
      expect(validateCNPJ('1234567890123')).toBe(false);
    });
  });

  describe('isValidCNPJ', () => {
    it('should return true for valid CNPJ', () => {
      expect(isValidCNPJ('11222333000181')).toBe(true);
    });

    it('should return false for CNPJ in invalid list', () => {
      expect(isValidCNPJ('00000000000000')).toBe(false);
      expect(isValidCNPJ('11111111111111')).toBe(false);
    });

    it('should return false for wrong length', () => {
      expect(isValidCNPJ('1234567890')).toBe(false);
    });

    it('should return false for invalid format', () => {
      expect(isValidCNPJ('abcdefghijklmn')).toBe(false);
    });

    it('should return false for invalid check digits', () => {
      expect(isValidCNPJ('11222333000182')).toBe(false);
    });
  });
});
