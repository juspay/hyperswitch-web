import * as BraintreeHelpers from '../Utilities/BraintreeHelpers.bs.js';

const mockLoadScriptIfNotExist = jest.fn();

jest.mock('../Utilities/Utils.bs.js', () => ({
  loadScriptIfNotExist: (url: string, logger: any, scriptName: string) =>
    mockLoadScriptIfNotExist(url, logger, scriptName),
}));

const createMockLogger = () => ({
  setLogInfo: jest.fn(),
  setLogError: jest.fn(),
});

describe('BraintreeHelpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('braintreeApplePayUrl', () => {
    it('has the correct Braintree Apple Pay script URL', () => {
      expect(BraintreeHelpers.braintreeApplePayUrl).toBe(
        'https://js.braintreegateway.com/web/3.92.1/js/apple-pay.min.js'
      );
    });

    it('is a string', () => {
      expect(typeof BraintreeHelpers.braintreeApplePayUrl).toBe('string');
    });

    it('contains braintreegateway domain', () => {
      expect(BraintreeHelpers.braintreeApplePayUrl).toContain('braintreegateway.com');
    });
  });

  describe('braintreeClientUrl', () => {
    it('has the correct Braintree client script URL', () => {
      expect(BraintreeHelpers.braintreeClientUrl).toBe(
        'https://js.braintreegateway.com/web/3.92.1/js/client.min.js'
      );
    });

    it('is a string', () => {
      expect(typeof BraintreeHelpers.braintreeClientUrl).toBe('string');
    });

    it('contains braintreegateway domain', () => {
      expect(BraintreeHelpers.braintreeClientUrl).toContain('braintreegateway.com');
    });

    it('points to client.min.js', () => {
      expect(BraintreeHelpers.braintreeClientUrl).toContain('client.min.js');
    });
  });

  describe('loadBraintreeApplePayScripts', () => {
    it('calls loadScriptIfNotExist for client script', () => {
      const mockLogger = createMockLogger();

      BraintreeHelpers.loadBraintreeApplePayScripts(mockLogger);

      expect(mockLoadScriptIfNotExist).toHaveBeenCalledWith(
        'https://js.braintreegateway.com/web/3.92.1/js/client.min.js',
        mockLogger,
        'BRAINTREE_CLIENT_SCRIPT'
      );
    });

    it('calls loadScriptIfNotExist for Apple Pay script', () => {
      const mockLogger = createMockLogger();

      BraintreeHelpers.loadBraintreeApplePayScripts(mockLogger);

      expect(mockLoadScriptIfNotExist).toHaveBeenCalledWith(
        'https://js.braintreegateway.com/web/3.92.1/js/apple-pay.min.js',
        mockLogger,
        'APPLE_PAY_BRAINTREE_SCRIPT'
      );
    });

    it('calls loadScriptIfNotExist twice', () => {
      const mockLogger = createMockLogger();

      BraintreeHelpers.loadBraintreeApplePayScripts(mockLogger);

      expect(mockLoadScriptIfNotExist).toHaveBeenCalledTimes(2);
    });

    it('passes logger to both script loads', () => {
      const mockLogger = createMockLogger();

      BraintreeHelpers.loadBraintreeApplePayScripts(mockLogger);

      expect(mockLoadScriptIfNotExist).toHaveBeenNthCalledWith(
        1,
        expect.any(String),
        mockLogger,
        expect.any(String)
      );
      expect(mockLoadScriptIfNotExist).toHaveBeenNthCalledWith(
        2,
        expect.any(String),
        mockLogger,
        expect.any(String)
      );
    });

    it('uses correct script names for logging', () => {
      const mockLogger = createMockLogger();

      BraintreeHelpers.loadBraintreeApplePayScripts(mockLogger);

      const calls = mockLoadScriptIfNotExist.mock.calls;
      const scriptNames = calls.map((call) => call[2]);

      expect(scriptNames).toContain('BRAINTREE_CLIENT_SCRIPT');
      expect(scriptNames).toContain('APPLE_PAY_BRAINTREE_SCRIPT');
    });

    it('handles null logger gracefully', () => {
      expect(() => {
        BraintreeHelpers.loadBraintreeApplePayScripts(null as any);
      }).not.toThrow();
    });

    it('handles undefined logger gracefully', () => {
      expect(() => {
        BraintreeHelpers.loadBraintreeApplePayScripts(undefined as any);
      }).not.toThrow();
    });

    it('loads scripts in correct order (client first, then Apple Pay)', () => {
      const mockLogger = createMockLogger();

      BraintreeHelpers.loadBraintreeApplePayScripts(mockLogger);

      const calls = mockLoadScriptIfNotExist.mock.calls;
      expect(calls[0][2]).toBe('BRAINTREE_CLIENT_SCRIPT');
      expect(calls[1][2]).toBe('APPLE_PAY_BRAINTREE_SCRIPT');
    });
  });
});
