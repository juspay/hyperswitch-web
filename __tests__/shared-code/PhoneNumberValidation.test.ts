import { formatPhoneNumber } from '../../shared-code/sdk-utils/validation/PhoneNumberValidation.bs.js';

const mockCountries = [
  { phone_number_code: '+1' },
  { phone_number_code: '+44' },
  { phone_number_code: '+91' },
  { phone_number_code: '+55' },
];

describe('PhoneNumberValidation', () => {
  describe('formatPhoneNumber', () => {
    describe('happy path', () => {
      it('should parse phone number with +1 country code', () => {
        const result = formatPhoneNumber('+14155551234', mockCountries);
        expect(result).toEqual(['+1', '4155551234']);
      });

      it('should parse phone number with +44 country code', () => {
        const result = formatPhoneNumber('+442071234567', mockCountries);
        expect(result).toEqual(['+44', '2071234567']);
      });

      it('should parse phone number with +91 country code', () => {
        const result = formatPhoneNumber('+919876543210', mockCountries);
        expect(result).toEqual(['+91', '9876543210']);
      });

      it('should return empty country code for number without plus', () => {
        const result = formatPhoneNumber('4155551234', mockCountries);
        expect(result).toEqual(['', '4155551234']);
      });
    });

    describe('edge cases', () => {
      it('should return empty result for empty string', () => {
        const result = formatPhoneNumber('', mockCountries);
        expect(result).toEqual(['', '']);
      });

      it('should return original text for string longer than 20 chars', () => {
        const longText = 'a'.repeat(25);
        const result = formatPhoneNumber(longText, mockCountries);
        expect(result).toEqual(['', longText]);
      });

      it('should return original text when no valid phone chars found', () => {
        const result = formatPhoneNumber('abcdef', mockCountries);
        expect(result).toEqual(['', 'abcdef']);
      });

      it('should return original text when no digits present', () => {
        const result = formatPhoneNumber('+++', mockCountries);
        expect(result).toEqual(['', '+++']);
      });

      it('should return empty national number when only country code present', () => {
        const result = formatPhoneNumber('+1', mockCountries);
        expect(result).toEqual(['+1', '']);
      });
    });

    describe('error/boundary', () => {
      it('should return original text when plus present but country code not found', () => {
        const result = formatPhoneNumber('+99912345678', mockCountries);
        expect(result).toEqual(['', '+99912345678']);
      });

      it('should handle phone number with special characters', () => {
        const result = formatPhoneNumber('+1 (415) 555-1234', mockCountries);
        expect(result).toEqual(['+1', '4155551234']);
      });

      it('should handle empty countries array', () => {
        const result = formatPhoneNumber('+14155551234', []);
        expect(result).toEqual(['', '+14155551234']);
      });

      it('should handle phone number starting with digits only', () => {
        const result = formatPhoneNumber('4155551234', mockCountries);
        expect(result).toEqual(['', '4155551234']);
      });

      it('should strip non-digit characters from national number', () => {
        const result = formatPhoneNumber('+1-415-555-1234', mockCountries);
        expect(result).toEqual(['+1', '4155551234']);
      });
    });
  });
});
