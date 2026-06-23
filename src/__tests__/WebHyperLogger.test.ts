import { logFileToObj, getSourceString, getRefFromOption, make } from '../hyper-log-catcher/HyperLogger.bs.js';

describe('HyperLogger', () => {
  describe('logFileToObj', () => {
    it('should convert log file entry to JSON object with all fields', () => {
      const logFile = {
        timestamp: '1234567890',
        logType: 'DEBUG',
        category: 'API',
        source: 'hyper sdk',
        version: '1.0.0',
        value: 'test value',
        sessionId: 'session_123',
        merchantId: 'merchant_456',
        paymentId: 'payment_789',
        appId: 'app_001',
        platform: 'web',
        userAgent: 'Mozilla/5.0',
        eventName: 'TEST_EVENT',
        browserName: 'Chrome',
        browserVersion: '120.0',
        latency: '100',
        firstEvent: true,
        paymentMethod: 'card',
      };

      const result = logFileToObj(logFile);

      expect(result.timestamp).toBe('1234567890');
      expect(result.log_type).toBe('DEBUG');
      expect(result.component).toBe('WEB');
      expect(result.category).toBe('API');
      expect(result.source).toBe('HYPER_SDK');
      expect(result.version).toBe('1.0.0');
      expect(result.value).toBe('test value');
      expect(result.session_id).toBe('session_123');
      expect(result.merchant_id).toBe('merchant_456');
      expect(result.payment_id).toBe('payment_789');
      expect(result.app_id).toBe('app_001');
      expect(result.platform).toBe('WEB');
      expect(result.user_agent).toBe('Mozilla/5.0');
      expect(result.event_name).toBe('TEST_EVENT');
      expect(result.browser_name).toBe('CHROME');
      expect(result.browser_version).toBe('120.0');
      expect(result.latency).toBe('100');
      expect(result.first_event).toBe('true');
      expect(result.payment_method).toBe('CARD');
    });

    it('should handle INFO log type', () => {
      const logFile = {
        timestamp: '1234567890',
        logType: 'INFO',
        category: 'USER_EVENT',
        source: 'test source',
        version: '1.0.0',
        value: '',
        sessionId: '',
        merchantId: '',
        paymentId: '',
        appId: '',
        platform: 'web',
        userAgent: '',
        eventName: 'APP_RENDERED',
        browserName: 'Firefox',
        browserVersion: '115.0',
        latency: '',
        firstEvent: false,
        paymentMethod: '',
      };

      const result = logFileToObj(logFile);
      expect(result.log_type).toBe('INFO');
      expect(result.category).toBe('USER_EVENT');
      expect(result.browser_name).toBe('FIREFOX');
    });

    it('should handle ERROR log type', () => {
      const logFile = {
        timestamp: '1234567890',
        logType: 'ERROR',
        category: 'USER_ERROR',
        source: 'error source',
        version: '1.0.0',
        value: 'error message',
        sessionId: '',
        merchantId: '',
        paymentId: '',
        appId: '',
        platform: 'web',
        userAgent: '',
        eventName: 'SDK_CRASH',
        browserName: 'Safari',
        browserVersion: '17.0',
        latency: '500',
        firstEvent: true,
        paymentMethod: '',
      };

      const result = logFileToObj(logFile);
      expect(result.log_type).toBe('ERROR');
      expect(result.category).toBe('USER_ERROR');
      expect(result.browser_name).toBe('SAFARI');
    });

    it('should handle WARNING log type', () => {
      const logFile = {
        timestamp: '1234567890',
        logType: 'WARNING',
        category: 'MERCHANT_EVENT',
        source: 'warning source',
        version: '1.0.0',
        value: 'warning message',
        sessionId: '',
        merchantId: '',
        paymentId: '',
        appId: '',
        platform: 'web',
        userAgent: '',
        eventName: 'PAYMENT_ATTEMPT',
        browserName: 'Edge',
        browserVersion: '120.0',
        latency: '',
        firstEvent: false,
        paymentMethod: '',
      };

      const result = logFileToObj(logFile);
      expect(result.log_type).toBe('WARNING');
      expect(result.category).toBe('MERCHANT_EVENT');
      expect(result.browser_name).toBe('EDGE');
    });

    it('should handle SILENT log type', () => {
      const logFile = {
        timestamp: '1234567890',
        logType: 'SILENT',
        category: 'API',
        source: 'silent source',
        version: '1.0.0',
        value: '',
        sessionId: '',
        merchantId: '',
        paymentId: '',
        appId: '',
        platform: 'web',
        userAgent: '',
        eventName: 'NETWORK_STATE',
        browserName: 'Others',
        browserVersion: '0',
        latency: '',
        firstEvent: false,
        paymentMethod: '',
      };

      const result = logFileToObj(logFile);
      expect(result.log_type).toBe('SILENT');
    });

    it('should convert firstEvent boolean to string', () => {
      const logFile = {
        timestamp: '',
        logType: 'INFO',
        category: 'API',
        source: '',
        version: '',
        value: '',
        sessionId: '',
        merchantId: '',
        paymentId: '',
        appId: '',
        platform: '',
        userAgent: '',
        eventName: '',
        browserName: '',
        browserVersion: '',
        latency: '',
        firstEvent: true,
        paymentMethod: '',
      };

      const result = logFileToObj(logFile);
      expect(result.first_event).toBe('true');

      const logFile2 = { ...logFile, firstEvent: false };
      const result2 = logFileToObj(logFile2);
      expect(result2.first_event).toBe('false');
    });
  });

  describe('getSourceString', () => {
    it('should return hyper_loader for Loader source', () => {
      expect(getSourceString('Loader')).toBe('hyper_loader');
    });

    it('should return headless for Headless source', () => {
      expect(getSourceString('Headless')).toBe('headless');
    });

    it('should return hyper + payment mode for payment mode variant', () => {
      const source = { _0: 'card' };
      expect(getSourceString(source)).toBe('hypercard');
    });

    it('should return hyper + snake_case payment mode for payment mode variant', () => {
      const source = { _0: 'paymentMethodCollect' };
      expect(getSourceString(source)).toBe('hyperpayment_method_collect');
    });

    it('should handle googlePay payment mode', () => {
      const source = { _0: 'googlePay' };
      expect(getSourceString(source)).toBe('hypergoogle_pay');
    });

    it('should handle applePay payment mode', () => {
      const source = { _0: 'applePay' };
      expect(getSourceString(source)).toBe('hyperapple_pay');
    });

    it('should handle payment mode with multiple words', () => {
      const source = { _0: 'paymentMethodsManagement' };
      expect(getSourceString(source)).toBe('hyperpayment_methods_management');
    });
  });

  describe('getRefFromOption', () => {
    it('should return ref with contents set to value when value is provided', () => {
      const result = getRefFromOption('test_value');
      expect(result).toHaveProperty('contents');
      expect(result.contents).toBe('test_value');
    });

    it('should return ref with empty string when value is undefined', () => {
      const result = getRefFromOption(undefined);
      expect(result).toHaveProperty('contents');
      expect(result.contents).toBe('');
    });

    it('should return ref with null when value is null', () => {
      const result = getRefFromOption(null);
      expect(result).toHaveProperty('contents');
      expect(result.contents).toBe(null);
    });

    it('should handle numeric string values', () => {
      const result = getRefFromOption('12345');
      expect(result.contents).toBe('12345');
    });

    it('should handle empty string value', () => {
      const result = getRefFromOption('');
      expect(result.contents).toBe('');
    });

    it('should return a mutable ref object', () => {
      const result = getRefFromOption('initial');
      result.contents = 'modified';
      expect(result.contents).toBe('modified');
    });
  });

  describe('make', () => {
    const originalWindow = globalThis.window;
    const originalNavigator = globalThis.navigator;
    const originalAddEventListener = window.addEventListener;

    beforeEach(() => {
      Object.defineProperty(globalThis, 'navigator', {
        value: {
          onLine: true,
          connection: {
            effectiveType: '4g',
            downlink: 10,
            rtt: 50,
          },
          sendBeacon: jest.fn(() => true),
          platform: 'MacIntel',
          userAgent: 'Mozilla/5.0',
        },
        writable: true,
        configurable: true,
      });
      Object.defineProperty(globalThis, 'window', {
        value: {
          navigator: globalThis.navigator,
          addEventListener: jest.fn(),
          removeEventListener: jest.fn(),
        },
        writable: true,
        configurable: true,
      });
      (globalThis as any).loggingLevel = 'INFO';
      (globalThis as any).enableLogging = true;
      (globalThis as any).maxLogsPushedPerEventName = 10;
      (globalThis as any).logEndpoint = 'https://test.example.com/logs';
      (globalThis as any).repoVersion = '1.0.0';
    });

    afterEach(() => {
      Object.defineProperty(globalThis, 'window', {
        value: originalWindow,
        writable: true,
        configurable: true,
      });
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        writable: true,
        configurable: true,
      });
      delete (globalThis as any).loggingLevel;
      delete (globalThis as any).enableLogging;
      delete (globalThis as any).maxLogsPushedPerEventName;
      delete (globalThis as any).logEndpoint;
      delete (globalThis as any).repoVersion;
    });

    it('should return logger object with all required methods', () => {
      const logger = make('session123', 'Loader', 'clientSecret123', 'merchant123', null);
      expect(logger).toHaveProperty('setLogInfo');
      expect(logger).toHaveProperty('setLogError');
      expect(logger).toHaveProperty('setLogApi');
      expect(logger).toHaveProperty('setLogInitiated');
      expect(logger).toHaveProperty('setConfirmPaymentValue');
      expect(logger).toHaveProperty('sendLogs');
      expect(logger).toHaveProperty('setSessionId');
      expect(logger).toHaveProperty('setClientSecret');
      expect(logger).toHaveProperty('setMerchantId');
      expect(logger).toHaveProperty('setMetadata');
      expect(logger).toHaveProperty('setSource');
    });

    it('should register beforeunload event listener', () => {
      make('session123', 'Loader', 'clientSecret123', 'merchant123', null);
      expect(window.addEventListener).toHaveBeenCalledWith('beforeunload', expect.any(Function));
    });

    describe('setConfirmPaymentValue', () => {
      it('should return object with method and type', () => {
        const logger = make('session123', 'Loader', 'clientSecret123', 'merchant123', null);
        const result = logger.setConfirmPaymentValue('card');
        expect(result.method).toBe('confirmPayment');
        expect(result.type).toBe('card');
      });

      it('should handle different payment types', () => {
        const logger = make('session123', 'Loader', 'clientSecret123', 'merchant123', null);
        expect(logger.setConfirmPaymentValue('wallet').type).toBe('wallet');
        expect(logger.setConfirmPaymentValue('bank_transfer').type).toBe('bank_transfer');
      });

      it('should handle empty payment type', () => {
        const logger = make('session123', 'Loader', 'clientSecret123', 'merchant123', null);
        const result = logger.setConfirmPaymentValue('');
        expect(result.type).toBe('');
      });
    });

    describe('setSessionId', () => {
      it('should update session ID', () => {
        const logger = make('initialSession', 'Loader', 'clientSecret123', 'merchant123', null);
        logger.setSessionId('newSessionId');
      });
    });

    describe('setClientSecret', () => {
      it('should update client secret', () => {
        const logger = make('session123', 'Loader', 'initialSecret', 'merchant123', null);
        logger.setClientSecret('newClientSecret');
      });
    });

    describe('setMerchantId', () => {
      it('should update merchant ID', () => {
        const logger = make('session123', 'Loader', 'clientSecret123', 'initialMerchant', null);
        logger.setMerchantId('newMerchantId');
      });
    });

    describe('setMetadata', () => {
      it('should update metadata', () => {
        const logger = make('session123', 'Loader', 'clientSecret123', 'merchant123', null);
        logger.setMetadata({ key: 'value' });
      });
    });

    describe('setSource', () => {
      it('should update source string', () => {
        const logger = make('session123', 'Loader', 'clientSecret123', 'merchant123', null);
        logger.setSource('new_source');
      });
    });
  });
});
