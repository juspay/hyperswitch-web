import {
  defaultError,
  getError,
  itemToObjMapper,
} from '../Types/PaymentError.bs.js';

describe('PaymentError', () => {
  describe('defaultError', () => {
    it('should have correct default values', () => {
      expect(defaultError.type_).toBe('server_error');
      expect(defaultError.code).toBe('');
      expect(defaultError.message).toBe('Something went wrong');
    });
  });

  describe('getError', () => {
    it('should extract error from dict', () => {
      const dict = {
        error: {
          type: 'validation_error',
          code: 'INVALID_CARD',
          message: 'Card number is invalid',
        },
      };
      const result = getError(dict, 'error');
      expect(result.type_).toBe('validation_error');
      expect(result.code).toBe('INVALID_CARD');
      expect(result.message).toBe('Card number is invalid');
    });

    it('should return default values when key not found', () => {
      const dict = {};
      const result = getError(dict, 'error');
      expect(result).toEqual(defaultError);
    });

    it('should return default values when value is null', () => {
      const dict = { error: null };
      const result = getError(dict, 'error');
      expect(result).toEqual(defaultError);
    });

    it('should handle partial error data', () => {
      const dict = {
        error: {
          type: 'api_error',
        },
      };
      const result = getError(dict, 'error');
      expect(result.type_).toBe('api_error');
      expect(result.code).toBe('');
      expect(result.message).toBe('');
    });

    it('should handle empty error object', () => {
      const dict = {
        error: {},
      };
      const result = getError(dict, 'error');
      expect(result.type_).toBe('');
      expect(result.code).toBe('');
      expect(result.message).toBe('');
    });
  });

  describe('itemToObjMapper', () => {
    it('should map dict to error response object', () => {
      const dict = {
        error: {
          type: 'authentication_error',
          code: 'AUTH_FAILED',
          message: 'Authentication failed',
        },
      };
      const result = itemToObjMapper(dict);
      expect(result.error.type_).toBe('authentication_error');
      expect(result.error.code).toBe('AUTH_FAILED');
      expect(result.error.message).toBe('Authentication failed');
    });

    it('should use default error when key not found', () => {
      const dict = {};
      const result = itemToObjMapper(dict);
      expect(result.error).toEqual(defaultError);
    });

    it('should handle various error types', () => {
      const dict = {
        error: {
          type: 'rate_limit_error',
          code: 'RATE_LIMIT',
          message: 'Too many requests',
        },
      };
      const result = itemToObjMapper(dict);
      expect(result.error.type_).toBe('rate_limit_error');
      expect(result.error.code).toBe('RATE_LIMIT');
    });

    it('should handle card decline error', () => {
      const dict = {
        error: {
          type: 'card_error',
          code: 'CARD_DECLINED',
          message: 'Your card was declined',
        },
      };
      const result = itemToObjMapper(dict);
      expect(result.error.type_).toBe('card_error');
      expect(result.error.code).toBe('CARD_DECLINED');
      expect(result.error.message).toBe('Your card was declined');
    });
  });
});
