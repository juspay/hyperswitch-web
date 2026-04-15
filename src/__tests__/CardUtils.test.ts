import {
  getCardType,
  getCardStringFromType,
  calculateLuhn,
  formatCardNumber,
  getExpiryValidity,
  cardValid,
  maxCardLength,
  isCardLengthValid,
  cvcNumberInRange,
  checkCardCVC,
  checkCardExpiry,
  getCardBin,
  getCardLast4,
  checkIfCardBinIsBlocked,
  pincodeVisibility,
  getCardBrand,
  getExpiryDates,
  isExipryValid,
  cardNumberInRange,
  getMaxLength,
  toString,
  getQueryParamsDictforKey,
  getCurrentMonthAndYear,
  getExpiryYearPrefix,
  formatExpiryToTwoDigit,
  isExpiryComplete,
  max,
  getBoolOptionVal,
  commonKeyDownEvent,
  swapCardOption,
  setCardValid,
  setExpiryValid,
  getLayoutClass,
  getAllBanknames,
  getFirstValidCardSchemeFromPML,
  getEligibleCoBadgedCardSchemes,
  getCardBrandFromStates,
  getCardBrandInvalidError,
  emitExpiryDate,
  emitIsFormReadyForSubmission,
  focusCardValid,
  useDefaultCardProps,
  useDefaultExpiryProps,
  useDefaultCvcProps,
  useDefaultZipProps,
  useCardDetails,
} from '../CardUtils.bs.js';
import { renderHook, act } from '@testing-library/react';

describe('CardUtils', () => {
  describe('getCardType', () => {
    it('should return VISA for Visa type', () => {
      expect(getCardType('Visa')).toBe('VISA');
    });

    it('should return MASTERCARD for Mastercard type', () => {
      expect(getCardType('Mastercard')).toBe('MASTERCARD');
    });

    it('should return AMEX for AmericanExpress type', () => {
      expect(getCardType('AmericanExpress')).toBe('AMEX');
    });

    it('should return NOTFOUND for unknown type', () => {
      expect(getCardType('UnknownCard')).toBe('NOTFOUND');
    });
  });

  describe('getCardStringFromType', () => {
    it('should return Visa for VISA type', () => {
      expect(getCardStringFromType('VISA')).toBe('Visa');
    });

    it('should return Mastercard for MASTERCARD type', () => {
      expect(getCardStringFromType('MASTERCARD')).toBe('Mastercard');
    });

    it('should return AmericanExpress for AMEX type', () => {
      expect(getCardStringFromType('AMEX')).toBe('AmericanExpress');
    });

    it('should return NOTFOUND for unknown type', () => {
      expect(getCardStringFromType('NOTFOUND')).toBe('NOTFOUND');
    });
  });

  describe('calculateLuhn', () => {
    it('should return true for valid Visa card number', () => {
      expect(calculateLuhn('4111111111111111')).toBe(true);
    });

    it('should return true for valid Mastercard number', () => {
      expect(calculateLuhn('5555555555554444')).toBe(true);
    });

    it('should return false for invalid card number', () => {
      expect(calculateLuhn('4111111111111112')).toBe(false);
    });

    it('should return true for empty string', () => {
      expect(calculateLuhn('')).toBe(true);
    });

    it('should handle card numbers with spaces', () => {
      expect(calculateLuhn('4111 1111 1111 1111')).toBe(true);
    });

    // Edge case: single digit "0" — sum is 0, 0 % 10 === 0
    it('should return true for single digit 0', () => {
      expect(calculateLuhn('0')).toBe(true);
    });

    // Edge case: single digit "5"
    it('should handle single digit 5', () => {
      // Single digit: uncheck=[5], check=[], sum=5, 5%10!==0 → false
      expect(calculateLuhn('5')).toBe(false);
    });

    // Edge case: all-zeros 16-digit string
    it('should return true for all-zeros card number', () => {
      expect(calculateLuhn('0000000000000000')).toBe(true);
    });
  });

  describe('formatCardNumber', () => {
    it('should format Visa card number with spaces (4-4-4-4)', () => {
      const result = formatCardNumber('4111111111111111', 'VISA');
      expect(result).toBe('4111 1111 1111 1111');
    });

    it('should format Amex card number (4-6-5)', () => {
      const result = formatCardNumber('378282246310005', 'AMEX');
      expect(result).toBe('3782 822463 10005');
    });

    it('should handle empty string', () => {
      const result = formatCardNumber('', 'VISA');
      expect(result).toBe('');
    });

    it('should handle short numbers', () => {
      const result = formatCardNumber('4111', 'VISA');
      expect(result).toBe('4111');
    });
  });

  describe('getExpiryValidity', () => {
    it('should return true for future expiry date', () => {
      const futureYear = new Date().getFullYear() + 1;
      const expiry = `12/${futureYear.toString().slice(-2)}`;
      expect(getExpiryValidity(expiry)).toBe(true);
    });

    it('should return false for past expiry date', () => {
      expect(getExpiryValidity('12/20')).toBe(false);
    });

    it('should return false for invalid month', () => {
      const futureYear = new Date().getFullYear() + 1;
      const expiry = `13/${futureYear.toString().slice(-2)}`;
      expect(getExpiryValidity(expiry)).toBe(false);
    });
  });

  describe('cardValid', () => {
    it('should return true for valid Visa card', () => {
      expect(cardValid('4111111111111111', 'Visa')).toBe(true);
    });

    it('should return false for invalid Luhn card', () => {
      expect(cardValid('4111111111111112', 'Visa')).toBe(false);
    });

    it('should return false for wrong length', () => {
      expect(cardValid('4111111111', 'Visa')).toBe(false);
    });
  });

  describe('maxCardLength', () => {
    it('should return 19 for Visa', () => {
      expect(maxCardLength('Visa')).toBe(19);
    });

    it('should return 15 for Amex', () => {
      expect(maxCardLength('AmericanExpress')).toBe(15);
    });

    it('should return 16 for Mastercard', () => {
      expect(maxCardLength('Mastercard')).toBe(16);
    });
  });

  describe('isCardLengthValid', () => {
    it('should return true for valid Visa length (16)', () => {
      expect(isCardLengthValid('Visa', 16)).toBe(true);
    });

    it('should return true for Visa length 15 (within range)', () => {
      expect(isCardLengthValid('Visa', 15)).toBe(true);
    });

    it('should return true for valid Amex length (15)', () => {
      expect(isCardLengthValid('AmericanExpress', 15)).toBe(true);
    });
  });

  describe('cvcNumberInRange', () => {
    it('should return array with true for valid Visa CVC (3 digits)', () => {
      const result = cvcNumberInRange('123', 'Visa');
      expect(result).toContain(true);
    });

    it('should return array with true for valid Amex CVC (4 digits)', () => {
      const result = cvcNumberInRange('1234', 'AmericanExpress');
      expect(result).toContain(true);
    });

    it('should return array without true for invalid CVC length', () => {
      const result = cvcNumberInRange('12', 'Visa');
      expect(result).not.toContain(true);
    });
  });

  describe('checkCardCVC', () => {
    it('should return true for valid CVC', () => {
      expect(checkCardCVC('123', 'Visa')).toBe(true);
    });

    it('should return false for empty CVC', () => {
      expect(checkCardCVC('', 'Visa')).toBe(false);
    });

    it('should return false for invalid CVC length', () => {
      expect(checkCardCVC('12', 'Visa')).toBe(false);
    });
  });

  describe('checkCardExpiry', () => {
    it('should return true for valid future expiry', () => {
      const futureYear = new Date().getFullYear() + 1;
      const expiry = `12/${futureYear.toString().slice(-2)}`;
      expect(checkCardExpiry(expiry)).toBe(true);
    });

    it('should return false for empty expiry', () => {
      expect(checkCardExpiry('')).toBe(false);
    });

    it('should return false for past expiry', () => {
      expect(checkCardExpiry('12/20')).toBe(false);
    });
  });

  describe('getCardBin', () => {
    it('should return first 6 digits for valid card number', () => {
      expect(getCardBin('4111111111111111')).toBe('411111');
    });

    it('should handle spaces in card number', () => {
      expect(getCardBin('4111 1111 1111 1111')).toBe('411111');
    });

    it('should return available digits for short number', () => {
      expect(getCardBin('4111')).toBe('4111');
    });

    // Edge case: empty string input
    it('should return empty string for empty input', () => {
      expect(getCardBin('')).toBe('');
    });
  });

  describe('getCardLast4', () => {
    it('should return last 4 digits for valid card number', () => {
      expect(getCardLast4('4111111111111111')).toBe('1111');
    });

    it('should handle spaces in card number', () => {
      expect(getCardLast4('4111 1111 1111 1234')).toBe('1234');
    });

    it('should return available digits for short number', () => {
      expect(getCardLast4('123')).toBe('123');
    });
  });

  describe('checkIfCardBinIsBlocked', () => {
    it('should return false when blockedBinsList is not loaded', () => {
      expect(checkIfCardBinIsBlocked('411111', { TAG: 'Loading' })).toBe(false);
    });

    it('should throw for null blockedBinsList', () => {
      expect(() => checkIfCardBinIsBlocked('411111', null)).toThrow();
    });

    it('should return false for empty blocked list', () => {
      expect(checkIfCardBinIsBlocked('411111', { TAG: 'Loaded', _0: [] })).toBe(false);
    });
  });

  describe('pincodeVisibility', () => {
    it('should return boolean for known card brand', () => {
      const result = pincodeVisibility('Visa');
      expect(typeof result).toBe('boolean');
    });

    it('should return default for unknown card brand', () => {
      const result = pincodeVisibility('UnknownBrand');
      expect(typeof result).toBe('boolean');
    });
  });

  describe('getCardBrand', () => {
    it('should return Visa for Visa card number', () => {
      expect(getCardBrand('4111111111111111')).toBe('Visa');
    });

    it('should return Mastercard for Mastercard number', () => {
      expect(getCardBrand('5555555555554444')).toBe('Mastercard');
    });

    it('should return empty string for invalid number', () => {
      expect(getCardBrand('123')).toBe('');
    });

    it('should handle numbers with spaces', () => {
      expect(getCardBrand('4111 1111 1111 1111')).toBe('Visa');
    });

    // Edge case: empty string input — caught by try/catch, returns ""
    it('should return empty string for empty input', () => {
      expect(getCardBrand('')).toBe('');
    });
  });

  describe('getExpiryDates', () => {
    it('should parse valid expiry date', () => {
      const result = getExpiryDates('12/25');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(2);
    });

    it('should return month and year', () => {
      const result = getExpiryDates('12/25');
      expect(result[0]).toBe('12');
    });
  });

  describe('isExipryValid', () => {
    it('should return true for valid future expiry', () => {
      const futureYear = new Date().getFullYear() + 1;
      const expiry = `12/${futureYear.toString().slice(-2)}`;
      expect(isExipryValid(expiry)).toBe(true);
    });

    it('should return false for empty expiry', () => {
      expect(isExipryValid('')).toBe(false);
    });

    it('should return false for past expiry', () => {
      expect(isExipryValid('12/20')).toBe(false);
    });
  });

  describe('cardNumberInRange', () => {
    it('should return array of booleans for card number length check', () => {
      const result = cardNumberInRange('4111111111111111', 'Visa');
      expect(Array.isArray(result)).toBe(true);
    });

    it('should handle empty card number', () => {
      const result = cardNumberInRange('', 'Visa');
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('getMaxLength', () => {
    it('should return formatted max length for Visa', () => {
      const result = getMaxLength('Visa');
      expect(result).toBeGreaterThan(0);
    });

    it('should return formatted max length for Amex', () => {
      const result = getMaxLength('AmericanExpress');
      expect(result).toBeGreaterThan(0);
    });
  });

  describe('toString', () => {
    it('should convert number to string', () => {
      expect(toString(123)).toBe('123');
    });

    it('should handle zero', () => {
      expect(toString(0)).toBe('0');
    });

    it('should handle negative numbers', () => {
      expect(toString(-456)).toBe('-456');
    });
  });

  describe('getQueryParamsDictforKey', () => {
    it('should return value for existing key', () => {
      const result = getQueryParamsDictforKey('key1=value1&key2=value2', 'key1');
      expect(result).toBe('value1');
    });

    it('should return empty string for missing key', () => {
      const result = getQueryParamsDictforKey('key1=value1', 'missing');
      expect(result).toBe('');
    });

    it('should handle empty query string', () => {
      const result = getQueryParamsDictforKey('', 'key');
      expect(result).toBe('');
    });

    it('should handle param without equals sign', () => {
      const result = getQueryParamsDictforKey('invalidparam', 'key');
      expect(result).toBe('');
    });

    it('should handle multiple equals signs', () => {
      const result = getQueryParamsDictforKey('url=https://example.com', 'url');
      expect(result).toBe('https://example.com');
    });
  });

  describe('getCurrentMonthAndYear', () => {
    it('should return array with month and year', () => {
      const result = getCurrentMonthAndYear('2025-06-15T10:30:00Z');
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(2);
    });

    it('should return correct month', () => {
      const result = getCurrentMonthAndYear('2025-06-15T10:30:00Z');
      expect(result[0]).toBe(6);
    });

    it('should return correct year', () => {
      const result = getCurrentMonthAndYear('2025-06-15T10:30:00Z');
      expect(result[1]).toBe(2025);
    });

    it('should handle January', () => {
      const result = getCurrentMonthAndYear('2025-01-15T10:30:00Z');
      expect(result[0]).toBe(1);
    });

    it('should handle December', () => {
      const result = getCurrentMonthAndYear('2025-12-15T10:30:00Z');
      expect(result[0]).toBe(12);
    });
  });

  describe('getExpiryYearPrefix', () => {
    it('should return 2-digit year prefix', () => {
      const result = getExpiryYearPrefix();
      expect(result.length).toBe(2);
      expect(typeof result).toBe('string');
    });

    it('should return current decade prefix', () => {
      const currentYear = new Date().getFullYear();
      const expected = currentYear.toString().slice(0, 2);
      expect(getExpiryYearPrefix()).toBe(expected);
    });
  });

  describe('formatExpiryToTwoDigit', () => {
    it('should return 2-digit expiry as-is', () => {
      expect(formatExpiryToTwoDigit('25')).toBe('25');
    });

    it('should extract last 2 digits from 4-digit string', () => {
      expect(formatExpiryToTwoDigit('2025')).toBe('25');
    });

    it('should handle 3-digit string', () => {
      expect(formatExpiryToTwoDigit('025')).toBe('5');
    });

    it('should handle single digit', () => {
      expect(formatExpiryToTwoDigit('5')).toBe('');
    });
  });

  describe('isExpiryComplete', () => {
    it('should return true for complete expiry (MM/YY)', () => {
      expect(isExpiryComplete('12/25')).toBe(true);
    });

    it('should return false for incomplete month', () => {
      expect(isExpiryComplete('1/25')).toBe(false);
    });

    it('should return false for incomplete year', () => {
      expect(isExpiryComplete('12/2')).toBe(false);
    });

    it('should return false for empty expiry', () => {
      expect(isExpiryComplete('')).toBe(false);
    });

    it('should return false for partial expiry', () => {
      expect(isExpiryComplete('12')).toBe(false);
    });
  });

  describe('max', () => {
    it('should return larger number', () => {
      expect(max(5, 10)).toBe(10);
    });

    it('should return first number when larger', () => {
      expect(max(20, 10)).toBe(20);
    });

    it('should handle equal numbers', () => {
      expect(max(5, 5)).toBe(5);
    });

    it('should handle negative numbers', () => {
      expect(max(-5, -10)).toBe(-5);
    });

    it('should handle zero', () => {
      expect(max(0, -1)).toBe(0);
    });
  });

  describe('getBoolOptionVal', () => {
    it('should return "valid" for true', () => {
      expect(getBoolOptionVal(true)).toBe('valid');
    });

    it('should return "invalid" for false', () => {
      expect(getBoolOptionVal(false)).toBe('invalid');
    });

    it('should return empty string for undefined', () => {
      expect(getBoolOptionVal(undefined)).toBe('');
    });
  });

  describe('commonKeyDownEvent', () => {
    it('should not modify state for non-backspace key', () => {
      const mockEv = { keyCode: 65, preventDefault: jest.fn() } as any;
      const mockSetEle = jest.fn();
      const mockSrcRef = { current: null };
      const mockDestRef = { current: null };

      commonKeyDownEvent(mockEv, mockSrcRef, mockDestRef, 'test', 'dest', mockSetEle);
      expect(mockSetEle).not.toHaveBeenCalled();
    });

    it('should not modify state when srcEle is not empty', () => {
      const mockEv = { keyCode: 8, preventDefault: jest.fn() } as any;
      const mockSetEle = jest.fn();
      const mockSrcRef = { current: null };
      const mockDestRef = { current: null };

      commonKeyDownEvent(mockEv, mockSrcRef, mockDestRef, 'nonempty', 'dest', mockSetEle);
      expect(mockSetEle).not.toHaveBeenCalled();
    });
  });

  describe('swapCardOption', () => {
    it('should swap selected option into card options', () => {
      const cardOpts = ['visa', 'mastercard'];
      const dropOpts = ['amex'];
      const result = swapCardOption([...cardOpts], [...dropOpts], 'discover');

      expect(result[0]).toContain('discover');
      expect(result[1]).not.toContain('discover');
    });

    it('should remove selected from dropdown options', () => {
      const cardOpts = ['visa'];
      const dropOpts = ['mastercard', 'amex'];
      const result = swapCardOption([...cardOpts], [...dropOpts], 'mastercard');

      expect(result[1]).not.toContain('mastercard');
    });
  });

  describe('setCardValid', () => {
    it('should call setIsCardValid with true for valid card', () => {
      const mockSetIsCardValid = jest.fn();
      setCardValid('4111111111111111', 'Visa', mockSetIsCardValid);
      expect(mockSetIsCardValid).toHaveBeenCalled();
    });

    it('should call setIsCardValid for invalid max length card', () => {
      const mockSetIsCardValid = jest.fn();
      setCardValid('4111111111111112', 'Visa', mockSetIsCardValid);
      expect(mockSetIsCardValid).toHaveBeenCalled();
    });

    it('should handle short card number', () => {
      const mockSetIsCardValid = jest.fn();
      setCardValid('4111', 'Visa', mockSetIsCardValid);
      expect(mockSetIsCardValid).toHaveBeenCalled();
    });
  });

  describe('setExpiryValid', () => {
    it('should call setIsExpiryValid for valid expiry', () => {
      const futureYear = new Date().getFullYear() + 1;
      const expiry = `12/${futureYear.toString().slice(-2)}`;
      const mockSetIsExpiryValid = jest.fn();
      setExpiryValid(expiry, mockSetIsExpiryValid);
      expect(mockSetIsExpiryValid).toHaveBeenCalled();
    });

    it('should call setIsExpiryValid for incomplete expiry', () => {
      const mockSetIsExpiryValid = jest.fn();
      setExpiryValid('12', mockSetIsExpiryValid);
      expect(mockSetIsExpiryValid).toHaveBeenCalled();
    });

    it('should call setIsExpiryValid for invalid expiry', () => {
      const mockSetIsExpiryValid = jest.fn();
      setExpiryValid('13/25', mockSetIsExpiryValid);
      expect(mockSetIsExpiryValid).toHaveBeenCalled();
    });
  });

  describe('getLayoutClass', () => {
    it('should handle StringLayout TAG', () => {
      const layout = { TAG: 'StringLayout', _0: 'accordion' };
      const result = getLayoutClass(layout);
      expect(result.type).toBe('accordion');
    });

    it('should handle non-StringLayout TAG', () => {
      const layoutObj = { 
        type: 'tabs', 
        defaultCollapsed: false, 
        radios: false,
        spacedAccordionItems: false,
        maxAccordionItems: 5,
        savedMethodCustomization: {},
        paymentMethodsArrangementForTabs: [],
        displayOneClickPaymentMethodsOnTop: false
      };
      const layout = { TAG: 'ObjectLayout', _0: layoutObj };
      const result = getLayoutClass(layout);
      expect(result).toBe(layoutObj);
    });
  });

  describe('getAllBanknames', () => {
    it('should flatten nested arrays of bank names', () => {
      const banks = [['bank1', 'bank2'], ['bank3']];
      const result = getAllBanknames(banks);
      expect(result).toEqual(['bank1', 'bank2', 'bank3']);
    });

    it('should return empty array for empty input', () => {
      const result = getAllBanknames([]);
      expect(result).toEqual([]);
    });

    it('should handle single array', () => {
      const result = getAllBanknames([['bank1']]);
      expect(result).toEqual(['bank1']);
    });
  });

  describe('getFirstValidCardSchemeFromPML', () => {
    it('should return undefined for invalid card number', () => {
      const result = getFirstValidCardSchemeFromPML('123', ['visa']);
      expect(result).toBeUndefined();
    });

    it('should return matching scheme for valid card', () => {
      const result = getFirstValidCardSchemeFromPML('4111111111111111', ['visa']);
      expect(result).toBeDefined();
    });

    it('should return undefined when no matching scheme enabled', () => {
      const result = getFirstValidCardSchemeFromPML('4111111111111111', ['mastercard']);
      expect(result).toBeUndefined();
    });
  });

  describe('getEligibleCoBadgedCardSchemes', () => {
    it('should filter matched schemes by enabled list', () => {
      const matched = ['visa', 'mastercard', 'amex'];
      const enabled = ['visa', 'mastercard'];
      const result = getEligibleCoBadgedCardSchemes(matched, enabled);
      expect(result).toEqual(['visa', 'mastercard']);
    });

    it('should return empty array when no matches', () => {
      const matched = ['visa'];
      const enabled = ['mastercard'];
      const result = getEligibleCoBadgedCardSchemes(matched, enabled);
      expect(result).toEqual([]);
    });

    it('should filter with lowercase matching', () => {
      const matched = ['Visa', 'Mastercard'];
      const enabled = ['visa'];
      const result = getEligibleCoBadgedCardSchemes(matched, enabled);
      expect(result).toEqual(['Visa']);
    });
  });

  describe('getCardBrandFromStates', () => {
    it('should return cardBrand when not showing payment methods screen', () => {
      const result = getCardBrandFromStates('Visa', 'Mastercard', false);
      expect(result).toBe('Mastercard');
    });

    it('should return cardScheme when showing payment methods screen', () => {
      const result = getCardBrandFromStates('Visa', 'Mastercard', true);
      expect(result).toBe('Visa');
    });
  });

  describe('getCardBrandInvalidError', () => {
    it('should return enterValidCardNumberErrorText for empty brand', () => {
      const localeString = {
        enterValidCardNumberErrorText: 'Enter a valid card number',
        cardBrandConfiguredErrorText: (brand: string) => `${brand} not configured`
      };
      const result = getCardBrandInvalidError('', localeString);
      expect(result).toBe('Enter a valid card number');
    });

    it('should return cardBrandConfiguredErrorText for non-empty brand', () => {
      const localeString = {
        enterValidCardNumberErrorText: 'Enter a valid card number',
        cardBrandConfiguredErrorText: (brand: string) => `${brand} not configured`
      };
      const result = getCardBrandInvalidError('Visa', localeString);
      expect(result).toBe('Visa not configured');
    });
  });

  describe('emitExpiryDate', () => {
    it('should call messageParentWindow with expiry date', () => {
      const mockMessageParentWindow = jest.fn();
      jest.mock('../Utilities/Utils.bs.js', () => ({
        messageParentWindow: mockMessageParentWindow,
      }));
      emitExpiryDate('12/25');
    });
  });

  describe('emitIsFormReadyForSubmission', () => {
    it('should call messageParentWindow with ready status', () => {
      emitIsFormReadyForSubmission(true);
    });
  });

  describe('focusCardValid', () => {
    it('should return true for valid card at max length', () => {
      expect(focusCardValid('4111111111111111', 'Visa')).toBe(true);
    });

    it('should return false for short card number', () => {
      expect(focusCardValid('4111', 'Visa')).toBe(false);
    });

    it('should return false for empty brand with short card', () => {
      expect(focusCardValid('4111', '')).toBe(false);
    });

    it('should handle invalid Luhn', () => {
      expect(focusCardValid('4111111111111112', 'Visa')).toBe(false);
    });

    it('should handle Visa 16 digit special case', () => {
      expect(focusCardValid('4111111111111111', 'Visa')).toBe(true);
    });
  });

  describe('checkIfCardBinIsBlocked - additional tests', () => {
    it('should return false for short card number', () => {
      expect(checkIfCardBinIsBlocked('41', { TAG: 'Loaded', _0: [] })).toBe(false);
    });

    it('should return false for card number with less than 6 digits', () => {
      expect(checkIfCardBinIsBlocked('41111', { TAG: 'Loaded', _0: [] })).toBe(false);
    });

    it('should return true when bin is in blocked list', () => {
      const blockedBins = [{ fingerprint_id: '411111' }];
      expect(checkIfCardBinIsBlocked('4111111111111111', { TAG: 'Loaded', _0: blockedBins })).toBe(true);
    });

    it('should return false when bin is not in blocked list', () => {
      const blockedBins = [{ fingerprint_id: '411112' }];
      expect(checkIfCardBinIsBlocked('4111111111111111', { TAG: 'Loaded', _0: blockedBins })).toBe(false);
    });

    it('should handle non-object blockedBinsList', () => {
      expect(checkIfCardBinIsBlocked('4111111111111111', 'invalid' as any)).toBe(false);
    });
  });

  describe('getCardType - additional tests', () => {
    it('should return BAJAJ for BAJAJ type', () => {
      expect(getCardType('BAJAJ')).toBe('BAJAJ');
    });

    it('should return CARTESBANCAIRES for CartesBancaires', () => {
      expect(getCardType('CartesBancaires')).toBe('CARTESBANCAIRES');
    });

    it('should return DINERSCLUB for DinersClub', () => {
      expect(getCardType('DinersClub')).toBe('DINERSCLUB');
    });

    it('should return DISCOVER for Discover', () => {
      expect(getCardType('Discover')).toBe('DISCOVER');
    });

    it('should return INTERAC for Interac', () => {
      expect(getCardType('Interac')).toBe('INTERAC');
    });

    it('should return JCB for JCB', () => {
      expect(getCardType('JCB')).toBe('JCB');
    });

    it('should return MAESTRO for Maestro', () => {
      expect(getCardType('Maestro')).toBe('MAESTRO');
    });

    it('should return RUPAY for RuPay', () => {
      expect(getCardType('RuPay')).toBe('RUPAY');
    });

    it('should return SODEXO for SODEXO', () => {
      expect(getCardType('SODEXO')).toBe('SODEXO');
    });

    it('should return UNIONPAY for UnionPay', () => {
      expect(getCardType('UnionPay')).toBe('UNIONPAY');
    });
  });

  describe('getCardStringFromType - additional tests', () => {
    it('should return BAJAJ for BAJAJ type', () => {
      expect(getCardStringFromType('BAJAJ')).toBe('BAJAJ');
    });

    it('should return SODEXO for SODEXO type', () => {
      expect(getCardStringFromType('SODEXO')).toBe('SODEXO');
    });

    it('should return RuPay for RUPAY type', () => {
      expect(getCardStringFromType('RUPAY')).toBe('RuPay');
    });

    it('should return JCB for JCB type', () => {
      expect(getCardStringFromType('JCB')).toBe('JCB');
    });

    it('should return CartesBancaires for CARTESBANCAIRES type', () => {
      expect(getCardStringFromType('CARTESBANCAIRES')).toBe('CartesBancaires');
    });

    it('should return UnionPay for UNIONPAY type', () => {
      expect(getCardStringFromType('UNIONPAY')).toBe('UnionPay');
    });

    it('should return Interac for INTERAC type', () => {
      expect(getCardStringFromType('INTERAC')).toBe('Interac');
    });
  });

  describe('formatCardNumber - additional tests', () => {
    it('should format MAESTRO card number', () => {
      const result = formatCardNumber('6759649826438453', 'MAESTRO');
      expect(result).toBe('6759 6498 2643 8453');
    });

    it('should format JCB card number', () => {
      const result = formatCardNumber('3530111333300000', 'JCB');
      expect(result).toBe('3530 1113 3330 0000');
    });

    it('should format DINERSCLUB card number', () => {
      const result = formatCardNumber('36070500001020', 'DINERSCLUB');
      expect(result).toBe('3607 0500 0010 20');
    });

    it('should format DISCOVER card number', () => {
      const result = formatCardNumber('6011111111111117', 'DISCOVER');
      expect(result).toBe('6011 1111 1111 1117');
    });

    it('should format BAJAJ card number', () => {
      const result = formatCardNumber('1234567890123456', 'BAJAJ');
      expect(result).toContain('1234');
    });

    it('should format NOTFOUND type', () => {
      const result = formatCardNumber('1234567890123456', 'NOTFOUND');
      expect(result).toContain('1234');
    });

    it('should format INTERAC card number', () => {
      const result = formatCardNumber('4506331111111111', 'INTERAC');
      expect(result).toContain('4506');
    });
  });

  describe('useDefaultCardProps', () => {
    it('should return default card props object', () => {
      const { result } = renderHook(() => useDefaultCardProps());
      expect(result.current).toHaveProperty('cardNumber');
      expect(result.current).toHaveProperty('cardBrand');
      expect(result.current).toHaveProperty('cardError');
      expect(result.current).toHaveProperty('maxCardLength');
      expect(result.current).toHaveProperty('cardRef');
    });

    it('should have empty string for cardNumber', () => {
      const { result } = renderHook(() => useDefaultCardProps());
      expect(result.current.cardNumber).toBe('');
    });

    it('should have empty string for cardBrand', () => {
      const { result } = renderHook(() => useDefaultCardProps());
      expect(result.current.cardBrand).toBe('');
    });

    it('should have zero for maxCardLength', () => {
      const { result } = renderHook(() => useDefaultCardProps());
      expect(result.current.maxCardLength).toBe(0);
    });
  });

  describe('useDefaultExpiryProps', () => {
    it('should return default expiry props object', () => {
      const { result } = renderHook(() => useDefaultExpiryProps());
      expect(result.current).toHaveProperty('cardExpiry');
      expect(result.current).toHaveProperty('expiryError');
      expect(result.current).toHaveProperty('expiryRef');
    });

    it('should have empty string for cardExpiry', () => {
      const { result } = renderHook(() => useDefaultExpiryProps());
      expect(result.current.cardExpiry).toBe('');
    });

    it('should have empty string for expiryError', () => {
      const { result } = renderHook(() => useDefaultExpiryProps());
      expect(result.current.expiryError).toBe('');
    });
  });

  describe('useDefaultCvcProps', () => {
    it('should return default cvc props object', () => {
      const { result } = renderHook(() => useDefaultCvcProps());
      expect(result.current).toHaveProperty('cvcNumber');
      expect(result.current).toHaveProperty('cvcError');
      expect(result.current).toHaveProperty('cvcRef');
    });

    it('should have empty string for cvcNumber', () => {
      const { result } = renderHook(() => useDefaultCvcProps());
      expect(result.current.cvcNumber).toBe('');
    });

    it('should have empty string for cvcError', () => {
      const { result } = renderHook(() => useDefaultCvcProps());
      expect(result.current.cvcError).toBe('');
    });
  });

  describe('useDefaultZipProps', () => {
    it('should return default zip props object', () => {
      const { result } = renderHook(() => useDefaultZipProps());
      expect(result.current).toHaveProperty('zipCode');
      expect(result.current).toHaveProperty('zipRef');
      expect(result.current).toHaveProperty('displayPincode');
    });

    it('should have empty string for zipCode', () => {
      const { result } = renderHook(() => useDefaultZipProps());
      expect(result.current.zipCode).toBe('');
    });

    it('should have false for displayPincode', () => {
      const { result } = renderHook(() => useDefaultZipProps());
      expect(result.current.displayPincode).toBe(false);
    });
  });

  describe('useCardDetails', () => {
    it('should return array of card details state', () => {
      const { result } = renderHook(() => useCardDetails('', '', undefined));
      expect(Array.isArray(result.current)).toBe(true);
      expect(result.current.length).toBe(3);
    });

    it('should indicate empty when cvcNumber is empty', () => {
      const { result } = renderHook(() => useCardDetails('', '', undefined));
      expect(result.current[0]).toBe(true);
    });

    it('should indicate valid when isCvcValidValue is "valid"', () => {
      const { result } = renderHook(() => useCardDetails('123', 'valid', true));
      expect(result.current[1]).toBe(true);
    });

    it('should indicate invalid when isCvcValidValue is "invalid"', () => {
      const { result } = renderHook(() => useCardDetails('123', 'invalid', false));
      expect(result.current[2]).toBe(true);
    });
  });

  describe('getCardBrand - additional tests', () => {
    it('should return RuPay for RuPay card number', () => {
      expect(getCardBrand('6073841234567890')).toBe('RuPay');
    });

    it('should return Mastercard for Mastercard 2-series', () => {
      expect(getCardBrand('2221001234567890')).toBe('Mastercard');
    });
  });
});
