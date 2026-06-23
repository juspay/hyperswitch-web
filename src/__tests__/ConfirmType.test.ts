import {
  defaultConfirm,
  getConfirmParams,
  itemToObjMapper,
} from '../Types/ConfirmType.bs.js';

describe('ConfirmType', () => {
  describe('defaultConfirm', () => {
    it('should have correct default values', () => {
      expect(defaultConfirm.return_url).toBe('');
      expect(defaultConfirm.publishableKey).toBe('');
      expect(defaultConfirm.redirect).toBe('if_required');
    });
  });

  describe('getConfirmParams', () => {
    it('should extract confirm params from dict', () => {
      const dict = {
        confirmParams: {
          return_url: 'https://example.com/return',
          publishableKey: 'pk_test_123',
          redirect: 'if_required',
        },
      };
      const result = getConfirmParams(dict, 'confirmParams');
      expect(result.return_url).toBe('https://example.com/return');
      expect(result.publishableKey).toBe('pk_test_123');
      expect(result.redirect).toBe('if_required');
    });

    it('should return default values when key not found', () => {
      const dict = {};
      const result = getConfirmParams(dict, 'confirmParams');
      expect(result).toEqual(defaultConfirm);
    });

    it('should return default values when value is null', () => {
      const dict = { confirmParams: null };
      const result = getConfirmParams(dict, 'confirmParams');
      expect(result).toEqual(defaultConfirm);
    });

    it('should use default redirect value when not specified', () => {
      const dict = {
        confirmParams: {
          return_url: 'https://example.com/return',
        },
      };
      const result = getConfirmParams(dict, 'confirmParams');
      expect(result.return_url).toBe('https://example.com/return');
      expect(result.redirect).toBe('if_required');
    });

    it('should handle empty return_url', () => {
      const dict = {
        confirmParams: {
          return_url: '',
          publishableKey: 'pk_test_123',
        },
      };
      const result = getConfirmParams(dict, 'confirmParams');
      expect(result.return_url).toBe('');
      expect(result.publishableKey).toBe('pk_test_123');
    });
  });

  describe('itemToObjMapper', () => {
    it('should map dict to confirm object', () => {
      const dict = {
        doSubmit: true,
        clientSecret: 'secret_123',
        confirmParams: {
          return_url: 'https://example.com/return',
          publishableKey: 'pk_test_123',
          redirect: 'if_required',
        },
        confirmTimestamp: 1234567890.123,
        readyTimestamp: 1234567880.0,
      };
      const result = itemToObjMapper(dict);
      expect(result.doSubmit).toBe(true);
      expect(result.clientSecret).toBe('secret_123');
      expect(result.confirmParams.return_url).toBe('https://example.com/return');
      expect(result.confirmTimestamp).toBe(1234567890.123);
      expect(result.readyTimestamp).toBe(1234567880.0);
    });

    it('should use default values for missing fields', () => {
      const dict = {};
      const result = itemToObjMapper(dict);
      expect(result.doSubmit).toBe(false);
      expect(result.clientSecret).toBe('');
      expect(result.confirmParams).toEqual(defaultConfirm);
      expect(result.confirmTimestamp).toBe(0.0);
      expect(result.readyTimestamp).toBe(0.0);
    });

    it('should handle partial confirm params', () => {
      const dict = {
        clientSecret: 'secret_456',
      };
      const result = itemToObjMapper(dict);
      expect(result.clientSecret).toBe('secret_456');
      expect(result.doSubmit).toBe(false);
    });

    it('should handle zero timestamps', () => {
      const dict = {
        confirmTimestamp: 0,
        readyTimestamp: 0,
      };
      const result = itemToObjMapper(dict);
      expect(result.confirmTimestamp).toBe(0);
      expect(result.readyTimestamp).toBe(0);
    });
  });
});
