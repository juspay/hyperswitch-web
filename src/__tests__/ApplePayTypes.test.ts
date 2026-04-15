import {
  getTotal,
  jsonToPaymentRequestDataType,
  billingContactItemToObjMapper,
  shippingContactItemToObjMapper,
  defaultHeadlessApplePayToken,
} from '../Types/ApplePayTypes.bs.js';

describe('ApplePayTypes', () => {
  describe('defaultHeadlessApplePayToken', () => {
    it('should have null paymentRequestData', () => {
      expect(defaultHeadlessApplePayToken.paymentRequestData).toBeNull();
    });

    it('should have undefined sessionTokenData', () => {
      expect(defaultHeadlessApplePayToken.sessionTokenData).toBeUndefined();
    });
  });

  describe('getTotal', () => {
    it('should extract total without type when type is empty', () => {
      const totalDict = {
        label: 'Total',
        amount: '10.00',
        type: '',
      };
      const result = getTotal(totalDict);
      expect(result.label).toBe('Total');
      expect(result.amount).toBe('10.00');
      expect(result.type).toBeUndefined();
    });

    it('should extract total with type when type is present', () => {
      const totalDict = {
        label: 'Total',
        amount: '10.00',
        type: 'final',
      };
      const result = getTotal(totalDict);
      expect(result.label).toBe('Total');
      expect(result.amount).toBe('10.00');
      expect(result.type).toBe('final');
    });

    it('should handle missing fields with defaults', () => {
      const totalDict = {};
      const result = getTotal(totalDict);
      expect(result.label).toBe('');
      expect(result.amount).toBe('');
    });

    it('should handle partial fields', () => {
      const totalDict = {
        label: 'Subtotal',
      };
      const result = getTotal(totalDict);
      expect(result.label).toBe('Subtotal');
      expect(result.amount).toBe('');
    });
  });

  describe('jsonToPaymentRequestDataType', () => {
    it('should parse basic payment request without merchant identifier', () => {
      const jsonDict = {
        country_code: 'US',
        currency_code: 'USD',
        total: {
          label: 'Total',
          amount: '10.00',
        },
        merchant_capabilities: ['supports3DS'],
        supported_networks: ['visa', 'mastercard'],
      };
      const result = jsonToPaymentRequestDataType(jsonDict);
      expect(result.countryCode).toBe('US');
      expect(result.currencyCode).toBe('USD');
      expect(result.total.label).toBe('Total');
      expect(result.total.amount).toBe('10.00');
      expect(result.merchantCapabilities).toEqual(['supports3DS']);
      expect(result.supportedNetworks).toEqual(['visa', 'mastercard']);
      expect(result.merchantIdentifier).toBeUndefined();
    });

    it('should parse payment request with merchant identifier', () => {
      const jsonDict = {
        country_code: 'US',
        currency_code: 'USD',
        total: {
          label: 'Total',
          amount: '10.00',
        },
        merchant_capabilities: ['supports3DS'],
        supported_networks: ['visa'],
        merchant_identifier: 'merchant.com.example',
      };
      const result = jsonToPaymentRequestDataType(jsonDict);
      expect(result.merchantIdentifier).toBe('merchant.com.example');
    });

    it('should use default country code when not provided', () => {
      const jsonDict = {
        currency_code: 'USD',
        total: {},
        merchant_capabilities: [],
        supported_networks: [],
      };
      const result = jsonToPaymentRequestDataType(jsonDict);
      expect(result.countryCode).toBe('IN');
    });

    it('should handle empty arrays for capabilities and networks', () => {
      const jsonDict = {
        country_code: 'GB',
        currency_code: 'GBP',
        total: {},
        merchant_capabilities: [],
        supported_networks: [],
      };
      const result = jsonToPaymentRequestDataType(jsonDict);
      expect(result.merchantCapabilities).toEqual([]);
      expect(result.supportedNetworks).toEqual([]);
    });
  });

  describe('billingContactItemToObjMapper', () => {
    it('should map billing contact with all fields', () => {
      const dict = {
        addressLines: ['123 Main St', 'Apt 4'],
        administrativeArea: 'CA',
        countryCode: 'US',
        familyName: 'Doe',
        givenName: 'John',
        locality: 'San Francisco',
        postalCode: '94105',
      };
      const result = billingContactItemToObjMapper(dict);
      expect(result.addressLines).toEqual(['123 Main St', 'Apt 4']);
      expect(result.administrativeArea).toBe('CA');
      expect(result.countryCode).toBe('US');
      expect(result.familyName).toBe('Doe');
      expect(result.givenName).toBe('John');
      expect(result.locality).toBe('San Francisco');
      expect(result.postalCode).toBe('94105');
    });

    it('should handle empty dict with defaults', () => {
      const dict = {};
      const result = billingContactItemToObjMapper(dict);
      expect(result.addressLines).toEqual([]);
      expect(result.administrativeArea).toBe('');
      expect(result.countryCode).toBe('');
      expect(result.familyName).toBe('');
      expect(result.givenName).toBe('');
      expect(result.locality).toBe('');
      expect(result.postalCode).toBe('');
    });

    it('should handle partial billing contact', () => {
      const dict = {
        givenName: 'Jane',
        familyName: 'Smith',
      };
      const result = billingContactItemToObjMapper(dict);
      expect(result.givenName).toBe('Jane');
      expect(result.familyName).toBe('Smith');
      expect(result.addressLines).toEqual([]);
    });
  });

  describe('shippingContactItemToObjMapper', () => {
    it('should map shipping contact with all fields', () => {
      const dict = {
        emailAddress: 'john@example.com',
        phoneNumber: '+14155551234',
        addressLines: ['456 Oak Ave'],
        administrativeArea: 'NY',
        countryCode: 'US',
        familyName: 'Doe',
        givenName: 'Jane',
        locality: 'New York',
        postalCode: '10001',
      };
      const result = shippingContactItemToObjMapper(dict);
      expect(result.emailAddress).toBe('john@example.com');
      expect(result.phoneNumber).toBe('+14155551234');
      expect(result.addressLines).toEqual(['456 Oak Ave']);
      expect(result.administrativeArea).toBe('NY');
      expect(result.countryCode).toBe('US');
      expect(result.familyName).toBe('Doe');
      expect(result.givenName).toBe('Jane');
      expect(result.locality).toBe('New York');
      expect(result.postalCode).toBe('10001');
    });

    it('should handle empty dict with defaults', () => {
      const dict = {};
      const result = shippingContactItemToObjMapper(dict);
      expect(result.emailAddress).toBe('');
      expect(result.phoneNumber).toBe('');
      expect(result.addressLines).toEqual([]);
      expect(result.administrativeArea).toBe('');
      expect(result.countryCode).toBe('');
    });

    it('should handle partial shipping contact', () => {
      const dict = {
        emailAddress: 'test@example.com',
        phoneNumber: '555-1234',
      };
      const result = shippingContactItemToObjMapper(dict);
      expect(result.emailAddress).toBe('test@example.com');
      expect(result.phoneNumber).toBe('555-1234');
      expect(result.addressLines).toEqual([]);
    });
  });
});
