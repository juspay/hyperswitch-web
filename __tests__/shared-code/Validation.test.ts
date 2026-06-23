import {
  splitExpiryDates,
  createFieldValidator,
  formatValue,
  validateField,
  format,
  getKeyboardType,
  getSecureTextEntry,
  containsOnlyDigits,
  containsDigit,
  containsMoreThanTwoDigits,
  clearAlphas,
  isEmailValid,
  isValidIban,
  checkCardExpiry,
  getCurrentMonthAndYear,
} from '../../shared-code/sdk-utils/validation/Validation.bs.js';

const mockLocaleObject = {
  mandatoryFieldText: 'This field is required',
  cardNumberEmptyText: 'Card number is empty',
  inValidCardErrorText: 'Invalid card number',
  emailEmptyText: 'Email is empty',
  emailInvalidText: 'Invalid email',
  cardHolderNameRequiredText: 'Cardholder name is required',
  lastNameRequiredText: 'Last name is required',
  invalidDigitsCardHolderNameError: 'Name cannot contain digits',
  cardExpiryDateEmptyText: 'Expiry date is empty',
  inValidExpiryErrorText: 'Invalid expiry date',
  cvcNumberEmptyText: 'CVC is empty',
  inValidCVCErrorText: 'Invalid CVC',
  unsupportedCardErrorText: 'Unsupported card',
};

const enabledCardSchemes = ['Visa', 'Mastercard', 'Amex'];

describe('Validation', () => {
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

    it('should trim whitespace from parts', () => {
      const result = splitExpiryDates('  12  /  25  ');
      expect(result[0]).toBe('12');
      expect(result[1]).toBe('25');
    });
  });

  describe('createFieldValidator', () => {
    it('should create a validator function for Required rule', () => {
      const validator = createFieldValidator('Required', enabledCardSchemes, mockLocaleObject);
      expect(validator('')).toBe('This field is required');
      expect(validator('  ')).toBe('This field is required');
      expect(validator('test')).toBeUndefined();
    });

    it('should create a validator function for Email rule', () => {
      const validator = createFieldValidator('Email', enabledCardSchemes, mockLocaleObject);
      expect(validator('')).toBe('Email is empty');
      expect(validator('invalid-email')).toBe('Invalid email');
      expect(validator('test@example.com')).toBeUndefined();
    });

    it('should create a validator function for FirstName rule', () => {
      const validator = createFieldValidator('FirstName', enabledCardSchemes, mockLocaleObject);
      expect(validator('')).toBe('Cardholder name is required');
      expect(validator('John123')).toBe('Name cannot contain digits');
      expect(validator('John')).toBeUndefined();
    });

    it('should create a validator function for LastName rule', () => {
      const validator = createFieldValidator('LastName', enabledCardSchemes, mockLocaleObject);
      expect(validator('')).toBe('Last name is required');
      expect(validator('Doe123')).toBe('Name cannot contain digits');
      expect(validator('Doe')).toBeUndefined();
    });

    it('should handle undefined value', () => {
      const validator = createFieldValidator('Required', enabledCardSchemes, mockLocaleObject);
      expect(validator(undefined)).toBe('This field is required');
    });

    it('should add MaxLength validation automatically', () => {
      const validator = createFieldValidator('Required', enabledCardSchemes, mockLocaleObject);
      const longValue = 'a'.repeat(300);
      expect(validator(longValue)).toBe('Maximum 255 characters allowed');
    });
  });

  describe('formatValue', () => {
    it('should create a formatter for CardNumber', () => {
      const formatter = formatValue('CardNumber');
      const result = formatter('4242424242424242', 'cardNumber');
      expect(result).toBe('4242 4242 4242 4242');
    });

    it('should create a formatter for CardExpiry', () => {
      const formatter = formatValue({ TAG: 'CardExpiry', _0: '1225' });
      const result = formatter('1225', 'expiry');
      expect(result).toBe('12 / 25');
    });

    it('should create a formatter for CardCVC', () => {
      const formatter = formatValue({ TAG: 'CardCVC', _0: 'Visa' });
      const result = formatter('1234', 'cvc');
      expect(result).toBe('1234');
    });

    it('should return undefined for undefined value', () => {
      const formatter = formatValue('CardNumber');
      const result = formatter(undefined, 'cardNumber');
      expect(result).toBeUndefined();
    });

    it('should pass through value for unknown rule', () => {
      const formatter = formatValue('Unknown');
      const result = formatter('test value', 'field');
      expect(result).toBe('test value');
    });
  });

  describe('format', () => {
    it('should format card number', () => {
      const result = format('4242424242424242', 'CardNumber');
      expect(result).toBe('4242 4242 4242 4242');
    });

    it('should format expiry date', () => {
      const result = format('', { TAG: 'CardExpiry', _0: '1225' });
      expect(result).toBe('12 / 25');
    });

    it('should format CVC', () => {
      const result = format('1234', { TAG: 'CardCVC', _0: 'Visa' });
      expect(result).toBe('1234');
    });

    it('should return value as-is for unknown rule', () => {
      const result = format('test value', 'Unknown');
      expect(result).toBe('test value');
    });
  });

  describe('getKeyboardType', () => {
    it('should return numeric for CardNumber', () => {
      expect(getKeyboardType('CardNumber')).toBe('numeric');
    });

    it('should return email-address for Email', () => {
      expect(getKeyboardType('Email')).toBe('email-address');
    });

    it('should return phone-pad for Phone', () => {
      expect(getKeyboardType('Phone')).toBe('phone-pad');
    });

    it('should return numeric for CardExpiry', () => {
      expect(getKeyboardType({ TAG: 'CardExpiry', _0: '' })).toBe('numeric');
    });

    it('should return numeric for CardCVC', () => {
      expect(getKeyboardType({ TAG: 'CardCVC', _0: 'Visa' })).toBe('numeric');
    });

    it('should return default for unknown rule', () => {
      expect(getKeyboardType('Unknown')).toBe('default');
    });
  });

  describe('getSecureTextEntry', () => {
    it('should return true for CardCVC', () => {
      expect(getSecureTextEntry({ TAG: 'CardCVC', _0: 'Visa' })).toBe(true);
    });

    it('should return false for other rules', () => {
      expect(getSecureTextEntry('CardNumber')).toBe(false);
      expect(getSecureTextEntry('Email')).toBe(false);
      expect(getSecureTextEntry({ TAG: 'CardExpiry', _0: '' })).toBe(false);
    });
  });

  describe('containsOnlyDigits', () => {
    it('should return true for digits only', () => {
      expect(containsOnlyDigits('123456')).toBe(true);
      expect(containsOnlyDigits('0')).toBe(true);
    });

    it('should return true for empty string', () => {
      expect(containsOnlyDigits('')).toBe(true);
    });

    it('should return false for non-digit characters', () => {
      expect(containsOnlyDigits('123abc')).toBe(false);
      expect(containsOnlyDigits('abc')).toBe(false);
      expect(containsOnlyDigits('12.34')).toBe(false);
    });
  });

  describe('containsDigit', () => {
    it('should return true if string contains digit', () => {
      expect(containsDigit('abc123')).toBe(true);
      expect(containsDigit('a1b')).toBe(true);
      expect(containsDigit('9')).toBe(true);
    });

    it('should return false if string has no digits', () => {
      expect(containsDigit('abcdef')).toBe(false);
      expect(containsDigit('')).toBe(false);
    });
  });

  describe('containsMoreThanTwoDigits', () => {
    it('should return true if string has more than 2 digits', () => {
      expect(containsMoreThanTwoDigits('abc123')).toBe(true);
      expect(containsMoreThanTwoDigits('1a2b3c')).toBe(true);
    });

    it('should return false if string has 2 or fewer digits', () => {
      expect(containsMoreThanTwoDigits('ab')).toBe(false);
      expect(containsMoreThanTwoDigits('a1b2')).toBe(false);
      expect(containsMoreThanTwoDigits('12')).toBe(false);
    });
  });

  describe('clearAlphas', () => {
    it('should remove alpha characters, keeping only digits and spaces', () => {
      expect(clearAlphas('abc123')).toBe('123');
      expect(clearAlphas('abc-123')).toBe('123');
      expect(clearAlphas('abc 123')).toBe(' 123');
    });

    it('should keep digits and spaces', () => {
      expect(clearAlphas('12 34 56')).toBe('12 34 56');
    });
  });

  describe('isEmailValid', () => {
    it('should return true for valid emails', () => {
      expect(isEmailValid('test@example.com')).toBe(true);
      expect(isEmailValid('user.name@domain.co.uk')).toBe(true);
    });

    it('should return false for invalid emails', () => {
      expect(isEmailValid('invalid')).toBe(false);
      expect(isEmailValid('test@')).toBe(false);
      expect(isEmailValid('@example.com')).toBe(false);
    });

    it('should return undefined for empty string', () => {
      expect(isEmailValid('')).toBeUndefined();
    });
  });

  describe('isValidIban', () => {
    it('should return true for non-empty trimmed string', () => {
      expect(isValidIban('DE89370400440532013000')).toBe(true);
      expect(isValidIban('  DE89370400440532013000  ')).toBe(true);
    });

    it('should return false for empty string', () => {
      expect(isValidIban('')).toBe(false);
      expect(isValidIban('   ')).toBe(false);
    });
  });

  describe('validateField', () => {
    it('should validate Required rule', () => {
      expect(validateField('', ['Required'], enabledCardSchemes, mockLocaleObject)).toBe('This field is required');
      expect(validateField('value', ['Required'], enabledCardSchemes, mockLocaleObject)).toBeUndefined();
    });

    it('should validate Email rule', () => {
      expect(validateField('', ['Email'], enabledCardSchemes, mockLocaleObject)).toBe('Email is empty');
      expect(validateField('invalid', ['Email'], enabledCardSchemes, mockLocaleObject)).toBe('Invalid email');
      expect(validateField('test@example.com', ['Email'], enabledCardSchemes, mockLocaleObject)).toBeUndefined();
    });

    it('should validate Phone rule', () => {
      expect(validateField('123', ['Phone'], enabledCardSchemes, mockLocaleObject)).toBe('Enter a valid phone number');
      expect(validateField('1234567890', ['Phone'], enabledCardSchemes, mockLocaleObject)).toBeUndefined();
    });

    it('should validate IBAN rule', () => {
      expect(validateField('', ['IBAN'], enabledCardSchemes, mockLocaleObject)).toBe('Enter a valid IBAN');
      expect(validateField('DE89370400440532013000', ['IBAN'], enabledCardSchemes, mockLocaleObject)).toBeUndefined();
    });

    it('should validate MinLength rule', () => {
      expect(validateField('ab', [{ TAG: 'MinLength', _0: 5 }], enabledCardSchemes, mockLocaleObject)).toBe('Minimum 5 characters required');
      expect(validateField('abcde', [{ TAG: 'MinLength', _0: 5 }], enabledCardSchemes, mockLocaleObject)).toBeUndefined();
    });

    it('should validate MaxLength rule', () => {
      expect(validateField('abcdefgh', [{ TAG: 'MaxLength', _0: 5 }], enabledCardSchemes, mockLocaleObject)).toBe('Maximum 5 characters allowed');
      expect(validateField('abc', [{ TAG: 'MaxLength', _0: 5 }], enabledCardSchemes, mockLocaleObject)).toBeUndefined();
    });

    it('should return first error from multiple rules', () => {
      const rules = ['Required', 'Email'];
      expect(validateField('', rules, enabledCardSchemes, mockLocaleObject)).toBe('This field is required');
    });
  });

  describe('getCurrentMonthAndYear', () => {
    it('should return current month and year', () => {
      const result = getCurrentMonthAndYear(new Date().toISOString());
      expect(result).toHaveLength(2);
      expect(result[0]).toBeGreaterThanOrEqual(1);
      expect(result[0]).toBeLessThanOrEqual(12);
      expect(result[1]).toBeGreaterThanOrEqual(2024);
    });
  });
});
