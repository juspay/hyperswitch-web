import {
  calculateLuhn,
  isEmailValid,
  containsOnlyDigits,
  cardValid,
  maxCardLength,
  cvcNumberInRange,
  getCardBrand,
  checkCardCVC,
  checkCardExpiry,
} from '../../shared-code/sdk-utils/validation/Validation.bs.js';

import { snakeToPascalCase } from '../../shared-code/sdk-utils/utils/CommonUtils.bs.js';

import { isEmailValid as isEmailValidFromEmailValidation } from '../../shared-code/sdk-utils/validation/EmailValidation.bs.js';

import { isValidCPF as isValidCPFFromCpfValidation } from '../../shared-code/sdk-utils/validation/CpfValidation.bs.js';

describe('SharedCodeWeb', () => {
  describe('Validation.bs.js', () => {
    describe('calculateLuhn', () => {
      it('should return true for valid card number', () => {
        expect(calculateLuhn('4111111111111111')).toBe(true);
      });

      it('should return false for invalid card number', () => {
        expect(calculateLuhn('4111111111111112')).toBe(false);
      });

      it('should handle empty string', () => {
        expect(calculateLuhn('')).toBe(true);
      });
    });

    describe('isEmailValid', () => {
      it('should return true for valid email', () => {
        expect(isEmailValid('user@example.com')).toBe(true);
      });

      it('should return false for invalid email', () => {
        expect(isEmailValid('invalid-email')).toBe(false);
      });

      it('should return undefined for empty email', () => {
        expect(isEmailValid('')).toBeUndefined();
      });
    });

    describe('containsOnlyDigits', () => {
      it('should return true for digits only', () => {
        expect(containsOnlyDigits('12345')).toBe(true);
      });

      it('should return false for non-digits', () => {
        expect(containsOnlyDigits('abc123')).toBe(false);
      });

      it('should return true for empty string', () => {
        expect(containsOnlyDigits('')).toBe(true);
      });
    });

    describe('cardValid', () => {
      it('should return true for valid Visa card', () => {
        expect(cardValid('4111111111111111', 'Visa')).toBe(true);
      });

      it('should return false for invalid card', () => {
        expect(cardValid('4111111111111112', 'Visa')).toBe(false);
      });
    });

    describe('maxCardLength', () => {
      it('should return correct max length for Visa', () => {
        expect(maxCardLength('Visa')).toBe(19);
      });

      it('should return correct max length for Amex', () => {
        expect(maxCardLength('AmericanExpress')).toBe(15);
      });
    });

    describe('cvcNumberInRange', () => {
      it('should return true for valid Visa CVC', () => {
        expect(cvcNumberInRange('123', 'Visa')).toBe(true);
      });

      it('should return true for valid Amex CVC', () => {
        expect(cvcNumberInRange('1234', 'AmericanExpress')).toBe(true);
      });
    });

    describe('getCardBrand', () => {
      it('should return Visa for Visa number', () => {
        expect(getCardBrand('4111111111111111')).toBe('Visa');
      });

      it('should return Mastercard for Mastercard number', () => {
        expect(getCardBrand('5555555555554444')).toBe('Mastercard');
      });
    });

    describe('checkCardCVC', () => {
      it('should return true for valid CVC', () => {
        expect(checkCardCVC('123', 'Visa')).toBe(true);
      });

      it('should return false for empty CVC', () => {
        expect(checkCardCVC('', 'Visa')).toBe(false);
      });
    });

    describe('checkCardExpiry', () => {
      it('should return true for valid future expiry', () => {
        const futureYear = new Date().getFullYear() + 1;
        const expiry = `12/${futureYear.toString().slice(-2)}`;
        expect(checkCardExpiry(expiry)).toBe(true);
      });

      it('should return false for past expiry', () => {
        expect(checkCardExpiry('12/20')).toBe(false);
      });
    });

    describe('isValidCPF', () => {
      it('should return true for valid CPF', () => {
        expect(isValidCPFFromCpfValidation('52998224725')).toBe(true);
      });

      it('should return false for invalid CPF', () => {
        expect(isValidCPFFromCpfValidation('12345678901')).toBe(false);
      });

      it('should return false for CPF with all same digits', () => {
        expect(isValidCPFFromCpfValidation('11111111111')).toBe(false);
      });
    });
  });

  describe('CommonUtils.bs.js', () => {
    describe('snakeToPascalCase', () => {
      it('should convert snake_case to PascalCase', () => {
        expect(snakeToPascalCase('hello_world')).toBe('HelloWorld');
      });

      it('should handle single word', () => {
        expect(snakeToPascalCase('hello')).toBe('Hello');
      });

      it('should handle empty string', () => {
        expect(snakeToPascalCase('')).toBe('');
      });

      it('should handle multiple underscores', () => {
        expect(snakeToPascalCase('hello__world')).toBe('HelloWorld');
      });
    });
  });

  describe('EmailValidation.bs.js', () => {
    describe('isEmailValid', () => {
      it('should return true for valid email', () => {
        expect(isEmailValidFromEmailValidation('user@example.com')).toBe(true);
      });

      it('should return false for invalid email', () => {
        expect(isEmailValidFromEmailValidation('invalid')).toBe(false);
      });

      it('should return undefined for empty string', () => {
        expect(isEmailValidFromEmailValidation('')).toBeUndefined();
      });

      it('should handle complex email', () => {
        expect(isEmailValidFromEmailValidation('user.name+tag@subdomain.example.com')).toBe(true);
      });
    });
  });

  describe('CpfValidation.bs.js', () => {
    describe('isValidCPF', () => {
      it('should return true for valid CPF', () => {
        expect(isValidCPFFromCpfValidation('52998224725')).toBe(true);
      });

      it('should return false for invalid CPF format', () => {
        expect(isValidCPFFromCpfValidation('123')).toBe(false);
      });

      it('should return false for CPF with letters', () => {
        expect(isValidCPFFromCpfValidation('abcdefghijk')).toBe(false);
      });

      it('should return false for known invalid CPF', () => {
        expect(isValidCPFFromCpfValidation('00000000000')).toBe(false);
        expect(isValidCPFFromCpfValidation('11111111111')).toBe(false);
      });
    });
  });
});
