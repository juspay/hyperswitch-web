import {
  toInt,
  getobjFromCardPattern,
  clearSpaces,
  slice,
  getAllMatchedCardSchemes,
  isCardSchemeEnabled,
  formatCVCNumber,
  getStrFromIndex,
  splitExpiryDates,
  formatCardExpiryNumber,
  cardType,
  formatCardNumber,
} from '../../shared-code/sdk-utils/validation/CardValidations.bs.js';

describe('CardValidations', () => {
  describe('toInt', () => {
    it('should convert string number to integer', () => {
      expect(toInt('123')).toBe(123);
      expect(toInt('0')).toBe(0);
      expect(toInt('999')).toBe(999);
    });

    it('should return 0 for non-numeric strings', () => {
      expect(toInt('abc')).toBe(0);
      expect(toInt('')).toBe(0);
      expect(toInt('12abc')).toBe(12);
    });

    it('should handle negative numbers', () => {
      expect(toInt('-123')).toBe(-123);
      expect(toInt('-0')).toBe(0);
    });

    it('should handle decimal strings by parsing integer part', () => {
      expect(toInt('12.34')).toBe(12);
      expect(toInt('0.5')).toBe(0);
    });

    it('should handle whitespace in string', () => {
      expect(toInt(' 123 ')).toBe(123);
      expect(toInt('  456  ')).toBe(456);
    });

    it('should handle large numbers', () => {
      expect(toInt('1234567890')).toBe(1234567890);
    });
  });

  describe('getobjFromCardPattern', () => {
    it('should return Visa pattern for "Visa"', () => {
      const result = getobjFromCardPattern('Visa');
      expect(result.issuer).toBe('Visa');
      expect(result.maxCVCLength).toBe(3);
      expect(result.cvcLength).toEqual([3]);
    });

    it('should return Mastercard pattern for "Mastercard"', () => {
      const result = getobjFromCardPattern('Mastercard');
      expect(result.issuer).toBe('Mastercard');
      expect(result.maxCVCLength).toBe(3);
    });

    it('should return AmericanExpress pattern for "AmericanExpress"', () => {
      const result = getobjFromCardPattern('AmericanExpress');
      expect(result.issuer).toBe('AmericanExpress');
      expect(result.maxCVCLength).toBe(4);
      expect(result.cvcLength).toEqual([4]);
    });

    it('should return default pattern for unknown card type', () => {
      const result = getobjFromCardPattern('UnknownCard');
      expect(result.issuer).toBe('');
      expect(result.maxCVCLength).toBe(4);
    });

    it('should return DinersClub pattern', () => {
      const result = getobjFromCardPattern('DinersClub');
      expect(result.issuer).toBe('DinersClub');
      expect(result.maxCVCLength).toBe(3);
    });

    it('should return Discover pattern', () => {
      const result = getobjFromCardPattern('Discover');
      expect(result.issuer).toBe('Discover');
      expect(result.maxCVCLength).toBe(3);
    });
  });

  describe('clearSpaces', () => {
    it('should remove non-digit characters', () => {
      expect(clearSpaces('4242 4242 4242 4242')).toBe('4242424242424242');
      expect(clearSpaces('1234-5678-9012')).toBe('123456789012');
      expect(clearSpaces('12/34')).toBe('1234');
    });

    it('should return only digits from mixed string', () => {
      expect(clearSpaces('abc123def456')).toBe('123456');
      expect(clearSpaces('card 4242 number')).toBe('4242');
    });

    it('should handle string with only digits', () => {
      expect(clearSpaces('1234567890')).toBe('1234567890');
    });

    it('should handle empty string', () => {
      expect(clearSpaces('')).toBe('');
    });

    it('should handle string with no digits', () => {
      expect(clearSpaces('abcdef')).toBe('');
    });

    it('should remove special characters', () => {
      expect(clearSpaces('42.42.42.42')).toBe('42424242');
      expect(clearSpaces('42-42-42-42')).toBe('42424242');
    });
  });

  describe('slice', () => {
    it('should slice string with start and end index', () => {
      expect(slice('hello world', 0, 5)).toBe('hello');
      expect(slice('1234567890', 2, 7)).toBe('34567');
    });

    it('should handle start index only', () => {
      expect(slice('hello world', 6)).toBe('world');
      expect(slice('12345', 2)).toBe('345');
    });

    it('should handle out of bounds gracefully', () => {
      expect(slice('hello', 0, 100)).toBe('hello');
      expect(slice('hello', 10, 20)).toBe('');
    });

    it('should handle negative indices', () => {
      expect(slice('hello', -2)).toBe('lo');
      expect(slice('hello', -5, -2)).toBe('hel');
    });

    it('should return empty string for invalid range', () => {
      expect(slice('hello', 3, 2)).toBe('');
    });

    it('should handle empty string', () => {
      expect(slice('', 0, 5)).toBe('');
    });
  });

  describe('getAllMatchedCardSchemes', () => {
    it('should return Visa for card starting with 4', () => {
      const result = getAllMatchedCardSchemes('4242424242424242');
      expect(result).toContain('Visa');
    });

    it('should return Mastercard for card starting with 51-55', () => {
      const result = getAllMatchedCardSchemes('5242424242424242');
      expect(result).toContain('Mastercard');
    });

    it('should return Mastercard for card starting with 2221-2720', () => {
      const result = getAllMatchedCardSchemes('2221004242424242');
      expect(result).toContain('Mastercard');
    });

    it('should return AmericanExpress for card starting with 34 or 37', () => {
      const result34 = getAllMatchedCardSchemes('342424242424242');
      expect(result34).toContain('AmericanExpress');
      
      const result37 = getAllMatchedCardSchemes('372424242424242');
      expect(result37).toContain('AmericanExpress');
    });

    it('should return Discover for matching pattern', () => {
      const result = getAllMatchedCardSchemes('6011424242424242');
      expect(result).toContain('Discover');
    });

    it('should return DinersClub for matching pattern', () => {
      const result = getAllMatchedCardSchemes('36242424242424');
      expect(result).toContain('DinersClub');
    });

    it('should return JCB for matching pattern', () => {
      const result = getAllMatchedCardSchemes('3530111333300000');
      expect(result).toContain('JCB');
    });

    it('should return empty array for non-matching card number', () => {
      const result = getAllMatchedCardSchemes('0000000000000000');
      expect(result).toEqual([]);
    });

    it('should return Maestro for matching pattern', () => {
      const result = getAllMatchedCardSchemes('5018424242424242');
      expect(result).toContain('Maestro');
    });
  });

  describe('isCardSchemeEnabled', () => {
    it('should return true when scheme is in enabled list', () => {
      expect(isCardSchemeEnabled('Visa', ['Visa', 'Mastercard'])).toBe(true);
      expect(isCardSchemeEnabled('Mastercard', ['Visa', 'Mastercard'])).toBe(true);
    });

    it('should return false when scheme is not in enabled list', () => {
      expect(isCardSchemeEnabled('Amex', ['Visa', 'Mastercard'])).toBe(false);
      expect(isCardSchemeEnabled('Visa', ['Mastercard'])).toBe(false);
    });

    it('should return false for empty enabled list', () => {
      expect(isCardSchemeEnabled('Visa', [])).toBe(false);
    });

    it('should be case sensitive', () => {
      expect(isCardSchemeEnabled('visa', ['Visa'])).toBe(false);
      expect(isCardSchemeEnabled('VISA', ['Visa'])).toBe(false);
    });

    it('should handle duplicate entries in list', () => {
      expect(isCardSchemeEnabled('Visa', ['Visa', 'Visa', 'Mastercard'])).toBe(true);
    });
  });

  describe('formatCVCNumber', () => {
    it('should format CVC for Visa (max 3 digits)', () => {
      expect(formatCVCNumber('123', 'Visa')).toBe('123');
      expect(formatCVCNumber('1234', 'Visa')).toBe('123');
      expect(formatCVCNumber('12', 'Visa')).toBe('12');
    });

    it('should format CVC for AmericanExpress (max 4 digits)', () => {
      expect(formatCVCNumber('1234', 'AmericanExpress')).toBe('1234');
      expect(formatCVCNumber('12345', 'AmericanExpress')).toBe('1234');
      expect(formatCVCNumber('123', 'AmericanExpress')).toBe('123');
    });

    it('should format CVC for Mastercard (max 3 digits)', () => {
      expect(formatCVCNumber('123', 'Mastercard')).toBe('123');
      expect(formatCVCNumber('1234', 'Mastercard')).toBe('123');
    });

    it('should remove non-digits before formatting', () => {
      expect(formatCVCNumber('12a3', 'Visa')).toBe('123');
      expect(formatCVCNumber('1 2 3', 'Visa')).toBe('123');
    });

    it('should handle empty string', () => {
      expect(formatCVCNumber('', 'Visa')).toBe('');
    });

    it('should handle unknown card type (default max 4)', () => {
      expect(formatCVCNumber('12345', 'Unknown')).toBe('1234');
    });
  });

  describe('getStrFromIndex', () => {
    it('should return string at valid index', () => {
      expect(getStrFromIndex(['a', 'b', 'c'], 0)).toBe('a');
      expect(getStrFromIndex(['a', 'b', 'c'], 1)).toBe('b');
      expect(getStrFromIndex(['a', 'b', 'c'], 2)).toBe('c');
    });

    it('should return empty string for out of bounds index', () => {
      expect(getStrFromIndex(['a', 'b', 'c'], 3)).toBe('');
      expect(getStrFromIndex(['a', 'b', 'c'], 10)).toBe('');
      expect(getStrFromIndex(['a', 'b', 'c'], -1)).toBe('');
    });

    it('should return empty string for empty array', () => {
      expect(getStrFromIndex([], 0)).toBe('');
      expect(getStrFromIndex([], 5)).toBe('');
    });

    it('should handle undefined elements', () => {
      const arr: (string | undefined)[] = ['a', undefined, 'c'];
      expect(getStrFromIndex(arr as string[], 1)).toBe('');
    });
  });

  describe('splitExpiryDates', () => {
    it('should split MM/YY format', () => {
      const result = splitExpiryDates('12/25');
      expect(result[0]).toBe('12');
      expect(result[1]).toBe('25');
    });

    it('should split MM / YY format with spaces', () => {
      const result = splitExpiryDates('12 / 25');
      expect(result[0]).toBe('12');
      expect(result[1]).toBe('25');
    });

    it('should handle single digit month', () => {
      const result = splitExpiryDates('1/25');
      expect(result[0]).toBe('1');
      expect(result[1]).toBe('25');
    });

    it('should handle empty parts', () => {
      const result = splitExpiryDates('/25');
      expect(result[0]).toBe('');
      expect(result[1]).toBe('25');
    });

    it('should handle string without separator', () => {
      const result = splitExpiryDates('1225');
      expect(result[0]).toBe('1225');
      expect(result[1]).toBe('');
    });

    it('should handle empty string', () => {
      const result = splitExpiryDates('');
      expect(result[0]).toBe('');
      expect(result[1]).toBe('');
    });
  });

  describe('formatCardExpiryNumber', () => {
    it('should format single digit 2-9 as 0X / ', () => {
      expect(formatCardExpiryNumber('2')).toBe('02 / ');
      expect(formatCardExpiryNumber('5')).toBe('05 / ');
      expect(formatCardExpiryNumber('9')).toBe('09 / ');
    });

    it('should format month > 12 as 0X / Y', () => {
      expect(formatCardExpiryNumber('13')).toBe('01 / 3');
      expect(formatCardExpiryNumber('15')).toBe('01 / 5');
      expect(formatCardExpiryNumber('99')).toBe('09 / 9');
    });

    it('should keep months 01-12 as is', () => {
      expect(formatCardExpiryNumber('01')).toBe('01');
      expect(formatCardExpiryNumber('12')).toBe('12');
    });

    it('should format 3+ digits as MM / YY', () => {
      expect(formatCardExpiryNumber('123')).toBe('12 / 3');
      expect(formatCardExpiryNumber('1225')).toBe('12 / 25');
      expect(formatCardExpiryNumber('0626')).toBe('06 / 26');
    });

    it('should handle month 1 (not 2-9 range)', () => {
      expect(formatCardExpiryNumber('1')).toBe('1');
    });

    it('should remove non-digits before processing', () => {
      expect(formatCardExpiryNumber('12/25')).toBe('12 / 25');
    });

    it('should handle empty string', () => {
      expect(formatCardExpiryNumber('')).toBe('');
    });

    it('should handle 0 as input', () => {
      expect(formatCardExpiryNumber('0')).toBe('0');
    });
  });

  describe('cardType', () => {
    it('should return AMEX for AMEX', () => {
      expect(cardType('AMEX')).toBe('AMEX');
    });

    it('should return VISA for VISA', () => {
      expect(cardType('VISA')).toBe('VISA');
    });

    it('should return MASTERCARD for MASTERCARD', () => {
      expect(cardType('MASTERCARD')).toBe('MASTERCARD');
    });

    it('should return DINERSCLUB for DINERSCLUB', () => {
      expect(cardType('DINERSCLUB')).toBe('DINERSCLUB');
    });

    it('should return DISCOVER for DISCOVER', () => {
      expect(cardType('DISCOVER')).toBe('DISCOVER');
    });

    it('should return JCB for JCB', () => {
      expect(cardType('JCB')).toBe('JCB');
    });

    it('should return MAESTRO for MAESTRO', () => {
      expect(cardType('MAESTRO')).toBe('MAESTRO');
    });

    it('should return RUPAY for RUPAY', () => {
      expect(cardType('RUPAY')).toBe('RUPAY');
    });

    it('should return SODEXO for SODEXO', () => {
      expect(cardType('SODEXO')).toBe('SODEXO');
    });

    it('should return BAJAJ for BAJAJ', () => {
      expect(cardType('BAJAJ')).toBe('BAJAJ');
    });

    it('should return CARTESBANCAIRES for CARTESBANCAIRES', () => {
      expect(cardType('CARTESBANCAIRES')).toBe('CARTESBANCAIRES');
    });

    it('should return NOTFOUND for unknown card type', () => {
      expect(cardType('UNKNOWN')).toBe('NOTFOUND');
      expect(cardType('')).toBe('NOTFOUND');
    });

    it('should be case insensitive (uppercase)', () => {
      expect(cardType('visa')).toBe('VISA');
      expect(cardType('mastercard')).toBe('MASTERCARD');
      expect(cardType('amex')).toBe('AMEX');
    });
  });

  describe('formatCardNumber', () => {
    it('should format Visa card number (16 digits, groups of 4)', () => {
      expect(formatCardNumber('4242424242424242', 'Visa')).toBe('4242 4242 4242 4242');
    });

    it('should format Mastercard card number (16 digits, groups of 4)', () => {
      expect(formatCardNumber('5555555555554444', 'Mastercard')).toBe('5555 5555 5555 4444');
    });

    it('should format AmericanExpress card number (15 digits, 4-6-5)', () => {
      expect(formatCardNumber('378282246310005', 'AMEX')).toBe('3782 822463 10005');
    });

    it('should format DinersClub card number (14 digits)', () => {
      expect(formatCardNumber('38520000023237', 'DINERSCLUB')).toBe('3852 000002 3237');
    });

    it('should format DinersClub card number (16+ digits)', () => {
      const result = formatCardNumber('3852000002323788', 'DINERSCLUB');
      expect(result).toBe('3852 0000 0232 3788');
    });

    it('should format Discover card number', () => {
      expect(formatCardNumber('6011111111111117', 'Discover')).toBe('6011 1111 1111 1117');
    });

    it('should format unknown card type with default spacing', () => {
      expect(formatCardNumber('1234567890123456789', 'Unknown')).toBe('1234 5678 9012 3456789');
    });

    it('should remove non-digits before formatting', () => {
      expect(formatCardNumber('4242-4242-4242-4242', 'Visa')).toBe('4242 4242 4242 4242');
    });

    it('should handle short card numbers', () => {
      expect(formatCardNumber('4242', 'Visa')).toBe('4242');
      expect(formatCardNumber('424242', 'Visa')).toBe('4242 42');
    });

    it('should trim trailing spaces', () => {
      const result = formatCardNumber('4242424242424242', 'Visa');
      expect(result.endsWith(' ')).toBe(false);
    });

    it('should format RuPay card number', () => {
      expect(formatCardNumber('5082123456789012', 'RuPay')).toBe('5082 1234 5678 9012');
    });

    it('should format SODEXO card number', () => {
      expect(formatCardNumber('6375131234567890', 'SODEXO')).toBe('6375 1312 3456 7890');
    });

    it('should format JCB card number', () => {
      expect(formatCardNumber('3530111333300000', 'JCB')).toBe('3530 1113 3330 0000');
    });
  });
});
