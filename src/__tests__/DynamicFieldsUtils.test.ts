import {
  getName,
  isBillingAddressFieldType,
  getBillingAddressPathFromFieldType,
  removeBillingDetailsIfUseBillingAddress,
  addBillingAddressIfUseBillingAddress,
  isClickToPayFieldType,
  removeClickToPayFieldsIfSaveDetailsWithClickToPay,
  addClickToPayFieldsIfSaveDetailsWithClickToPay,
  checkIfNameIsValid,
  isFieldTypeToRenderOutsideBilling,
  combineStateAndCity,
  combineCountryAndPostal,
  combineCardExpiryMonthAndYear,
  combineCardExpiryAndCvc,
  combinePhoneNumberAndCountryCode,
  updateDynamicFields,
  removeRequiredFieldsDuplicates,
  getNameFromString,
  getNameFromFirstAndLastName,
  getApplePayRequiredFields,
  getGooglePayRequiredFields,
  getPaypalRequiredFields,
  getKlarnaRequiredFields,
  dynamicFieldsEnabledPaymentMethods,
  useRequiredFieldsEmptyAndValid,
  useSetInitialRequiredFields,
  useRequiredFieldsBody,
  useSubmitCallback,
  usePaymentMethodTypeFromList,
} from '../Utilities/DynamicFieldsUtils.bs.js';
import { renderHook, act } from '@testing-library/react';
import { RecoilRoot } from 'recoil';
import * as React from 'react';
import * as RecoilAtoms from '../Utilities/RecoilAtoms.bs.js';

describe('DynamicFieldsUtils', () => {
  describe('getName', () => {
    it('should return first name for first_name required field', () => {
      const item = {
        required_field: 'payment_method_data.billing.address.first_name',
        value: 'John Doe',
      };
      const field = { value: 'John Doe' };
      const result = getName(item, field);
      expect(result).toBe('John');
    });

    it('should return last name for last_name required field', () => {
      const item = {
        required_field: 'payment_method_data.billing.address.last_name',
        value: 'John Doe',
      };
      const field = { value: 'John Doe' };
      const result = getName(item, field);
      expect(result).toBe('Doe');
    });

    it('should return field value for other required fields', () => {
      const item = {
        required_field: 'payment_method_data.email',
        value: 'test@example.com',
      };
      const field = { value: 'test@example.com' };
      const result = getName(item, field);
      expect(result).toBe('test@example.com');
    });

    it('should handle empty field value', () => {
      const item = {
        required_field: 'payment_method_data.billing.address.first_name',
        value: '',
      };
      const field = { value: '' };
      const result = getName(item, field);
      expect(result).toBe('');
    });
  });

  describe('isBillingAddressFieldType', () => {
    it('should return true for BillingName', () => {
      expect(isBillingAddressFieldType('BillingName')).toBe(true);
    });

    it('should return true for AddressLine1', () => {
      expect(isBillingAddressFieldType('AddressLine1')).toBe(true);
    });

    it('should return true for AddressLine2', () => {
      expect(isBillingAddressFieldType('AddressLine2')).toBe(true);
    });

    it('should return true for AddressCity', () => {
      expect(isBillingAddressFieldType('AddressCity')).toBe(true);
    });

    it('should return true for AddressPincode', () => {
      expect(isBillingAddressFieldType('AddressPincode')).toBe(true);
    });

    it('should return true for AddressState', () => {
      expect(isBillingAddressFieldType('AddressState')).toBe(true);
    });

    it('should return true for AddressCountry object', () => {
      expect(isBillingAddressFieldType({ TAG: 'AddressCountry', _0: ['US'] })).toBe(true);
    });

    it('should return false for non-billing field types', () => {
      expect(isBillingAddressFieldType('Email')).toBe(false);
      expect(isBillingAddressFieldType('FullName')).toBe(false);
      expect(isBillingAddressFieldType('CardNumber')).toBe(false);
    });
  });

  describe('getBillingAddressPathFromFieldType', () => {
    it('should return correct path for AddressLine1', () => {
      expect(getBillingAddressPathFromFieldType('AddressLine1')).toBe('payment_method_data.billing.address.line1');
    });

    it('should return correct path for AddressLine2', () => {
      expect(getBillingAddressPathFromFieldType('AddressLine2')).toBe('payment_method_data.billing.address.line2');
    });

    it('should return correct path for AddressCity', () => {
      expect(getBillingAddressPathFromFieldType('AddressCity')).toBe('payment_method_data.billing.address.city');
    });

    it('should return correct path for AddressPincode', () => {
      expect(getBillingAddressPathFromFieldType('AddressPincode')).toBe('payment_method_data.billing.address.zip');
    });

    it('should return correct path for AddressState', () => {
      expect(getBillingAddressPathFromFieldType('AddressState')).toBe('payment_method_data.billing.address.state');
    });

    it('should return correct path for AddressCountry', () => {
      expect(getBillingAddressPathFromFieldType({ TAG: 'AddressCountry', _0: ['US'] })).toBe('payment_method_data.billing.address.country');
    });

    it('should return empty string for non-billing fields', () => {
      expect(getBillingAddressPathFromFieldType('Email')).toBe('');
      expect(getBillingAddressPathFromFieldType('FullName')).toBe('');
    });
  });

  describe('removeBillingDetailsIfUseBillingAddress', () => {
    const requiredFields = [
      { field_type: 'Email', required_field: 'email' },
      { field_type: 'BillingName', required_field: 'billing.name' },
      { field_type: 'AddressLine1', required_field: 'address.line1' },
    ];

    it('should remove billing fields when isUseBillingAddress is true', () => {
      const billingAddress = { isUseBillingAddress: true };
      const result = removeBillingDetailsIfUseBillingAddress(requiredFields, billingAddress);
      expect(result.length).toBe(1);
      expect(result[0].field_type).toBe('Email');
    });

    it('should keep all fields when isUseBillingAddress is false', () => {
      const billingAddress = { isUseBillingAddress: false };
      const result = removeBillingDetailsIfUseBillingAddress(requiredFields, billingAddress);
      expect(result.length).toBe(3);
    });

    it('should handle empty required fields array', () => {
      const billingAddress = { isUseBillingAddress: true };
      const result = removeBillingDetailsIfUseBillingAddress([], billingAddress);
      expect(result).toEqual([]);
    });
  });

  describe('addBillingAddressIfUseBillingAddress', () => {
    it('should add billing address fields when isUseBillingAddress is true', () => {
      const fieldsArr = ['Email', 'FullName'];
      const billingAddress = { isUseBillingAddress: true };
      const result = addBillingAddressIfUseBillingAddress(fieldsArr, billingAddress);
      expect(result.length).toBeGreaterThan(fieldsArr.length);
    });

    it('should not add fields when isUseBillingAddress is false', () => {
      const fieldsArr = ['Email', 'FullName'];
      const billingAddress = { isUseBillingAddress: false };
      const result = addBillingAddressIfUseBillingAddress(fieldsArr, billingAddress);
      expect(result.length).toBe(fieldsArr.length);
    });

    it('should handle empty fields array', () => {
      const billingAddress = { isUseBillingAddress: true };
      const result = addBillingAddressIfUseBillingAddress([], billingAddress);
      expect(result.length).toBeGreaterThan(0);
    });
  });

  describe('isClickToPayFieldType', () => {
    it('should return true for Email', () => {
      expect(isClickToPayFieldType('Email')).toBe(true);
    });

    it('should return true for PhoneNumber', () => {
      expect(isClickToPayFieldType('PhoneNumber')).toBe(true);
    });

    it('should return false for other field types', () => {
      expect(isClickToPayFieldType('FullName')).toBe(false);
      expect(isClickToPayFieldType('CardNumber')).toBe(false);
      expect(isClickToPayFieldType('AddressLine1')).toBe(false);
    });

    it('should return false for object field types', () => {
      expect(isClickToPayFieldType({ TAG: 'AddressCountry', _0: [] })).toBe(false);
    });
  });

  describe('removeClickToPayFieldsIfSaveDetailsWithClickToPay', () => {
    const requiredFields = [
      { field_type: 'Email', required_field: 'email' },
      { field_type: 'PhoneNumber', required_field: 'phone' },
      { field_type: 'FullName', required_field: 'name' },
    ];

    it('should remove CTP fields when isSaveDetailsWithClickToPay is true', () => {
      const result = removeClickToPayFieldsIfSaveDetailsWithClickToPay(requiredFields, true);
      expect(result.length).toBe(1);
      expect(result[0].field_type).toBe('FullName');
    });

    it('should keep all fields when isSaveDetailsWithClickToPay is false', () => {
      const result = removeClickToPayFieldsIfSaveDetailsWithClickToPay(requiredFields, false);
      expect(result.length).toBe(3);
    });

    it('should handle empty required fields array', () => {
      const result = removeClickToPayFieldsIfSaveDetailsWithClickToPay([], true);
      expect(result).toEqual([]);
    });
  });

  describe('addClickToPayFieldsIfSaveDetailsWithClickToPay', () => {
    const defaultConfig = {
      clickToPayCards: [],
      clickToPayProvider: 'NONE',
    };

    it('should add CTP fields for VISA provider when saving', () => {
      const fieldsArr = ['FullName'];
      const config = { clickToPayCards: [], clickToPayProvider: 'VISA' };
      const result = addClickToPayFieldsIfSaveDetailsWithClickToPay(fieldsArr, true, config);
      expect(result).toContain('Email');
      expect(result).toContain('PhoneNumber');
      expect(result).toContain('FullName');
    });

    it('should add CTP fields for MASTERCARD provider when saving', () => {
      const fieldsArr = ['FullName'];
      const config = { clickToPayCards: [], clickToPayProvider: 'MASTERCARD' };
      const result = addClickToPayFieldsIfSaveDetailsWithClickToPay(fieldsArr, true, config);
      expect(result).toContain('Email');
      expect(result).toContain('PhoneNumber');
    });

    it('should not add fields when not saving and NONE provider', () => {
      const fieldsArr = ['FullName'];
      const result = addClickToPayFieldsIfSaveDetailsWithClickToPay(fieldsArr, false, defaultConfig);
      expect(result).toEqual(['FullName']);
    });

    it('should add fields for recognized CTP payment with VISA', () => {
      const fieldsArr = ['FullName'];
      const config = { clickToPayCards: ['card1'], clickToPayProvider: 'VISA' };
      const result = addClickToPayFieldsIfSaveDetailsWithClickToPay(fieldsArr, false, config);
      expect(result).toContain('Email');
      expect(result).toContain('PhoneNumber');
    });
  });

  describe('checkIfNameIsValid', () => {
    it('should return true when first and last name are provided', () => {
      const requiredFields = [
        { field_type: 'FullName', required_field: 'payment_method_data.billing.first_name', value: '' },
        { field_type: 'FullName', required_field: 'payment_method_data.billing.last_name', value: '' },
      ];
      const field = { value: 'John Doe' };
      const result = checkIfNameIsValid(requiredFields, 'FullName', field);
      expect(result).toBe(true);
    });

    it('should return false when only first name is provided but last name is required', () => {
      const requiredFields = [
        { field_type: 'FullName', required_field: 'payment_method_data.billing.first_name', value: '' },
        { field_type: 'FullName', required_field: 'payment_method_data.billing.last_name', value: '' },
      ];
      const field = { value: 'John' };
      const result = checkIfNameIsValid(requiredFields, 'FullName', field);
      expect(result).toBe(false);
    });

    it('should return true when only first name is required', () => {
      const requiredFields = [
        { field_type: 'FullName', required_field: 'payment_method_data.billing.first_name', value: '' },
      ];
      const field = { value: 'John' };
      const result = checkIfNameIsValid(requiredFields, 'FullName', field);
      expect(result).toBe(true);
    });

    it('should return false when name is empty', () => {
      const requiredFields = [
        { field_type: 'FullName', required_field: 'payment_method_data.billing.first_name', value: '' },
      ];
      const field = { value: '' };
      const result = checkIfNameIsValid(requiredFields, 'FullName', field);
      expect(result).toBe(false);
    });

    it('should handle missing required fields', () => {
      const field = { value: 'John' };
      const result = checkIfNameIsValid([], 'FullName', field);
      expect(result).toBe(true);
    });
  });

  describe('isFieldTypeToRenderOutsideBilling', () => {
    it('should return true for card-related fields', () => {
      expect(isFieldTypeToRenderOutsideBilling('CardNumber')).toBe(true);
      expect(isFieldTypeToRenderOutsideBilling('CardExpiryMonth')).toBe(true);
      expect(isFieldTypeToRenderOutsideBilling('CardExpiryYear')).toBe(true);
      expect(isFieldTypeToRenderOutsideBilling('CardCvc')).toBe(true);
    });

    it('should return true for other outside-billing fields', () => {
      expect(isFieldTypeToRenderOutsideBilling('FullName')).toBe(true);
      expect(isFieldTypeToRenderOutsideBilling('Email')).toBe(false);
      expect(isFieldTypeToRenderOutsideBilling('VpaId')).toBe(true);
      expect(isFieldTypeToRenderOutsideBilling('PixKey')).toBe(true);
    });

    it('should return true for Currency object', () => {
      expect(isFieldTypeToRenderOutsideBilling({ TAG: 'Currency', _0: [] })).toBe(true);
    });

    it('should return true for DocumentType object', () => {
      expect(isFieldTypeToRenderOutsideBilling({ TAG: 'DocumentType', _0: [] })).toBe(true);
    });

    it('should return false for billing address fields', () => {
      expect(isFieldTypeToRenderOutsideBilling('AddressLine1')).toBe(false);
      expect(isFieldTypeToRenderOutsideBilling('AddressCity')).toBe(false);
    });
  });

  describe('combineStateAndCity', () => {
    it('should combine AddressState and AddressCity into StateAndCity', () => {
      const arr = ['AddressState', 'AddressCity', 'Email'];
      const result = combineStateAndCity(arr);
      expect(result).toContain('StateAndCity');
      expect(result).not.toContain('AddressState');
      expect(result).not.toContain('AddressCity');
      expect(result).toContain('Email');
    });

    it('should not modify array if only AddressState is present', () => {
      const arr = ['AddressState', 'Email'];
      const result = combineStateAndCity(arr);
      expect(result).toContain('AddressState');
      expect(result).toContain('Email');
    });

    it('should not modify array if only AddressCity is present', () => {
      const arr = ['AddressCity', 'Email'];
      const result = combineStateAndCity(arr);
      expect(result).toContain('AddressCity');
      expect(result).toContain('Email');
    });

    it('should handle empty array', () => {
      const result = combineStateAndCity([]);
      expect(result).toEqual([]);
    });
  });

  describe('combineCountryAndPostal', () => {
    it('should combine AddressCountry and AddressPincode into CountryAndPincode', () => {
      const arr = [{ TAG: 'AddressCountry', _0: ['US'] }, 'AddressPincode', 'Email'];
      const result = combineCountryAndPostal(arr);
      expect(result.some((item: any) => item.TAG === 'CountryAndPincode')).toBe(true);
      expect(result).not.toContain('AddressPincode');
    });

    it('should not modify array if only AddressPincode is present', () => {
      const arr = ['AddressPincode', 'Email'];
      const result = combineCountryAndPostal(arr);
      expect(result).toContain('AddressPincode');
    });

    it('should handle empty array', () => {
      const result = combineCountryAndPostal([]);
      expect(result).toEqual([]);
    });
  });

  describe('combineCardExpiryMonthAndYear', () => {
    it('should combine CardExpiryMonth and CardExpiryYear into CardExpiryMonthAndYear', () => {
      const arr = ['CardExpiryMonth', 'CardExpiryYear', 'CardNumber'];
      const result = combineCardExpiryMonthAndYear(arr);
      expect(result).toContain('CardExpiryMonthAndYear');
      expect(result).not.toContain('CardExpiryMonth');
      expect(result).not.toContain('CardExpiryYear');
      expect(result).toContain('CardNumber');
    });

    it('should not modify array if only CardExpiryMonth is present', () => {
      const arr = ['CardExpiryMonth', 'CardNumber'];
      const result = combineCardExpiryMonthAndYear(arr);
      expect(result).toContain('CardExpiryMonth');
    });

    it('should handle empty array', () => {
      const result = combineCardExpiryMonthAndYear([]);
      expect(result).toEqual([]);
    });
  });

  describe('combineCardExpiryAndCvc', () => {
    it('should combine CardExpiryMonthAndYear and CardCvc into CardExpiryAndCvc', () => {
      const arr = ['CardExpiryMonthAndYear', 'CardCvc', 'CardNumber'];
      const result = combineCardExpiryAndCvc(arr);
      expect(result).toContain('CardExpiryAndCvc');
      expect(result).not.toContain('CardExpiryMonthAndYear');
      expect(result).not.toContain('CardCvc');
      expect(result).toContain('CardNumber');
    });

    it('should not modify array if prerequisites are not met', () => {
      const arr = ['CardCvc', 'CardNumber'];
      const result = combineCardExpiryAndCvc(arr);
      expect(result).toContain('CardCvc');
    });

    it('should handle empty array', () => {
      const result = combineCardExpiryAndCvc([]);
      expect(result).toEqual([]);
    });
  });

  describe('combinePhoneNumberAndCountryCode', () => {
    it('should combine PhoneNumber and PhoneCountryCode into PhoneNumberAndCountryCode', () => {
      const arr = ['PhoneNumber', 'PhoneCountryCode', 'Email'];
      const result = combinePhoneNumberAndCountryCode(arr);
      expect(result).toContain('PhoneNumberAndCountryCode');
      expect(result).not.toContain('PhoneNumber');
      expect(result).not.toContain('PhoneCountryCode');
    });

    it('should work with only PhoneCountryCode', () => {
      const arr = ['PhoneCountryCode', 'Email'];
      const result = combinePhoneNumberAndCountryCode(arr);
      expect(result).toContain('PhoneNumberAndCountryCode');
      expect(result).not.toContain('PhoneCountryCode');
    });

    it('should work with only PhoneNumber', () => {
      const arr = ['PhoneNumber', 'Email'];
      const result = combinePhoneNumberAndCountryCode(arr);
      expect(result).toContain('PhoneNumberAndCountryCode');
      expect(result).not.toContain('PhoneNumber');
    });

    it('should handle empty array', () => {
      const result = combinePhoneNumberAndCountryCode([]);
      expect(result).toEqual([]);
    });
  });

  describe('updateDynamicFields', () => {
    const defaultBillingAddress = { isUseBillingAddress: false };
    const defaultClickToPayConfig = { clickToPayCards: [], clickToPayProvider: 'NONE' };

    it('should process array and combine fields', () => {
      const arr = ['CardExpiryMonth', 'CardExpiryYear', 'Email'];
      const result = updateDynamicFields(arr, defaultBillingAddress, false, defaultClickToPayConfig);
      expect(result).toContain('CardExpiryMonthAndYear');
    });

    it('should remove None values', () => {
      const arr = ['Email', 'None', 'FullName'];
      const result = updateDynamicFields(arr, defaultBillingAddress, false, defaultClickToPayConfig);
      expect(result).not.toContain('None');
    });

    it('should remove duplicates', () => {
      const arr = ['Email', 'Email', 'FullName'];
      const result = updateDynamicFields(arr, defaultBillingAddress, false, defaultClickToPayConfig);
      const emailCount = result.filter((item: any) => item === 'Email').length;
      expect(emailCount).toBe(1);
    });

    it('should handle empty array', () => {
      const result = updateDynamicFields([], defaultBillingAddress, false, defaultClickToPayConfig);
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('removeRequiredFieldsDuplicates', () => {
    it('should remove duplicate required fields based on required_field', () => {
      const fields = [
        { required_field: 'email', field_type: 'Email' },
        { required_field: 'email', field_type: 'Email' },
        { required_field: 'name', field_type: 'FullName' },
      ];
      const result = removeRequiredFieldsDuplicates(fields);
      expect(result.length).toBe(2);
    });

    it('should preserve order of first occurrence', () => {
      const fields = [
        { required_field: 'email', field_type: 'Email' },
        { required_field: 'name', field_type: 'FullName' },
        { required_field: 'email', field_type: 'Email2' },
      ];
      const result = removeRequiredFieldsDuplicates(fields);
      expect(result[0].field_type).toBe('Email');
      expect(result[1].field_type).toBe('FullName');
    });

    it('should handle empty array', () => {
      const result = removeRequiredFieldsDuplicates([]);
      expect(result).toEqual([]);
    });

    it('should handle array without duplicates', () => {
      const fields = [
        { required_field: 'email', field_type: 'Email' },
        { required_field: 'name', field_type: 'FullName' },
      ];
      const result = removeRequiredFieldsDuplicates(fields);
      expect(result.length).toBe(2);
    });
  });

  describe('getNameFromString', () => {
    it('should extract first name for first_name field', () => {
      const result = getNameFromString('John Doe', ['payment', 'billing', 'first_name']);
      expect(result.trim()).toBe('John');
    });

    it('should extract last name for last_name field', () => {
      const result = getNameFromString('John Doe', ['payment', 'billing', 'last_name']);
      expect(result).toBe('Doe');
    });

    it('should return full name for other fields', () => {
      const result = getNameFromString('John Doe', ['payment', 'email']);
      expect(result).toBe('John Doe');
    });

    it('should handle single word name', () => {
      const result = getNameFromString('John', ['payment', 'billing', 'first_name']);
      expect(result.trim()).toBe('John');
    });

    it('should handle empty string', () => {
      const result = getNameFromString('', ['payment', 'billing', 'first_name']);
      expect(result).toBe('');
    });
  });

  describe('getNameFromFirstAndLastName', () => {
    it('should return first name for first_name field', () => {
      const result = getNameFromFirstAndLastName('John', 'Doe', ['billing', 'first_name']);
      expect(result).toBe('John');
    });

    it('should return last name for last_name field', () => {
      const result = getNameFromFirstAndLastName('John', 'Doe', ['billing', 'last_name']);
      expect(result).toBe('Doe');
    });

    it('should return combined name for other fields', () => {
      const result = getNameFromFirstAndLastName('John', 'Doe', ['billing', 'full_name']);
      expect(result).toBe('John Doe');
    });

    it('should handle empty strings', () => {
      const result = getNameFromFirstAndLastName('', '', ['billing', 'first_name']);
      expect(result).toBe('');
    });
  });

  describe('getApplePayRequiredFields', () => {
    const billingContact = {
      givenName: 'John',
      familyName: 'Doe',
      addressLines: ['123 Main St', 'Apt 4'],
      locality: 'New York',
      administrativeArea: 'NY',
      postalCode: '10001',
      countryCode: 'US',
    };

    const shippingContact = {
      emailAddress: 'test@example.com',
      phoneNumber: '+1234567890',
      ...billingContact,
    };

    it('should extract email from shipping contact', () => {
      const result = getApplePayRequiredFields(billingContact, shippingContact);
      expect(result['email']).toBe('test@example.com');
    });

    it('should extract billing address fields', () => {
      const result = getApplePayRequiredFields(billingContact, shippingContact);
      expect(result['payment_method_data.billing.address.line1']).toBe('123 Main St');
      expect(result['payment_method_data.billing.address.city']).toBe('New York');
    });

    it('should handle missing optional fields', () => {
      const minimalBilling = {
        givenName: '',
        familyName: '',
        addressLines: [],
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'US',
      };
      const minimalShipping = {
        emailAddress: 'test@example.com',
        phoneNumber: '',
        givenName: '',
        familyName: '',
        addressLines: [],
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'US',
      };
      const result = getApplePayRequiredFields(minimalBilling, minimalShipping);
      expect(result).toBeDefined();
    });
  });

  describe('getGooglePayRequiredFields', () => {
    const billingContact = {
      name: 'John Doe',
      address1: '123 Main St',
      address2: 'Apt 4',
      locality: 'New York',
      administrativeArea: 'NY',
      postalCode: '10001',
      countryCode: 'US',
    };

    const shippingContact = {
      name: 'Jane Doe',
      phoneNumber: '+1234567890',
      ...billingContact,
    };

    it('should extract email from parameter', () => {
      const result = getGooglePayRequiredFields(billingContact, shippingContact, undefined, 'test@example.com');
      expect(result['email']).toBe('test@example.com');
    });

    it('should extract billing address fields', () => {
      const result = getGooglePayRequiredFields(billingContact, shippingContact, undefined, 'test@example.com');
      expect(result['payment_method_data.billing.address.line1']).toBe('123 Main St');
    });

    it('should extract phone number from shipping contact', () => {
      const paymentMethodTypes = [
        { required_field: 'payment_method_data.phone', field_type: 'PhoneNumber' },
      ];
      const result = getGooglePayRequiredFields(billingContact, shippingContact, paymentMethodTypes, 'test@example.com');
      expect(result['payment_method_data.phone']).toBe('+1234567890');
    });
  });

  describe('getPaypalRequiredFields', () => {
    const details = {
      email: 'test@example.com',
      phone: '+1234567890',
      shippingAddress: {
        recipientName: 'John Doe',
        line1: '123 Main St',
        line2: 'Apt 4',
        city: 'New York',
        postalCode: '10001',
        state: 'NY',
        countryCode: 'US',
      },
    };

    const paymentMethodTypes = {
      required_fields: [
        { required_field: 'email', field_type: 'Email' },
        { required_field: 'phone', field_type: 'PhoneNumber' },
        { required_field: 'shipping.line1', field_type: 'ShippingAddressLine1' },
      ],
    };

    it('should extract email from details', () => {
      const result = getPaypalRequiredFields(details, paymentMethodTypes);
      expect(result['email']).toBe('test@example.com');
    });

    it('should extract shipping address fields', () => {
      const result = getPaypalRequiredFields(details, paymentMethodTypes);
      expect(result['shipping.line1']).toBe('123 Main St');
    });

    it('should handle missing optional fields', () => {
      const minimalDetails = {
        email: 'test@example.com',
        shippingAddress: {},
      };
      const result = getPaypalRequiredFields(minimalDetails, { required_fields: [] });
      expect(result).toBeDefined();
    });
  });

  describe('getKlarnaRequiredFields', () => {
    const shippingContact = {
      email: 'test@example.com',
      phone: '+1234567890',
      given_name: 'John',
      family_name: 'Doe',
      street_address: '123 Main St',
      city: 'New York',
      postal_code: '10001',
      region: 'NY',
      country: 'US',
    };

    const paymentMethodTypes = {
      required_fields: [
        { required_field: 'email', field_type: 'Email' },
        { required_field: 'phone', field_type: 'PhoneNumber' },
        { required_field: 'shipping.address', field_type: 'ShippingAddressLine1' },
      ],
    };

    it('should extract email from shipping contact', () => {
      const result = getKlarnaRequiredFields(shippingContact, paymentMethodTypes);
      expect(result['email']).toBe('test@example.com');
    });

    it('should extract shipping address fields', () => {
      const result = getKlarnaRequiredFields(shippingContact, paymentMethodTypes);
      expect(result['shipping.address']).toBe('123 Main St');
    });

    it('should handle missing optional fields', () => {
      const minimalContact = { email: 'test@example.com' };
      const result = getKlarnaRequiredFields(minimalContact, { required_fields: [] });
      expect(result).toBeDefined();
    });
  });

  describe('dynamicFieldsEnabledPaymentMethods', () => {
    it('should contain common payment methods', () => {
      expect(dynamicFieldsEnabledPaymentMethods).toContain('credit');
      expect(dynamicFieldsEnabledPaymentMethods).toContain('debit');
      expect(dynamicFieldsEnabledPaymentMethods).toContain('google_pay');
      expect(dynamicFieldsEnabledPaymentMethods).toContain('apple_pay');
      expect(dynamicFieldsEnabledPaymentMethods).toContain('paypal');
      expect(dynamicFieldsEnabledPaymentMethods).toContain('klarna');
    });

    it('should be an array', () => {
      expect(Array.isArray(dynamicFieldsEnabledPaymentMethods)).toBe(true);
    });

    it('should contain bank debit methods', () => {
      expect(dynamicFieldsEnabledPaymentMethods).toContain('ach');
      expect(dynamicFieldsEnabledPaymentMethods).toContain('sepa');
    });
  });

  describe('getName edge cases', () => {
    it('should handle multi-word last name', () => {
      const item = {
        required_field: 'payment_method_data.billing.address.last_name',
        value: 'John Michael Doe',
      };
      const field = { value: 'John Michael Doe' };
      const result = getName(item, field);
      expect(result).toBe('Michael Doe');
    });

    it('should handle single word name for last_name', () => {
      const item = {
        required_field: 'payment_method_data.billing.address.last_name',
        value: 'John',
      };
      const field = { value: 'John' };
      const result = getName(item, field);
      expect(result).toBe('');
    });
  });

  describe('isBillingAddressFieldType edge cases', () => {
    it('should return false for object without AddressCountry tag', () => {
      expect(isBillingAddressFieldType({ TAG: 'OtherTag', _0: [] })).toBe(false);
    });
  });

  describe('checkIfNameIsValid edge cases', () => {
    it('should return true when no matching required fields', () => {
      const requiredFields = [
        { field_type: 'Email', required_field: 'email' },
      ];
      const field = { value: 'John Doe' };
      const result = checkIfNameIsValid(requiredFields, 'FullName', field);
      expect(result).toBe(true);
    });

    it('should handle name with only first name required', () => {
      const requiredFields = [
        { field_type: 'FullName', required_field: 'billing.first_name', value: '' },
      ];
      const field = { value: 'John' };
      const result = checkIfNameIsValid(requiredFields, 'FullName', field);
      expect(result).toBe(true);
    });
  });

  describe('isFieldTypeToRenderOutsideBilling additional cases', () => {
    it('should return true for InfoElement', () => {
      expect(isFieldTypeToRenderOutsideBilling('InfoElement')).toBe(true);
    });

    it('should return false for Email', () => {
      expect(isFieldTypeToRenderOutsideBilling('Email')).toBe(false);
    });

    it('should return false for Country', () => {
      expect(isFieldTypeToRenderOutsideBilling('Country')).toBe(false);
    });
  });

  describe('combineStateAndCity edge cases', () => {
    it('should not combine if only AddressCity present', () => {
      const arr = ['AddressCity', 'Email'];
      const result = combineStateAndCity(arr);
      expect(result).toContain('AddressCity');
      expect(result).not.toContain('StateAndCity');
    });
  });

  describe('combineCountryAndPostal edge cases', () => {
    it('should not combine if only AddressCountry present', () => {
      const arr = [{ TAG: 'AddressCountry', _0: ['US'] }, 'Email'];
      const result = combineCountryAndPostal(arr);
      expect(result.some((item: any) => item.TAG === 'AddressCountry')).toBe(true);
    });
  });

  describe('getApplePayRequiredFields edge cases', () => {
    it('should handle empty address lines', () => {
      const billingContact = {
        givenName: 'John',
        familyName: 'Doe',
        addressLines: [],
        locality: 'New York',
        administrativeArea: 'NY',
        postalCode: '10001',
        countryCode: 'US',
      };
      const shippingContact = {
        emailAddress: 'test@example.com',
        phoneNumber: '+1234567890',
        ...billingContact,
      };
      const result = getApplePayRequiredFields(billingContact, shippingContact);
      expect(result).toBeDefined();
    });

    it('should handle missing email in shipping contact', () => {
      const billingContact = {
        givenName: '',
        familyName: '',
        addressLines: [],
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'US',
      };
      const shippingContact = {
        emailAddress: '',
        phoneNumber: '',
        ...billingContact,
      };
      const result = getApplePayRequiredFields(billingContact, shippingContact);
      expect(result).toBeDefined();
    });
  });

  describe('getGooglePayRequiredFields edge cases', () => {
    it('should handle empty contacts', () => {
      const billingContact = {
        name: '',
        address1: '',
        address2: '',
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'US',
      };
      const shippingContact = { ...billingContact, phoneNumber: '' };
      const result = getGooglePayRequiredFields(billingContact, shippingContact, undefined, '');
      expect(result).toBeDefined();
    });

    it('should extract shipping address fields', () => {
      const billingContact = {
        name: 'John Doe',
        address1: '123 Main St',
        address2: '',
        locality: 'New York',
        administrativeArea: 'NY',
        postalCode: '10001',
        countryCode: 'US',
      };
      const shippingContact = {
        name: 'Jane Doe',
        phoneNumber: '+1234567890',
        address1: '456 Oak St',
        address2: '',
        locality: 'Boston',
        administrativeArea: 'MA',
        postalCode: '02101',
        countryCode: 'US',
      };
      const requiredFields = [
        { required_field: 'shipping.name', field_type: 'ShippingName' },
        { required_field: 'shipping.address', field_type: 'ShippingAddressLine1' },
      ];
      const result = getGooglePayRequiredFields(billingContact, shippingContact, requiredFields, 'test@example.com');
      expect(result['shipping.address']).toBe('456 Oak St');
    });
  });

  describe('getPaypalRequiredFields edge cases', () => {
    it('should handle missing shipping address', () => {
      const details = {
        email: 'test@example.com',
      };
      const result = getPaypalRequiredFields(details, { required_fields: [] });
      expect(result).toBeDefined();
    });

    it('should handle shipping address country code', () => {
      const details = {
        email: 'test@example.com',
        shippingAddress: {
          countryCode: 'US',
        },
      };
      const requiredFields = [
        { required_field: 'shipping.country', field_type: { TAG: 'ShippingAddressCountry' } },
      ];
      const result = getPaypalRequiredFields(details, { required_fields: requiredFields });
      expect(result['shipping.country']).toBe('US');
    });
  });

  describe('getKlarnaRequiredFields edge cases', () => {
    it('should handle missing phone', () => {
      const contact = {
        email: 'test@example.com',
        given_name: 'John',
        family_name: 'Doe',
      };
      const requiredFields = [
        { required_field: 'phone', field_type: 'PhoneNumber' },
      ];
      const result = getKlarnaRequiredFields(contact, { required_fields: requiredFields });
      expect(result).toBeDefined();
    });

    it('should handle shipping address country', () => {
      const contact = {
        email: 'test@example.com',
        country: 'US',
      };
      const requiredFields = [
        { required_field: 'shipping.country', field_type: { TAG: 'ShippingAddressCountry' } },
      ];
      const result = getKlarnaRequiredFields(contact, { required_fields: requiredFields });
      expect(result['shipping.country']).toBe('US');
    });
  });

  describe('updateDynamicFields edge cases', () => {
    const defaultBillingAddress = { isUseBillingAddress: false };
    const defaultClickToPayConfig = { clickToPayCards: [], clickToPayProvider: 'NONE' };

    it('should add billing fields when isUseBillingAddress is true', () => {
      const arr = ['Email'];
      const billingAddress = { isUseBillingAddress: true };
      const result = updateDynamicFields(arr, billingAddress, false, defaultClickToPayConfig);
      expect(result.length).toBeGreaterThan(1);
    });

    it('should add click to pay fields when saving with VISA', () => {
      const arr = ['Email'];
      const config = { clickToPayCards: [], clickToPayProvider: 'VISA' };
      const result = updateDynamicFields(arr, defaultBillingAddress, true, config);
      expect(result).toContain('Email');
      expect(result).toContain('FullName');
    });
  });

  describe('getNameFromString edge cases', () => {
    it('should handle single word name for last_name', () => {
      const result = getNameFromString('John', ['billing', 'last_name']);
      expect(result).toBe('');
    });

    it('should handle three word name for first_name', () => {
      const result = getNameFromString('John Michael Doe', ['billing', 'first_name']);
      expect(result.trim()).toBe('John Michael');
    });
  });

  describe('getNameFromFirstAndLastName edge cases', () => {
    it('should handle empty first name', () => {
      const result = getNameFromFirstAndLastName('', 'Doe', ['billing', 'first_name']);
      expect(result).toBe('');
    });

    it('should handle empty last name', () => {
      const result = getNameFromFirstAndLastName('John', '', ['billing', 'last_name']);
      expect(result).toBe('');
    });
  });

  describe('additional edge cases for addClickToPayFieldsIfSaveDetailsWithClickToPay', () => {
    it('should return fieldsArr unchanged when not saving and provider is NONE with no cards', () => {
      const fieldsArr = ['Email'];
      const config = { clickToPayCards: [], clickToPayProvider: 'NONE' };
      const result = addClickToPayFieldsIfSaveDetailsWithClickToPay(fieldsArr, false, config);
      expect(result).toEqual(['Email']);
    });

    it('should add FullName for VISA provider when not saving but has recognized cards', () => {
      const fieldsArr = ['Email'];
      const config = { clickToPayCards: ['card1'], clickToPayProvider: 'VISA' };
      const result = addClickToPayFieldsIfSaveDetailsWithClickToPay(fieldsArr, false, config);
      expect(result).toContain('FullName');
    });

    it('should return defaultCtpFields for MASTERCARD provider when not saving and has recognized cards', () => {
      const fieldsArr = ['Email'];
      const config = { clickToPayCards: ['card1'], clickToPayProvider: 'MASTERCARD' };
      const result = addClickToPayFieldsIfSaveDetailsWithClickToPay(fieldsArr, false, config);
      expect(result).toEqual(['Email']);
    });
  });

  describe('additional edge cases for checkIfNameIsValid', () => {
    it('should return true when all name parts are provided', () => {
      const requiredFields = [
        { field_type: 'FullName', required_field: 'payment_method_data.billing.first_name', value: '' },
        { field_type: 'FullName', required_field: 'payment_method_data.billing.last_name', value: '' },
      ];
      const field = { value: 'John Doe' };
      const result = checkIfNameIsValid(requiredFields, 'FullName', field);
      expect(result).toBe(true);
    });

    it('should return false when field value is empty', () => {
      const requiredFields = [
        { field_type: 'FullName', required_field: 'payment_method_data.billing.first_name', value: '' },
      ];
      const field = { value: '' };
      const result = checkIfNameIsValid(requiredFields, 'FullName', field);
      expect(result).toBe(false);
    });
  });

  describe('additional edge cases for combinePhoneNumberAndCountryCode', () => {
    it('should not add PhoneNumberAndCountryCode when neither field is present', () => {
      const arr = ['Email', 'FullName'];
      const result = combinePhoneNumberAndCountryCode([...arr]);
      expect(result).toEqual(arr);
    });

    it('should work with both PhoneNumber and PhoneCountryCode present', () => {
      const arr = ['PhoneNumber', 'PhoneCountryCode', 'Email'];
      const result = combinePhoneNumberAndCountryCode([...arr]);
      expect(result).toContain('PhoneNumberAndCountryCode');
      expect(result).not.toContain('PhoneNumber');
      expect(result).not.toContain('PhoneCountryCode');
    });
  });

  describe('additional edge cases for getApplePayRequiredFields', () => {
    it('should extract shipping address fields', () => {
      const billingContact = {
        givenName: 'John',
        familyName: 'Doe',
        addressLines: ['123 Billing St'],
        locality: 'Billing City',
        administrativeArea: 'BC',
        postalCode: '12345',
        countryCode: 'US',
      };
      const shippingContact = {
        emailAddress: 'ship@example.com',
        phoneNumber: '+1234567890',
        givenName: 'Jane',
        familyName: 'Smith',
        addressLines: ['456 Shipping St'],
        locality: 'Shipping City',
        administrativeArea: 'SC',
        postalCode: '67890',
        countryCode: 'US',
      };
      const requiredFields = [
        { required_field: 'shipping.name', field_type: 'ShippingName' },
        { required_field: 'shipping.line1', field_type: 'ShippingAddressLine1' },
      ];
      const result = getApplePayRequiredFields(billingContact, shippingContact, requiredFields);
      expect(result['shipping.name']).toBe('Jane Smith');
      expect(result['shipping.line1']).toBe('456 Shipping St');
    });

    it('should handle AddressCountry field type', () => {
      const billingContact = {
        givenName: 'John',
        familyName: 'Doe',
        addressLines: [],
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'US',
      };
      const shippingContact = {
        emailAddress: '',
        phoneNumber: '',
        givenName: '',
        familyName: '',
        addressLines: [],
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'GB',
      };
      const requiredFields = [
        { required_field: 'billing.country', field_type: { TAG: 'AddressCountry', _0: [] } },
        { required_field: 'shipping.country', field_type: { TAG: 'ShippingAddressCountry', _0: [] } },
      ];
      const result = getApplePayRequiredFields(billingContact, shippingContact, requiredFields);
      expect(result['billing.country']).toBe('US');
      expect(result['shipping.country']).toBe('GB');
    });
  });

  describe('additional edge cases for getGooglePayRequiredFields', () => {
    it('should handle AddressCountry field type', () => {
      const billingContact = {
        name: 'John Doe',
        address1: '123 Main St',
        address2: '',
        locality: 'City',
        administrativeArea: 'State',
        postalCode: '12345',
        countryCode: 'US',
      };
      const shippingContact = {
        name: 'Jane Doe',
        phoneNumber: '+1234567890',
        address1: '',
        address2: '',
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'GB',
      };
      const requiredFields = [
        { required_field: 'billing.country', field_type: { TAG: 'AddressCountry', _0: [] } },
        { required_field: 'shipping.country', field_type: { TAG: 'ShippingAddressCountry', _0: [] } },
      ];
      const result = getGooglePayRequiredFields(billingContact, shippingContact, requiredFields, 'test@example.com');
      expect(result['billing.country']).toBe('US');
      expect(result['shipping.country']).toBe('GB');
    });

    it('should handle empty name for name extraction', () => {
      const billingContact = {
        name: '',
        address1: '',
        address2: '',
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'US',
      };
      const shippingContact = {
        name: '',
        phoneNumber: '',
        address1: '',
        address2: '',
        locality: '',
        administrativeArea: '',
        postalCode: '',
        countryCode: 'US',
      };
      const requiredFields = [
        { required_field: 'billing.name', field_type: 'BillingName' },
      ];
      const result = getGooglePayRequiredFields(billingContact, shippingContact, requiredFields, '');
      expect(result).toBeDefined();
    });
  });

  describe('additional edge cases for getPaypalRequiredFields', () => {
    it('should handle missing shipping address gracefully', () => {
      const details = {
        email: 'test@example.com',
        shippingAddress: {},
      };
      const requiredFields = [
        { required_field: 'shipping.line1', field_type: 'ShippingAddressLine1' },
      ];
      const result = getPaypalRequiredFields(details, { required_fields: requiredFields });
      expect(result).toBeDefined();
    });

    it('should handle recipient name extraction', () => {
      const details = {
        email: 'test@example.com',
        shippingAddress: {
          recipientName: 'Jane Doe',
          line1: '123 Main St',
        },
      };
      const requiredFields = [
        { required_field: 'shipping.name', field_type: 'ShippingName' },
      ];
      const result = getPaypalRequiredFields(details, { required_fields: requiredFields });
      expect(result['shipping.name']).toBe('Jane Doe');
    });
  });

  describe('additional edge cases for getKlarnaRequiredFields', () => {
    it('should handle missing optional fields', () => {
      const contact = {
        email: 'test@example.com',
        given_name: 'John',
        family_name: 'Doe',
      };
      const requiredFields = [
        { required_field: 'shipping.line1', field_type: 'ShippingAddressLine1' },
        { required_field: 'shipping.city', field_type: 'ShippingAddressCity' },
      ];
      const result = getKlarnaRequiredFields(contact, { required_fields: requiredFields });
      expect(result).toBeDefined();
    });
  });

  describe('additional edge cases for updateDynamicFields', () => {
    it('should handle combined operations for card expiry and cvc', () => {
      const arr = ['CardExpiryMonth', 'CardExpiryYear', 'CardCvc'];
      const billingAddress = { isUseBillingAddress: false };
      const clickToPayConfig = { clickToPayCards: [], clickToPayProvider: 'NONE' };
      const result = updateDynamicFields(arr, billingAddress, false, clickToPayConfig);
      expect(result).toContain('CardExpiryAndCvc');
    });

    it('should handle all combine operations together', () => {
      const arr = ['AddressState', 'AddressCity', 'CardExpiryMonth', 'CardExpiryYear', 'PhoneNumber'];
      const billingAddress = { isUseBillingAddress: false };
      const clickToPayConfig = { clickToPayCards: [], clickToPayProvider: 'NONE' };
      const result = updateDynamicFields(arr, billingAddress, false, clickToPayConfig);
      expect(result).toContain('StateAndCity');
      expect(result).toContain('CardExpiryMonthAndYear');
      expect(result).toContain('PhoneNumberAndCountryCode');
    });
  });

  describe('useRequiredFieldsEmptyAndValid', () => {
    const createWrapper = (initialState: any = {}) => {
      return function Wrapper({ children }: { children: React.ReactNode }) {
        return React.createElement(
          RecoilRoot,
          {
            initializeState: ({ set }: any) => {
              if (initialState.userEmailAddress) {
                set(RecoilAtoms.userEmailAddress, initialState.userEmailAddress);
              }
              if (initialState.userFullName) {
                set(RecoilAtoms.userFullName, initialState.userFullName);
              }
              if (initialState.optionAtom) {
                set(RecoilAtoms.optionAtom, initialState.optionAtom);
              }
              if (initialState.areRequiredFieldsValid !== undefined) {
                set(RecoilAtoms.areRequiredFieldsValid, initialState.areRequiredFieldsValid);
              }
            },
          },
          children
        );
      };
    };

    it('should be callable with required parameters', () => {
      const wrapper = createWrapper({
        userEmailAddress: { value: 'test@example.com', isValid: true },
        userFullName: { value: 'John Doe', isValid: true },
        optionAtom: { billingAddress: { isUseBillingAddress: false } },
        areRequiredFieldsValid: true,
      });

      const requiredFields: any[] = [];
      const fieldsArr: any[] = ['Email'];
      const countryNames: string[] = ['United States'];
      const bankNames: string[] = [];

      const { result } = renderHook(
        () => useRequiredFieldsEmptyAndValid(
          requiredFields,
          fieldsArr,
          countryNames,
          bankNames,
          true,
          true,
          true,
          '4242424242424242',
          '12/25',
          '123',
          false
        ),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });

    it('should handle empty fields array', () => {
      const wrapper = createWrapper({
        userEmailAddress: { value: '', isValid: false },
        userFullName: { value: '', isValid: false },
        optionAtom: { billingAddress: { isUseBillingAddress: false } },
        areRequiredFieldsValid: false,
      });

      const { result } = renderHook(
        () => useRequiredFieldsEmptyAndValid(
          [],
          [],
          [],
          [],
          false,
          false,
          false,
          '',
          '',
          '',
          false
        ),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });
  });

  describe('useSetInitialRequiredFields', () => {
    const createWrapper = (initialState: any = {}) => {
      return function Wrapper({ children }: { children: React.ReactNode }) {
        return React.createElement(
          RecoilRoot,
          {
            initializeState: ({ set }: any) => {
              if (initialState.userEmailAddress) {
                set(RecoilAtoms.userEmailAddress, initialState.userEmailAddress);
              }
              if (initialState.userFullName) {
                set(RecoilAtoms.userFullName, initialState.userFullName);
              }
            },
          },
          children
        );
      };
    };

    it('should be callable with required parameters', () => {
      const wrapper = createWrapper({
        userEmailAddress: { value: 'test@example.com' },
        userFullName: { value: 'John Doe' },
      });

      const requiredFields = [
        { field_type: 'Email', required_field: 'email', value: 'test@example.com' },
      ];

      const { result } = renderHook(
        () => useSetInitialRequiredFields(requiredFields, 'credit'),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });

    it('should handle empty required fields', () => {
      const wrapper = createWrapper({
        userEmailAddress: { value: '' },
        userFullName: { value: '' },
      });

      const { result } = renderHook(
        () => useSetInitialRequiredFields([], 'credit'),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });

    it('should handle different payment method types', () => {
      const wrapper = createWrapper({
        userEmailAddress: { value: '' },
        userFullName: { value: '' },
      });

      const { result: result1 } = renderHook(
        () => useSetInitialRequiredFields([], 'debit'),
        { wrapper }
      );

      const { result: result2 } = renderHook(
        () => useSetInitialRequiredFields([], 'google_pay'),
        { wrapper }
      );

      expect(result1.current).toBeUndefined();
      expect(result2.current).toBeUndefined();
    });
  });

  describe('useRequiredFieldsBody', () => {
    const createWrapper = (initialState: any = {}) => {
      return function Wrapper({ children }: { children: React.ReactNode }) {
        return React.createElement(
          RecoilRoot,
          {
            initializeState: ({ set }: any) => {
              if (initialState.configAtom) {
                set(RecoilAtoms.configAtom, initialState.configAtom);
              }
              if (initialState.userEmailAddress) {
                set(RecoilAtoms.userEmailAddress, initialState.userEmailAddress);
              }
              if (initialState.optionAtom) {
                set(RecoilAtoms.optionAtom, initialState.optionAtom);
              }
            },
          },
          children
        );
      };
    };

    it('should be callable with required parameters', () => {
      const mockSetRequiredFieldsBody = jest.fn();
      
      const wrapper = createWrapper({
        configAtom: { config: { locale: 'en-US' } },
        userEmailAddress: { value: 'test@example.com' },
        optionAtom: { billingAddress: { isUseBillingAddress: false } },
      });

      const requiredFields = [
        { field_type: 'Email', required_field: 'email', value: 'test@example.com' },
      ];

      const { result } = renderHook(
        () => useRequiredFieldsBody(
          requiredFields,
          'credit',
          '4242424242424242',
          '12/25',
          '123',
          false,
          false,
          mockSetRequiredFieldsBody
        ),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });

    it('should handle empty required fields', () => {
      const mockSetRequiredFieldsBody = jest.fn();
      
      const wrapper = createWrapper({
        configAtom: { config: { locale: 'en-US' } },
        userEmailAddress: { value: '' },
        optionAtom: { billingAddress: { isUseBillingAddress: false } },
      });

      const { result } = renderHook(
        () => useRequiredFieldsBody(
          [],
          'credit',
          '',
          '',
          '',
          false,
          false,
          mockSetRequiredFieldsBody
        ),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });
  });

  describe('useSubmitCallback', () => {
    const createWrapper = (initialState: any = {}) => {
      return function Wrapper({ children }: { children: React.ReactNode }) {
        return React.createElement(
          RecoilRoot,
          {
            initializeState: ({ set }: any) => {
              if (initialState.userAddressline1) {
                set(RecoilAtoms.userAddressline1, initialState.userAddressline1);
              }
              if (initialState.userAddressline2) {
                set(RecoilAtoms.userAddressline2, initialState.userAddressline2);
              }
              if (initialState.optionAtom) {
                set(RecoilAtoms.optionAtom, initialState.optionAtom);
              }
              if (initialState.configAtom) {
                set(RecoilAtoms.configAtom, initialState.configAtom);
              }
            },
          },
          children
        );
      };
    };

    it('should return a callback function', () => {
      const wrapper = createWrapper({
        userAddressline1: { value: '123 Main St' },
        userAddressline2: { value: 'Apt 4' },
        optionAtom: { billingAddress: { isUseBillingAddress: false } },
        configAtom: { localeString: { line1EmptyText: 'Line 1 is required' } },
      });

      const { result } = renderHook(
        () => useSubmitCallback(),
        { wrapper }
      );

      expect(typeof result.current).toBe('function');
    });

    it('should handle callback invocation', () => {
      const wrapper = createWrapper({
        userAddressline1: { value: '123 Main St', errorString: '' },
        userAddressline2: { value: 'Apt 4', errorString: '' },
        optionAtom: { billingAddress: { isUseBillingAddress: false } },
        configAtom: { localeString: { line1EmptyText: 'Line 1 is required' } },
      });

      const { result } = renderHook(
        () => useSubmitCallback(),
        { wrapper }
      );

      expect(typeof result.current).toBe('function');
    });
  });

  describe('usePaymentMethodTypeFromList', () => {
    const createWrapper = () => {
      return function Wrapper({ children }: { children: React.ReactNode }) {
        return React.createElement(RecoilRoot, null, children);
      };
    };

    it('should return payment method type from list', () => {
      const wrapper = createWrapper();

      const paymentMethodListValue = {
        payment_methods: [
          {
            payment_method: 'card',
            payment_method_types: [
              { payment_method_type: 'credit' },
            ],
          },
        ],
      };

      const { result } = renderHook(
        () => usePaymentMethodTypeFromList(paymentMethodListValue, 'card', 'credit'),
        { wrapper }
      );

      expect(result.current).toBeDefined();
    });

    it('should handle empty payment method list', () => {
      const wrapper = createWrapper();

      const paymentMethodListValue = {
        payment_methods: [],
      };

      const { result } = renderHook(
        () => usePaymentMethodTypeFromList(paymentMethodListValue, 'card', 'credit'),
        { wrapper }
      );

      expect(result.current).toBeDefined();
    });

    it('should handle undefined payment method type', () => {
      const wrapper = createWrapper();

      const paymentMethodListValue = {
        payment_methods: [],
      };

      const { result } = renderHook(
        () => usePaymentMethodTypeFromList(paymentMethodListValue, 'card', undefined),
        { wrapper }
      );

      expect(result.current).toBeDefined();
    });
  });
});
