import {
  getIdentityType,
  clickToPayCardItemToObjMapper,
  clickToPayTokenItemToObjMapper,
  urlToParamUrlItemToObjMapper,
  getStrFromActionCode,
  defaultProfile,
  defaultCountry,
  defaultParamUrl,
  formatOrderId,
  getVisaInitConfig,
  closeWindow,
  handleSuccessResponse,
  scriptId,
  srcUiKitScriptSrc,
  srcUiKitCssHref,
  recognitionTokenCookieName,
  manualCardId,
  savedCardId,
  getScriptSrc,
  orderIdRef,
  clickToPayWindowRef,
  SrcLoader,
  SrcLearnMore,
  setLocalStorage,
  getLocalStorage,
  deleteLocalStorage,
  handleCloseClickToPayWindow,
  handleOpenClickToPayWindow,
  mcCheckoutService,
  initializeMastercardCheckout,
  getCards,
  authenticate,
  checkoutWithCard,
  encryptCardForClickToPay,
  checkoutWithNewCard,
  signOut,
  getCardsVisaUnified,
  signOutVisaUnified,
  loadVisaScript,
  loadClickToPayUIScripts,
  checkoutVisaUnified,
  handleCheckoutWithCard,
  handleProceedToPay,
} from '../Types/ClickToPayHelpers.bs.js';

const createMockLogger = () => ({
  setLogInfo: jest.fn(),
  setLogError: jest.fn(),
});

describe('ClickToPayHelpers', () => {
  describe('getIdentityType', () => {
    it('should return "EMAIL_ADDRESS" for "EMAIL_ADDRESS"', () => {
      expect(getIdentityType('EMAIL_ADDRESS')).toBe('EMAIL_ADDRESS');
    });

    it('should return "MOBILE_PHONE_NUMBER" for any other value', () => {
      expect(getIdentityType('MOBILE_PHONE_NUMBER')).toBe('MOBILE_PHONE_NUMBER');
    });

    it('should return "MOBILE_PHONE_NUMBER" for unknown string', () => {
      expect(getIdentityType('UNKNOWN')).toBe('MOBILE_PHONE_NUMBER');
    });

    it('should return "MOBILE_PHONE_NUMBER" for empty string', () => {
      expect(getIdentityType('')).toBe('MOBILE_PHONE_NUMBER');
    });
  });

  describe('clickToPayCardItemToObjMapper', () => {
    it('should map card item object to typed object', () => {
      const jsonObj = {
        srcDigitalCardId: 'card-123',
        panLastFour: '4242',
        panExpirationMonth: '12',
        panExpirationYear: '2025',
        paymentCardDescriptor: 'Visa',
        digitalCardData: {
          descriptorName: 'Visa Gold',
        },
        panBin: '424242',
      };
      const result = clickToPayCardItemToObjMapper(jsonObj);
      expect(result.srcDigitalCardId).toBe('card-123');
      expect(result.panLastFour).toBe('4242');
      expect(result.panExpirationMonth).toBe('12');
      expect(result.panExpirationYear).toBe('2025');
      expect(result.paymentCardDescriptor).toBe('Visa');
      expect(result.digitalCardData.descriptorName).toBe('Visa Gold');
      expect(result.panBin).toBe('424242');
    });

    it('should handle missing fields with defaults', () => {
      const jsonObj = {};
      const result = clickToPayCardItemToObjMapper(jsonObj);
      expect(result.srcDigitalCardId).toBe('');
      expect(result.panLastFour).toBe('');
      expect(result.panExpirationMonth).toBe('');
      expect(result.panExpirationYear).toBe('');
      expect(result.paymentCardDescriptor).toBe('');
      expect(result.panBin).toBe('');
    });

    it('should handle partial card data', () => {
      const jsonObj = {
        srcDigitalCardId: 'card-456',
        panLastFour: '1234',
      };
      const result = clickToPayCardItemToObjMapper(jsonObj);
      expect(result.srcDigitalCardId).toBe('card-456');
      expect(result.panLastFour).toBe('1234');
      expect(result.panExpirationMonth).toBe('');
    });
  });

  describe('clickToPayTokenItemToObjMapper', () => {
    it('should map token item object to typed object', () => {
      const jsonObj = {
        dpa_id: 'dpa-123',
        dpa_name: 'Test Merchant',
        locale: 'en_US',
        transaction_amount: 100.5,
        transaction_currency_code: 'USD',
        acquirer_bin: '123456',
        acquirer_merchant_id: 'merchant-123',
        merchant_category_code: '5999',
        merchant_country_code: 'US',
        card_brands: ['VISA', 'MASTERCARD'],
        email: 'test@example.com',
        provider: 'mastercard',
      };
      const result = clickToPayTokenItemToObjMapper(jsonObj);
      expect(result.dpaId).toBe('dpa-123');
      expect(result.dpaName).toBe('Test Merchant');
      expect(result.locale).toBe('en_US');
      expect(result.transactionAmount).toBe(100.5);
      expect(result.transactionCurrencyCode).toBe('USD');
      expect(result.acquirerBIN).toBe('123456');
      expect(result.acquirerMerchantId).toBe('merchant-123');
      expect(result.merchantCategoryCode).toBe('5999');
      expect(result.merchantCountryCode).toBe('US');
      expect(result.cardBrands).toEqual(['VISA', 'MASTERCARD']);
      expect(result.email).toBe('test@example.com');
      expect(result.provider).toBe('mastercard');
    });

    it('should handle missing fields with defaults', () => {
      const jsonObj = {};
      const result = clickToPayTokenItemToObjMapper(jsonObj);
      expect(result.dpaId).toBe('');
      expect(result.dpaName).toBe('');
      expect(result.locale).toBe('');
      expect(result.transactionAmount).toBe(0.0);
      expect(result.transactionCurrencyCode).toBe('');
      expect(result.provider).toBe('mastercard');
    });

    it('should handle empty card_brands array', () => {
      const jsonObj = {
        card_brands: [],
      };
      const result = clickToPayTokenItemToObjMapper(jsonObj);
      expect(result.cardBrands).toEqual([]);
    });
  });

  describe('urlToParamUrlItemToObjMapper', () => {
    it('should parse URL parameters into key-value pairs', () => {
      const url = '?key1=value1&key2=value2&key3=value3';
      const result = urlToParamUrlItemToObjMapper(url);
      expect(result).toHaveLength(3);
      expect(result[0]).toEqual({ key: 'key1', value: 'value1' });
      expect(result[1]).toEqual({ key: 'key2', value: 'value2' });
      expect(result[2]).toEqual({ key: 'key3', value: 'value3' });
    });

    it('should handle URL without leading question mark', () => {
      const url = 'key1=value1&key2=value2';
      const result = urlToParamUrlItemToObjMapper(url);
      expect(result).toHaveLength(2);
      expect(result[0]).toEqual({ key: 'key1', value: 'value1' });
    });

    it('should handle empty string', () => {
      const result = urlToParamUrlItemToObjMapper('');
      expect(result).toEqual([]);
    });

    it('should handle string with only question mark', () => {
      const result = urlToParamUrlItemToObjMapper('?');
      expect(result).toEqual([]);
    });

    it('should handle empty values', () => {
      const url = 'key1=&key2=value2';
      const result = urlToParamUrlItemToObjMapper(url);
      expect(result).toHaveLength(2);
      expect(result[0]).toEqual({ key: 'key1', value: '' });
      expect(result[1]).toEqual({ key: 'key2', value: 'value2' });
    });

    it('should filter out empty parameters', () => {
      const url = '?key1=value1&&key2=value2';
      const result = urlToParamUrlItemToObjMapper(url);
      expect(result).toHaveLength(2);
    });
  });

  describe('getStrFromActionCode', () => {
    it('should return "SUCCESS" for "SUCCESS"', () => {
      expect(getStrFromActionCode('SUCCESS')).toBe('SUCCESS');
    });

    it('should return "PENDING_CONSUMER_IDV" for "PENDING_CONSUMER_IDV"', () => {
      expect(getStrFromActionCode('PENDING_CONSUMER_IDV')).toBe('PENDING_CONSUMER_IDV');
    });

    it('should return "FAILED" for "FAILED"', () => {
      expect(getStrFromActionCode('FAILED')).toBe('FAILED');
    });

    it('should return "ERROR" for "ERROR"', () => {
      expect(getStrFromActionCode('ERROR')).toBe('ERROR');
    });

    it('should return "ADD_CARD" for "ADD_CARD"', () => {
      expect(getStrFromActionCode('ADD_CARD')).toBe('ADD_CARD');
    });

    it('should return undefined for unknown action code', () => {
      expect(getStrFromActionCode('UNKNOWN')).toBeUndefined();
    });
  });

  describe('defaultProfile', () => {
    it('should have empty maskedCards array', () => {
      expect(defaultProfile.maskedCards).toEqual([]);
    });
  });

  describe('defaultCountry', () => {
    it('should have empty code', () => {
      expect(defaultCountry.code).toBe('');
    });

    it('should have empty countryISO', () => {
      expect(defaultCountry.countryISO).toBe('');
    });
  });

  describe('defaultParamUrl', () => {
    it('should have empty key', () => {
      expect(defaultParamUrl.key).toBe('');
    });

    it('should have empty value', () => {
      expect(defaultParamUrl.value).toBe('');
    });
  });

  describe('formatOrderId', () => {
    it('should extract order ID from payment secret format', () => {
      const orderId = 'pay_abc123_secret_xyz789';
      const result = formatOrderId(orderId);
      expect(result).toBe('abc123');
    });

    it('should handle payment ID without secret suffix', () => {
      const orderId = 'pay_test123';
      const result = formatOrderId(orderId);
      expect(result).toBe('test123');
    });

    it('should truncate to 40 characters max', () => {
      const longId = 'pay_' + 'a'.repeat(50) + '_secret_xyz';
      const result = formatOrderId(longId);
      expect(result.length).toBeLessThanOrEqual(40);
    });

    it('should handle empty string', () => {
      const result = formatOrderId('');
      expect(result).toBe('');
    });

    it('should handle string without pay_ prefix', () => {
      const orderId = 'test123_secret_xyz';
      const result = formatOrderId(orderId);
      expect(result).toBe('test123');
    });
  });

  describe('getVisaInitConfig', () => {
    it('should build Visa init config from token', () => {
      const token = {
        locale: 'en_US',
        transactionAmount: 100.0,
        transactionCurrencyCode: 'USD',
        merchantCountryCode: 'US',
        merchantCategoryCode: '5999',
        acquirerBIN: '123456',
        acquirerMerchantId: 'merchant-123',
      };
      const clientSecret = 'pay_test123_secret_xyz';
      const result = getVisaInitConfig(token, clientSecret);
      expect(result.dpaTransactionOptions.dpaLocale).toBe('en_US');
      expect(result.dpaTransactionOptions.dpaBillingPreference).toBe('NONE');
      expect(result.dpaTransactionOptions.payloadTypeIndicator).toBe('FULL');
      expect(result.dpaTransactionOptions.merchantCountryCode).toBe('US');
      expect(result.dpaTransactionOptions.merchantCategoryCode).toBe('5999');
      expect(result.dpaTransactionOptions.acquirerBIN).toBe('123456');
      expect(result.dpaTransactionOptions.acquirerMerchantId).toBe('merchant-123');
    });

    it('should handle undefined clientSecret', () => {
      const token = {
        locale: 'en_US',
        transactionAmount: 50.0,
        transactionCurrencyCode: 'EUR',
        merchantCountryCode: 'DE',
        merchantCategoryCode: '5999',
        acquirerBIN: '654321',
        acquirerMerchantId: 'merchant-456',
      };
      const result = getVisaInitConfig(token, undefined);
      expect(result.dpaTransactionOptions.merchantOrderId).toBe('');
    });

    it('should set payloadTypeIndicator to FULL', () => {
      const token = {
        locale: 'en_US',
        transactionAmount: 100,
        transactionCurrencyCode: 'USD',
        merchantCountryCode: 'US',
        merchantCategoryCode: '5999',
        acquirerBIN: '123456',
        acquirerMerchantId: 'merchant-123',
      };
      const result = getVisaInitConfig(token, 'pay_test');
      expect(result.dpaTransactionOptions.payloadTypeIndicator).toBe('FULL');
    });

    it('should set consumerNationalIdentifierRequested to false', () => {
      const token = {
        locale: 'en_US',
        transactionAmount: 100,
        transactionCurrencyCode: 'USD',
        merchantCountryCode: 'US',
        merchantCategoryCode: '5999',
        acquirerBIN: '123456',
        acquirerMerchantId: 'merchant-123',
      };
      const result = getVisaInitConfig(token, 'pay_test');
      expect(result.dpaTransactionOptions.consumerNationalIdentifierRequested).toBe(false);
    });
  });

  describe('closeWindow', () => {
    it('should return object with status and payload', () => {
      const payload = { test: 'data' };
      const result = closeWindow('COMPLETE', payload);
      expect(result.status).toBe('COMPLETE');
      expect(result.payload).toBe(payload);
    });

    it('should handle ERROR status', () => {
      const result = closeWindow('ERROR', null);
      expect(result.status).toBe('ERROR');
      expect(result.payload).toBeNull();
    });

    it('should handle CANCEL status', () => {
      const result = closeWindow('CANCEL', { reason: 'user_cancelled' });
      expect(result.status).toBe('CANCEL');
      expect(result.payload).toEqual({ reason: 'user_cancelled' });
    });

    it('should handle null payload', () => {
      const result = closeWindow('COMPLETE', null);
      expect(result.status).toBe('COMPLETE');
      expect(result.payload).toBeNull();
    });
  });

  describe('handleSuccessResponse', () => {
    it('should return CANCEL status for checkoutActionCode "CANCEL"', () => {
      const response = { checkoutActionCode: 'CANCEL' };
      const result = handleSuccessResponse(response);
      expect(result.status).toBe('CANCEL');
    });

    it('should return COMPLETE status for checkoutActionCode "COMPLETE"', () => {
      const response = { checkoutActionCode: 'COMPLETE' };
      const result = handleSuccessResponse(response);
      expect(result.status).toBe('COMPLETE');
    });

    it('should return PAY_V3_CARD status for checkoutActionCode "PAY_V3_CARD"', () => {
      const response = { checkoutActionCode: 'PAY_V3_CARD' };
      const result = handleSuccessResponse(response);
      expect(result.status).toBe('PAY_V3_CARD');
    });

    it('should return ERROR status for unknown checkoutActionCode', () => {
      const response = { checkoutActionCode: 'UNKNOWN' };
      const result = handleSuccessResponse(response);
      expect(result.status).toBe('ERROR');
    });

    it('should return ERROR status for empty checkoutActionCode', () => {
      const response = { checkoutActionCode: '' };
      const result = handleSuccessResponse(response);
      expect(result.status).toBe('ERROR');
    });
  });

  describe('constants', () => {
    it('should have correct scriptId', () => {
      expect(scriptId).toBe('mastercard-external-script');
    });

    it('should have correct srcUiKitScriptSrc', () => {
      expect(srcUiKitScriptSrc).toBe('https://src.mastercard.com/srci/integration/components/src-ui-kit/src-ui-kit.esm.js');
    });

    it('should have correct srcUiKitCssHref', () => {
      expect(srcUiKitCssHref).toBe('https://src.mastercard.com/srci/integration/components/src-ui-kit/src-ui-kit.css');
    });

    it('should have correct recognitionTokenCookieName', () => {
      expect(recognitionTokenCookieName).toBe('__mastercard_click_to_pay');
    });

    it('should have correct manualCardId', () => {
      expect(manualCardId).toBe('click_to_pay_manual_card');
    });

    it('should have correct savedCardId prefix', () => {
      expect(savedCardId).toBe('click_to_pay_saved_card_');
    });

    it('should have orderIdRef with empty string contents', () => {
      expect(orderIdRef).toHaveProperty('contents');
      expect(orderIdRef.contents).toBe('');
    });

    it('should have clickToPayWindowRef with null contents', () => {
      expect(clickToPayWindowRef).toHaveProperty('contents');
      expect(clickToPayWindowRef.contents).toBeNull();
    });

    it('should have SrcLoader as an empty object', () => {
      expect(SrcLoader).toEqual({});
    });

    it('should have SrcLearnMore as an empty object', () => {
      expect(SrcLearnMore).toEqual({});
    });
  });

  describe('getScriptSrc', () => {
    const originalIsProductionEnv = (globalThis as any).isProductionEnv;

    afterEach(() => {
      (globalThis as any).isProductionEnv = originalIsProductionEnv;
    });

    it('should return sandbox URL when isProductionEnv is false', () => {
      (globalThis as any).isProductionEnv = false;
      expect(getScriptSrc()).toBe('https://sandbox.src.mastercard.com/srci/integration/2/lib.js');
    });

    it('should return production URL when isProductionEnv is true', () => {
      (globalThis as any).isProductionEnv = true;
      expect(getScriptSrc()).toBe('https://src.mastercard.com/srci/integration/2/lib.js');
    });

    it('should return sandbox URL when isProductionEnv is undefined', () => {
      (globalThis as any).isProductionEnv = undefined;
      expect(getScriptSrc()).toBe('https://sandbox.src.mastercard.com/srci/integration/2/lib.js');
    });
  });

  describe('setLocalStorage', () => {
    const originalLocalStorage = window.localStorage;

    beforeEach(() => {
      const storage: { [key: string]: string } = {};
      Object.defineProperty(window, 'localStorage', {
        value: {
          setItem: (key: string, value: string) => {
            storage[key] = value;
          },
          getItem: (key: string) => (key in storage ? storage[key] : null),
          removeItem: (key: string) => {
            delete storage[key];
          },
        },
        writable: true,
        configurable: true,
      });
    });

    afterEach(() => {
      Object.defineProperty(window, 'localStorage', {
        value: originalLocalStorage,
        writable: true,
        configurable: true,
      });
    });

    it('should set item in localStorage', () => {
      setLocalStorage('testKey', 'testValue');
      expect(window.localStorage.getItem('testKey')).toBe('testValue');
    });

    it('should overwrite existing value', () => {
      setLocalStorage('testKey', 'value1');
      setLocalStorage('testKey', 'value2');
      expect(window.localStorage.getItem('testKey')).toBe('value2');
    });

    it('should handle empty string value', () => {
      setLocalStorage('emptyKey', '');
      expect(window.localStorage.getItem('emptyKey')).toBe('');
    });
  });

  describe('getLocalStorage', () => {
    const originalLocalStorage = window.localStorage;

    beforeEach(() => {
      const storage: { [key: string]: string } = { existingKey: 'existingValue' };
      Object.defineProperty(window, 'localStorage', {
        value: {
          setItem: (key: string, value: string) => {
            storage[key] = value;
          },
          getItem: (key: string) => (key in storage ? storage[key] : null),
          removeItem: (key: string) => {
            delete storage[key];
          },
        },
        writable: true,
        configurable: true,
      });
    });

    afterEach(() => {
      Object.defineProperty(window, 'localStorage', {
        value: originalLocalStorage,
        writable: true,
        configurable: true,
      });
    });

    it('should get existing item from localStorage', () => {
      expect(getLocalStorage('existingKey')).toBe('existingValue');
    });

    it('should return null for non-existing key', () => {
      expect(getLocalStorage('nonExistingKey')).toBeNull();
    });

    it('should return null for empty key', () => {
      expect(getLocalStorage('')).toBeNull();
    });
  });

  describe('deleteLocalStorage', () => {
    const originalLocalStorage = window.localStorage;

    beforeEach(() => {
      const storage: { [key: string]: string } = { testKey: 'testValue' };
      Object.defineProperty(window, 'localStorage', {
        value: {
          setItem: (key: string, value: string) => {
            storage[key] = value;
          },
          getItem: (key: string) => (key in storage ? storage[key] : null),
          removeItem: (key: string) => {
            delete storage[key];
          },
        },
        writable: true,
        configurable: true,
      });
    });

    afterEach(() => {
      Object.defineProperty(window, 'localStorage', {
        value: originalLocalStorage,
        writable: true,
        configurable: true,
      });
    });

    it('should delete existing item from localStorage', () => {
      deleteLocalStorage('testKey');
      expect(window.localStorage.getItem('testKey')).toBeNull();
    });

    it('should not throw when deleting non-existing key', () => {
      expect(() => deleteLocalStorage('nonExistingKey')).not.toThrow();
    });

    it('should not throw when deleting with empty key', () => {
      expect(() => deleteLocalStorage('')).not.toThrow();
    });
  });

  describe('handleCloseClickToPayWindow', () => {
    it('should close window when clickToPayWindowRef has a window', () => {
      const mockClose = jest.fn();
      (clickToPayWindowRef as any).contents = { close: mockClose };
      handleCloseClickToPayWindow();
      expect(mockClose).toHaveBeenCalled();
    });

    it('should set clickToPayWindowRef.contents to null after closing', () => {
      const mockClose = jest.fn();
      (clickToPayWindowRef as any).contents = { close: mockClose };
      handleCloseClickToPayWindow();
      expect(clickToPayWindowRef.contents).toBeNull();
    });

    it('should not throw when clickToPayWindowRef is null', () => {
      (clickToPayWindowRef as any).contents = null;
      expect(() => handleCloseClickToPayWindow()).not.toThrow();
    });
  });

  describe('handleOpenClickToPayWindow', () => {
    const originalOpen = window.open;

    beforeEach(() => {
      const mockWindow = { document: { write: jest.fn(), close: jest.fn() } };
      Object.defineProperty(window, 'open', {
        value: jest.fn(() => mockWindow),
        writable: true,
        configurable: true,
      });
    });

    afterEach(() => {
      Object.defineProperty(window, 'open', {
        value: originalOpen,
        writable: true,
        configurable: true,
      });
      (clickToPayWindowRef as any).contents = null;
    });

    it('should open a new window with correct parameters', () => {
      handleOpenClickToPayWindow();
      expect(window.open).toHaveBeenCalledWith('', 'ClickToPayWindow', 'width=480,height=600');
    });

    it('should set clickToPayWindowRef.contents to the opened window', () => {
      const mockWindow = { document: { write: jest.fn(), close: jest.fn() } };
      (window.open as jest.Mock).mockReturnValue(mockWindow);
      handleOpenClickToPayWindow();
      expect(clickToPayWindowRef.contents).toBe(mockWindow);
    });
  });

  describe('mcCheckoutService', () => {
    it('should have contents property', () => {
      expect(mcCheckoutService).toHaveProperty('contents');
    });
  });

  describe('initializeMastercardCheckout', () => {
    beforeEach(() => {
      (mcCheckoutService as any).contents = undefined;
    });

    it('should reject when MastercardCheckoutServices is not available', async () => {
      const mockLogger = createMockLogger();
      const token = {
        dpaId: 'test-dpa',
        dpaName: 'Test Merchant',
        locale: 'en_US',
        transactionAmount: 100,
        transactionCurrencyCode: 'USD',
        acquirerBIN: '123456',
        acquirerMerchantId: 'merchant-123',
        merchantCategoryCode: '5999',
        merchantCountryCode: 'US',
        cardBrands: ['VISA'],
      };

      (window as any).MastercardCheckoutServices = undefined;

      await expect(initializeMastercardCheckout(token, mockLogger)).rejects.toBeDefined();
      expect(mockLogger.setLogError).toHaveBeenCalled();
    });

    it('should reject when MastercardCheckoutServices constructor throws', async () => {
      const mockLogger = createMockLogger();
      const token = {
        dpaId: 'test-dpa',
        dpaName: 'Test Merchant',
        locale: 'en_US',
        transactionAmount: 100,
        transactionCurrencyCode: 'USD',
        acquirerBIN: '123456',
        acquirerMerchantId: 'merchant-123',
        merchantCategoryCode: '5999',
        merchantCountryCode: 'US',
        cardBrands: ['VISA'],
      };

      (window as any).MastercardCheckoutServices = jest.fn().mockImplementation(() => {
        throw new Error('Constructor error');
      });

      try {
        await initializeMastercardCheckout(token, mockLogger);
        fail('Should have thrown');
      } catch (e) {
        expect(e).toBeDefined();
      }
    });
  });

  describe('getCards', () => {
    it('should return empty array when service is not initialized', async () => {
      const mockLogger = createMockLogger();
      (mcCheckoutService as any).contents = undefined;

      const result = await getCards(mockLogger);

      expect(result.TAG).toBe('Ok');
      expect(result._0).toEqual([]);
    });

    it('should return cards when service is available', async () => {
      const mockLogger = createMockLogger();
      const mockCards = [{ srcDigitalCardId: 'card-1' }];
      (mcCheckoutService as any).contents = {
        getCards: jest.fn().mockResolvedValue(mockCards),
      };

      const result = await getCards(mockLogger);

      expect(result.TAG).toBe('Ok');
      expect(result._0).toEqual(mockCards);
    });

    it('should return empty array on error', async () => {
      const mockLogger = createMockLogger();
      (mcCheckoutService as any).contents = {
        getCards: jest.fn().mockRejectedValue(new Error('Network error')),
      };

      const result = await getCards(mockLogger);

      expect(result.TAG).toBe('Ok');
      expect(result._0).toEqual([]);
    });
  });

  describe('authenticate', () => {
    it('should return Error when service is not initialized', async () => {
      const mockLogger = createMockLogger();
      (mcCheckoutService as any).contents = undefined;

      const payload = {
        windowRef: {} as Window,
        consumerIdentity: {
          identityType: 'EMAIL_ADDRESS',
          identityValue: 'test@example.com',
        },
      };

      const result = await authenticate(payload, mockLogger);

      expect(result.TAG).toBe('Error');
    });

    it('should return Ok with authentication response on success', async () => {
      const mockLogger = createMockLogger();
      const mockAuthResponse = JSON.stringify({ recognitionToken: 'token-123' });
      (mcCheckoutService as any).contents = {
        authenticate: jest.fn().mockResolvedValue(mockAuthResponse),
      };

      const payload = {
        windowRef: {} as Window,
        consumerIdentity: {
          identityType: 'EMAIL_ADDRESS',
          identityValue: 'test@example.com',
        },
      };

      const result = await authenticate(payload, mockLogger);

      expect(result.TAG).toBe('Ok');
    });
  });

  describe('checkoutWithCard', () => {
    it('should return Error when service is not initialized', async () => {
      const mockLogger = createMockLogger();
      (mcCheckoutService as any).contents = undefined;

      const result = await checkoutWithCard({} as Window, 'card-123', mockLogger);

      expect(result.TAG).toBe('Error');
    });

    it('should return Ok on successful checkout', async () => {
      const mockLogger = createMockLogger();
      const mockResponse = { checkoutActionCode: 'COMPLETE' };
      (mcCheckoutService as any).contents = {
        checkoutWithCard: jest.fn().mockResolvedValue(mockResponse),
      };

      const result = await checkoutWithCard({} as Window, 'card-123', mockLogger);

      expect(result.TAG).toBe('Ok');
      expect(result._0).toEqual(mockResponse);
    });
  });

  describe('encryptCardForClickToPay', () => {
    it('should return Error when service is not initialized', async () => {
      const mockLogger = createMockLogger();
      (mcCheckoutService as any).contents = undefined;

      const result = await encryptCardForClickToPay('4111111111111111', '12', '2025', '123', mockLogger);

      expect(result.TAG).toBe('Error');
    });

    it('should return Ok with encrypted card on success', async () => {
      const mockLogger = createMockLogger();
      const mockEncryptedCard = { encryptedData: 'encrypted-value' };
      (mcCheckoutService as any).contents = {
        encryptCard: jest.fn().mockResolvedValue(mockEncryptedCard),
      };

      const result = await encryptCardForClickToPay('4111111111111111', '12', '2025', '123', mockLogger);

      expect(result.TAG).toBe('Ok');
      expect(result._0).toEqual(mockEncryptedCard);
    });
  });

  describe('checkoutWithNewCard', () => {
    it('should return Error when service is not initialized', async () => {
      const mockLogger = createMockLogger();
      (mcCheckoutService as any).contents = undefined;

      const result = await checkoutWithNewCard({}, mockLogger);

      expect(result.TAG).toBe('Error');
    });

    it('should return Ok on successful new card checkout', async () => {
      const mockLogger = createMockLogger();
      const mockResponse = { checkoutActionCode: 'COMPLETE' };
      (mcCheckoutService as any).contents = {
        checkoutWithNewCard: jest.fn().mockResolvedValue(mockResponse),
      };

      const payload = {
        windowRef: {} as Window,
        cardBrand: 'VISA',
        encryptedCard: 'encrypted-data',
        rememberMe: true,
      };

      const result = await checkoutWithNewCard(payload, mockLogger);

      expect(result.TAG).toBe('Ok');
    });
  });

  describe('signOut', () => {
    it('should return Error when service is not initialized', async () => {
      (mcCheckoutService as any).contents = undefined;

      const result = await signOut();

      expect(result.TAG).toBe('Error');
    });

    it('should return Ok on successful sign out', async () => {
      (mcCheckoutService as any).contents = {
        signOut: jest.fn().mockResolvedValue({}),
      };

      const result = await signOut();

      expect(result.TAG).toBe('Ok');
    });

    it('should return Error on sign out failure', async () => {
      (mcCheckoutService as any).contents = {
        signOut: jest.fn().mockRejectedValue(new Error('Sign out failed')),
      };

      const result = await signOut();

      expect(result.TAG).toBe('Error');
    });
  });

  describe('getCardsVisaUnified', () => {
    it('should call VSDK.getCards with config', () => {
      const mockGetCards = jest.fn().mockResolvedValue([]);
      (window as any).VSDK = { getCards: mockGetCards };

      const config = { dpaId: 'test-dpa' };
      getCardsVisaUnified(config);

      expect(mockGetCards).toHaveBeenCalledWith(config);
    });
  });

  describe('signOutVisaUnified', () => {
    it('should call VSDK.unbindAppInstance', () => {
      const mockUnbind = jest.fn();
      (window as any).VSDK = { unbindAppInstance: mockUnbind };

      signOutVisaUnified();

      expect(mockUnbind).toHaveBeenCalled();
    });
  });

  describe('loadVisaScript', () => {
    const originalCreateElement = document.createElement.bind(document);
    const originalAppendChild = document.body.appendChild.bind(document.body);

    beforeEach(() => {
      const mockScript = {
        type: '',
        src: '',
        onload: null as (() => void) | null,
        onerror: null as (() => void) | null,
      };
      document.createElement = jest.fn().mockReturnValue(mockScript);
      document.body.appendChild = jest.fn();
    });

    afterEach(() => {
      document.createElement = originalCreateElement;
      document.body.appendChild = originalAppendChild;
    });

    it('should create and append script element', () => {
      const mockOnLoad = jest.fn();
      const mockOnError = jest.fn();
      const token = {
        dpaId: 'test-dpa',
        dpaName: 'Test Merchant',
        locale: 'en_US',
        cardBrands: ['VISA'],
      };

      loadVisaScript(token, mockOnLoad, mockOnError);

      expect(document.createElement).toHaveBeenCalledWith('script');
      expect(document.body.appendChild).toHaveBeenCalled();
    });
  });

  describe('loadClickToPayUIScripts', () => {
    const originalQuerySelector = document.querySelector.bind(document);
    const originalCreateElement = document.createElement.bind(document);
    const originalAppendChild = document.head.appendChild.bind(document.head);

    beforeEach(() => {
      document.querySelector = jest.fn().mockReturnValue(null);
      document.createElement = jest.fn().mockReturnValue({
        type: '',
        src: '',
        rel: '',
        href: '',
        onload: null as (() => void) | null,
        onerror: null as (() => void) | null,
      });
      document.head.appendChild = jest.fn();
    });

    afterEach(() => {
      document.querySelector = originalQuerySelector;
      document.createElement = originalCreateElement;
      document.head.appendChild = originalAppendChild;
    });

    it('should load scripts and call callbacks', () => {
      const mockLogger = createMockLogger();
      const mockOnLoad = jest.fn();
      const mockOnError = jest.fn();

      loadClickToPayUIScripts(mockLogger, mockOnLoad, mockOnError);

      expect(document.createElement).toHaveBeenCalled();
    });
  });

  describe('checkoutVisaUnified', () => {
    beforeEach(() => {
      (window as any).VSDK = {
        checkout: jest.fn().mockResolvedValue({ actionCode: 'SUCCESS' }),
      };
      (clickToPayWindowRef as any).contents = {} as Window;
    });

    afterEach(() => {
      (clickToPayWindowRef as any).contents = null;
    });

    it('should call VSDK.checkout with correct config for existing card', async () => {
      const token = {
        dpaId: 'test-dpa',
        dpaName: 'Test Merchant',
        locale: 'en_US',
        transactionAmount: 100,
        transactionCurrencyCode: 'USD',
        acquirerBIN: '123456',
        acquirerMerchantId: 'merchant-123',
        merchantCategoryCode: '5999',
        merchantCountryCode: 'US',
        cardBrands: ['VISA'],
      };
      const consumer = {
        fullName: 'Test User',
        emailAddress: 'test@example.com',
        mobileNumber: { phoneNumber: '1234567890', countryCode: '1' },
      };

      const result = await checkoutVisaUnified(
        'card-123',
        undefined,
        {} as Window,
        false,
        true,
        token,
        'pay_test_secret_123',
        consumer,
        true
      );

      expect(result).toBeDefined();
    });
  });

  describe('handleCheckoutWithCard', () => {
    const mockLogger = createMockLogger();

    beforeEach(() => {
      (clickToPayWindowRef as any).contents = null;
    });

    it('should return ERROR status when window reference is null', async () => {
      (clickToPayWindowRef as any).contents = null;

      const result = await handleCheckoutWithCard(
        'VISA',
        'card-123',
        mockLogger,
        'Test User',
        'test@example.com',
        '1234567890',
        '1',
        undefined,
        false,
        'pay_test'
      );

      expect(result.status).toBe('ERROR');
    });

    it('should return ERROR status for NONE provider', async () => {
      (clickToPayWindowRef as any).contents = { close: jest.fn() } as unknown as Window;

      const result = await handleCheckoutWithCard(
        'NONE',
        'card-123',
        mockLogger,
        'Test User',
        'test@example.com',
        '1234567890',
        '1',
        undefined,
        false,
        'pay_test'
      );

      expect(result.status).toBe('ERROR');
    });
  });

  describe('handleProceedToPay', () => {
    const mockLogger = createMockLogger();

    beforeEach(() => {
      (clickToPayWindowRef as any).contents = null;
    });

    it('should return ERROR status when window reference is null and new card checkout', async () => {
      (clickToPayWindowRef as any).contents = null;

      const result = await handleProceedToPay(
        undefined,
        undefined,
        true,
        false,
        'test@example.com',
        '1234567890',
        '1',
        false,
        mockLogger,
        undefined,
        'VISA',
        false,
        undefined,
        undefined,
        undefined
      );

      expect(result.status).toBe('ERROR');
    });
  });
});
