import {
  logApi,
  logInputChangeInfo,
  handleLogging,
  eventNameToStrMapper,
  getPaymentId,
  convertToScreamingSnakeCase,
  toSnakeCaseWithSeparator,
  defaultLoggerConfig,
  apiEventInitMapper,
} from '../Utilities/LoggerUtils.bs.js';

describe('LoggerUtils', () => {
  describe('getPaymentId', () => {
    it('should extract payment ID from client secret', () => {
      const clientSecret = 'pay_12345_secret_abcdef';
      const result = getPaymentId(clientSecret);
      expect(result).toBe('pay_12345');
    });

    it('should handle client secret without secret suffix', () => {
      const clientSecret = 'pay_67890';
      const result = getPaymentId(clientSecret);
      expect(result).toBe('pay_67890');
    });

    it('should return full string if no separator found', () => {
      const clientSecret = 'simplepaymentid';
      const result = getPaymentId(clientSecret);
      expect(result).toBe('simplepaymentid');
    });

    it('should handle empty string', () => {
      const result = getPaymentId('');
      expect(result).toBe('');
    });

    it('should handle multiple secret separators', () => {
      const clientSecret = 'pay_123_secret_abc_secret_def';
      const result = getPaymentId(clientSecret);
      expect(result).toBe('pay_123');
    });
  });

  describe('convertToScreamingSnakeCase', () => {
    it('should convert space-separated text to SCREAMING_SNAKE_CASE', () => {
      expect(convertToScreamingSnakeCase('hello world')).toBe('HELLO_WORLD');
    });

    it('should handle single word', () => {
      expect(convertToScreamingSnakeCase('hello')).toBe('HELLO');
    });

    it('should trim leading and trailing spaces', () => {
      expect(convertToScreamingSnakeCase('  hello world  ')).toBe('HELLO_WORLD');
    });

    it('should handle multiple spaces between words', () => {
      expect(convertToScreamingSnakeCase('hello  world')).toBe('HELLO__WORLD');
    });

    it('should handle already uppercase text', () => {
      expect(convertToScreamingSnakeCase('HELLO WORLD')).toBe('HELLO_WORLD');
    });

    it('should handle mixed case text', () => {
      expect(convertToScreamingSnakeCase('Hello World')).toBe('HELLO_WORLD');
    });

    it('should handle empty string', () => {
      expect(convertToScreamingSnakeCase('')).toBe('');
    });
  });

  describe('toSnakeCaseWithSeparator', () => {
    it('should convert camelCase to snake_case with separator', () => {
      expect(toSnakeCaseWithSeparator('helloWorld', '_')).toBe('hello_world');
    });

    it('should convert PascalCase to snake_case', () => {
      expect(toSnakeCaseWithSeparator('HelloWorld', '_')).toBe('_hello_world');
    });

    it('should handle multiple uppercase letters', () => {
      expect(toSnakeCaseWithSeparator('helloWorldTest', '_')).toBe('hello_world_test');
    });

    it('should handle single word without uppercase', () => {
      expect(toSnakeCaseWithSeparator('hello', '_')).toBe('hello');
    });

    it('should handle custom separator', () => {
      expect(toSnakeCaseWithSeparator('helloWorld', '-')).toBe('hello-world');
    });

    it('should handle empty string', () => {
      expect(toSnakeCaseWithSeparator('', '_')).toBe('');
    });

    it('should handle consecutive uppercase letters', () => {
      expect(toSnakeCaseWithSeparator('helloWORLD', '_')).toBe('hello_w_o_r_l_d');
    });
  });

  describe('eventNameToStrMapper', () => {
    it('should return the same event name string', () => {
      expect(eventNameToStrMapper('PAYMENT_INITIATED')).toBe('PAYMENT_INITIATED');
    });

    it('should handle empty string', () => {
      expect(eventNameToStrMapper('')).toBe('');
    });

    it('should handle any string input', () => {
      expect(eventNameToStrMapper('SomeEventName')).toBe('SomeEventName');
    });
  });

  describe('apiEventInitMapper', () => {
    it('should map RETRIEVE_CALL to RETRIEVE_CALL_INIT', () => {
      expect(apiEventInitMapper('RETRIEVE_CALL')).toBe('RETRIEVE_CALL_INIT');
    });

    it('should map AUTHENTICATION_CALL to AUTHENTICATION_CALL_INIT', () => {
      expect(apiEventInitMapper('AUTHENTICATION_CALL')).toBe('AUTHENTICATION_CALL_INIT');
    });

    it('should map CONFIRM_CALL to CONFIRM_CALL_INIT', () => {
      expect(apiEventInitMapper('CONFIRM_CALL')).toBe('CONFIRM_CALL_INIT');
    });

    it('should map CONFIRM_PAYOUT_CALL to CONFIRM_PAYOUT_CALL_INIT', () => {
      expect(apiEventInitMapper('CONFIRM_PAYOUT_CALL')).toBe('CONFIRM_PAYOUT_CALL_INIT');
    });

    it('should map SESSIONS_CALL to SESSIONS_CALL_INIT', () => {
      expect(apiEventInitMapper('SESSIONS_CALL')).toBe('SESSIONS_CALL_INIT');
    });

    it('should map PAYMENT_METHODS_CALL to PAYMENT_METHODS_CALL_INIT', () => {
      expect(apiEventInitMapper('PAYMENT_METHODS_CALL')).toBe('PAYMENT_METHODS_CALL_INIT');
    });

    it('should map CUSTOMER_PAYMENT_METHODS_CALL to CUSTOMER_PAYMENT_METHODS_CALL_INIT', () => {
      expect(apiEventInitMapper('CUSTOMER_PAYMENT_METHODS_CALL')).toBe('CUSTOMER_PAYMENT_METHODS_CALL_INIT');
    });

    it('should map CREATE_CUSTOMER_PAYMENT_METHODS_CALL to CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT', () => {
      expect(apiEventInitMapper('CREATE_CUSTOMER_PAYMENT_METHODS_CALL')).toBe('CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT');
    });

    it('should map POLL_STATUS_CALL to POLL_STATUS_CALL_INIT', () => {
      expect(apiEventInitMapper('POLL_STATUS_CALL')).toBe('POLL_STATUS_CALL_INIT');
    });

    it('should map COMPLETE_AUTHORIZE_CALL to COMPLETE_AUTHORIZE_CALL_INIT', () => {
      expect(apiEventInitMapper('COMPLETE_AUTHORIZE_CALL')).toBe('COMPLETE_AUTHORIZE_CALL_INIT');
    });

    it('should map PAYMENT_METHODS_AUTH_EXCHANGE_CALL to PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT', () => {
      expect(apiEventInitMapper('PAYMENT_METHODS_AUTH_EXCHANGE_CALL')).toBe('PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT');
    });

    it('should map PAYMENT_METHODS_AUTH_LINK_CALL to PAYMENT_METHODS_AUTH_LINK_CALL_INIT', () => {
      expect(apiEventInitMapper('PAYMENT_METHODS_AUTH_LINK_CALL')).toBe('PAYMENT_METHODS_AUTH_LINK_CALL_INIT');
    });

    it('should map POST_SESSION_TOKENS_CALL to POST_SESSION_TOKENS_CALL_INIT', () => {
      expect(apiEventInitMapper('POST_SESSION_TOKENS_CALL')).toBe('POST_SESSION_TOKENS_CALL_INIT');
    });

    it('should return ENABLED_AUTHN_METHODS_TOKEN_CALL unchanged', () => {
      expect(apiEventInitMapper('ENABLED_AUTHN_METHODS_TOKEN_CALL')).toBe('ENABLED_AUTHN_METHODS_TOKEN_CALL');
    });

    it('should return ELIGIBILITY_CHECK_CALL unchanged', () => {
      expect(apiEventInitMapper('ELIGIBILITY_CHECK_CALL')).toBe('ELIGIBILITY_CHECK_CALL');
    });

    it('should return AUTHENTICATION_SYNC_CALL unchanged', () => {
      expect(apiEventInitMapper('AUTHENTICATION_SYNC_CALL')).toBe('AUTHENTICATION_SYNC_CALL');
    });

    it('should return undefined for unknown event names', () => {
      expect(apiEventInitMapper('UNKNOWN_EVENT')).toBeUndefined();
    });

    it('should return undefined for empty string', () => {
      expect(apiEventInitMapper('')).toBeUndefined();
    });
  });

  describe('logApi', () => {
    const mockLogger = {
      setLogApi: jest.fn(),
    };

    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('should call logger.setLogApi for Request type', () => {
      logApi(
        'TEST_EVENT',
        200,
        { data: 'test' },
        'Request',
        'https://api.example.com',
        'credit',
        { result: 'success' },
        mockLogger,
        'INFO',
        'API',
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
      const call = mockLogger.setLogApi.mock.calls[0];
      expect(call[1]).toBe('TEST_EVENT');
    });

    it('should call logger.setLogApi for Response type', () => {
      logApi(
        'TEST_EVENT',
        200,
        { data: 'test' },
        'Response',
        'https://api.example.com',
        'credit',
        { result: 'success' },
        mockLogger,
        'INFO',
        'API',
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
    });

    it('should call logger.setLogApi for NoResponse type', () => {
      logApi(
        'TEST_EVENT',
        504,
        { error: 'timeout' },
        'NoResponse',
        'https://api.example.com',
        'credit',
        {},
        mockLogger,
        'ERROR',
        'API',
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
    });

    it('should call logger.setLogApi for Method type', () => {
      logApi(
        'TEST_EVENT',
        0,
        {},
        'Method',
        '',
        'credit',
        { valid: true },
        mockLogger,
        'INFO',
        'METHOD',
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
    });

    it('should call logger.setLogApi for Err type', () => {
      logApi(
        'TEST_EVENT',
        500,
        { error: 'server error' },
        'Err',
        'https://api.example.com',
        'credit',
        {},
        mockLogger,
        'ERROR',
        'API',
        false
      );

      expect(mockLogger.setLogApi).toHaveBeenCalled();
    });

    it('should not call setLogApi when logger is undefined', () => {
      expect(() => {
        logApi('TEST_EVENT', 200, {}, 'Request', 'url', 'credit', {}, undefined);
      }).not.toThrow();
    });

    it('should use default values for optional parameters', () => {
      logApi('TEST_EVENT', undefined, undefined, 'Request', undefined, undefined, undefined, mockLogger);

      expect(mockLogger.setLogApi).toHaveBeenCalled();
    });
  });

  describe('logInputChangeInfo', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
    };

    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('should call logger.setLogInfo with correct parameters', () => {
      logInputChangeInfo('card_number', mockLogger);

      expect(mockLogger.setLogInfo).toHaveBeenCalledWith(
        'card_number',
        'INPUT_FIELD_CHANGED',
        undefined,
        undefined,
        undefined,
        undefined,
        undefined
      );
    });

    it('should handle empty text', () => {
      logInputChangeInfo('', mockLogger);

      expect(mockLogger.setLogInfo).toHaveBeenCalledWith(
        '',
        'INPUT_FIELD_CHANGED',
        undefined,
        undefined,
        undefined,
        undefined,
        undefined
      );
    });
  });

  describe('handleLogging', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
    };

    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('should call logger.setLogInfo with correct parameters', () => {
      handleLogging(mockLogger, 'test_value', 'TEST_EVENT', 'credit', 'INFO');

      expect(mockLogger.setLogInfo).toHaveBeenCalledWith(
        'test_value',
        'TEST_EVENT',
        undefined,
        undefined,
        'INFO',
        undefined,
        'credit'
      );
    });

    it('should use default logType when not provided', () => {
      handleLogging(mockLogger, 'test_value', 'TEST_EVENT', 'credit');

      expect(mockLogger.setLogInfo).toHaveBeenCalledWith(
        'test_value',
        'TEST_EVENT',
        undefined,
        undefined,
        'INFO',
        undefined,
        'credit'
      );
    });

    it('should not throw when logger is undefined', () => {
      expect(() => {
        handleLogging(undefined, 'test_value', 'TEST_EVENT', 'credit');
      }).not.toThrow();
    });

    it('should handle empty values', () => {
      handleLogging(mockLogger, '', '', '', '');

      expect(mockLogger.setLogInfo).toHaveBeenCalled();
    });
  });

  describe('defaultLoggerConfig', () => {
    it('should have all required methods', () => {
      expect(defaultLoggerConfig).toHaveProperty('setLogInfo');
      expect(defaultLoggerConfig).toHaveProperty('setLogError');
      expect(defaultLoggerConfig).toHaveProperty('setLogApi');
      expect(defaultLoggerConfig).toHaveProperty('setLogInitiated');
      expect(defaultLoggerConfig).toHaveProperty('setConfirmPaymentValue');
      expect(defaultLoggerConfig).toHaveProperty('sendLogs');
      expect(defaultLoggerConfig).toHaveProperty('setSessionId');
      expect(defaultLoggerConfig).toHaveProperty('setClientSecret');
      expect(defaultLoggerConfig).toHaveProperty('setMerchantId');
      expect(defaultLoggerConfig).toHaveProperty('setMetadata');
      expect(defaultLoggerConfig).toHaveProperty('setSource');
    });

    it('should have setLogInfo as a function', () => {
      expect(typeof defaultLoggerConfig.setLogInfo).toBe('function');
    });

    it('should have setLogError as a function', () => {
      expect(typeof defaultLoggerConfig.setLogError).toBe('function');
    });

    it('should have setLogApi as a function', () => {
      expect(typeof defaultLoggerConfig.setLogApi).toBe('function');
    });

    it('should have setLogInitiated as a function', () => {
      expect(typeof defaultLoggerConfig.setLogInitiated).toBe('function');
    });

    it('should have setConfirmPaymentValue as a function that returns empty object', () => {
      expect(typeof defaultLoggerConfig.setConfirmPaymentValue).toBe('function');
      expect(defaultLoggerConfig.setConfirmPaymentValue({})).toEqual({});
    });

    it('should have sendLogs as a function', () => {
      expect(typeof defaultLoggerConfig.sendLogs).toBe('function');
    });

    it('should have setSessionId as a function', () => {
      expect(typeof defaultLoggerConfig.setSessionId).toBe('function');
    });

    it('should have setClientSecret as a function', () => {
      expect(typeof defaultLoggerConfig.setClientSecret).toBe('function');
    });

    it('should have setMerchantId as a function', () => {
      expect(typeof defaultLoggerConfig.setMerchantId).toBe('function');
    });

    it('should have setMetadata as a function', () => {
      expect(typeof defaultLoggerConfig.setMetadata).toBe('function');
    });

    it('should have setSource as a function', () => {
      expect(typeof defaultLoggerConfig.setSource).toBe('function');
    });

    it('should not throw when calling setLogInfo', () => {
      expect(() => defaultLoggerConfig.setLogInfo({}, '', '', '', '', '', '')).not.toThrow();
    });

    it('should not throw when calling setLogError', () => {
      expect(() => defaultLoggerConfig.setLogError({}, '', '', '', '', '', '')).not.toThrow();
    });

    it('should not throw when calling setLogApi', () => {
      expect(() => defaultLoggerConfig.setLogApi({}, '', '', '', '', '', '', '')).not.toThrow();
    });

    it('should not throw when calling setLogInitiated', () => {
      expect(() => defaultLoggerConfig.setLogInitiated()).not.toThrow();
    });

    it('should not throw when calling sendLogs', () => {
      expect(() => defaultLoggerConfig.sendLogs()).not.toThrow();
    });

    it('should not throw when calling setSessionId', () => {
      expect(() => defaultLoggerConfig.setSessionId('session123')).not.toThrow();
    });

    it('should not throw when calling setClientSecret', () => {
      expect(() => defaultLoggerConfig.setClientSecret('secret123')).not.toThrow();
    });

    it('should not throw when calling setMerchantId', () => {
      expect(() => defaultLoggerConfig.setMerchantId('merchant123')).not.toThrow();
    });

    it('should not throw when calling setMetadata', () => {
      expect(() => defaultLoggerConfig.setMetadata({})).not.toThrow();
    });

    it('should not throw when calling setSource', () => {
      expect(() => defaultLoggerConfig.setSource('web')).not.toThrow();
    });
  });
});
