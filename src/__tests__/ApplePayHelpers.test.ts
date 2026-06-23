import { renderHook, act } from '@testing-library/react';
import * as ApplePayHelpers from '../Utilities/ApplePayHelpers.bs.js';

const mockGetDictFromJson = jest.fn((obj: any) => (typeof obj === 'object' && obj !== null ? obj : {}));
const mockGetString = jest.fn((obj: any, key: string, def: string) => obj?.[key] ?? def);
const mockMergeAndFlattenToTuples = jest.fn((a: any, b: any) => [...(a || []), ...(b || [])]);
const mockMessageParentWindow = jest.fn();
const mockGetDictFromDict = jest.fn((obj: any, key: string) => obj?.[key] || {});
const mockGetArray = jest.fn((obj: any, key: string) => obj?.[key] || []);
const mockGetDictFromObj = jest.fn((obj: any, key: string) => obj?.[key] || {});
const mockGetStrArray = jest.fn((obj: any, key: string) => obj?.[key] || []);
const mockGetOptionsDict = jest.fn((obj: any) => obj || {});
const mockFormatException = jest.fn((e: any) => e?.message || String(e));
const mockSafeParse = jest.fn((str: string) => {
  try {
    return JSON.parse(str);
  } catch {
    return null;
  }
});
const mockPostFailedSubmitResponse = jest.fn();
const mockHandleFailureResponse = jest.fn((msg: string, type: string) => ({ error: { message: msg, type } }));
const mockTransformKeys = jest.fn((obj: any) => obj);
const mockMinorUnitToString = jest.fn((val: number) => String(val));
const mockSendPostMessage = jest.fn();
const mockGetJsonFromArrayOfJson = jest.fn((arr: any) => Object.fromEntries(arr || []));

jest.mock('../Utilities/Utils.bs.js', () => ({
  getDictFromJson: (obj: any) => mockGetDictFromJson(obj),
  getString: (obj: any, key: string, def: string) => mockGetString(obj, key, def),
  mergeAndFlattenToTuples: (a: any, b: any) => mockMergeAndFlattenToTuples(a, b),
  messageParentWindow: (a: any, b: any) => mockMessageParentWindow(a, b),
  getDictFromDict: (obj: any, key: string) => mockGetDictFromDict(obj, key),
  getArray: (obj: any, key: string) => mockGetArray(obj, key),
  getDictFromObj: (obj: any, key: string) => mockGetDictFromObj(obj, key),
  getStrArray: (obj: any, key: string) => mockGetStrArray(obj, key),
  getOptionsDict: (obj: any) => mockGetOptionsDict(obj),
  formatException: (e: any) => mockFormatException(e),
  defaultCountryCode: 'US',
  safeParse: (str: string) => mockSafeParse(str),
  postFailedSubmitResponse: (type: string, msg: string) => mockPostFailedSubmitResponse(type, msg),
  handleFailureResponse: (msg: string, type: string) => mockHandleFailureResponse(msg, type),
  transformKeys: (obj: any) => mockTransformKeys(obj),
  minorUnitToString: (val: number) => mockMinorUnitToString(val),
  getJsonFromArrayOfJson: (arr: any) => mockGetJsonFromArrayOfJson(arr),
}));

jest.mock('../Window.bs.js', () => ({
  sendPostMessage: (source: any, msg: any) => mockSendPostMessage(source, msg),
}));

jest.mock('../Utilities/PaymentBody.bs.js', () => ({
  applePayBody: jest.fn((token: any, connectors: any) => [['apple_pay', { token }]]),
  applePayThirdPartySdkBody: jest.fn((connectors: any, token: string) => [['apple_pay', { token }]]),
}));

jest.mock('../Utilities/PaymentUtils.bs.js', () => ({
  appendedCustomerAcceptance: jest.fn((isGuest: boolean, type: string, body: any) => body),
  paymentMethodListValue: { key: 'paymentMethodListValue' },
}));

jest.mock('../Utilities/DynamicFieldsUtils.bs.js', () => ({
  getApplePayRequiredFields: jest.fn((billing: any, shipping: any, fields: any) => [['required', {}]]),
  usePaymentMethodTypeFromList: jest.fn(() => ({ required_fields: [] })),
}));

jest.mock('../Types/ApplePayTypes.bs.js', () => ({
  billingContactItemToObjMapper: jest.fn((obj: any) => obj || {}),
  shippingContactItemToObjMapper: jest.fn((obj: any) => obj || {
    administrativeArea: '',
    countryCode: '',
    postalCode: '',
  }),
  getPaymentRequestFromSession: jest.fn(() => ({})),
  getTotal: jest.fn((obj: any) => obj || { label: 'Test', amount: '100' }),
}));

jest.mock('../Payments/PaymentMethodsRecord.bs.js', () => ({
  defaultList: { payment_type: 'NORMAL' },
}));

jest.mock('../Utilities/TaxCalculation.bs.js', () => ({
  calculateTax: jest.fn(() => Promise.resolve({ net_amount: 100, order_tax_amount: 10, shipping_cost: 5 })),
  taxResponseToObjMapper: jest.fn((obj: any) => obj),
}));

jest.mock('recoil', () => {
  const actualRecoil = jest.requireActual('recoil');
  return {
    ...actualRecoil,
    useRecoilValue: jest.fn((atom: any) => {
      if (atom?.key === 'optionAtom') {
        return { wallets: { walletReturnUrl: 'https://return.url' }, readOnly: false };
      }
      if (atom?.key === 'keys') {
        return { publishableKey: 'pk_test', iframeId: 'iframe-123' };
      }
      if (atom?.key === 'isManualRetryEnabled') {
        return false;
      }
      if (atom?.key === 'areRequiredFieldsValid') {
        return true;
      }
      if (atom?.key === 'areRequiredFieldsEmpty') {
        return false;
      }
      if (atom?.key === 'configAtom') {
        return { localeString: { enterFieldsText: 'Please enter fields', enterValidDetailsText: 'Please enter valid details' } };
      }
      if (atom?.key === 'loggerAtom') {
        return { setLogInfo: jest.fn(), setLogError: jest.fn() };
      }
      return { key: 'paymentMethodListValue', payment_type: 'NORMAL' };
    }),
    useSetRecoilState: jest.fn(() => jest.fn()),
  };
});

jest.mock('../Utilities/RecoilAtoms.bs.js', () => ({
  optionAtom: { key: 'optionAtom' },
  keys: { key: 'keys' },
  isManualRetryEnabled: { key: 'isManualRetryEnabled' },
  areRequiredFieldsValid: { key: 'areRequiredFieldsValid' },
  areRequiredFieldsEmpty: { key: 'areRequiredFieldsEmpty' },
  configAtom: { key: 'configAtom' },
  loggerAtom: { key: 'loggerAtom' },
}));

jest.mock('../Hooks/UtilityHooks.bs.js', () => ({
  useIsGuestCustomer: jest.fn(() => false),
}));

describe('ApplePayHelpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('thirdPartyApplePayConnectors', () => {
    it('contains braintree as a supported connector', () => {
      expect(ApplePayHelpers.thirdPartyApplePayConnectors).toContain('braintree');
    });

    it('is an array', () => {
      expect(Array.isArray(ApplePayHelpers.thirdPartyApplePayConnectors)).toBe(true);
    });

    it('has expected length', () => {
      expect(ApplePayHelpers.thirdPartyApplePayConnectors).toHaveLength(1);
    });
  });

  describe('processPayment', () => {
    it('calls intent with correct parameters', () => {
      const mockIntent = jest.fn();
      const bodyArr = [['card', { number: '4242' }]];
      const options = { wallets: { walletReturnUrl: 'https://return.url' } };

      ApplePayHelpers.processPayment(
        bodyArr,
        false,
        true,
        { payment_type: 'NORMAL' },
        mockIntent,
        options,
        'pk_test',
        false
      );

      expect(mockIntent).toHaveBeenCalledWith(
        true,
        bodyArr,
        { return_url: 'https://return.url', publishableKey: 'pk_test' },
        undefined,
        false,
        undefined,
        false
      );
    });

    it('uses default values for optional parameters', () => {
      const mockIntent = jest.fn();
      const bodyArr = [['card', { number: '4242' }]];
      const options = { wallets: { walletReturnUrl: 'https://return.url' } };

      ApplePayHelpers.processPayment(
        bodyArr,
        undefined,
        undefined,
        undefined,
        mockIntent,
        options,
        'pk_test',
        undefined
      );

      expect(mockIntent).toHaveBeenCalledWith(
        true,
        bodyArr,
        { return_url: 'https://return.url', publishableKey: 'pk_test' },
        undefined,
        false,
        undefined,
        undefined
      );
    });

    it('passes isThirdPartyFlow as true when provided', () => {
      const mockIntent = jest.fn();
      const bodyArr = [['card', { number: '4242' }]];
      const options = { wallets: { walletReturnUrl: 'https://return.url' } };

      ApplePayHelpers.processPayment(
        bodyArr,
        true,
        false,
        { payment_type: 'NORMAL' },
        mockIntent,
        options,
        'pk_test',
        false
      );

      expect(mockIntent).toHaveBeenCalledWith(
        true,
        bodyArr,
        expect.any(Object),
        undefined,
        true,
        undefined,
        false
      );
    });

    it('passes isManualRetryEnabled when true', () => {
      const mockIntent = jest.fn();
      const bodyArr = [['card', { number: '4242' }]];
      const options = { wallets: { walletReturnUrl: 'https://return.url' } };

      ApplePayHelpers.processPayment(
        bodyArr,
        false,
        false,
        { payment_type: 'NORMAL' },
        mockIntent,
        options,
        'pk_test',
        true
      );

      expect(mockIntent).toHaveBeenCalledWith(
        true,
        bodyArr,
        expect.any(Object),
        undefined,
        false,
        undefined,
        true
      );
    });
  });

  describe('getApplePayFromResponse', () => {
    it('returns merged tuples for billing and shipping contacts', () => {
      const token = { paymentData: 'test-data' };
      const billingContact = { givenName: 'John', familyName: 'Doe' };
      const shippingContact = { emailAddress: 'test@example.com' };

      mockMergeAndFlattenToTuples.mockReturnValue([
        ['apple_pay', { token }],
        ['billing', billingContact],
      ]);

      const result = ApplePayHelpers.getApplePayFromResponse(
        token,
        billingContact,
        shippingContact,
        [],
        {}
      );

      expect(mockMergeAndFlattenToTuples).toHaveBeenCalled();
      expect(result).toBeDefined();
    });

    it('handles empty billing and shipping contacts', () => {
      const token = { paymentData: 'test-data' };

      mockMergeAndFlattenToTuples.mockReturnValue([['apple_pay', { token }]]);

      const result = ApplePayHelpers.getApplePayFromResponse(token, {}, {}, [], {});

      expect(result).toBeDefined();
    });

    it('uses default empty array for requiredFields when not provided', () => {
      const token = { paymentData: 'test-data' };

      ApplePayHelpers.getApplePayFromResponse(token, {}, {});

      expect(mockMergeAndFlattenToTuples).toHaveBeenCalled();
    });

    it('handles payment session flow', () => {
      const token = { paymentData: 'test-data' };

      mockMergeAndFlattenToTuples.mockReturnValue([['apple_pay', { token }]]);

      const result = ApplePayHelpers.getApplePayFromResponse(
        token,
        {},
        {},
        [],
        {},
        true,
        undefined
      );

      expect(result).toBeDefined();
    });

    it('handles saved methods flow', () => {
      const token = { paymentData: 'test-data' };

      mockMergeAndFlattenToTuples.mockReturnValue([['apple_pay', { token }]]);

      const result = ApplePayHelpers.getApplePayFromResponse(
        token,
        {},
        {},
        [],
        {},
        false,
        true
      );

      expect(result).toBeDefined();
    });
  });

  describe('createApplePayTransactionInfo', () => {
    it('creates transaction info with all fields', () => {
      const jsonDict = {
        countryCode: 'US',
        currencyCode: 'USD',
        total: { label: 'Test Merchant', amount: '1000' },
        merchantCapabilities: ['supports3DS'],
        supportedNetworks: ['visa', 'masterCard'],
      };

      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const result = ApplePayHelpers.createApplePayTransactionInfo(jsonDict);

      expect(result.countryCode).toBe('US');
      expect(result.currencyCode).toBe('USD');
    });

    it('uses default country code when not provided', () => {
      const jsonDict = {
        currencyCode: 'EUR',
        total: { label: 'Test', amount: '500' },
        merchantCapabilities: [],
        supportedNetworks: [],
      };

      mockGetString.mockImplementation((obj: any, key: string, def: string) => {
        if (key === 'countryCode') return def;
        return obj?.[key] ?? def;
      });

      const result = ApplePayHelpers.createApplePayTransactionInfo(jsonDict);

      expect(result.countryCode).toBe('US');
    });

    it('handles empty jsonDict', () => {
      mockGetString.mockImplementation((_obj: any, _key: string, def: string) => def);
      mockGetArray.mockImplementation(() => []);
      mockGetDictFromObj.mockImplementation(() => ({}));

      const result = ApplePayHelpers.createApplePayTransactionInfo({});

      expect(result).toBeDefined();
      expect(result.merchantCapabilities).toEqual([]);
      expect(result.supportedNetworks).toEqual([]);
    });
  });

  describe('handleApplePayButtonClicked', () => {
    it('sends message to parent window with correct data', () => {
      const sessionObj = {
        session_token_data: { secrets: { display: 'test-token' } },
        connector: 'stripe',
      };
      const paymentMethodListValue = { is_tax_calculation_enabled: false };

      mockGetDictFromJson.mockImplementation((obj: any) => obj);
      mockGetDictFromDict.mockImplementation((obj: any, key: string) => obj?.[key] || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);

      ApplePayHelpers.handleApplePayButtonClicked(sessionObj, 'apple-pay-component', paymentMethodListValue);

      expect(mockMessageParentWindow).toHaveBeenCalled();
    });

    it('handles missing session token data', () => {
      const sessionObj = {};
      const paymentMethodListValue = { is_tax_calculation_enabled: false };

      mockGetDictFromJson.mockImplementation((obj: any) => obj);
      mockGetDictFromDict.mockImplementation((obj: any, key: string) => obj?.[key] || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => def);

      ApplePayHelpers.handleApplePayButtonClicked(sessionObj, 'apple-pay-component', paymentMethodListValue);

      expect(mockMessageParentWindow).toHaveBeenCalled();
    });

    it('includes tax calculation flag in message', () => {
      const sessionObj = {
        session_token_data: { secrets: { display: 'test-token' } },
        connector: 'adyen',
      };
      const paymentMethodListValue = { is_tax_calculation_enabled: true };

      mockGetDictFromJson.mockImplementation((obj: any) => obj);
      mockGetDictFromDict.mockImplementation((obj: any, key: string) => obj?.[key] || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);

      ApplePayHelpers.handleApplePayButtonClicked(sessionObj, 'apple-pay-component', paymentMethodListValue);

      const callArgs = mockMessageParentWindow.mock.calls[0];
      const messageData = callArgs[1];
      const taxCalculationEntry = messageData.find((entry: any) => entry[0] === 'isTaxCalculationEnabled');
      expect(taxCalculationEntry[1]).toBe(true);
    });
  });

  describe('useHandleApplePayResponse', () => {
    let addEventListenerSpy: jest.SpyInstance;
    let removeEventListenerSpy: jest.SpyInstance;

    beforeEach(() => {
      addEventListenerSpy = jest.spyOn(window, 'addEventListener');
      removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
    });

    afterEach(() => {
      addEventListenerSpy.mockRestore();
      removeEventListenerSpy.mockRestore();
    });

    it('hook exists and is a function', () => {
      expect(typeof ApplePayHelpers.useHandleApplePayResponse).toBe('function');
    });

    it('adds message event listener on mount', () => {
      renderHook(() => ApplePayHelpers.useHandleApplePayResponse({}, jest.fn()));

      expect(addEventListenerSpy).toHaveBeenCalledWith('message', expect.any(Function));
    });

    it('removes message event listener on unmount', () => {
      const { unmount } = renderHook(() => ApplePayHelpers.useHandleApplePayResponse({}, jest.fn()));

      unmount();

      expect(removeEventListenerSpy).toHaveBeenCalledWith('message', expect.any(Function));
    });

    it('handles applePayPaymentToken message', () => {
      const mockIntent = jest.fn();
      mockSafeParse.mockImplementation((str: string) => {
        try {
          return JSON.parse(str);
        } catch {
          return null;
        }
      });
      mockGetDictFromJson.mockImplementation((obj: any) => obj);
      mockGetDictFromDict.mockImplementation((obj: any, key: string) => obj?.[key]);
      mockMergeAndFlattenToTuples.mockReturnValue([['apple_pay', {}]]);

      renderHook(() => ApplePayHelpers.useHandleApplePayResponse({}, mockIntent));

      const messageHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'message'
      )?.[1];

      act(() => {
        messageHandler?.({
          data: JSON.stringify({
            applePayPaymentToken: { paymentData: 'test' },
            applePayBillingContact: {},
            applePayShippingContact: {},
          }),
        });
      });

      expect(mockMergeAndFlattenToTuples).toHaveBeenCalled();
    });

    it('handles showApplePayButton message', () => {
      const mockSetApplePayClicked = jest.fn();
      mockSafeParse.mockImplementation((str: string) => {
        try {
          return JSON.parse(str);
        } catch {
          return null;
        }
      });
      mockGetDictFromJson.mockImplementation((obj: any) => obj);

      renderHook(() =>
        ApplePayHelpers.useHandleApplePayResponse(
          {},
          jest.fn(),
          mockSetApplePayClicked
        )
      );

      const messageHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'message'
      )?.[1];

      act(() => {
        messageHandler?.({
          data: JSON.stringify({
            showApplePayButton: true,
          }),
        });
      });

      expect(mockSetApplePayClicked).toHaveBeenCalled();
    });

    it('handles applePaySyncPayment message', () => {
      const mockSyncPayment = jest.fn();
      mockSafeParse.mockImplementation((str: string) => {
        try {
          return JSON.parse(str);
        } catch {
          return null;
        }
      });
      mockGetDictFromJson.mockImplementation((obj: any) => obj);

      renderHook(() =>
        ApplePayHelpers.useHandleApplePayResponse(
          {},
          jest.fn(),
          jest.fn(),
          mockSyncPayment
        )
      );

      const messageHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'message'
      )?.[1];

      act(() => {
        messageHandler?.({
          data: JSON.stringify({
            applePaySyncPayment: true,
          }),
        });
      });

      expect(mockSyncPayment).toHaveBeenCalled();
    });

    it('handles applePayBraintreeSuccess message', () => {
      const mockIntent = jest.fn();
      mockSafeParse.mockImplementation((str: string) => {
        try {
          return JSON.parse(str);
        } catch {
          return null;
        }
      });
      mockGetDictFromJson.mockImplementation((obj: any) => obj);
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);

      renderHook(() => ApplePayHelpers.useHandleApplePayResponse({}, mockIntent));

      const messageHandler = addEventListenerSpy.mock.calls.find(
        (call) => call[0] === 'message'
      )?.[1];

      act(() => {
        messageHandler?.({
          data: JSON.stringify({
            applePayBraintreeSuccess: true,
            token: 'test-nonce',
          }),
        });
      });

      expect(mockIntent).toHaveBeenCalled();
    });

    it('sends applePaySessionAbort on unmount', () => {
      const { unmount } = renderHook(() => ApplePayHelpers.useHandleApplePayResponse({}, jest.fn()));

      unmount();

      expect(mockMessageParentWindow).toHaveBeenCalledWith(
        undefined,
        [['applePaySessionAbort', true]]
      );
    });
  });

  describe('useSubmitCallback', () => {
    it('hook exists and is a function', () => {
      expect(typeof ApplePayHelpers.useSubmitCallback).toBe('function');
    });

    it('returns a callback function', () => {
      const { result } = renderHook(() =>
        ApplePayHelpers.useSubmitCallback(true, {}, 'test-component')
      );

      expect(typeof result.current).toBe('function');
    });

    it('does nothing when isWallet is true', () => {
      mockSafeParse.mockImplementation((str: string) => {
        try {
          return JSON.parse(str);
        } catch {
          return null;
        }
      });

      const { result } = renderHook(() =>
        ApplePayHelpers.useSubmitCallback(true, {}, 'test-component')
      );

      act(() => {
        result.current({ data: JSON.stringify({ doSubmit: true }) });
      });

      expect(mockMessageParentWindow).not.toHaveBeenCalled();
    });
  });

  describe('startApplePaySession', () => {
    let mockSession: any;

    beforeEach(() => {
      mockSession = {
        abort: jest.fn(),
        begin: jest.fn(),
        completeMerchantValidation: jest.fn(),
        completeShippingContactSelection: jest.fn(),
        completePayment: jest.fn(),
        onvalidatemerchant: null,
        onshippingcontactselected: null,
        onpaymentauthorized: null,
        oncancel: null,
        STATUS_SUCCESS: 1,
        STATUS_FAILURE: 0,
      };

      (globalThis as any).ApplePaySession = jest.fn(() => mockSession);
    });

    afterEach(() => {
      delete (globalThis as any).ApplePaySession;
    });

    it('function exists', () => {
      expect(typeof ApplePayHelpers.startApplePaySession).toBe('function');
    });

    it('creates new ApplePaySession and calls begin', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      const paymentRequest = JSON.stringify({
        total: { label: 'Test', amount: '100', type: 'final' },
      });
      const applePaySessionRef = { contents: null };
      const callBackFunc = jest.fn();
      const resolvePromise = jest.fn();

      ApplePayHelpers.startApplePaySession(
        paymentRequest,
        applePaySessionRef,
        undefined,
        mockLogger,
        callBackFunc,
        resolvePromise,
        'client_secret',
        'pk_test'
      );

      expect(mockSession.begin).toHaveBeenCalled();
      expect(mockSession.onvalidatemerchant).not.toBeNull();
      expect(mockSession.onpaymentauthorized).not.toBeNull();
      expect(mockSession.oncancel).not.toBeNull();
    });

    it('aborts existing session before creating new one', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      const paymentRequest = JSON.stringify({ total: { label: 'Test', amount: '100' } });
      const existingSession = { abort: jest.fn() };
      const applePaySessionRef = { contents: existingSession };
      const callBackFunc = jest.fn();
      const resolvePromise = jest.fn();

      ApplePayHelpers.startApplePaySession(
        paymentRequest,
        applePaySessionRef,
        undefined,
        mockLogger,
        callBackFunc,
        resolvePromise,
        'client_secret',
        'pk_test'
      );

      expect(existingSession.abort).toHaveBeenCalled();
    });

    it('handles abort failure gracefully', () => {
      const mockAbort = jest.fn(() => { throw new Error('Abort failed'); });
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      const paymentRequest = JSON.stringify({ total: { label: 'Test', amount: '100' } });
      const existingSession = { abort: mockAbort };
      const applePaySessionRef = { contents: existingSession };
      const callBackFunc = jest.fn();
      const resolvePromise = jest.fn();

      ApplePayHelpers.startApplePaySession(
        paymentRequest,
        applePaySessionRef,
        undefined,
        mockLogger,
        callBackFunc,
        resolvePromise,
        'client_secret',
        'pk_test'
      );

      expect(mockSession.begin).toHaveBeenCalled();
    });

    it('onvalidatemerchant completes merchant validation', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      const paymentRequest = JSON.stringify({
        total: { label: 'Test', amount: '100', type: 'final' },
      });
      const applePaySessionRef = { contents: null };
      const callBackFunc = jest.fn();
      const resolvePromise = jest.fn();

      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetDictFromDict.mockImplementation((obj: any, key: string) => obj?.[key] || {});
      mockTransformKeys.mockImplementation((obj: any) => obj);

      ApplePayHelpers.startApplePaySession(
        paymentRequest,
        applePaySessionRef,
        { session_token_data: {} },
        mockLogger,
        callBackFunc,
        resolvePromise,
        'client_secret',
        'pk_test'
      );

      act(() => {
        mockSession.onvalidatemerchant({});
      });

      expect(mockSession.completeMerchantValidation).toHaveBeenCalled();
    });

    it('onshippingcontactselected completes without tax calculation', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      const paymentRequest = JSON.stringify({
        total: { label: 'Test', amount: '100', type: 'final' },
      });
      const applePaySessionRef = { contents: null };
      const callBackFunc = jest.fn();
      const resolvePromise = jest.fn();

      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);

      ApplePayHelpers.startApplePaySession(
        paymentRequest,
        applePaySessionRef,
        undefined,
        mockLogger,
        callBackFunc,
        resolvePromise,
        'client_secret',
        'pk_test',
        false
      );

      act(() => {
        mockSession.onshippingcontactselected({
          shippingContact: {},
        });
      });

      expect(mockSession.completeShippingContactSelection).toHaveBeenCalled();
    });

    it('onshippingcontactselected with tax calculation enabled', async () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      const paymentRequest = JSON.stringify({
        total: { label: 'Test', amount: '100', type: 'final' },
      });
      const applePaySessionRef = { contents: null };
      const callBackFunc = jest.fn();
      const resolvePromise = jest.fn();

      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockMinorUnitToString.mockImplementation((val: number) => String(val));

      ApplePayHelpers.startApplePaySession(
        paymentRequest,
        applePaySessionRef,
        undefined,
        mockLogger,
        callBackFunc,
        resolvePromise,
        'client_secret',
        'pk_test',
        true
      );

      await act(async () => {
        await mockSession.onshippingcontactselected({
          shippingContact: JSON.stringify({
            administrativeArea: 'CA',
            countryCode: 'US',
            postalCode: '12345',
          }),
        });
      });

      expect(mockSession.completeShippingContactSelection).toHaveBeenCalled();
    });

    it('onpaymentauthorized completes payment and calls callback', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      const paymentRequest = JSON.stringify({
        total: { label: 'Test', amount: '100', type: 'final' },
      });
      const applePaySessionRef = { contents: null };
      const callBackFunc = jest.fn();
      const resolvePromise = jest.fn();

      ApplePayHelpers.startApplePaySession(
        paymentRequest,
        applePaySessionRef,
        undefined,
        mockLogger,
        callBackFunc,
        resolvePromise,
        'client_secret',
        'pk_test'
      );

      act(() => {
        mockSession.onpaymentauthorized({
          payment: { token: { paymentData: 'test' } },
        });
      });

      expect(mockSession.completePayment).toHaveBeenCalled();
      expect(callBackFunc).toHaveBeenCalled();
      expect(applePaySessionRef.contents).toBeNull();
    });

    it('oncancel resolves promise with failure response', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      const paymentRequest = JSON.stringify({
        total: { label: 'Test', amount: '100', type: 'final' },
      });
      const applePaySessionRef = { contents: null };
      const callBackFunc = jest.fn();
      const resolvePromise = jest.fn();

      ApplePayHelpers.startApplePaySession(
        paymentRequest,
        applePaySessionRef,
        undefined,
        mockLogger,
        callBackFunc,
        resolvePromise,
        'client_secret',
        'pk_test'
      );

      act(() => {
        mockSession.oncancel();
      });

      expect(mockLogger.setLogError).toHaveBeenCalled();
      expect(resolvePromise).toHaveBeenCalled();
      expect(applePaySessionRef.contents).toBeNull();
    });
  });

  describe('handleApplePayBraintreePaymentSession', () => {
    let mockSession: any;

    beforeEach(() => {
      mockSession = {
        begin: jest.fn(),
        abort: jest.fn(),
        completeMerchantValidation: jest.fn(),
        completePayment: jest.fn(),
        onvalidatemerchant: null,
        onpaymentauthorized: null,
        oncancel: null,
        STATUS_SUCCESS: 1,
        STATUS_FAILURE: 0,
      };

      (globalThis as any).ApplePaySession = jest.fn(() => mockSession);
    });

    afterEach(() => {
      delete (globalThis as any).ApplePaySession;
    });

    it('function exists', () => {
      expect(typeof ApplePayHelpers.handleApplePayBraintreePaymentSession).toBe('function');
    });

    it('creates session and calls begin', () => {
      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const mockApplePayInstance = {
        createPaymentRequest: jest.fn(() => ({})),
        performValidation: jest.fn(),
        tokenize: jest.fn(),
      };

      const onError = jest.fn();
      const onSuccess = jest.fn();

      ApplePayHelpers.handleApplePayBraintreePaymentSession({}, mockApplePayInstance, onError, onSuccess);

      expect(mockSession.begin).toHaveBeenCalled();
    });

    it('onvalidatemerchant calls performValidation', () => {
      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const mockApplePayInstance = {
        createPaymentRequest: jest.fn(() => ({})),
        performValidation: jest.fn((_config: any, callback: any) => callback(null, {})),
        tokenize: jest.fn(),
      };

      const onError = jest.fn();
      const onSuccess = jest.fn();

      ApplePayHelpers.handleApplePayBraintreePaymentSession(
        { total: { label: 'Test', amount: '100' } },
        mockApplePayInstance,
        onError,
        onSuccess
      );

      act(() => {
        mockSession.onvalidatemerchant({ validationURL: 'https://test.com' });
      });

      expect(mockApplePayInstance.performValidation).toHaveBeenCalled();
    });

    it('onvalidatemerchant handles validation error', () => {
      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const mockApplePayInstance = {
        createPaymentRequest: jest.fn(() => ({})),
        performValidation: jest.fn((_config: any, callback: any) => callback(new Error('Validation failed'), null)),
        tokenize: jest.fn(),
      };

      const onError = jest.fn();
      const onSuccess = jest.fn();

      ApplePayHelpers.handleApplePayBraintreePaymentSession(
        { total: { label: 'Test', amount: '100' } },
        mockApplePayInstance,
        onError,
        onSuccess
      );

      act(() => {
        mockSession.onvalidatemerchant({ validationURL: 'https://test.com' });
      });

      expect(onError).toHaveBeenCalled();
      expect(mockSession.abort).toHaveBeenCalled();
    });

    it('onpaymentauthorized tokenizes and calls onSuccess', () => {
      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const mockApplePayInstance = {
        createPaymentRequest: jest.fn(() => ({})),
        performValidation: jest.fn(),
        tokenize: jest.fn((_config: any, callback: any) => callback(null, { nonce: 'test-nonce' })),
      };

      const onError = jest.fn();
      const onSuccess = jest.fn();

      (globalThis as any).ApplePaySession = jest.fn(() => mockSession);
      (globalThis as any).window = { ApplePaySession: mockSession };

      ApplePayHelpers.handleApplePayBraintreePaymentSession(
        { total: { label: 'Test', amount: '100' } },
        mockApplePayInstance,
        onError,
        onSuccess
      );

      act(() => {
        mockSession.onpaymentauthorized({ payment: { token: {} } });
      });

      expect(mockApplePayInstance.tokenize).toHaveBeenCalled();
    });

    it('onpaymentauthorized handles tokenization error', () => {
      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const mockApplePayInstance = {
        createPaymentRequest: jest.fn(() => ({})),
        performValidation: jest.fn(),
        tokenize: jest.fn((_config: any, callback: any) => callback(new Error('Tokenization failed'), null)),
      };

      const onError = jest.fn();
      const onSuccess = jest.fn();

      (globalThis as any).window = { ApplePaySession: mockSession };

      ApplePayHelpers.handleApplePayBraintreePaymentSession(
        { total: { label: 'Test', amount: '100' } },
        mockApplePayInstance,
        onError,
        onSuccess
      );

      act(() => {
        mockSession.onpaymentauthorized({ payment: { token: {} } });
      });

      expect(onError).toHaveBeenCalledWith('ApplePay Tokenization Failed');
    });

    it('oncancel calls onError', () => {
      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const mockApplePayInstance = {
        createPaymentRequest: jest.fn(() => ({})),
        performValidation: jest.fn(),
        tokenize: jest.fn(),
      };

      const onError = jest.fn();
      const onSuccess = jest.fn();

      ApplePayHelpers.handleApplePayBraintreePaymentSession({}, mockApplePayInstance, onError, onSuccess);

      act(() => {
        mockSession.oncancel();
      });

      expect(onError).toHaveBeenCalledWith('Apple Pay Payment Cancelled.');
    });

    it('handles exception during session creation', () => {
      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});
      mockFormatException.mockImplementation((e: any) => e?.message || String(e));

      (globalThis as any).ApplePaySession = jest.fn(() => {
        throw new Error('Session creation failed');
      });

      const mockApplePayInstance = {
        createPaymentRequest: jest.fn(() => ({})),
      };

      const onError = jest.fn();
      const onSuccess = jest.fn();

      ApplePayHelpers.handleApplePayBraintreePaymentSession({}, mockApplePayInstance, onError, onSuccess);

      expect(onError).toHaveBeenCalled();
    });
  });

  describe('handleApplePayBraintreeClick', () => {
    let mockBraintree: any;

    beforeEach(() => {
      mockBraintree = {
        client: {
          create: jest.fn(),
        },
        applePay: {
          create: jest.fn(),
        },
      };

      (globalThis as any).braintree = mockBraintree;
    });

    afterEach(() => {
      delete (globalThis as any).braintree;
    });

    it('function exists', () => {
      expect(typeof ApplePayHelpers.handleApplePayBraintreeClick).toBe('function');
    });

    it('calls messageParentWindow with fullscreen true on start', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      mockBraintree.client.create.mockImplementation((_config: any, callback: any) => {
        callback(null, {});
      });
      mockBraintree.applePay.create.mockImplementation((_config: any, callback: any) => {
        callback(null, { createPaymentRequest: jest.fn(() => ({})) });
      });

      const mockEvent = { source: { postMessage: jest.fn() } };

      ApplePayHelpers.handleApplePayBraintreeClick(
        'test-auth',
        {},
        'test-selector',
        mockLogger,
        mockEvent
      );

      expect(mockMessageParentWindow).toHaveBeenCalledWith(
        undefined,
        expect.arrayContaining([['fullscreen', true]])
      );
    });

    it('calls braintree.client.create with authorization', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      mockBraintree.client.create.mockImplementation((_config: any, callback: any) => {
        callback(null, {});
      });
      mockBraintree.applePay.create.mockImplementation((_config: any, callback: any) => {
        callback(null, { createPaymentRequest: jest.fn(() => ({})) });
      });

      const mockEvent = { source: { postMessage: jest.fn() } };

      ApplePayHelpers.handleApplePayBraintreeClick(
        'test-auth',
        {},
        'test-selector',
        mockLogger,
        mockEvent
      );

      expect(mockBraintree.client.create).toHaveBeenCalledWith(
        { authorization: 'test-auth' },
        expect.any(Function)
      );
    });

    it('handles braintree client creation error', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      mockBraintree.client.create.mockImplementation((_config: any, callback: any) => {
        callback(new Error('Client creation failed'), null);
      });

      const mockEvent = { source: { postMessage: jest.fn() } };

      ApplePayHelpers.handleApplePayBraintreeClick(
        'test-auth',
        {},
        'test-selector',
        mockLogger,
        mockEvent
      );

      expect(mockLogger.setLogError).toHaveBeenCalled();
    });

    it('handles braintree applePay creation error', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      mockBraintree.client.create.mockImplementation((_config: any, callback: any) => {
        callback(null, {});
      });
      mockBraintree.applePay.create.mockImplementation((_config: any, callback: any) => {
        callback(new Error('ApplePay creation failed'), null);
      });

      const mockEvent = { source: { postMessage: jest.fn() } };

      ApplePayHelpers.handleApplePayBraintreeClick(
        'test-auth',
        {},
        'test-selector',
        mockLogger,
        mockEvent
      );

      expect(mockLogger.setLogError).toHaveBeenCalled();
    });

    it('handles exception during client creation', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      mockFormatException.mockImplementation((e: any) => e?.message || String(e));
      mockBraintree.client.create.mockImplementation(() => {
        throw new Error('Unexpected error');
      });

      const mockEvent = { source: { postMessage: jest.fn() } };

      ApplePayHelpers.handleApplePayBraintreeClick(
        'test-auth',
        {},
        'test-selector',
        mockLogger,
        mockEvent
      );

      expect(mockLogger.setLogError).toHaveBeenCalled();
    });

    it('handles exception during applePay creation', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      mockFormatException.mockImplementation((e: any) => e?.message || String(e));
      mockBraintree.client.create.mockImplementation((_config: any, callback: any) => {
        callback(null, {});
      });
      mockBraintree.applePay.create.mockImplementation(() => {
        throw new Error('ApplePay creation error');
      });

      const mockEvent = { source: { postMessage: jest.fn() } };

      ApplePayHelpers.handleApplePayBraintreeClick(
        'test-auth',
        {},
        'test-selector',
        mockLogger,
        mockEvent
      );

      expect(mockLogger.setLogError).toHaveBeenCalled();
    });

    it('onSuccess with empty token logs error', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      mockBraintree.client.create.mockImplementation((_config: any, callback: any) => {
        callback(null, {});
      });

      const mockSession = {
        begin: jest.fn(),
        abort: jest.fn(),
        completeMerchantValidation: jest.fn(),
        completePayment: jest.fn(),
        onvalidatemerchant: null,
        onpaymentauthorized: null,
        oncancel: null,
        STATUS_SUCCESS: 1,
        STATUS_FAILURE: 0,
      };
      (globalThis as any).ApplePaySession = jest.fn(() => mockSession);

      mockBraintree.applePay.create.mockImplementation((_config: any, callback: any) => {
        callback(null, {
          createPaymentRequest: jest.fn(() => ({})),
          performValidation: jest.fn((_c: any, cb: any) => cb(null, {})),
          tokenize: jest.fn((_c: any, cb: any) => cb(null, { nonce: '' })),
        });
      });

      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const mockEvent = { source: { postMessage: jest.fn() } };

      ApplePayHelpers.handleApplePayBraintreeClick(
        'test-auth',
        { total: { label: 'Test', amount: '100' } },
        'test-selector',
        mockLogger,
        mockEvent
      );

      delete (globalThis as any).ApplePaySession;
    });

    it('onSuccess with valid token sends post message', () => {
      const mockLogger = { setLogInfo: jest.fn(), setLogError: jest.fn() };
      mockBraintree.client.create.mockImplementation((_config: any, callback: any) => {
        callback(null, {});
      });

      const mockSession = {
        begin: jest.fn(),
        abort: jest.fn(),
        completeMerchantValidation: jest.fn(),
        completePayment: jest.fn(),
        onvalidatemerchant: null,
        onpaymentauthorized: null,
        oncancel: null,
        STATUS_SUCCESS: 1,
        STATUS_FAILURE: 0,
      };
      (globalThis as any).ApplePaySession = jest.fn(() => mockSession);
      (globalThis as any).window = { ApplePaySession: mockSession };

      mockBraintree.applePay.create.mockImplementation((_config: any, callback: any) => {
        callback(null, {
          createPaymentRequest: jest.fn(() => ({})),
          performValidation: jest.fn((_c: any, cb: any) => cb(null, {})),
          tokenize: jest.fn((_c: any, cb: any) => cb(null, { nonce: 'valid-nonce' })),
        });
      });

      mockGetDictFromJson.mockImplementation((obj: any) => obj || {});
      mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
      mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
      mockGetDictFromObj.mockImplementation((obj: any, key: string) => obj?.[key] || {});

      const mockEvent = { source: { postMessage: jest.fn() } };

      ApplePayHelpers.handleApplePayBraintreeClick(
        'test-auth',
        { total: { label: 'Test', amount: '100' } },
        'test-selector',
        mockLogger,
        mockEvent
      );

      delete (globalThis as any).ApplePaySession;
    });
  });
});
