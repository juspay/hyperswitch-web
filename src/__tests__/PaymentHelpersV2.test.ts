import * as PaymentHelpersV2 from '../Utilities/PaymentHelpersV2.bs.js';
import { renderHook } from '@testing-library/react';
import { RecoilRoot } from 'recoil';
import * as React from 'react';
import * as RecoilAtoms from '../Utilities/RecoilAtoms.bs.js';
import * as RecoilAtomsV2 from '../Utilities/RecoilAtomsV2.bs.js';

const mockFetchApi = jest.fn();
const mockGetDictFromJson = jest.fn((obj: any) => (typeof obj === 'object' && obj !== null ? obj : {}));
const mockGetString = jest.fn((obj: any, key: string, def: string) => obj?.[key] ?? def);
const mockMessageParentWindow = jest.fn();
const mockGetPaymentId = jest.fn((secret: string) => secret?.split('_secret_')[0] || '');
const mockPostFailedSubmitResponse = jest.fn();
const mockGetJsonFromArrayOfJson = jest.fn((arr: any) => Object.fromEntries(arr));
const mockGetNonEmptyOption = jest.fn((val: any) => (val ? val : undefined));
const mockOpenUrl = jest.fn();
const mockReplaceRootHref = jest.fn();
const mockPostSubmitResponse = jest.fn();
const mockHandleOnCompleteDoThisMessage = jest.fn();
const mockGetFailedSubmitResponse = jest.fn((type: string, msg: string) => ({ type, message: msg }));
const mockFormatException = jest.fn((e: any) => e?.message || String(e));
const mockSafeParse = jest.fn((str: string) => {
  try {
    return JSON.parse(str);
  } catch {
    return null;
  }
});
const mockGetStringFromJson = jest.fn((val: any, def: string) => (typeof val === 'string' ? val : def));

jest.mock('../Utilities/Utils.bs.js', () => ({
  getDictFromJson: (obj: any) => mockGetDictFromJson(obj),
  getString: (obj: any, key: string, def: string) => mockGetString(obj, key, def),
  messageParentWindow: (a: any, b: any) => mockMessageParentWindow(a, b),
  getPaymentId: (secret: string) => mockGetPaymentId(secret),
  postFailedSubmitResponse: (type: string, msg: string) => mockPostFailedSubmitResponse(type, msg),
  getJsonFromArrayOfJson: (arr: any) => mockGetJsonFromArrayOfJson(arr),
  getNonEmptyOption: (val: any) => mockGetNonEmptyOption(val),
  fetchApi: (url: string, body: any, headers: any, method: string) => mockFetchApi(url, body, headers, method),
  openUrl: (url: string) => mockOpenUrl(url),
  replaceRootHref: (url: string, flags: any) => mockReplaceRootHref(url, flags),
  postSubmitResponse: (data: any, url: string) => mockPostSubmitResponse(data, url),
  handleOnCompleteDoThisMessage: (a: any) => mockHandleOnCompleteDoThisMessage(a),
  getFailedSubmitResponse: (type: string, msg: string) => mockGetFailedSubmitResponse(type, msg),
  formatException: (e: any) => mockFormatException(e),
  safeParse: (str: string) => mockSafeParse(str),
  getStringFromJson: (val: any, def: string) => mockGetStringFromJson(val, def),
}));

jest.mock('../Utilities/ApiEndpoint.bs.js', () => ({
  getApiEndPoint: jest.fn((key: string, isThirdParty: boolean) => 'https://api.test.com'),
  addCustomPodHeader: jest.fn((headers: any, uri: any) => headers),
}));

jest.mock('../Utilities/LoggerUtils.bs.js', () => ({
  logApi: jest.fn(),
  handleLogging: jest.fn(),
}));

jest.mock('../BrowserSpec.bs.js', () => ({
  broswerInfo: jest.fn(() => [['browser_info', { user_agent: 'test-agent' }]]),
}));

jest.mock('../Types/PaymentConfirmTypesV2.bs.js', () => ({
  itemToPMMConfirmMapper: jest.fn((obj: any) => ({
    authenticationDetails: { status: 'succeeded' },
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

jest.mock('../Utilities/PaymentHelpers.bs.js', () => ({
  closePaymentLoaderIfAny: jest.fn(),
}));

const createWrapperWithAtoms = (atomValues: any) => {
  return function Wrapper({ children }: { children: React.ReactNode }) {
    return React.createElement(
      RecoilRoot,
      {
        initializeState: ({ set }: any) => {
          Object.entries(atomValues).forEach(([key, value]) => {
            const atom = (RecoilAtoms as any)[key] || (RecoilAtomsV2 as any)[key];
            if (atom) {
              set(atom, value);
            }
          });
        },
      },
      children
    );
  };
};

describe('PaymentHelpersV2', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('fetchPaymentManagementList', () => {
    it('returns data on successful fetch', async () => {
      const mockData = { payment_methods: [] };
      mockFetchApi.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockData),
      });

      const result = await PaymentHelpersV2.fetchPaymentManagementList(
        'pm_session_123',
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'https://api.test.com',
        undefined,
        undefined
      );

      expect(mockFetchApi).toHaveBeenCalled();
      expect(result).toEqual(mockData);
    });

    it('returns null on failed fetch', async () => {
      mockFetchApi.mockResolvedValue({
        ok: false,
        json: () => Promise.resolve({ error: 'not_found' }),
      });

      const result = await PaymentHelpersV2.fetchPaymentManagementList(
        'pm_session_123',
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'https://api.test.com',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });

    it('returns null on fetch exception', async () => {
      mockFetchApi.mockRejectedValue(new Error('Network error'));
      mockFormatException.mockReturnValue('Network error');

      const result = await PaymentHelpersV2.fetchPaymentManagementList(
        'pm_session_123',
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'https://api.test.com',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });
  });

  describe('deletePaymentMethodV2', () => {
    it('returns data on successful delete', async () => {
      const mockData = { deleted: true };
      mockFetchApi.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockData),
      });

      const result = await PaymentHelpersV2.deletePaymentMethodV2(
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'pm_token_123',
        'pm_session_123',
        undefined,
        undefined
      );

      expect(mockFetchApi).toHaveBeenCalled();
      expect(result).toEqual(mockData);
    });

    it('returns null on failed delete', async () => {
      mockFetchApi.mockResolvedValue({
        ok: false,
        json: () => Promise.resolve({ error: 'not_found' }),
      });

      const result = await PaymentHelpersV2.deletePaymentMethodV2(
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'pm_token_123',
        'pm_session_123',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });

    it('returns null on fetch exception', async () => {
      mockFetchApi.mockRejectedValue(new Error('Network error'));
      mockFormatException.mockReturnValue('Network error');

      const result = await PaymentHelpersV2.deletePaymentMethodV2(
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'pm_token_123',
        'pm_session_123',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });
  });

  describe('updatePaymentMethod', () => {
    it('returns data on successful update', async () => {
      const mockData = { updated: true };
      mockFetchApi.mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockData),
      });

      const result = await PaymentHelpersV2.updatePaymentMethod(
        [['card_exp_month', '12'], ['card_exp_year', '2025']],
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'pm_session_123',
        undefined,
        undefined
      );

      expect(mockFetchApi).toHaveBeenCalled();
      expect(result).toEqual(mockData);
    });

    it('returns null on failed update', async () => {
      mockFetchApi.mockResolvedValue({
        ok: false,
        json: () => Promise.resolve({ error: 'invalid_request' }),
      });

      const result = await PaymentHelpersV2.updatePaymentMethod(
        [],
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'pm_session_123',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });

    it('returns null on fetch exception', async () => {
      mockFetchApi.mockRejectedValue(new Error('Network error'));
      mockFormatException.mockReturnValue('Network error');

      const result = await PaymentHelpersV2.updatePaymentMethod(
        [],
        'pm_secret_123',
        'pk_test',
        'profile_123',
        'pm_session_123',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });
  });

  describe('intentCall', () => {
    it('is callable and returns a promise', () => {
      const mockResponse = {
        ok: true,
        json: () =>
          Promise.resolve({
            status: 'succeeded',
            payment_method_type: 'card',
          }),
      };
      mockFetchApi.mockResolvedValue(mockResponse);
      mockGetDictFromJson.mockReturnValue({
        status: 'succeeded',
        payment_method_type: 'card',
      });
      mockGetString.mockImplementation((obj: any, key: string) => obj?.[key]);

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpersV2.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [['Content-Type', 'application/json']],
        JSON.stringify({ client_secret: 'secret_123' }),
        confirmParam,
        'pay_123_secret_123',
        undefined,
        false,
        'Card',
        'POST',
        undefined,
        false,
        false,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
      expect(mockFetchApi).toHaveBeenCalled();
    });

    it('handles non-ok response', () => {
      const mockResponse = {
        ok: false,
        json: () =>
          Promise.resolve({
            error: { type: 'invalid_request', message: 'Invalid request' },
          }),
      };
      mockFetchApi.mockResolvedValue(mockResponse);
      mockGetDictFromJson.mockReturnValue({
        error: { type: 'invalid_request', message: 'Invalid request' },
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpersV2.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [['Content-Type', 'application/json']],
        JSON.stringify({ client_secret: 'secret_123' }),
        confirmParam,
        'pay_123_secret_123',
        undefined,
        false,
        'Card',
        'POST',
        undefined,
        false,
        false,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
      expect(mockFetchApi).toHaveBeenCalled();
    });

    it('handles fetch exception', () => {
      mockFetchApi.mockRejectedValue(new Error('Network error'));
      mockFormatException.mockReturnValue('Network error');

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      const result = PaymentHelpersV2.intentCall(
        mockFetchApi,
        'https://api.test.com/payments/pay_123/confirm',
        [['Content-Type', 'application/json']],
        JSON.stringify({ client_secret: 'secret_123' }),
        confirmParam,
        'pay_123_secret_123',
        undefined,
        false,
        'Card',
        'POST',
        undefined,
        false,
        false,
        undefined
      );

      expect(result).toBeInstanceOf(Promise);
    });
  });

  describe('useSaveCard', () => {
    it('hook exists and is a function', () => {
      expect(typeof PaymentHelpersV2.useSaveCard).toBe('function');
    });

    it('returns a function when rendered with LoadedV2 paymentManagementList', () => {
      const Wrapper = createWrapperWithAtoms({
        paymentManagementList: { TAG: 'LoadedV2', _0: { payment_methods: [] } },
        keys: {
          pmClientSecret: 'pm_secret_123',
          pmSessionId: 'pm_session_123',
          publishableKey: 'pk_test',
          profileId: 'profile_123',
          sdkHandleOneClickConfirmPayment: false,
        },
        customPodUri: '',
        isCompleteCallbackUsed: false,
        redirectionFlagsAtom: { shouldUseTopRedirection: false, shouldRemoveBeforeUnloadEvents: false },
      });

      const { result } = renderHook(() => PaymentHelpersV2.useSaveCard(undefined, 'Card'), {
        wrapper: Wrapper,
      });

      expect(typeof result.current).toBe('function');
    });

    it('returns a function that does nothing when paymentManagementList is not LoadedV2', () => {
      const Wrapper = createWrapperWithAtoms({
        paymentManagementList: 'LoadingV2',
        keys: {
          pmClientSecret: 'pm_secret_123',
          pmSessionId: 'pm_session_123',
          publishableKey: 'pk_test',
          profileId: 'profile_123',
          sdkHandleOneClickConfirmPayment: false,
        },
        customPodUri: '',
        isCompleteCallbackUsed: false,
        redirectionFlagsAtom: { shouldUseTopRedirection: false, shouldRemoveBeforeUnloadEvents: false },
      });

      const { result } = renderHook(() => PaymentHelpersV2.useSaveCard(undefined, 'Card'), {
        wrapper: Wrapper,
      });

      expect(typeof result.current).toBe('function');

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      if (result.current) {
        result.current(false, [], confirmParam);
      }

      expect(mockFetchApi).not.toHaveBeenCalled();
    });

    it('posts failed response when pmClientSecret is undefined', () => {
      const Wrapper = createWrapperWithAtoms({
        paymentManagementList: { TAG: 'LoadedV2', _0: { payment_methods: [] } },
        keys: {
          pmClientSecret: undefined,
          pmSessionId: 'pm_session_123',
          publishableKey: 'pk_test',
          profileId: 'profile_123',
          sdkHandleOneClickConfirmPayment: false,
        },
        customPodUri: '',
        isCompleteCallbackUsed: false,
        redirectionFlagsAtom: { shouldUseTopRedirection: false, shouldRemoveBeforeUnloadEvents: false },
      });

      const { result } = renderHook(() => PaymentHelpersV2.useSaveCard(undefined, 'Card'), {
        wrapper: Wrapper,
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      if (result.current) {
        result.current(false, [], confirmParam);
      }

      expect(mockPostFailedSubmitResponse).toHaveBeenCalledWith(
        'confirm_payment_failed',
        'Payment failed. Try again!'
      );
    });
  });

  describe('useUpdateCard', () => {
    it('hook exists and is a function', () => {
      expect(typeof PaymentHelpersV2.useUpdateCard).toBe('function');
    });

    it('returns a function when rendered with LoadedV2 paymentManagementList', () => {
      const Wrapper = createWrapperWithAtoms({
        paymentManagementList: { TAG: 'LoadedV2', _0: { payment_methods: [] } },
        keys: {
          pmClientSecret: 'pm_secret_123',
          pmSessionId: 'pm_session_123',
          publishableKey: 'pk_test',
          profileId: 'profile_123',
          sdkHandleOneClickConfirmPayment: false,
        },
        customPodUri: '',
        isCompleteCallbackUsed: false,
        redirectionFlagsAtom: { shouldUseTopRedirection: false, shouldRemoveBeforeUnloadEvents: false },
      });

      const { result } = renderHook(() => PaymentHelpersV2.useUpdateCard(undefined, 'Card'), {
        wrapper: Wrapper,
      });

      expect(typeof result.current).toBe('function');
    });

    it('returns a function that does nothing when paymentManagementList is not LoadedV2', () => {
      const Wrapper = createWrapperWithAtoms({
        paymentManagementList: 'LoadingV2',
        keys: {
          pmClientSecret: 'pm_secret_123',
          pmSessionId: 'pm_session_123',
          publishableKey: 'pk_test',
          profileId: 'profile_123',
          sdkHandleOneClickConfirmPayment: false,
        },
        customPodUri: '',
        isCompleteCallbackUsed: false,
        redirectionFlagsAtom: { shouldUseTopRedirection: false, shouldRemoveBeforeUnloadEvents: false },
      });

      const { result } = renderHook(() => PaymentHelpersV2.useUpdateCard(undefined, 'Card'), {
        wrapper: Wrapper,
      });

      expect(typeof result.current).toBe('function');

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      if (result.current) {
        result.current(false, [], confirmParam);
      }

      expect(mockFetchApi).not.toHaveBeenCalled();
    });

    it('posts failed response when pmClientSecret is undefined', () => {
      const Wrapper = createWrapperWithAtoms({
        paymentManagementList: { TAG: 'LoadedV2', _0: { payment_methods: [] } },
        keys: {
          pmClientSecret: undefined,
          pmSessionId: 'pm_session_123',
          publishableKey: 'pk_test',
          profileId: 'profile_123',
          sdkHandleOneClickConfirmPayment: false,
        },
        customPodUri: '',
        isCompleteCallbackUsed: false,
        redirectionFlagsAtom: { shouldUseTopRedirection: false, shouldRemoveBeforeUnloadEvents: false },
      });

      const { result } = renderHook(() => PaymentHelpersV2.useUpdateCard(undefined, 'Card'), {
        wrapper: Wrapper,
      });

      const confirmParam = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test',
        redirect: 'if_required',
      };

      if (result.current) {
        result.current(false, [], confirmParam);
      }

      expect(mockPostFailedSubmitResponse).toHaveBeenCalledWith(
        'confirm_payment_failed',
        'Payment failed. Try again!'
      );
    });
  });
});
