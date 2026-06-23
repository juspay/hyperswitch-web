import {
  getTransactionDetail,
  getPaymentMethodData,
  itemToObjMapper,
  getSamsungPayBodyFromResponse,
  handleSamsungPayClicked,
  useHandleSamsungPayResponse,
} from '../Utilities/SamsungPayHelpers.bs.js';
import * as Utils from '../Utilities/Utils.bs.js';
import { renderHook, act } from '@testing-library/react';
import { RecoilRoot } from 'recoil';
import * as React from 'react';
import * as RecoilAtoms from '../Utilities/RecoilAtoms.bs.js';

jest.mock('../Utilities/Utils.bs.js', () => ({
  messageParentWindow: jest.fn(),
  getDictFromDict: jest.fn((dict, key) => dict[key]),
  getString: jest.fn((dict, key, def) => (dict && dict[key] !== undefined ? dict[key] : def)),
  getBool: jest.fn((dict, key, def) => (dict && dict[key] !== undefined ? dict[key] : def)),
  getJsonFromArrayOfJson: jest.fn((arr) => arr),
  getDictFromJson: jest.fn((json) => json),
}));

describe('SamsungPayHelpers', () => {
  describe('getTransactionDetail', () => {
    it('should extract transaction details from complete dict', () => {
      const dict = {
        order_number: 'ORDER-123',
        merchant: {
          name: 'Test Merchant',
          url: 'https://example.com',
          country_code: 'US',
        },
        amount: {
          option: 'formattedTotal',
          currency_code: 'USD',
          total: '100.00',
        },
      };

      const result = getTransactionDetail(dict);

      expect(result.orderNumber).toBe('ORDER-123');
      expect(result.merchant.name).toBe('Test Merchant');
      expect(result.merchant.url).toBe('https://example.com');
      expect(result.merchant.countryCode).toBe('US');
      expect(result.amount.option).toBe('formattedTotal');
      expect(result.amount.currency).toBe('USD');
      expect(result.amount.total).toBe('100.00');
    });

    it('should return empty strings for missing fields', () => {
      const dict = {};

      const result = getTransactionDetail(dict);

      expect(result.orderNumber).toBe('');
      expect(result.merchant.name).toBe('');
      expect(result.merchant.url).toBe('');
      expect(result.merchant.countryCode).toBe('');
      expect(result.amount.option).toBe('');
      expect(result.amount.currency).toBe('');
      expect(result.amount.total).toBe('');
    });

    it('should handle partial merchant data', () => {
      const dict = {
        order_number: 'ORDER-456',
        merchant: {
          name: 'Partial Merchant',
        },
        amount: {},
      };

      const result = getTransactionDetail(dict);

      expect(result.orderNumber).toBe('ORDER-456');
      expect(result.merchant.name).toBe('Partial Merchant');
      expect(result.merchant.url).toBe('');
      expect(result.merchant.countryCode).toBe('');
    });

    it('should handle partial amount data', () => {
      const dict = {
        amount: {
          currency_code: 'EUR',
        },
      };

      const result = getTransactionDetail(dict);

      expect(result.amount.currency).toBe('EUR');
      expect(result.amount.total).toBe('');
      expect(result.amount.option).toBe('');
    });

    it('should handle different currency codes', () => {
      const dict = {
        amount: {
          currency_code: 'JPY',
          total: '1000',
        },
      };

      const result = getTransactionDetail(dict);
      expect(result.amount.currency).toBe('JPY');
      expect(result.amount.total).toBe('1000');
    });

    it('should handle long order numbers', () => {
      const dict = {
        order_number: 'ORDER-12345678901234567890',
      };

      const result = getTransactionDetail(dict);
      expect(result.orderNumber).toBe('ORDER-12345678901234567890');
    });

    it('should handle merchant with long URL', () => {
      const dict = {
        merchant: {
          url: 'https://very-long-subdomain.example.com/path/to/resource?param=value',
        },
      };

      const result = getTransactionDetail(dict);
      expect(result.merchant.url).toBe('https://very-long-subdomain.example.com/path/to/resource?param=value');
    });
  });

  describe('getPaymentMethodData', () => {
    it('should extract payment method data from complete dict', () => {
      const dict = {
        method: 'samsung_pay',
        recurring_payment: true,
        card_brand: 'VISA',
        card_last4digits: '4242',
        '3DS': {
          type: '01',
          version: '2.0',
          data: 'encrypted_data_string',
        },
      };

      const result = getPaymentMethodData(dict);

      expect(result.method).toBe('samsung_pay');
      expect(result.recurring_payment).toBe(true);
      expect(result.card_brand).toBe('VISA');
      expect(result.card_last4digits).toBe('4242');
      expect(result['3_d_s'].type).toBe('01');
      expect(result['3_d_s'].version).toBe('2.0');
      expect(result['3_d_s'].data).toBe('encrypted_data_string');
    });

    it('should return default values for missing fields', () => {
      const dict = {};

      const result = getPaymentMethodData(dict);

      expect(result.method).toBe('');
      expect(result.recurring_payment).toBe(false);
      expect(result.card_brand).toBe('');
      expect(result.card_last4digits).toBe('');
      expect(result['3_d_s'].type).toBe('');
      expect(result['3_d_s'].version).toBe('');
      expect(result['3_d_s'].data).toBe('');
    });

    it('should handle missing 3DS object', () => {
      const dict = {
        method: 'samsung_pay',
        card_brand: 'MASTERCARD',
      };

      const result = getPaymentMethodData(dict);

      expect(result.method).toBe('samsung_pay');
      expect(result.card_brand).toBe('MASTERCARD');
      expect(result['3_d_s'].type).toBe('');
    });

    it('should handle recurring_payment as false', () => {
      const dict = {
        method: 'samsung_pay',
        recurring_payment: false,
      };

      const result = getPaymentMethodData(dict);

      expect(result.recurring_payment).toBe(false);
    });

    it('should handle partial 3DS data', () => {
      const dict = {
        '3DS': {
          type: '01',
        },
      };

      const result = getPaymentMethodData(dict);

      expect(result['3_d_s'].type).toBe('01');
      expect(result['3_d_s'].version).toBe('');
      expect(result['3_d_s'].data).toBe('');
    });

    it('should handle different card brands', () => {
      const dict = {
        card_brand: 'AMEX',
        card_last4digits: '1001',
      };

      const result = getPaymentMethodData(dict);
      expect(result.card_brand).toBe('AMEX');
      expect(result.card_last4digits).toBe('1001');
    });

    it('should handle empty card_last4digits', () => {
      const dict = {
        card_brand: 'VISA',
        card_last4digits: '',
      };

      const result = getPaymentMethodData(dict);
      expect(result.card_last4digits).toBe('');
    });

    it('should handle complex 3DS data', () => {
      const dict = {
        '3DS': {
          type: '02',
          version: '2.1.0',
          data: 'very-long-encrypted-string-with-special-chars-!@#$%',
        },
      };

      const result = getPaymentMethodData(dict);
      expect(result['3_d_s'].type).toBe('02');
      expect(result['3_d_s'].version).toBe('2.1.0');
      expect(result['3_d_s'].data).toBe('very-long-encrypted-string-with-special-chars-!@#$%');
    });
  });

  describe('itemToObjMapper', () => {
    it('should map dict to Samsung Pay response object', () => {
      const dict = {
        method: 'samsung_pay',
        card_brand: 'VISA',
        card_last4digits: '1234',
        '3DS': {
          type: '01',
          version: '2.0',
          data: 'test_data',
        },
      };

      const result = itemToObjMapper(dict);

      expect(result.paymentMethodData).toBeDefined();
      expect(result.paymentMethodData.method).toBe('samsung_pay');
      expect(result.paymentMethodData.card_brand).toBe('VISA');
    });

    it('should handle empty dict', () => {
      const result = itemToObjMapper({});

      expect(result.paymentMethodData).toBeDefined();
      expect(result.paymentMethodData.method).toBe('');
    });

    it('should map complete payment data', () => {
      const dict = {
        method: 'samsung_pay',
        recurring_payment: true,
        card_brand: 'MASTERCARD',
        card_last4digits: '9999',
        '3DS': {
          type: '02',
          version: '2.1',
          data: 'encrypted',
        },
      };

      const result = itemToObjMapper(dict);
      expect(result.paymentMethodData.method).toBe('samsung_pay');
      expect(result.paymentMethodData.recurring_payment).toBe(true);
      expect(result.paymentMethodData.card_brand).toBe('MASTERCARD');
      expect(result.paymentMethodData.card_last4digits).toBe('9999');
      expect(result.paymentMethodData['3_d_s'].type).toBe('02');
    });
  });

  describe('getSamsungPayBodyFromResponse', () => {
    it('should parse JSON object and return Samsung Pay body', () => {
      const sPayResponse = {
        method: 'samsung_pay',
        card_brand: 'VISA',
        card_last4digits: '4242',
        '3DS': {
          type: '01',
          version: '2.0',
          data: 'encrypted_data',
        },
      };

      const result = getSamsungPayBodyFromResponse(sPayResponse);

      expect(result.paymentMethodData).toBeDefined();
      expect(result.paymentMethodData.method).toBe('samsung_pay');
      expect(result.paymentMethodData.card_brand).toBe('VISA');
      expect(result.paymentMethodData.card_last4digits).toBe('4242');
    });

    it('should handle JSON object with missing fields', () => {
      const sPayResponse = {
        method: 'samsung_pay',
      };

      const result = getSamsungPayBodyFromResponse(sPayResponse);

      expect(result.paymentMethodData.method).toBe('samsung_pay');
      expect(result.paymentMethodData.card_brand).toBe('');
    });

    it('should handle empty JSON object', () => {
      const sPayResponse = {};

      const result = getSamsungPayBodyFromResponse(sPayResponse);

      expect(result.paymentMethodData).toBeDefined();
      expect(result.paymentMethodData.method).toBe('');
    });

    it('should handle JSON object with recurring_payment field', () => {
      const sPayResponse = {
        method: 'samsung_pay',
        recurring_payment: true,
      };

      const result = getSamsungPayBodyFromResponse(sPayResponse);

      expect(result.paymentMethodData.recurring_payment).toBe(true);
    });

    it('should handle response with only 3DS data', () => {
      const sPayResponse = {
        '3DS': {
          type: '02',
          version: '2.2',
          data: '3ds-data',
        },
      };

      const result = getSamsungPayBodyFromResponse(sPayResponse);
      expect(result.paymentMethodData['3_d_s'].type).toBe('02');
      expect(result.paymentMethodData['3_d_s'].version).toBe('2.2');
    });
  });

  describe('handleSamsungPayClicked', () => {
    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('should call messageParentWindow with fullscreen and param when readOnly is false', () => {
      const sessionObj = {
        order_number: 'ORDER-123',
        merchant: {
          name: 'Test Merchant',
          url: 'https://example.com',
          country_code: 'US',
        },
        amount: {
          option: 'formattedTotal',
          currency_code: 'USD',
          total: '100.00',
        },
      };

      handleSamsungPayClicked(sessionObj, 'SamsungPay', 'iframe-123', false);

      expect(Utils.messageParentWindow).toHaveBeenCalled();
    });

    it('should call messageParentWindow when readOnly is true', () => {
      const sessionObj = {
        order_number: 'ORDER-456',
        merchant: {
          name: 'Test Merchant',
          url: 'https://example.com',
          country_code: 'US',
        },
        amount: {
          option: 'formattedTotal',
          currency_code: 'USD',
          total: '50.00',
        },
      };

      handleSamsungPayClicked(sessionObj, 'SamsungPay', 'iframe-456', true);

      expect(Utils.messageParentWindow).toHaveBeenCalledTimes(1);
    });

    it('should send SamsungPayClicked message when readOnly is false', () => {
      const sessionObj = {
        order_number: 'ORDER-789',
        merchant: {
          name: 'Merchant',
          url: 'https://test.com',
          country_code: 'GB',
        },
        amount: {
          option: 'formattedTotal',
          currency_code: 'GBP',
          total: '75.00',
        },
      };

      handleSamsungPayClicked(sessionObj, 'SamsungPayComponent', 'test-iframe', false);

      expect(Utils.messageParentWindow).toHaveBeenCalledTimes(2);
    });

    it('should handle empty session object', () => {
      handleSamsungPayClicked({}, 'SamsungPay', 'iframe-empty', false);

      expect(Utils.messageParentWindow).toHaveBeenCalled();
    });

    it('should handle missing merchant and amount data', () => {
      const sessionObj = {
        order_number: 'ORDER-999',
      };

      handleSamsungPayClicked(sessionObj, 'SamsungPay', 'iframe-test', false);

      expect(Utils.messageParentWindow).toHaveBeenCalled();
    });

    it('should handle different component names', () => {
      const sessionObj = { order_number: 'ORDER-001' };
      
      handleSamsungPayClicked(sessionObj, 'SamsungPayWidget', 'iframe-1', false);
      expect(Utils.messageParentWindow).toHaveBeenCalled();
      
      jest.clearAllMocks();
      
      handleSamsungPayClicked(sessionObj, 'CustomSamsungPay', 'iframe-2', false);
      expect(Utils.messageParentWindow).toHaveBeenCalled();
    });

    it('should handle different iframe IDs', () => {
      const sessionObj = { order_number: 'ORDER-002' };
      
      handleSamsungPayClicked(sessionObj, 'SamsungPay', 'iframe-A', false);
      expect(Utils.messageParentWindow).toHaveBeenCalled();
      
      jest.clearAllMocks();
      
      handleSamsungPayClicked(sessionObj, 'SamsungPay', 'iframe-B', false);
      expect(Utils.messageParentWindow).toHaveBeenCalled();
    });

    it('should handle complete transaction details', () => {
      const sessionObj = {
        order_number: 'ORDER-123',
        merchant: {
          name: 'Test Merchant',
          url: 'https://example.com',
          country_code: 'US',
        },
        amount: {
          option: 'formattedTotal',
          currency_code: 'USD',
          total: '100.00',
        },
      };

      handleSamsungPayClicked(sessionObj, 'SamsungPay', 'iframe-123', false);

      expect(Utils.messageParentWindow).toHaveBeenCalledTimes(2);
      const calls = (Utils.messageParentWindow as jest.Mock).mock.calls;
      expect(calls.length).toBeGreaterThan(0);
    });
  });

  describe('useHandleSamsungPayResponse', () => {
    const mockIntent = jest.fn();
    
    const createWrapper = (initialState: any = {}) => {
      return function Wrapper({ children }: { children: React.ReactNode }) {
        return React.createElement(
          RecoilRoot,
          {
            initializeState: ({ set }: any) => {
              if (initialState.optionAtom) {
                set(RecoilAtoms.optionAtom, initialState.optionAtom);
              }
              if (initialState.keys) {
                set(RecoilAtoms.keys, initialState.keys);
              }
              if (initialState.isManualRetryEnabled !== undefined) {
                set(RecoilAtoms.isManualRetryEnabled, initialState.isManualRetryEnabled);
              }
            },
          },
          children
        );
      };
    };

    beforeEach(() => {
      jest.clearAllMocks();
    });

    afterEach(() => {
      jest.clearAllMocks();
    });

    it('should add message event listener on mount', () => {
      const addEventListenerSpy = jest.spyOn(window, 'addEventListener');
      
      const wrapper = createWrapper({
        optionAtom: { wallets: { walletReturnUrl: 'https://return.url' } },
        keys: { publishableKey: 'pk_test_123' },
        isManualRetryEnabled: false,
      });

      const { unmount } = renderHook(
        () => useHandleSamsungPayResponse(mockIntent, false, true),
        { wrapper }
      );

      expect(addEventListenerSpy).toHaveBeenCalledWith('message', expect.any(Function));
      
      addEventListenerSpy.mockRestore();
      unmount();
    });

    it('should remove message event listener on unmount', () => {
      const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
      
      const wrapper = createWrapper({
        optionAtom: { wallets: { walletReturnUrl: 'https://return.url' } },
        keys: { publishableKey: 'pk_test_123' },
        isManualRetryEnabled: false,
      });

      const { unmount } = renderHook(
        () => useHandleSamsungPayResponse(mockIntent, false, true),
        { wrapper }
      );

      unmount();

      expect(removeEventListenerSpy).toHaveBeenCalledWith('message', expect.any(Function));
      
      removeEventListenerSpy.mockRestore();
    });

    it('should use default values for optional parameters', () => {
      const wrapper = createWrapper({
        optionAtom: { wallets: { walletReturnUrl: 'https://return.url' } },
        keys: { publishableKey: 'pk_test_123' },
        isManualRetryEnabled: false,
      });

      const { result } = renderHook(
        () => useHandleSamsungPayResponse(mockIntent),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });

    it('should handle isSavedMethodsFlow parameter as true', () => {
      const wrapper = createWrapper({
        optionAtom: { wallets: { walletReturnUrl: 'https://return.url' } },
        keys: { publishableKey: 'pk_test_123' },
        isManualRetryEnabled: false,
      });

      const { result } = renderHook(
        () => useHandleSamsungPayResponse(mockIntent, true, true),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });

    it('should handle isWallet parameter as false', () => {
      const wrapper = createWrapper({
        optionAtom: { wallets: { walletReturnUrl: 'https://return.url' } },
        keys: { publishableKey: 'pk_test_123' },
        isManualRetryEnabled: false,
      });

      const { result } = renderHook(
        () => useHandleSamsungPayResponse(mockIntent, false, false),
        { wrapper }
      );

      expect(result.current).toBeUndefined();
    });
  });
});
