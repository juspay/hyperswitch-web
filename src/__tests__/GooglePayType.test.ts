import {
  getLabel,
  defaultTokenizationData,
  defaultPaymentMethodData,
  getTokenizationData,
  getPaymentMethodData,
  itemToObjMapper,
  jsonToPaymentRequestDataType,
  billingContactItemToObjMapper,
  baseRequest,
  getPaymentDataFromSession,
} from '../Types/GooglePayType.bs.js';

describe('GooglePayType', () => {
  describe('getLabel', () => {
    it('should return "plain" for "Default"', () => {
      expect(getLabel('Default')).toBe('plain');
    });

    it('should return "buy" for "Buy"', () => {
      expect(getLabel('Buy')).toBe('buy');
    });

    it('should return "donate" for "Donate"', () => {
      expect(getLabel('Donate')).toBe('donate');
    });

    it('should return "checkout" for "Checkout"', () => {
      expect(getLabel('Checkout')).toBe('checkout');
    });

    it('should return "subscribe" for "Subscribe"', () => {
      expect(getLabel('Subscribe')).toBe('subscribe');
    });

    it('should return "book" for "Book"', () => {
      expect(getLabel('Book')).toBe('book');
    });

    it('should return "pay" for "Pay"', () => {
      expect(getLabel('Pay')).toBe('pay');
    });

    it('should return "order" for "Order"', () => {
      expect(getLabel('Order')).toBe('order');
    });
  });

  describe('defaultTokenizationData', () => {
    it('should have empty token string', () => {
      expect(defaultTokenizationData.token).toBe('');
    });
  });

  describe('defaultPaymentMethodData', () => {
    it('should have empty description', () => {
      expect(defaultPaymentMethodData.description).toBe('');
    });

    it('should have empty type', () => {
      expect(defaultPaymentMethodData.type).toBe('');
    });

    it('should have empty info object', () => {
      expect(defaultPaymentMethodData.info).toEqual({});
    });

    it('should have empty tokenizationData object', () => {
      expect(defaultPaymentMethodData.tokenizationData).toEqual({});
    });
  });

  describe('getTokenizationData', () => {
    it('should return default when key not found', () => {
      const dict = {};
      const result = getTokenizationData('nonexistent', dict);
      expect(result.token).toBe('');
    });

    it('should return default when tokenizationData is missing', () => {
      const dict = {
        paymentMethodData: {},
      };
      const result = getTokenizationData('paymentMethodData', dict);
      expect(result.token).toBe('');
    });

    it('should return default tokenizationData structure', () => {
      const result = getTokenizationData('anyKey', {});
      expect(result).toEqual({ token: '' });
    });
  });

  describe('getPaymentMethodData', () => {
    it('should return default when key not found', () => {
      const dict = {};
      const result = getPaymentMethodData('nonexistent', dict);
      expect(result.description).toBe('');
      expect(result.type).toBe('');
    });

    it('should handle partial payment method data', () => {
      const dict = {
        paymentMethodData: {},
      };
      const result = getPaymentMethodData('paymentMethodData', dict);
      expect(result.type).toBe('');
      expect(result.description).toBe('');
    });

    it('should return default payment method data structure', () => {
      const result = getPaymentMethodData('anyKey', {});
      expect(result.description).toBe('');
      expect(result.type).toBe('');
      expect(result.info).toEqual({});
      expect(result.tokenizationData).toEqual({});
    });
  });

  describe('itemToObjMapper', () => {
    it('should map dict to payment method data object', () => {
      const dict = {};
      const result = itemToObjMapper(dict);
      expect(result.paymentMethodData).toBeDefined();
      expect(result.paymentMethodData.description).toBe('');
      expect(result.paymentMethodData.type).toBe('');
    });

    it('should handle empty dict', () => {
      const result = itemToObjMapper({});
      expect(result.paymentMethodData.description).toBe('');
      expect(result.paymentMethodData.type).toBe('');
    });
  });

  describe('jsonToPaymentRequestDataType', () => {
    it('should transform keys and modify payment request', () => {
      const paymentRequest: any = {};
      const jsonDict = {
        allowed_payment_methods: [{ type: 'CARD' }],
        transaction_info: { total_price: '10.00' },
        merchant_info: { merchant_name: 'Test Merchant' },
      };
      const result = jsonToPaymentRequestDataType(paymentRequest, jsonDict);
      expect(result.allowedPaymentMethods).toBeDefined();
      expect(result.allowedPaymentMethods.length).toBe(1);
    });

    it('should handle empty arrays', () => {
      const paymentRequest: any = {};
      const jsonDict = {
        allowed_payment_methods: [],
        transaction_info: null,
        merchant_info: null,
      };
      const result = jsonToPaymentRequestDataType(paymentRequest, jsonDict);
      expect(result.allowedPaymentMethods).toEqual([]);
    });

    it('should return the modified payment request object', () => {
      const paymentRequest: any = {};
      const jsonDict = {
        allowed_payment_methods: [],
      };
      const result = jsonToPaymentRequestDataType(paymentRequest, jsonDict);
      expect(result).toBe(paymentRequest);
    });
  });

  describe('billingContactItemToObjMapper', () => {
    it('should map all billing contact fields', () => {
      const dict = {
        address1: '123 Main St',
        address2: 'Apt 4',
        address3: 'Floor 2',
        administrativeArea: 'CA',
        countryCode: 'US',
        locality: 'San Francisco',
        name: 'John Doe',
        phoneNumber: '+14155551234',
        postalCode: '94105',
        sortingCode: 'ABC123',
      };
      const result = billingContactItemToObjMapper(dict);
      expect(result.address1).toBe('123 Main St');
      expect(result.address2).toBe('Apt 4');
      expect(result.address3).toBe('Floor 2');
      expect(result.administrativeArea).toBe('CA');
      expect(result.countryCode).toBe('US');
      expect(result.locality).toBe('San Francisco');
      expect(result.name).toBe('John Doe');
      expect(result.phoneNumber).toBe('+14155551234');
      expect(result.postalCode).toBe('94105');
      expect(result.sortingCode).toBe('ABC123');
    });

    it('should handle empty dict with defaults', () => {
      const result = billingContactItemToObjMapper({});
      expect(result.address1).toBe('');
      expect(result.address2).toBe('');
      expect(result.address3).toBe('');
      expect(result.administrativeArea).toBe('');
      expect(result.countryCode).toBe('');
      expect(result.locality).toBe('');
      expect(result.name).toBe('');
      expect(result.phoneNumber).toBe('');
      expect(result.postalCode).toBe('');
      expect(result.sortingCode).toBe('');
    });

    it('should handle partial billing contact', () => {
      const dict = {
        countryCode: 'GB',
        postalCode: 'SW1A 1AA',
      };
      const result = billingContactItemToObjMapper(dict);
      expect(result.countryCode).toBe('GB');
      expect(result.postalCode).toBe('SW1A 1AA');
      expect(result.address1).toBe('');
    });
  });

  describe('baseRequest', () => {
    it('should have apiVersion 2', () => {
      expect(baseRequest.apiVersion).toBe(2);
    });

    it('should have apiVersionMinor 0', () => {
      expect(baseRequest.apiVersionMinor).toBe(0);
    });
  });

  describe('getPaymentDataFromSession', () => {
    it('should build payment data request from session object', () => {
      const sessionObj = {
        allowed_payment_methods: [{ type: 'CARD' }],
        transaction_info: { totalPrice: '10.00', currencyCode: 'USD' },
        merchant_info: { merchantName: 'Test' },
        emailRequired: true,
      };
      const result = getPaymentDataFromSession(sessionObj, 'googlePay');
      expect(result.apiVersion).toBe(2);
      expect(result.apiVersionMinor).toBe(0);
      expect(result.emailRequired).toBe(true);
    });

    it('should handle undefined session object', () => {
      const result = getPaymentDataFromSession(undefined, 'googlePay');
      expect(result.apiVersion).toBe(2);
      expect(result.apiVersionMinor).toBe(0);
    });

    it('should add shipping address parameters for express checkout', () => {
      const sessionObj = {
        allowed_payment_methods: [],
        transaction_info: {},
        merchant_info: {},
        emailRequired: false,
        shippingAddressRequired: true,
        shippingAddressParameters: { allowedCountryCodes: ['US'] },
      };
      const result = getPaymentDataFromSession(sessionObj, 'expressCheckout');
      expect(result.shippingAddressRequired).toBe(true);
      expect(result.callbackIntents).toEqual(['SHIPPING_ADDRESS']);
    });

    it('should not add shipping address for non-express checkout component', () => {
      const sessionObj = {
        allowed_payment_methods: [],
        transaction_info: {},
        merchant_info: {},
        emailRequired: false,
        shippingAddressRequired: true,
      };
      const result = getPaymentDataFromSession(sessionObj, 'payment');
      expect(result.shippingAddressRequired).toBeUndefined();
    });

    it('should add shipping address for googlePay express checkout', () => {
      const sessionObj = {
        allowed_payment_methods: [],
        transaction_info: {},
        merchant_info: {},
        emailRequired: false,
        shippingAddressRequired: true,
        shippingAddressParameters: {},
      };
      const result = getPaymentDataFromSession(sessionObj, 'googlePay');
      expect(result.shippingAddressRequired).toBe(true);
      expect(result.callbackIntents).toEqual(['SHIPPING_ADDRESS']);
    });
  });
});
