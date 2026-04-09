import { stringToFieldType } from '../../shared-code/sdk-utils/types/SuperpositionTypes.bs.js';

describe('SuperpositionTypes', () => {
  describe('stringToFieldType', () => {
    it('should map "card_number_text_input" to CardNumberTextInput', () => {
      expect(stringToFieldType('card_number_text_input')).toBe('CardNumberTextInput');
    });

    it('should map "email_input" to EmailInput', () => {
      expect(stringToFieldType('email_input')).toBe('EmailInput');
    });

    it('should map "phone_input" to PhoneInput', () => {
      expect(stringToFieldType('phone_input')).toBe('PhoneInput');
    });

    it('should map "country_select" to CountrySelect', () => {
      expect(stringToFieldType('country_select')).toBe('CountrySelect');
    });

    it('should map "state_select" to StateSelect', () => {
      expect(stringToFieldType('state_select')).toBe('StateSelect');
    });

    it('should map "currency_select" to CurrencySelect', () => {
      expect(stringToFieldType('currency_select')).toBe('CurrencySelect');
    });

    it('should map "country_code_select" to CountryCodeSelect', () => {
      expect(stringToFieldType('country_code_select')).toBe('CountryCodeSelect');
    });

    it('should map "dropdown_select" to DropdownSelect', () => {
      expect(stringToFieldType('dropdown_select')).toBe('DropdownSelect');
    });

    it('should map "password_input" to PasswordInput', () => {
      expect(stringToFieldType('password_input')).toBe('PasswordInput');
    });

    it('should map "cvc_password_input" to CvcPasswordInput', () => {
      expect(stringToFieldType('cvc_password_input')).toBe('CvcPasswordInput');
    });

    it('should map "date_picker" to DatePicker', () => {
      expect(stringToFieldType('date_picker')).toBe('DatePicker');
    });

    it('should map "month_select" to MonthSelect', () => {
      expect(stringToFieldType('month_select')).toBe('MonthSelect');
    });

    it('should map "year_select" to YearSelect', () => {
      expect(stringToFieldType('year_select')).toBe('YearSelect');
    });

    it('should return "TextInput" for unknown field type', () => {
      expect(stringToFieldType('unknown_field_type')).toBe('TextInput');
    });

    it('should return "TextInput" for empty string', () => {
      expect(stringToFieldType('')).toBe('TextInput');
    });
  });
});
