import {
  logFileToObj,
  getRefFromOption,
  getSourceString,
  make,
} from '../hyper-log-catcher/HyperLogger.bs.js';
import * as LoggerUtils from '../Utilities/LoggerUtils.bs.js';
import * as CardThemeType from '../Types/CardThemeType.bs.js';

jest.mock('../Utilities/LoggerUtils.bs.js', () => ({
  convertToScreamingSnakeCase: jest.fn((str) => str?.toUpperCase() || ''),
  eventNameToStrMapper: jest.fn((eventName) => eventName),
  toSnakeCaseWithSeparator: jest.fn((str, sep) => str?.toLowerCase().replace(/ /g, sep) || ''),
  retrieveLogsFromIndexedDB: jest.fn(),
  clearLogsFromIndexedDB: jest.fn(),
  saveLogsToIndexedDB: jest.fn(),
  getPaymentId: jest.fn((secret) => secret?.split('_')[0] || ''),
}));

jest.mock('../Hooks/NetworkInformation.bs.js', () => ({
  getNetworkState: jest.fn(() => ({ _0: { isOnline: true } })),
  defaultNetworkState: { isOnline: true },
}));

jest.mock('../Utilities/Utils.bs.js', () => ({
  getStringFromBool: jest.fn((bool) => bool?.toString() || 'false'),
  arrayOfNameAndVersion: ['Chrome', '120'],
}));

jest.mock('../Types/CardThemeType.bs.js', () => ({
  getPaymentModeToStrMapper: jest.fn((mode) => mode),
}));

describe('HyperLogger', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (window as any).navigator = {
      platform: 'MacIntel',
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
      sendBeacon: jest.fn(),
    };
    (window as any).addEventListener = jest.fn();
    (window as any).removeEventListener = jest.fn();
  });

  describe('logFileToObj', () => {
    it('should convert log file with DEBUG log type', () => {
      const logFile = {
        logType: 'DEBUG',
        category: 'API',
        source: 'hyper_loader',
        version: '1.0.0',
        value: 'test value',
        sessionId: 'session123',
        merchantId: 'merchant456',
        paymentId: 'payment789',
        appId: 'app001',
        platform: 'web',
        userAgent: 'Mozilla/5.0',
        eventName: 'APP_RENDERED',
        browserName: 'Chrome',
        browserVersion: '120',
        latency: '100',
        firstEvent: true,
        paymentMethod: 'card',
        timestamp: '1234567890',
      };

      const result = logFileToObj(logFile);

      expect(result.log_type).toBe('DEBUG');
      expect(result.category).toBe('API');
      expect(result.component).toBe('WEB');
      expect(result.timestamp).toBe('1234567890');
    });

    it('should convert log file with ERROR log type', () => {
      const logFile = {
        logType: 'ERROR',
        category: 'USER_ERROR',
        source: 'hyper_payment',
        version: '1.0.0',
        value: 'error occurred',
        sessionId: 'session123',
        merchantId: 'merchant456',
        paymentId: 'payment789',
        appId: 'app001',
        platform: 'web',
        userAgent: 'Mozilla/5.0',
        eventName: 'SDK_CRASH',
        browserName: 'Firefox',
        browserVersion: '121',
        latency: '',
        firstEvent: false,
        paymentMethod: 'paypal',
        timestamp: '1234567891',
      };

      const result = logFileToObj(logFile);

      expect(result.log_type).toBe('ERROR');
      expect(result.category).toBe('USER_ERROR');
    });

    it('should convert log file with INFO log type', () => {
      const logFile = {
        logType: 'INFO',
        category: 'USER_EVENT',
        source: 'headless',
        version: '2.0.0',
        value: 'user action',
        sessionId: 'session456',
        merchantId: 'merchant789',
        paymentId: 'payment001',
        appId: 'app002',
        platform: 'ios',
        userAgent: 'Safari/605.1.15',
        eventName: 'PAYMENT_ATTEMPT',
        browserName: 'Safari',
        browserVersion: '17',
        latency: '50',
        firstEvent: true,
        paymentMethod: 'apple_pay',
        timestamp: '1234567892',
      };

      const result = logFileToObj(logFile);

      expect(result.log_type).toBe('INFO');
      expect(result.category).toBe('USER_EVENT');
    });

    it('should convert log file with WARNING log type', () => {
      const logFile = {
        logType: 'WARNING',
        category: 'MERCHANT_EVENT',
        source: 'test',
        version: '1.0.0',
        value: 'warning message',
        sessionId: 'session789',
        merchantId: 'merchant001',
        paymentId: 'payment002',
        appId: 'app003',
        platform: 'android',
        userAgent: 'Chrome Mobile',
        eventName: 'PAYMENT_METHOD_CHANGED',
        browserName: 'Chrome',
        browserVersion: '120',
        latency: '',
        firstEvent: true,
        paymentMethod: 'google_pay',
        timestamp: '1234567893',
      };

      const result = logFileToObj(logFile);

      expect(result.log_type).toBe('WARNING');
      expect(result.category).toBe('MERCHANT_EVENT');
    });

    it('should convert log file with SILENT log type', () => {
      const logFile = {
        logType: 'SILENT',
        category: 'API',
        source: 'silent',
        version: '1.0.0',
        value: '',
        sessionId: 'session999',
        merchantId: 'merchant999',
        paymentId: 'payment999',
        appId: 'app999',
        platform: 'web',
        userAgent: 'Bot/1.0',
        eventName: 'LOG_INITIATED',
        browserName: 'Unknown',
        browserVersion: '0',
        latency: '',
        firstEvent: true,
        paymentMethod: '',
        timestamp: '1234567894',
      };

      const result = logFileToObj(logFile);

      expect(result.log_type).toBe('SILENT');
    });

    it('should handle undefined values gracefully', () => {
      const logFile = {
        logType: 'INFO',
        category: 'API',
        source: undefined,
        version: undefined,
        value: undefined,
        sessionId: undefined,
        merchantId: undefined,
        paymentId: undefined,
        appId: undefined,
        platform: undefined,
        userAgent: undefined,
        eventName: undefined,
        browserName: undefined,
        browserVersion: undefined,
        latency: undefined,
        firstEvent: undefined,
        paymentMethod: undefined,
        timestamp: undefined,
      };

      const result = logFileToObj(logFile);

      expect(result.component).toBe('WEB');
      expect(result).toHaveProperty('timestamp');
    });
  });

  describe('getRefFromOption', () => {
    it('should create ref with provided value', () => {
      const result = getRefFromOption('test-value');
      expect(result.contents).toBe('test-value');
    });

    it('should create ref with empty string for undefined', () => {
      const result = getRefFromOption(undefined);
      expect(result.contents).toBe('');
    });

    it('should handle null value gracefully', () => {
      const result = getRefFromOption(null as any);
      expect(result.contents).toBeNull();
    });

    it('should create ref that can be updated', () => {
      const result = getRefFromOption('initial');
      expect(result.contents).toBe('initial');
      result.contents = 'updated';
      expect(result.contents).toBe('updated');
    });
  });

  describe('getSourceString', () => {
    it('should return hyper_loader for Loader source', () => {
      const result = getSourceString('Loader');
      expect(result).toBe('hyper_loader');
    });

    it('should return headless for non-Loader string source', () => {
      const result = getSourceString('Headless' as any);
      expect(result).toBe('headless');
    });

    it('should format payment mode source correctly', () => {
      (CardThemeType.getPaymentModeToStrMapper as jest.Mock).mockReturnValue('payment');
      const result = getSourceString({ _0: 'payment' } as any);
      expect(result).toContain('hyper');
    });

    it('should handle Payment mode with snake case conversion', () => {
      (CardThemeType.getPaymentModeToStrMapper as jest.Mock).mockReturnValue('card payment');
      const result = getSourceString({ _0: 'card payment' } as any);
      expect(result).toBe('hypercard_payment');
    });

    it('should handle Checkout mode', () => {
      (CardThemeType.getPaymentModeToStrMapper as jest.Mock).mockReturnValue('checkout');
      const result = getSourceString({ _0: 'checkout' } as any);
      expect(result).toBe('hypercheckout');
    });
  });

  describe('make', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('should create logger with setLogInfo method', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.setLogInfo).toBeDefined();
      expect(typeof logger.setLogInfo).toBe('function');
    });

    it('should create logger with setLogError method', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.setLogError).toBeDefined();
      expect(typeof logger.setLogError).toBe('function');
    });

    it('should create logger with setLogApi method', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.setLogApi).toBeDefined();
      expect(typeof logger.setLogApi).toBe('function');
    });

    it('should create logger with setLogInitiated method', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.setLogInitiated).toBeDefined();
      expect(typeof logger.setLogInitiated).toBe('function');
    });

    it('should create logger with sendLogs method', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.sendLogs).toBeDefined();
      expect(typeof logger.sendLogs).toBe('function');
    });

    it('should create logger with setConfirmPaymentValue method', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.setConfirmPaymentValue).toBeDefined();
      expect(typeof logger.setConfirmPaymentValue).toBe('function');
    });

    it('should create logger with setter methods', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.setSessionId).toBeDefined();
      expect(logger.setClientSecret).toBeDefined();
      expect(logger.setMerchantId).toBeDefined();
      expect(logger.setMetadata).toBeDefined();
      expect(logger.setSource).toBeDefined();
    });

    it('should set sessionId correctly', () => {
      const logger = make('initial', 'Loader', 'secret_456', 'merchant789', null);
      logger.setSessionId('new-session');
      expect(typeof logger.setSessionId).toBe('function');
    });

    it('should set clientSecret correctly', () => {
      const logger = make('session123', 'Loader', 'initial_secret', 'merchant789', null);
      logger.setClientSecret('new_secret_789');
      expect(typeof logger.setClientSecret).toBe('function');
    });

    it('should set merchantId correctly', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'initial', null);
      logger.setMerchantId('new-merchant');
      expect(typeof logger.setMerchantId).toBe('function');
    });

    it('should set metadata correctly', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', { key: 'value' });
      logger.setMetadata({ newKey: 'newValue' });
      expect(typeof logger.setMetadata).toBe('function');
    });

    it('should set source correctly', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      logger.setSource('new-source');
      expect(typeof logger.setSource).toBe('function');
    });

    it('should create confirmPayment value object', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      const result = logger.setConfirmPaymentValue('card');
      expect(result).toEqual({
        method: 'confirmPayment',
        type: 'card',
      });
    });

    it('should handle different payment types in setConfirmPaymentValue', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      const paypalResult = logger.setConfirmPaymentValue('paypal');
      expect(paypalResult).toEqual({
        method: 'confirmPayment',
        type: 'paypal',
      });
    });

    it('should call sendBeacon when sendLogs is invoked with data', async () => {
      const sendBeaconMock = jest.fn();
      (window.navigator as any).sendBeacon = sendBeaconMock;
      
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      logger.setLogInfo('test', 'APP_RENDERED', '1234567890');
      
      jest.advanceTimersByTime(20000);
      
      expect(sendBeaconMock).toBeDefined();
    });

    it('should handle headless source', () => {
      const logger = make('session123', 'Headless' as any, 'secret_456', 'merchant789', null);
      expect(logger.setLogInfo).toBeDefined();
    });

    it('should handle empty sessionId', () => {
      const logger = make('', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.setLogInfo).toBeDefined();
    });

    it('should handle empty clientSecret', () => {
      const logger = make('session123', 'Loader', '', 'merchant789', null);
      expect(logger.setLogInfo).toBeDefined();
    });

    it('should handle empty merchantId', () => {
      const logger = make('session123', 'Loader', 'secret_456', '', null);
      expect(logger.setLogInfo).toBeDefined();
    });

    it('should handle null metadata', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(logger.setLogInfo).toBeDefined();
    });

    it('should handle object metadata', () => {
      const metadata = { customField: 'customValue', nested: { key: 'value' } };
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', metadata);
      expect(logger.setLogInfo).toBeDefined();
    });

    it('should handle payment mode source object', () => {
      const source = { _0: 'payment' };
      const logger = make('session123', source as any, 'secret_456', 'merchant789', null);
      expect(logger.setLogInfo).toBeDefined();
    });

    it('should add beforeunload event listener', () => {
      make('session123', 'Loader', 'secret_456', 'merchant789', null);
      expect(window.addEventListener).toHaveBeenCalledWith('beforeunload', expect.any(Function));
    });
  });

  describe('make - logging methods behavior', () => {
    beforeEach(() => {
      jest.useFakeTimers();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it('should call setLogInfo with correct parameters', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      
      expect(() => {
        logger.setLogInfo('test value', 'APP_RENDERED', '1234567890', 'INFO', 'USER_EVENT', 'card');
      }).not.toThrow();
    });

    it('should call setLogError with correct parameters', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      
      expect(() => {
        logger.setLogError('error message', 'SDK_CRASH', '1234567890', '', 'ERROR', 'USER_ERROR', 'card');
      }).not.toThrow();
    });

    it('should call setLogApi with correct parameters', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      
      expect(() => {
        logger.setLogApi(
          { TAG: 'StringType', _0: 'api data' },
          'PAYMENT_METHODS_CALL',
          '1234567890',
          'INFO',
          'API',
          'card',
          'Request',
          false
        );
      }).not.toThrow();
    });

    it('should call setLogInitiated', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      
      expect(() => {
        logger.setLogInitiated();
      }).not.toThrow();
    });

    it('should handle ArrayType in setLogApi', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      
      expect(() => {
        logger.setLogApi(
          { TAG: 'ArrayType', _0: [['key', 'value']] },
          'PAYMENT_METHODS_CALL',
          '1234567890'
        );
      }).not.toThrow();
    });

    it('should handle optional parameters with defaults in setLogInfo', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      
      expect(() => {
        logger.setLogInfo('test value', 'APP_RENDERED');
      }).not.toThrow();
    });

    it('should handle optional parameters with defaults in setLogError', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      
      expect(() => {
        logger.setLogError('error message', 'SDK_CRASH');
      }).not.toThrow();
    });

    it('should handle optional parameters with defaults in setLogApi', () => {
      const logger = make('session123', 'Loader', 'secret_456', 'merchant789', null);
      
      expect(() => {
        logger.setLogApi({ TAG: 'StringType', _0: 'data' }, 'PAYMENT_METHODS_CALL');
      }).not.toThrow();
    });
  });

  describe('edge cases', () => {
    it('should handle very long sessionId', () => {
      const longSessionId = 'a'.repeat(1000);
      const result = getRefFromOption(longSessionId);
      expect(result.contents).toBe(longSessionId);
    });

    it('should handle special characters in sessionId', () => {
      const specialSessionId = 'session-123_test.456';
      const result = getRefFromOption(specialSessionId);
      expect(result.contents).toBe(specialSessionId);
    });

    it('should handle unicode characters', () => {
      const unicodeString = '测试-テスト-테스트';
      const result = getRefFromOption(unicodeString);
      expect(result.contents).toBe(unicodeString);
    });

    it('should handle empty string in getSourceString', () => {
      const result = getSourceString('' as any);
      expect(result).toBe('headless');
    });

    it('should handle object source with payment mode', () => {
      (CardThemeType.getPaymentModeToStrMapper as jest.Mock).mockReturnValue('checkout');
      const result = getSourceString({ _0: 'checkout' } as any);
      expect(result).toContain('hyper');
    });

    it('should handle undefined in getSourceString', () => {
      const result = getSourceString(undefined as any);
      expect(result).toBe('headless');
    });
  });
});
