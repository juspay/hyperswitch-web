import {
  errorWarning,
  unknownKeysWarning,
  unknownPropValueWarning,
  valueOutRangeWarning,
} from '../Utilities/ErrorUtils.bs.js';

describe('ErrorUtils', () => {
  describe('errorWarning', () => {
    it('should be an array of error/warning definitions', () => {
      expect(errorWarning).toBeDefined();
      expect(Array.isArray(errorWarning)).toBe(true);
    });

    it('should contain INVALID_PK error', () => {
      const invalidPk = errorWarning.find((entry: any) => entry[0] === 'INVALID_PK');
      expect(invalidPk).toBeDefined();
      expect(invalidPk[1]).toBe('Error');
    });

    it('should contain DEPRECATED_LOADSTRIPE warning', () => {
      const deprecated = errorWarning.find((entry: any) => entry[0] === 'DEPRECATED_LOADSTRIPE');
      expect(deprecated).toBeDefined();
      expect(deprecated[1]).toBe('Warning');
    });

    it('should contain REQUIRED_PARAMETER error', () => {
      const required = errorWarning.find((entry: any) => entry[0] === 'REQUIRED_PARAMETER');
      expect(required).toBeDefined();
      expect(required[1]).toBe('Error');
    });

    it('should have dynamic messages for certain errors', () => {
      const typeError = errorWarning.find((entry: any) => entry[0] === 'TYPE_BOOL_ERROR');
      expect(typeError).toBeDefined();
      expect((typeError![2] as any).TAG).toBe('Dynamic');
    });

    it('should have static messages for certain errors', () => {
      const internalApi = errorWarning.find((entry: any) => entry[0] === 'INTERNAL_API_DOWN');
      expect(internalApi).toBeDefined();
      expect((internalApi![2] as any).TAG).toBe('Static');
    });
  });

  describe('unknownKeysWarning', () => {
    it('should warn for unknown keys', () => {
      const validKeys = ['name', 'email', 'phone'];
      const dict = { name: 'John', unknownKey: 'value' };
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
      
      unknownKeysWarning(validKeys, dict, 'testDict');
      
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('should not warn for valid keys', () => {
      const validKeys = ['name', 'email', 'phone'];
      const dict = { name: 'John', email: 'test@test.com' };
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
      
      unknownKeysWarning(validKeys, dict, 'testDict');
      
      expect(consoleSpy).not.toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('should handle empty dict', () => {
      const validKeys = ['name', 'email'];
      const dict = {};
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
      
      unknownKeysWarning(validKeys, dict, 'testDict');
      
      expect(consoleSpy).not.toHaveBeenCalled();
      consoleSpy.mockRestore();
    });
  });

  describe('unknownPropValueWarning', () => {
    it('should warn for invalid prop value', () => {
      const validValues = ['option1', 'option2', 'option3'];
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
      
      unknownPropValueWarning('invalidOption', validValues, 'testProp');
      
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });

    it('should include expected values in warning', () => {
      const validValues = ['option1', 'option2'];
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
      
      unknownPropValueWarning('invalidOption', validValues, 'testProp');
      
      const warningCall = consoleSpy.mock.calls[0][0];
      expect(warningCall).toContain('option1');
      expect(warningCall).toContain('option2');
      consoleSpy.mockRestore();
    });
  });

  describe('valueOutRangeWarning', () => {
    it('should call manageErrorWarning for out of range value', () => {
      const mockLogger = {
        setLogError: jest.fn(),
        setLogInfo: jest.fn(),
      };
      const consoleSpy = jest.spyOn(console, 'warn').mockImplementation();
      
      valueOutRangeWarning(150, 'age', '0-100', mockLogger);
      
      expect(consoleSpy).toHaveBeenCalled();
      consoleSpy.mockRestore();
    });
  });
});
