import { decodeRedirectionFlags, defaultPaymentToken } from '../Types/RecoilAtomTypes.bs.js';

describe('RecoilAtomTypes', () => {
  describe('decodeRedirectionFlags', () => {
    const defaultFlags = {
      shouldUseTopRedirection: false,
      shouldRemoveBeforeUnloadEvents: false,
    };

    it('should decode redirection flags from valid JSON object', () => {
      const json = {
        shouldUseTopRedirection: true,
        shouldRemoveBeforeUnloadEvents: true,
      };
      const result = decodeRedirectionFlags(json, defaultFlags);
      expect(result.shouldUseTopRedirection).toBe(true);
      expect(result.shouldRemoveBeforeUnloadEvents).toBe(true);
    });

    it('should return default values when JSON is null', () => {
      const result = decodeRedirectionFlags(null, defaultFlags);
      expect(result.shouldUseTopRedirection).toBe(false);
      expect(result.shouldRemoveBeforeUnloadEvents).toBe(false);
    });

    it('should return default values when JSON is undefined', () => {
      const result = decodeRedirectionFlags(undefined, defaultFlags);
      expect(result.shouldUseTopRedirection).toBe(false);
      expect(result.shouldRemoveBeforeUnloadEvents).toBe(false);
    });

    it('should use default for missing shouldUseTopRedirection field', () => {
      const json = {
        shouldRemoveBeforeUnloadEvents: true,
      };
      const customDefault = {
        shouldUseTopRedirection: true,
        shouldRemoveBeforeUnloadEvents: false,
      };
      const result = decodeRedirectionFlags(json, customDefault);
      expect(result.shouldUseTopRedirection).toBe(true);
      expect(result.shouldRemoveBeforeUnloadEvents).toBe(true);
    });

    it('should use default for missing shouldRemoveBeforeUnloadEvents field', () => {
      const json = {
        shouldUseTopRedirection: true,
      };
      const customDefault = {
        shouldUseTopRedirection: false,
        shouldRemoveBeforeUnloadEvents: true,
      };
      const result = decodeRedirectionFlags(json, customDefault);
      expect(result.shouldUseTopRedirection).toBe(true);
      expect(result.shouldRemoveBeforeUnloadEvents).toBe(true);
    });

    it('should use default values for empty object', () => {
      const json = {};
      const customDefault = {
        shouldUseTopRedirection: true,
        shouldRemoveBeforeUnloadEvents: true,
      };
      const result = decodeRedirectionFlags(json, customDefault);
      expect(result.shouldUseTopRedirection).toBe(true);
      expect(result.shouldRemoveBeforeUnloadEvents).toBe(true);
    });

    it('should handle false values correctly', () => {
      const json = {
        shouldUseTopRedirection: false,
        shouldRemoveBeforeUnloadEvents: false,
      };
      const customDefault = {
        shouldUseTopRedirection: true,
        shouldRemoveBeforeUnloadEvents: true,
      };
      const result = decodeRedirectionFlags(json, customDefault);
      expect(result.shouldUseTopRedirection).toBe(false);
      expect(result.shouldRemoveBeforeUnloadEvents).toBe(false);
    });

    it('should handle mixed true and false values', () => {
      const json = {
        shouldUseTopRedirection: true,
        shouldRemoveBeforeUnloadEvents: false,
      };
      const result = decodeRedirectionFlags(json, defaultFlags);
      expect(result.shouldUseTopRedirection).toBe(true);
      expect(result.shouldRemoveBeforeUnloadEvents).toBe(false);
    });

    it('should return default when JSON is a non-object value', () => {
      const result1 = decodeRedirectionFlags('string', defaultFlags);
      expect(result1).toEqual(defaultFlags);

      const result2 = decodeRedirectionFlags(123, defaultFlags);
      expect(result2).toEqual(defaultFlags);

      const result3 = decodeRedirectionFlags([], defaultFlags);
      expect(result3).toEqual(defaultFlags);
    });
  });

  describe('defaultPaymentToken', () => {
    it('should have empty paymentToken', () => {
      expect(defaultPaymentToken.paymentToken).toBe('');
    });

    it('should have empty customerId', () => {
      expect(defaultPaymentToken.customerId).toBe('');
    });

    it('should be a frozen object structure', () => {
      expect(typeof defaultPaymentToken).toBe('object');
      expect(Object.keys(defaultPaymentToken)).toContain('paymentToken');
      expect(Object.keys(defaultPaymentToken)).toContain('customerId');
    });
  });
});
