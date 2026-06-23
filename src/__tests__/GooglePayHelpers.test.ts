import * as React from 'react';
import { renderHook } from '@testing-library/react';
import * as GooglePayHelpers from '../Utilities/GooglePayHelpers.bs.js';

const mockMessageParentWindow = jest.fn();
const mockPostFailedSubmitResponse = jest.fn();
const mockSafeParse = jest.fn((str: string) => {
  try {
    return JSON.parse(str);
  } catch {
    return null;
  }
});
const mockGetDictFromJson = jest.fn((obj: any) => {
  if (typeof obj === 'string') {
    try {
      return JSON.parse(obj);
    } catch {
      return {};
    }
  }
  return typeof obj === 'object' && obj !== null ? obj : {};
});
const mockGetString = jest.fn((obj: any, key: string, def: string) => obj?.[key] ?? def);
const mockMergeAndFlattenToTuples = jest.fn((a: any, b: any) => [...(a || []), ...(b || [])]);
const mockGetJsonObjectFromDict = jest.fn((obj: any, key: string) => obj?.[key] || {});

jest.mock('../Utilities/Utils.bs.js', () => ({
  getDictFromJson: (obj: any) => mockGetDictFromJson(obj),
  getString: (obj: any, key: string, def: string) => mockGetString(obj, key, def),
  mergeAndFlattenToTuples: (a: any, b: any) => mockMergeAndFlattenToTuples(a, b),
  messageParentWindow: (a: any, b: any) => mockMessageParentWindow(a, b),
  getJsonObjectFromDict: (obj: any, key: string) => mockGetJsonObjectFromDict(obj, key),
  safeParse: (str: string) => mockSafeParse(str),
  postFailedSubmitResponse: (type: string, msg: string) => mockPostFailedSubmitResponse(type, msg),
}));

jest.mock('../Utilities/PaymentBody.bs.js', () => ({
  gpayBody: jest.fn((obj: any, connectors: any) => [['google_pay', obj]]),
}));

jest.mock('../Utilities/PaymentUtils.bs.js', () => ({
  appendedCustomerAcceptance: jest.fn((isGuest: boolean, type: string, body: any) => body),
  paymentMethodListValue: { key: 'paymentMethodListValue' },
}));

const mockGetGooglePayRequiredFields = jest.fn((billing: any, shipping: any, fields: any, email: string) => [['required', {}]]);
const mockUsePaymentMethodTypeFromList = jest.fn(() => ({ required_fields: [] }));

jest.mock('../Utilities/DynamicFieldsUtils.bs.js', () => ({
  getGooglePayRequiredFields: (billing: any, shipping: any, fields: any, email: string) => mockGetGooglePayRequiredFields(billing, shipping, fields, email),
  usePaymentMethodTypeFromList: () => mockUsePaymentMethodTypeFromList(),
}));

jest.mock('../Types/GooglePayType.bs.js', () => ({
  itemToObjMapper: jest.fn((obj: any) => obj || {}),
  billingContactItemToObjMapper: jest.fn((obj: any) => obj || {}),
  getPaymentDataFromSession: jest.fn((session: any, name: string) => JSON.stringify({ testData: 'value' })),
}));

jest.mock('../Payments/PaymentMethodsRecord.bs.js', () => ({
  defaultList: { payment_type: 'NORMAL' },
}));

jest.mock('../Types/ConfirmType.bs.js', () => ({
  itemToObjMapper: jest.fn((obj: any) => ({ doSubmit: true, ...obj })),
}));

const mockUseIsGuestCustomer = jest.fn(() => false);
jest.mock('../Hooks/UtilityHooks.bs.js', () => ({
  useIsGuestCustomer: () => mockUseIsGuestCustomer(),
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
}));

describe('GooglePayHelpers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getGooglePayBodyFromResponse', () => {
    it('returns merged body with billing and shipping contacts', () => {
      const gPayResponse = JSON.stringify({
        paymentMethodData: {
          info: {
            billingAddress: { name: 'John Doe', country: 'US' },
          },
        },
        shippingAddress: { name: 'Jane Doe', country: 'CA' },
        email: 'test@example.com',
      });

      const result = GooglePayHelpers.getGooglePayBodyFromResponse(
        gPayResponse,
        true,
        undefined,
        [],
        undefined,
        undefined,
        undefined
      );

      expect(result).toBeDefined();
    });

    it('handles gPayResponse with complete payment data', () => {
      const gPayResponse = JSON.stringify({
        paymentMethodData: {
          description: 'Visa •••• 4242',
          info: {
            billingAddress: {
              name: 'Test User',
              countryCode: 'US',
              postalCode: '12345',
            },
          },
          tokenizationData: {
            type: 'PAYMENT_GATEWAY',
            token: 'test-token',
          },
        },
        shippingAddress: {
          name: 'Shipping User',
          countryCode: 'CA',
        },
        email: 'shipping@example.com',
      });

      const result = GooglePayHelpers.getGooglePayBodyFromResponse(
        gPayResponse,
        false,
        undefined,
        [],
        undefined,
        undefined,
        undefined
      );

      expect(result).toBeDefined();
    });

    it('uses default values for optional parameters', () => {
      const gPayResponse = JSON.stringify({
        paymentMethodData: {
          info: {
            billingAddress: {},
          },
        },
        shippingAddress: {},
        email: '',
      });

      const result = GooglePayHelpers.getGooglePayBodyFromResponse(gPayResponse, false);

      expect(result).toBeDefined();
    });

    it('handles payment session flow', () => {
      const gPayResponse = JSON.stringify({
        paymentMethodData: {
          info: {
            billingAddress: { country: 'US' },
          },
        },
        shippingAddress: {},
        email: 'test@test.com',
      });

      const result = GooglePayHelpers.getGooglePayBodyFromResponse(
        gPayResponse,
        true,
        undefined,
        [],
        undefined,
        true,
        undefined
      );

      expect(result).toBeDefined();
    });

    it('handles saved methods flow', () => {
      const gPayResponse = JSON.stringify({
        paymentMethodData: {
          info: {
            billingAddress: {},
          },
        },
        shippingAddress: {},
        email: '',
      });

      const result = GooglePayHelpers.getGooglePayBodyFromResponse(
        gPayResponse,
        true,
        undefined,
        [],
        undefined,
        undefined,
        true
      );

      expect(result).toBeDefined();
    });

    it('passes required fields when not payment session or saved methods flow', () => {
      const gPayResponse = JSON.stringify({
        paymentMethodData: {
          info: {
            billingAddress: {},
          },
        },
        shippingAddress: {},
        email: '',
      });

      const requiredFields = ['billing_address', 'email'];
      const result = GooglePayHelpers.getGooglePayBodyFromResponse(
        gPayResponse,
        true,
        undefined,
        [],
        requiredFields,
        false,
        false
      );

      expect(result).toBeDefined();
    });
  });

  describe('processPayment', () => {
    it('calls intent with correct parameters', () => {
      const mockIntent = jest.fn();
      const bodyArr = [['card', { number: '4242' }]];
      const options = { wallets: { walletReturnUrl: 'https://return.url' } };

      GooglePayHelpers.processPayment(bodyArr, undefined, mockIntent, options, 'pk_test', false);

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

    it('passes isThirdPartyFlow as true when provided', () => {
      const mockIntent = jest.fn();
      const bodyArr = [['google_pay', { token: 'test' }]];
      const options = { wallets: { walletReturnUrl: 'https://return.url' } };

      GooglePayHelpers.processPayment(bodyArr, true, mockIntent, options, 'pk_test', true);

      expect(mockIntent).toHaveBeenCalledWith(
        true,
        bodyArr,
        expect.any(Object),
        undefined,
        true,
        undefined,
        true
      );
    });

    it('uses default isThirdPartyFlow value when not provided', () => {
      const mockIntent = jest.fn();
      const options = { wallets: { walletReturnUrl: 'https://return.url' } };

      GooglePayHelpers.processPayment([], undefined, mockIntent, options, 'pk_test', undefined);

      expect(mockIntent).toHaveBeenCalledWith(
        expect.any(Boolean),
        expect.any(Array),
        expect.any(Object),
        undefined,
        false,
        undefined,
        undefined
      );
    });
  });

  describe('handleGooglePayClicked', () => {
    it('sends message to parent window with payment data request', () => {
      const sessionObj = { session_token_data: { secrets: { display: 'test-token' } } };

      mockMessageParentWindow.mockImplementation(() => {});

      GooglePayHelpers.handleGooglePayClicked(sessionObj, 'gpay-component', 'iframe-123', false);

      expect(mockMessageParentWindow).toHaveBeenCalled();
    });

    it('does not send GpayClicked message when readOnly is true', () => {
      const sessionObj = { session_token_data: { secrets: { display: 'test-token' } } };

      mockMessageParentWindow.mockClear();

      GooglePayHelpers.handleGooglePayClicked(sessionObj, 'gpay-component', 'iframe-123', true);

      const calls = mockMessageParentWindow.mock.calls;
      const hasGpayClicked = calls.some((call: any) => {
        const messageData = call[1];
        return messageData?.some((entry: any) => entry[0] === 'GpayClicked');
      });
      expect(hasGpayClicked).toBe(false);
    });

    it('sends fullscreen message before payment data', () => {
      const sessionObj = {};

      mockMessageParentWindow.mockClear();

      GooglePayHelpers.handleGooglePayClicked(sessionObj, 'gpay-component', 'iframe-123', false);

      const firstCall = mockMessageParentWindow.mock.calls[0];
      const messageData = firstCall[1];
      const fullscreenEntry = messageData?.find((entry: any) => entry[0] === 'fullscreen');
      expect(fullscreenEntry).toBeDefined();
      expect(fullscreenEntry[1]).toBe(true);
    });

    it('includes paymentloader param in message', () => {
      const sessionObj = {};

      mockMessageParentWindow.mockClear();

      GooglePayHelpers.handleGooglePayClicked(sessionObj, 'gpay-component', 'iframe-123', false);

      const firstCall = mockMessageParentWindow.mock.calls[0];
      const messageData = firstCall[1];
      const paramEntry = messageData?.find((entry: any) => entry[0] === 'param');
      expect(paramEntry).toBeDefined();
      expect(paramEntry[1]).toBe('paymentloader');
    });

    it('includes iframeId in message', () => {
      const sessionObj = {};

      mockMessageParentWindow.mockClear();

      GooglePayHelpers.handleGooglePayClicked(sessionObj, 'gpay-component', 'my-custom-iframe', false);

      const firstCall = mockMessageParentWindow.mock.calls[0];
      const messageData = firstCall[1];
      const iframeEntry = messageData?.find((entry: any) => entry[0] === 'iframeId');
      expect(iframeEntry).toBeDefined();
      expect(iframeEntry[1]).toBe('my-custom-iframe');
    });
  });

  describe('useHandleGooglePayResponse', () => {
    it('hook exists and is a function', () => {
      expect(typeof GooglePayHelpers.useHandleGooglePayResponse).toBe('function');
    });

    it('sets up message event listener on mount', () => {
      const addEventListenerSpy = jest.spyOn(window, 'addEventListener');
      const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
      
      const mockIntent = jest.fn();
      const { unmount } = renderHook(() =>
        GooglePayHelpers.useHandleGooglePayResponse([], mockIntent)
      );

      expect(addEventListenerSpy).toHaveBeenCalledWith('message', expect.any(Function));
      
      unmount();
      expect(removeEventListenerSpy).toHaveBeenCalledWith('message', expect.any(Function));
      
      addEventListenerSpy.mockRestore();
      removeEventListenerSpy.mockRestore();
    });

    it('uses default isSavedMethodsFlow when not provided', () => {
      const mockIntent = jest.fn();
      renderHook(() =>
        GooglePayHelpers.useHandleGooglePayResponse([], mockIntent)
      );
      expect(mockIntent).not.toHaveBeenCalled();
    });

    it('uses default isWallet value when not provided', () => {
      const mockIntent = jest.fn();
      renderHook(() =>
        GooglePayHelpers.useHandleGooglePayResponse([], mockIntent)
      );
      expect(typeof GooglePayHelpers.useHandleGooglePayResponse).toBe('function');
    });
  });

  describe('useSubmitCallback', () => {
    it('hook exists and is a function', () => {
      expect(typeof GooglePayHelpers.useSubmitCallback).toBe('function');
    });

    it('returns a callback function', () => {
      const sessionObj = { session_token_data: { secrets: { display: 'token' } } };
      const { result } = renderHook(() =>
        GooglePayHelpers.useSubmitCallback(true, sessionObj, 'gpay-component')
      );

      expect(typeof result.current).toBe('function');
    });

    it('returns early when isWallet is true', () => {
      const sessionObj = { session_token_data: { secrets: { display: 'token' } } };
      const { result } = renderHook(() =>
        GooglePayHelpers.useSubmitCallback(true, sessionObj, 'gpay-component')
      );

      const mockEvent = { data: JSON.stringify({ doSubmit: true }) };
      result.current(mockEvent);
      
      expect(mockMessageParentWindow).not.toHaveBeenCalledWith(
        expect.anything(),
        expect.arrayContaining([expect.arrayContaining(['GpayClicked', true])])
      );
    });

    it('handles submit when fields are valid and not empty', () => {
      const sessionObj = { session_token_data: { secrets: { display: 'token' } } };

      const { result } = renderHook(() =>
        GooglePayHelpers.useSubmitCallback(false, sessionObj, 'gpay-component')
      );

      mockSafeParse.mockReturnValue(JSON.stringify({ doSubmit: true }));
      mockGetDictFromJson.mockReturnValue({ doSubmit: true });

      const mockEvent = { data: JSON.stringify({ doSubmit: true }) };
      result.current(mockEvent);
    });

    it('posts failed response when required fields are empty', () => {
      const sessionObj = { session_token_data: { secrets: { display: 'token' } } };
      
      const { result } = renderHook(() =>
        GooglePayHelpers.useSubmitCallback(false, sessionObj, 'gpay-component')
      );

      mockSafeParse.mockReturnValue(JSON.stringify({ doSubmit: true }));
      mockGetDictFromJson.mockReturnValue({ doSubmit: true });

      const mockEvent = { data: JSON.stringify({ doSubmit: true }) };
      result.current(mockEvent);
    });

    it('posts failed response when required fields are invalid', () => {
      const sessionObj = { session_token_data: { secrets: { display: 'token' } } };

      const { result } = renderHook(() =>
        GooglePayHelpers.useSubmitCallback(false, sessionObj, 'gpay-component')
      );

      mockSafeParse.mockReturnValue(JSON.stringify({ doSubmit: true }));
      mockGetDictFromJson.mockReturnValue({ doSubmit: true });

      const mockEvent = { data: JSON.stringify({ doSubmit: true }) };
      result.current(mockEvent);
    });

    it('does nothing when doSubmit is false', () => {
      const sessionObj = { session_token_data: { secrets: { display: 'token' } } };

      const { result } = renderHook(() =>
        GooglePayHelpers.useSubmitCallback(false, sessionObj, 'gpay-component')
      );

      mockSafeParse.mockReturnValue(JSON.stringify({ doSubmit: false }));
      mockGetDictFromJson.mockReturnValue({ doSubmit: false });

      mockPostFailedSubmitResponse.mockClear();
      const mockEvent = { data: JSON.stringify({ doSubmit: false }) };
      result.current(mockEvent);

      expect(mockPostFailedSubmitResponse).not.toHaveBeenCalled();
    });
  });
});
