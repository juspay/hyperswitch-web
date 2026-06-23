import {
  eventNameToStrMapper,
  getPaymentId,
  convertToScreamingSnakeCase,
  toSnakeCaseWithSeparator,
  defaultLoggerConfig,
  apiEventInitMapper,
} from '../Utilities/LoggerUtils.bs.js';

describe('WebLoggerUtils', () => {
  describe('eventNameToStrMapper', () => {
    it('should return the event name as string', () => {
      expect(eventNameToStrMapper('TEST_EVENT')).toBe('TEST_EVENT');
    });

    it('should handle empty string', () => {
      expect(eventNameToStrMapper('')).toBe('');
    });

    it('should handle any string', () => {
      expect(eventNameToStrMapper('any_event_name')).toBe('any_event_name');
    });
  });

  describe('getPaymentId', () => {
    it('should extract payment ID from client secret', () => {
      expect(getPaymentId('pay_abc123_secret_xyz')).toBe('pay_abc123');
    });

    it('should handle client secret with multiple _secret_ occurrences', () => {
      expect(getPaymentId('pay_test_secret_value')).toBe('pay_test');
    });

    it('should handle invalid format', () => {
      expect(getPaymentId('invalid')).toBe('invalid');
    });

    it('should handle empty string', () => {
      expect(getPaymentId('')).toBe('');
    });
  });

  describe('convertToScreamingSnakeCase', () => {
    it('should convert to SCREAMING_SNAKE_CASE', () => {
      expect(convertToScreamingSnakeCase('hello world')).toBe('HELLO_WORLD');
    });

    it('should handle already uppercase', () => {
      expect(convertToScreamingSnakeCase('HELLO WORLD')).toBe('HELLO_WORLD');
    });

    it('should handle empty string', () => {
      expect(convertToScreamingSnakeCase('')).toBe('');
    });

    it('should handle single word', () => {
      expect(convertToScreamingSnakeCase('hello')).toBe('HELLO');
    });
  });

  describe('toSnakeCaseWithSeparator', () => {
    it('should convert to snake_case with underscore separator', () => {
      expect(toSnakeCaseWithSeparator('helloWorld', '_')).toBe('hello_world');
    });

    it('should convert to kebab-style with dash separator', () => {
      expect(toSnakeCaseWithSeparator('helloWorld', '-')).toBe('hello-world');
    });

    it('should handle empty string', () => {
      expect(toSnakeCaseWithSeparator('', '_')).toBe('');
    });

    it('should handle already snake_case', () => {
      expect(toSnakeCaseWithSeparator('hello_world', '_')).toBe('hello_world');
    });
  });

  describe('defaultLoggerConfig', () => {
    it('should be defined', () => {
      expect(defaultLoggerConfig).toBeDefined();
    });

    it('should have setLogInfo method', () => {
      expect(defaultLoggerConfig.setLogInfo).toBeDefined();
      expect(typeof defaultLoggerConfig.setLogInfo).toBe('function');
    });

    it('should have setLogError method', () => {
      expect(defaultLoggerConfig.setLogError).toBeDefined();
      expect(typeof defaultLoggerConfig.setLogError).toBe('function');
    });

    it('should have setLogApi method', () => {
      expect(defaultLoggerConfig.setLogApi).toBeDefined();
      expect(typeof defaultLoggerConfig.setLogApi).toBe('function');
    });

    it('should have sendLogs method', () => {
      expect(defaultLoggerConfig.sendLogs).toBeDefined();
      expect(typeof defaultLoggerConfig.sendLogs).toBe('function');
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

    it('should map SESSIONS_CALL to SESSIONS_CALL_INIT', () => {
      expect(apiEventInitMapper('SESSIONS_CALL')).toBe('SESSIONS_CALL_INIT');
    });

    it('should map PAYMENT_METHODS_CALL to PAYMENT_METHODS_CALL_INIT', () => {
      expect(apiEventInitMapper('PAYMENT_METHODS_CALL')).toBe('PAYMENT_METHODS_CALL_INIT');
    });

    it('should return undefined for unknown event', () => {
      expect(apiEventInitMapper('UNKNOWN_EVENT')).toBeUndefined();
    });
  });
});
