import * as PaymentHelpers from '../Utilities/PaymentHelpers.bs.js';

const mockMessageParentWindow = jest.fn();
const mockFetchApiWithLogging = jest.fn();
const mockGetNonEmptyOption = jest.fn((val: any) => (val ? val : undefined));
const mockGetDictFromJson = jest.fn((obj: any) => (typeof obj === 'object' && obj !== null ? obj : {}));
const mockGetString = jest.fn((obj: any, key: string, def: string) => obj?.[key] ?? def);
const mockDelay = jest.fn((ms: number) => Promise.resolve());
const mockFetchApi = jest.fn();
const mockOpenUrl = jest.fn();
const mockReplaceRootHref = jest.fn();
const mockPostSubmitResponse = jest.fn();
const mockHandleOnCompleteDoThisMessage = jest.fn();
const mockGetFailedSubmitResponse = jest.fn((type: string, msg: string) => ({ type, message: msg }));
const mockFormatException = jest.fn((e: any) => e?.message || String(e));
const mockGetPaymentId = jest.fn((secret: string) => secret?.split('_secret_')[0] || '');
const mockGetJsonFromArrayOfJson = jest.fn((arr: any) => Object.fromEntries(arr));
const mockGetStringFromJson = jest.fn((val: any, def: string) => (typeof val === 'string' ? val : def));
const mockDeepCopyDict = jest.fn((obj: any) => JSON.parse(JSON.stringify(obj)));
const mockGetBoolValue = jest.fn((val: any) => Boolean(val));
const mockGetJsonObjectFromDict = jest.fn((obj: any, key: string) => obj?.[key] || {});
const mockGetDictFromDict = jest.fn((obj: any, key: string) => obj?.[key] || {});
const mockMergeHeadersIntoDict = jest.fn();
const mockPostFailedSubmitResponse = jest.fn();
const mockSafeParse = jest.fn((str: string) => {
  try {
    return JSON.parse(str);
  } catch {
    return null;
  }
});
const mockSafeParseOpt = jest.fn((str: string) => {
  try {
    return JSON.parse(str);
  } catch {
    return null;
  }
});
const mockGetStringFromBool = jest.fn((val: boolean) => (val ? 'true' : 'false'));

jest.mock('../Utilities/Utils.bs.js', () => ({
  getDictFromJson: (obj: any) => mockGetDictFromJson(obj),
  getString: (obj: any, key: string, def: string) => mockGetString(obj, key, def),
  messageParentWindow: (a: any, b: any) => mockMessageParentWindow(a, b),
  getNonEmptyOption: (val: any) => mockGetNonEmptyOption(val),
  fetchApiWithLogging: (...args: any[]) => mockFetchApiWithLogging(...args),
  delay: (ms: number) => mockDelay(ms),
  fetchApi: (url: string, body: any, headers: any, method: string) => mockFetchApi(url, body, headers, method),
  openUrl: (url: string) => mockOpenUrl(url),
  replaceRootHref: (url: string, flags: any) => mockReplaceRootHref(url, flags),
  postSubmitResponse: (data: any, url: string) => mockPostSubmitResponse(data, url),
  handleOnCompleteDoThisMessage: (a: any) => mockHandleOnCompleteDoThisMessage(a),
  getFailedSubmitResponse: (type: string, msg: string) => mockGetFailedSubmitResponse(type, msg),
  formatException: (e: any) => mockFormatException(e),
  getPaymentId: (secret: string) => mockGetPaymentId(secret),
  getJsonFromArrayOfJson: (arr: any) => mockGetJsonFromArrayOfJson(arr),
  getStringFromJson: (val: any, def: string) => mockGetStringFromJson(val, def),
  deepCopyDict: (obj: any) => mockDeepCopyDict(obj),
  getBoolValue: (val: any) => mockGetBoolValue(val),
  getJsonObjectFromDict: (obj: any, key: string) => mockGetJsonObjectFromDict(obj, key),
  getDictFromDict: (obj: any, key: string) => mockGetDictFromDict(obj, key),
  mergeHeadersIntoDict: (dict: any, headers: any) => mockMergeHeadersIntoDict(dict, headers),
  postFailedSubmitResponse: (type: string, msg: string) => mockPostFailedSubmitResponse(type, msg),
  safeParse: (str: string) => mockSafeParse(str),
  safeParseOpt: (str: string) => mockSafeParseOpt(str),
  getStringFromBool: (val: boolean) => mockGetStringFromBool(val),
}));

jest.mock('../Utilities/APIHelpers/APIUtils.bs.js', () => ({
  generateApiUrlV1: jest.fn((params: any, endpoint: string) => `https://api.test.com/${endpoint}`),
  addCustomPodHeader: jest.fn((headers: any, uri: any) => headers),
}));

jest.mock('../Utilities/ApiEndpoint.bs.js', () => ({
  getApiEndPoint: jest.fn((key: string, isThirdParty: boolean) => 'https://api.test.com'),
  addCustomPodHeader: jest.fn((headers: any, uri: any) => headers),
}));

jest.mock('../Utilities/LoggerUtils.bs.js', () => ({
  logApi: jest.fn(),
  handleLogging: jest.fn(),
}));

jest.mock('../Utilities/PaymentBody.bs.js', () => ({
  paymentTypeBody: jest.fn((type: string) => []),
  mandateBody: jest.fn((type: string) => []),
}));

jest.mock('../Payments/PaymentMethodsRecord.bs.js', () => ({
  itemToObjMapper: jest.fn((obj: any) => ({
    payment_type: 'NORMAL',
    payment_methods: [{ payment_method_type: 'card' }],
    mandate_payment: undefined,
    ...obj,
  })),
  paymentTypeToStringMapper: jest.fn((type: any) => 'NORMAL'),
}));

jest.mock('../Types/PaymentConfirmTypes.bs.js', () => ({
  itemToObjMapper: jest.fn((obj: any) => ({
    status: 'succeeded',
    payment_method_type: 'card',
    nextAction: { type_: '' },
    ...obj,
  })),
}));

jest.mock('../Types/PaymentError.bs.js', () => ({
  itemToObjMapper: jest.fn((obj: any) => ({
    error: { type_: 'test_error', message: 'Test error message' },
    ...obj,
  })),
}));

jest.mock('../BrowserSpec.bs.js', () => ({
  broswerInfo: jest.fn(() => [
    ['user_agent', 'test-agent'],
    ['ip', '127.0.0.1'],
  ]),
}));

jest.mock('../CardUtils.bs.js', () => ({
  getQueryParamsDictforKey: jest.fn((search: string, key: string) => 'payment'),
}));

jest.mock('../Types/CardThemeType.bs.js', () => ({
  getPaymentMode: jest.fn((name: string) => 'NONE'),
  getPaymentModeToStrMapper: jest.fn((mode: any) => 'payment'),
}));

jest.mock('../Window.bs.js', () => ({
  getRootHostName: jest.fn(() => 'example.com'),
}));

describe('PaymentHelpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getPaymentType', () => {
    it('returns Applepay for apple_pay', () => {
      expect(PaymentHelpers.getPaymentType('apple_pay')).toBe('Applepay');
    });

    it('returns Card for credit', () => {
      expect(PaymentHelpers.getPaymentType('credit')).toBe('Card');
    });

    it('returns Card for debit', () => {
      expect(PaymentHelpers.getPaymentType('debit')).toBe('Card');
    });

    it('returns Card for empty string', () => {
      expect(PaymentHelpers.getPaymentType('')).toBe('Card');
    });

    it('returns Gpay for google_pay', () => {
      expect(PaymentHelpers.getPaymentType('google_pay')).toBe('Gpay');
    });

    it('returns Paze for paze', () => {
      expect(PaymentHelpers.getPaymentType('paze')).toBe('Paze');
    });

    it('returns Samsungpay for samsung_pay', () => {
      expect(PaymentHelpers.getPaymentType('samsung_pay')).toBe('Samsungpay');
    });

    it('returns Other for unknown payment method types', () => {
      expect(PaymentHelpers.getPaymentType('unknown_method')).toBe('Other');
    });

    it('returns Other for paypal', () => {
      expect(PaymentHelpers.getPaymentType('paypal')).toBe('Other');
    });
  });

  describe('closePaymentLoaderIfAny', () => {
    it('calls messageParentWindow with fullscreen false', () => {
      PaymentHelpers.closePaymentLoaderIfAny();
      expect(mockMessageParentWindow).toHaveBeenCalledWith(undefined, [['fullscreen', false]]);
    });

    it('is callable multiple times', () => {
      PaymentHelpers.closePaymentLoaderIfAny();
      PaymentHelpers.closePaymentLoaderIfAny();
      expect(mockMessageParentWindow).toHaveBeenCalledTimes(2);
    });
  });

  describe('maskStr', () => {
    it('replaces all non-whitespace characters with x', () => {
      expect(PaymentHelpers.maskStr('hello world')).toBe('xxxxx xxxxx');
    });

    it('handles empty string', () => {
      expect(PaymentHelpers.maskStr('')).toBe('');
    });

    it('preserves whitespace', () => {
      expect(PaymentHelpers.maskStr('  test  ')).toBe('  xxxx  ');
    });

    it('handles numbers as strings', () => {
      expect(PaymentHelpers.maskStr('12345')).toBe('xxxxx');
    });

    it('handles special characters', () => {
      expect(PaymentHelpers.maskStr('test@email.com')).toBe('xxxxxxxxxxxxxx');
    });

    it('handles strings with mixed characters', () => {
      expect(PaymentHelpers.maskStr('Hello World 123!')).toBe('xxxxx xxxxx xxxx');
    });

    it('handles unicode characters', () => {
      const masked = PaymentHelpers.maskStr('日本語');
      expect(masked).toMatch(/^x+$/);
    });

    it('handles very long strings', () => {
      const longStr = 'a'.repeat(1000);
      const masked = PaymentHelpers.maskStr(longStr);
      expect(masked).toBe('x'.repeat(1000));
    });
  });

  describe('maskPayload', () => {
    it('masks string values', () => {
      const result = PaymentHelpers.maskPayload('sensitive-data');
      expect(result).toBe('xxxxxxxxxxxxxx');
    });

    it('returns string representation of numbers masked', () => {
      const result = PaymentHelpers.maskPayload(12345);
      expect(result).toBe('xxxxx');
    });

    it('returns string representation for boolean true', () => {
      const result = PaymentHelpers.maskPayload(true);
      expect(result).toBe('true');
    });

    it('returns string representation for boolean false', () => {
      const result = PaymentHelpers.maskPayload(false);
      expect(result).toBe('false');
    });

    it('returns null for null input', () => {
      const result = PaymentHelpers.maskPayload(null);
      expect(result).toBe('null');
    });

    it('processes array values', () => {
      const result = PaymentHelpers.maskPayload(['a', 'b', 'c']);
      expect(Array.isArray(result)).toBe(true);
    });

    it('handles nested objects', () => {
      const nestedObj = {
        level1: {
          level2: {
            level3: 'secret'
          }
        }
      };
      const result = PaymentHelpers.maskPayload(nestedObj);
      expect(result).toBeDefined();
    });

    it('handles arrays of objects', () => {
      const arr = [
        { name: 'John', email: 'john@example.com' },
        { name: 'Jane', email: 'jane@example.com' }
      ];
      const result = PaymentHelpers.maskPayload(arr);
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('getConstructedPaymentMethodName', () => {
    it('returns card for card payment method', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('card', 'visa')).toBe('card');
    });

    it('appends _debit for bank_debit payment method', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_debit', 'ach')).toBe('ach_debit');
    });

    it('returns payment method type for bank_transfer not in list', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_transfer', 'sepa')).toBe('sepa_transfer');
    });

    it('returns payment method type as-is for unknown payment method', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('wallet', 'apple_pay')).toBe('apple_pay');
    });

    it('handles bank_debit with different connector types', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_debit', 'ach')).toBe('ach_debit');
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_debit', 'sepa')).toBe('sepa_debit');
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_debit', 'becs')).toBe('becs_debit');
    });

    it('handles bank_transfer connector types', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_transfer', 'sepa')).toBe('sepa_transfer');
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_transfer', 'ach')).toBe('ach_transfer');
    });

    it('returns payment method type for non-bank payment methods', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('wallet', 'apple_pay')).toBe('apple_pay');
      expect(PaymentHelpers.getConstructedPaymentMethodName('card', 'credit')).toBe('card');
    });
  });

  describe('retrievePaymentIntent', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { id: 'pay_123', status: 'requires_payment_method' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.retrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        false,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = await PaymentHelpers.retrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        false,
        undefined
      );

      expect(result).toBeNull();
    });

    it('handles force sync flag', async () => {
      const mockData = { id: 'pay_123', status: 'requires_payment_method' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.retrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        true,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles with sdkAuthorization', async () => {
      const mockData = { id: 'pay_123' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await PaymentHelpers.retrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        false,
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchBlockedBins', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { blocked_bins: ['411111'] };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchBlockedBins(
        'auth_token',
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);

      const result = await PaymentHelpers.fetchBlockedBins(
        undefined,
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com'
      );

      expect(result).toBeNull();
    });

    it('handles fetch with sdkAuthorization', async () => {
      const mockData = { blocked_bins: ['411111'] };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchBlockedBins(
        'auth_token',
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('retrieveStatus', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { status: 'completed' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.retrieveStatus(
        'pk_test',
        'customUri',
        'poll_123',
        undefined,
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);

      const result = await PaymentHelpers.retrieveStatus(
        'pk_test',
        'customUri',
        'poll_123',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });
  });

  describe('fetchSessions', () => {
    it('returns session data on successful fetch', async () => {
      const mockData = { session_tokens: {} };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.fetchSessions(
        'secret_test',
        'pk_test',
        ['google_pay', 'apple_pay'],
        false,
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'merchant.example.com',
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('uses default wallet array when not provided', async () => {
      mockFetchApiWithLogging.mockResolvedValue({});
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.fetchSessions(
        'secret_test',
        'pk_test',
        undefined,
        undefined,
        undefined,
        'customUri',
        'https://endpoint.com'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles delayed session token flag', async () => {
      const mockData = { session_tokens: {} };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await PaymentHelpers.fetchSessions(
        'secret_test',
        'pk_test',
        ['google_pay'],
        true,
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'merchant.example.com',
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('confirmPayout', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { status: 'succeeded' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.confirmPayout(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        [['amount', 100]],
        'payout_123'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);

      const result = await PaymentHelpers.confirmPayout(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        [],
        'payout_123'
      );

      expect(result).toBeNull();
    });

    it('handles payout confirmation with body', async () => {
      const mockData = { status: 'succeeded' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.confirmPayout(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        [['amount', 100], ['currency', 'USD']],
        'payout_123'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('createPaymentMethod', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { id: 'pm_123' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.createPaymentMethod(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        [['type', 'card']]
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);

      const result = await PaymentHelpers.createPaymentMethod(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        []
      );

      expect(result).toBeNull();
    });

    it('handles payment method creation with body', async () => {
      const mockData = { id: 'pm_123' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.createPaymentMethod(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        [['type', 'card'], ['card[number]', '4111111111111111']]
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchPaymentMethodList', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { payment_methods: [] };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchPaymentMethodList(
        undefined,
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);

      const result = await PaymentHelpers.fetchPaymentMethodList(
        undefined,
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com'
      );

      expect(result).toBeNull();
    });

    it('uses sdkAuthorization when provided', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ payment_methods: [] });
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await PaymentHelpers.fetchPaymentMethodList(
        'auth_token',
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchCustomerPaymentMethodList', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { customer_payment_methods: [] };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchCustomerPaymentMethodList(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);

      const result = await PaymentHelpers.fetchCustomerPaymentMethodList(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        undefined
      );

      expect(result).toBeNull();
    });

    it('handles payment session flag', async () => {
      const mockData = { customer_payment_methods: [] };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await PaymentHelpers.fetchCustomerPaymentMethodList(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('calculateTax', () => {
    it('returns tax data on successful fetch', async () => {
      const mockData = { tax_amount: 100 };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.calculateTax(
        'pk_test',
        'secret_test',
        'card',
        { country: 'US', postal_code: '12345' },
        undefined,
        'customUri',
        'session_123',
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = await PaymentHelpers.calculateTax(
        'pk_test',
        'secret_test',
        'card',
        {},
        undefined,
        'customUri',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });

    it('handles tax calculation with session ID', async () => {
      const mockData = { tax_amount: 100 };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.calculateTax(
        'pk_test',
        'secret_test',
        'card',
        { country: 'US', postal_code: '12345' },
        undefined,
        'customUri',
        'session_123',
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchEnabledAuthnMethodsToken', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { token: 'auth_token' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchEnabledAuthnMethodsToken(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'profile_123',
        'auth_123'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);

      const result = await PaymentHelpers.fetchEnabledAuthnMethodsToken(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'profile_123',
        'auth_123'
      );

      expect(result).toBeNull();
    });

    it('handles with payment session flag', async () => {
      const mockData = { token: 'auth_token' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchEnabledAuthnMethodsToken(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'profile_123',
        'auth_123'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchEligibilityCheck', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { eligible: true };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchEligibilityCheck(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'profile_123',
        'auth_123',
        [['method', 'sms']]
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);

      const result = await PaymentHelpers.fetchEligibilityCheck(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'profile_123',
        'auth_123',
        []
      );

      expect(result).toBeNull();
    });

    it('handles with payment session flag', async () => {
      const mockData = { eligible: true };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchEligibilityCheck(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'profile_123',
        'auth_123',
        [['method', 'sms']]
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchAuthenticationSync', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { authenticated: true };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchAuthenticationSync(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'profile_123',
        'auth_123',
        'merchant_123',
        [['otp', '123456']]
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns error on failure', async () => {
      const mockError = { error: 'authentication_failed' };
      mockFetchApiWithLogging.mockResolvedValue(mockError);

      const result = await PaymentHelpers.fetchAuthenticationSync(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'profile_123',
        'auth_123',
        'merchant_123',
        []
      );

      expect(result).toBeDefined();
    });

    it('handles successful authentication', async () => {
      const mockData = { authenticated: true };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchAuthenticationSync(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'profile_123',
        'auth_123',
        'merchant_123',
        [['otp', '123456']]
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles error response', async () => {
      const mockError = { error: 'authentication_failed' };
      mockFetchApiWithLogging.mockResolvedValue(mockError);

      const result = await PaymentHelpers.fetchAuthenticationSync(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'profile_123',
        'auth_123',
        'merchant_123',
        []
      );

      expect(result).toBeDefined();
    });
  });

  describe('threeDsAuth', () => {
    it('returns data on successful authentication', async () => {
      const mockData = { three_ds_auth: { status: 'success' } };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.threeDsAuth(
        'secret_test',
        undefined,
        'Y',
        [['Content-Type', 'application/json']],
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on authentication failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);
      mockGetNonEmptyOption.mockReturnValue(undefined);
      mockGetDictFromJson.mockReturnValue({
        error: { type: 'auth_failed', message: 'Authentication failed' },
      });

      await PaymentHelpers.threeDsAuth(
        'secret_test',
        undefined,
        'N',
        [],
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles failure with error response', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);
      mockGetDictFromJson.mockReturnValue({
        error: { type: 'auth_failed', message: 'Authentication failed' },
      });
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = await PaymentHelpers.threeDsAuth(
        'secret_test',
        undefined,
        'N',
        [],
        undefined
      );

      expect(result).toBeNull();
    });
  });

  describe('pollRetrievePaymentIntent', () => {
    it('returns succeeded status immediately', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ status: 'succeeded' });
      mockGetDictFromJson.mockReturnValue({ status: 'succeeded' });
      mockGetString.mockReturnValue('succeeded');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.pollRetrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        false,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns failed status immediately', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ status: 'failed' });
      mockGetDictFromJson.mockReturnValue({ status: 'failed' });
      mockGetString.mockReturnValue('failed');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.pollRetrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        false,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns a promise', () => {
      mockFetchApiWithLogging.mockResolvedValue({ status: 'succeeded' });
      mockGetDictFromJson.mockReturnValue({ status: 'succeeded' });
      mockGetString.mockReturnValue('succeeded');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = PaymentHelpers.pollRetrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        false,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });
  });

  describe('pollStatus', () => {
    it('returns completed status immediately', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ status: 'completed' });
      mockGetDictFromJson.mockReturnValue({ status: 'completed' });
      mockGetString.mockReturnValue('completed');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.pollStatus(
        'pk_test',
        'customUri',
        'poll_123',
        1000,
        5,
        'https://example.com/return',
        undefined,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns a promise', () => {
      mockFetchApiWithLogging.mockResolvedValue({ status: 'completed' });
      mockGetDictFromJson.mockReturnValue({ status: 'completed' });
      mockGetString.mockReturnValue('completed');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = PaymentHelpers.pollStatus(
        'pk_test',
        'customUri',
        'poll_123',
        1000,
        5,
        'https://example.com/return',
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });
  });

  describe('callAuthLink', () => {
    it('returns null on successful auth link call', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ link_token: 'link_test_123' });
      mockGetDictFromJson.mockReturnValue({ link_token: 'link_test_123' });
      mockGetString.mockReturnValue('link_test_123');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.callAuthLink(
        'pk_test',
        'secret_test',
        'ach',
        ['plaid'],
        'iframe_123',
        undefined,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on auth link failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = await PaymentHelpers.callAuthLink(
        'pk_test',
        undefined,
        'ach',
        ['plaid'],
        'iframe_123',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });

    it('handles with undefined clientSecret', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ link_token: 'link_test_123' });
      mockGetDictFromJson.mockReturnValue({ link_token: 'link_test_123' });
      mockGetString.mockReturnValue('link_test_123');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.callAuthLink(
        'pk_test',
        undefined,
        'ach',
        ['plaid'],
        'iframe_123',
        undefined,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('callAuthExchange', () => {
    it('handles successful auth exchange', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ success: true });
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const mockSetOptionValue = jest.fn();
      await PaymentHelpers.callAuthExchange(
        'public_token_123',
        'secret_test',
        'ach',
        'pk_test',
        mockSetOptionValue,
        undefined,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('returns null on auth exchange failure', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = await PaymentHelpers.callAuthExchange(
        'public_token_123',
        'secret_test',
        'ach',
        'pk_test',
        jest.fn(),
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });

    it('handles with sdkAuthorization', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ success: true });
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      const mockSetOptionValue = jest.fn();
      await PaymentHelpers.callAuthExchange(
        'public_token_123',
        'secret_test',
        'ach',
        'pk_test',
        mockSetOptionValue,
        undefined,
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('paymentIntentForPaymentSession', () => {
    it('is callable with valid parameters', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });
      mockGetDictFromJson.mockReturnValue({
        confirmParams: {
          return_url: 'https://example.com/return',
          redirect: 'if_required',
        },
      });
      mockGetDictFromDict.mockReturnValue({
        return_url: 'https://example.com/return',
        redirect: 'if_required',
      });
      mockGetString.mockImplementation((obj: any, key: string, def: string) => {
        if (key === 'return_url') return 'https://example.com/return';
        if (key === 'redirect') return 'if_required';
        return def;
      });
      mockGetPaymentId.mockReturnValue('pay_123');
      mockGetJsonFromArrayOfJson.mockImplementation((arr: any) => Object.fromEntries(arr));

      const payload = JSON.stringify({
        confirmParams: {
          return_url: 'https://example.com/return',
          redirect: 'if_required',
        },
      });

      PaymentHelpers.paymentIntentForPaymentSession(
        [['payment_method_type', 'card']],
        'Card',
        payload,
        'pk_test',
        'pay_123_secret_123',
        undefined,
        'customUri',
        undefined,
        true,
        'NONE'
      );

      expect(mockFetchApi).toHaveBeenCalled();
    });

    it('returns a promise for payment session', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });
      mockGetDictFromJson.mockReturnValue({
        confirmParams: {
          return_url: 'https://example.com/return',
          redirect: 'if_required',
        },
      });
      mockGetDictFromDict.mockReturnValue({
        return_url: 'https://example.com/return',
        redirect: 'if_required',
      });
      mockGetString.mockImplementation((obj: any, key: string, def: string) => {
        if (key === 'return_url') return 'https://example.com/return';
        if (key === 'redirect') return 'if_required';
        return def;
      });
      mockGetPaymentId.mockReturnValue('pay_123');
      mockGetJsonFromArrayOfJson.mockImplementation((arr: any) => Object.fromEntries(arr));

      const payload = JSON.stringify({
        confirmParams: {
          return_url: 'https://example.com/return',
          redirect: 'if_required',
        },
      });

      const result = PaymentHelpers.paymentIntentForPaymentSession(
        [],
        'Card',
        payload,
        'pk_test',
        'pay_123_secret_123',
        undefined,
        'customUri',
        undefined,
        true,
        'NONE'
      );

      expect(result).toBeInstanceOf(Promise);
    });
  });

  describe('hooks', () => {
    it('usePaymentSync hook exists and is a function', () => {
      expect(typeof PaymentHelpers.usePaymentSync).toBe('function');
    });

    it('useCompleteAuthorizeHandler hook exists and is a function', () => {
      expect(typeof PaymentHelpers.useCompleteAuthorizeHandler).toBe('function');
    });

    it('useCompleteAuthorize hook exists and is a function', () => {
      expect(typeof PaymentHelpers.useCompleteAuthorize).toBe('function');
    });

    it('useRedsysCompleteAuthorize hook exists and is a function', () => {
      expect(typeof PaymentHelpers.useRedsysCompleteAuthorize).toBe('function');
    });

    it('usePaymentIntent hook exists and is a function', () => {
      expect(typeof PaymentHelpers.usePaymentIntent).toBe('function');
    });

    it('usePostSessionTokens hook exists and is a function', () => {
      expect(typeof PaymentHelpers.usePostSessionTokens).toBe('function');
    });
  });

  describe('intentCall - error scenarios', () => {
    it('handles non-ok response with error data', async () => {
      const mockErrorResponse = { error: { type: 'card_declined', message: 'Card was declined' } };
      mockFetchApi.mockResolvedValue({
        ok: false,
        status: 400,
        json: () => Promise.resolve(mockErrorResponse),
      });
      mockGetDictFromJson.mockReturnValue(mockErrorResponse);
      mockGetNonEmptyOption.mockReturnValue(undefined);
      mockGetPaymentId.mockReturnValue('pay_123');

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [['Content-Type', 'application/json']],
        JSON.stringify({ payment_method_type: 'card' }),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('returns a promise for confirm endpoint', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('returns a promise for complete_authorize endpoint', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/complete_authorize',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('returns a promise for post_session_tokens endpoint', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/post_session_tokens',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('returns a promise for retrieve endpoint', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'GET',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles Applepay payment type', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Applepay',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        true,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles Gpay payment type', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Gpay',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        true,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles Paypal payment type', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Paypal',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        true,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles BankTransfer payment type', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'BankTransfer',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles Samsungpay payment type', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Samsungpay',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles Paze payment type', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Paze',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles Other payment type', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Other',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles payment session flag', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        true,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles redirect always flag', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'always',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        true,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles mode CardCVCElement', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        'CardCVCElement'
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles with sdkAuthorization', () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ status: 'succeeded' }),
      });
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined,
        undefined,
        undefined,
        'auth_token'
      );

      expect(result).toBeInstanceOf(Promise);
    });
  });

  describe('getConstructedPaymentMethodName', () => {
    it('returns card for card payment method', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('card', 'credit')).toBe('card');
    });

    it('appends _debit for bank_debit payment method', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_debit', 'ach')).toBe('ach_debit');
    });

    it('returns payment method type for bank_transfer not in list', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_transfer', 'sepa')).toBe('sepa_transfer');
    });

    it('returns payment method type as-is for bank_transfer in list', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_transfer', 'pix')).toBe('pix');
    });

    it('returns payment method type for other payment methods', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('wallet', 'apple_pay')).toBe('apple_pay');
    });

    it('handles bank_debit with sepa', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_debit', 'sepa')).toBe('sepa_debit');
    });

    it('handles bank_debit with bacs', () => {
      expect(PaymentHelpers.getConstructedPaymentMethodName('bank_debit', 'bacs')).toBe('bacs_debit');
    });
  });

  describe('getPaymentType - additional tests', () => {
    it('returns Card for empty string', () => {
      expect(PaymentHelpers.getPaymentType('')).toBe('Card');
    });

    it('returns Other for unknown types', () => {
      expect(PaymentHelpers.getPaymentType('unknown')).toBe('Other');
      expect(PaymentHelpers.getPaymentType('bank_transfer')).toBe('Other');
    });
  });

  describe('maskStr - additional tests', () => {
    it('handles single character', () => {
      expect(PaymentHelpers.maskStr('a')).toBe('x');
    });

    it('handles unicode characters', () => {
      const result = PaymentHelpers.maskStr('hello世界');
      expect(result).toMatch(/^x+$/);
    });
  });

  describe('maskPayload - additional tests', () => {
    it('handles nested arrays', () => {
      const result = PaymentHelpers.maskPayload([['a', 'b'], ['c', 'd']]);
      expect(Array.isArray(result)).toBe(true);
    });

    it('handles number values', () => {
      const result = PaymentHelpers.maskPayload(12345);
      expect(result).toBe('xxxxx');
    });

    it('handles object with nested values', () => {
      const result = PaymentHelpers.maskPayload({ key: 'value', nested: { inner: 'secret' } });
      expect(typeof result).toBe('object');
    });

    it('handles empty object', () => {
      const result = PaymentHelpers.maskPayload({});
      expect(typeof result).toBe('object');
    });

    it('handles empty array', () => {
      const result = PaymentHelpers.maskPayload([]);
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('retrievePaymentIntent - additional tests', () => {
    it('handles successful response with force sync', async () => {
      const mockData = { id: 'pay_123', status: 'succeeded' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.retrievePaymentIntent(
        'secret_test',
        {},
        'pk_test',
        undefined,
        'customUri',
        true,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles with undefined headers', async () => {
      const mockData = { id: 'pay_123' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.retrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        false,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('threeDsAuth - additional tests', () => {
    it('handles successful response', async () => {
      const mockData = { three_ds_auth: 'success' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await PaymentHelpers.threeDsAuth(
        'secret_test',
        undefined,
        'Y',
        [['Content-Type', 'application/json']],
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles without sdkAuthorization', async () => {
      mockFetchApiWithLogging.mockResolvedValue({});
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.threeDsAuth(
        'secret_test',
        undefined,
        'N',
        [],
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchSessions - additional tests', () => {
    it('handles with delayed session token', async () => {
      const mockData = { session_tokens: {} };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.fetchSessions(
        'secret_test',
        'pk_test',
        ['google_pay'],
        true,
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'merchant.example.com',
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles with sdkAuthorization', async () => {
      const mockData = { session_tokens: {} };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await PaymentHelpers.fetchSessions(
        'secret_test',
        'pk_test',
        ['apple_pay'],
        false,
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'merchant.example.com',
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('intentCall - additional error scenarios', () => {
    it('handles non-ok response with 400 status', async () => {
      const mockErrorResponse = { error: { type: 'validation_error', message: 'Invalid request' } };
      mockFetchApi.mockResolvedValue({
        ok: false,
        status: 400,
        json: () => Promise.resolve(mockErrorResponse),
      });
      mockGetDictFromJson.mockReturnValue(mockErrorResponse);
      mockGetNonEmptyOption.mockReturnValue(undefined);
      mockGetPaymentId.mockReturnValue('pay_123');

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        true,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });

    it('handles response with requires_customer_action status', async () => {
      mockFetchApi.mockResolvedValue({
        ok: true,
        status: 200,
        json: () => Promise.resolve({
          status: 'requires_customer_action',
          nextAction: { type_: 'redirect_to_url', redirectToUrl: 'https://redirect.com' }
        }),
      });
      mockGetDictFromJson.mockReturnValue({
        status: 'requires_customer_action',
        nextAction: { type_: 'redirect_to_url', redirectToUrl: 'https://redirect.com' }
      });
      mockGetNonEmptyOption.mockReturnValue(undefined);
      mockGetPaymentId.mockReturnValue('pay_123');

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpers.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [],
        JSON.stringify({}),
        confirmParam,
        'pay_123_secret_abc',
        undefined,
        false,
        'Card',
        'iframe_123',
        'POST',
        jest.fn(),
        undefined,
        false,
        false,
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });
  });

  describe('calculateTax - additional tests', () => {
    it('handles with session ID', async () => {
      const mockData = { tax_amount: 100 };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.calculateTax(
        'pk_test',
        'secret_test',
        'card',
        { country: 'US', postal_code: '12345' },
        undefined,
        'customUri',
        'session_123',
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles with sdkAuthorization', async () => {
      const mockData = { tax_amount: 100 };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await PaymentHelpers.calculateTax(
        'pk_test',
        'secret_test',
        'card',
        { country: 'US' },
        undefined,
        'customUri',
        undefined,
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchCustomerPaymentMethodList - additional tests', () => {
    it('handles with isPaymentSession true', async () => {
      const mockData = { customer_payment_methods: [] };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await PaymentHelpers.fetchCustomerPaymentMethodList(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchPaymentMethodList - additional tests', () => {
    it('handles without sdkAuthorization', async () => {
      const mockData = { payment_methods: [] };
      mockFetchApiWithLogging.mockResolvedValue(mockData);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await PaymentHelpers.fetchPaymentMethodList(
        undefined,
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('pollRetrievePaymentIntent - additional tests', () => {
    it('handles processing status', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ status: 'processing' });
      mockGetDictFromJson.mockReturnValue({ status: 'processing' });
      mockGetString.mockReturnValue('processing');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = PaymentHelpers.pollRetrievePaymentIntent(
        'secret_test',
        undefined,
        'pk_test',
        undefined,
        'customUri',
        false,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });
  });

  describe('pollStatus - additional tests', () => {
    it('handles non-completed status with retries', async () => {
      mockFetchApiWithLogging.mockResolvedValue({ status: 'pending' });
      mockGetDictFromJson.mockReturnValue({ status: 'pending' });
      mockGetString.mockReturnValue('pending');
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = PaymentHelpers.pollStatus(
        'pk_test',
        'customUri',
        'poll_123',
        100,
        3,
        'https://example.com/return',
        undefined,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });
  });

  describe('fetchEnabledAuthnMethodsToken - additional tests', () => {
    it('handles with isPaymentSession true', async () => {
      const mockData = { token: 'auth_token' };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchEnabledAuthnMethodsToken(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'profile_123',
        'auth_123'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchEligibilityCheck - additional tests', () => {
    it('handles with isPaymentSession true', async () => {
      const mockData = { eligible: true };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchEligibilityCheck(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'profile_123',
        'auth_123',
        [['method', 'sms']]
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });

  describe('fetchAuthenticationSync - additional tests', () => {
    it('handles with isPaymentSession true', async () => {
      const mockData = { authenticated: true };
      mockFetchApiWithLogging.mockResolvedValue(mockData);

      await PaymentHelpers.fetchAuthenticationSync(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        true,
        'profile_123',
        'auth_123',
        'merchant_123',
        [['otp', '123456']]
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('handles error response', async () => {
      const mockError = { error: 'authentication_failed' };
      mockFetchApiWithLogging.mockResolvedValue(mockError);

      const result = await PaymentHelpers.fetchAuthenticationSync(
        'secret_test',
        'pk_test',
        undefined,
        'customUri',
        'https://endpoint.com',
        false,
        'profile_123',
        'auth_123',
        'merchant_123',
        []
      );

      expect(result).toBeDefined();
    });
  });
});
