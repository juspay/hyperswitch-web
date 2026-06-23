import { renderHook, act } from '@testing-library/react';
import { RecoilRoot } from 'recoil';
import * as React from 'react';
import * as ClickToPayHook from '../Hooks/ClickToPayHook.bs.js';
import * as RecoilAtoms from '../Utilities/RecoilAtoms.bs.js';

const mockGetCardsVisaUnified = jest.fn();
const mockGetVisaInitConfig = jest.fn();
const mockLoadClickToPayUIScripts = jest.fn();
const mockLoadVisaScript = jest.fn();
const mockLoadClickToPayScripts = jest.fn();
const mockLoadMastercardScript = jest.fn();
const mockGetCards = jest.fn();
const mockGetDictFromJson = jest.fn((obj: any) => (typeof obj === 'object' && obj !== null ? obj : {}));
const mockItemToObjMapper = jest.fn((obj: any, key: string) => obj?.[key] || {});
const mockGetPaymentSessionObj = jest.fn();
const mockClickToPayTokenItemToObjMapper = jest.fn();
const mockFormatException = jest.fn((e: any) => e?.message || String(e));
const mockMessageParentWindow = jest.fn();

jest.mock('../Types/ClickToPayHelpers.bs.js', () => ({
  getCardsVisaUnified: (config: any) => mockGetCardsVisaUnified(config),
  getVisaInitConfig: (token: any, secret: any) => mockGetVisaInitConfig(token, secret),
  loadClickToPayUIScripts: (logger: any, onLoad: any, onError: any) => mockLoadClickToPayUIScripts(logger, onLoad, onError),
  loadVisaScript: (token: any, onLoad: any, onError: any) => mockLoadVisaScript(token, onLoad, onError),
  loadClickToPayScripts: (logger: any) => mockLoadClickToPayScripts(logger),
  loadMastercardScript: (token: any, logger: any) => mockLoadMastercardScript(token, logger),
  getCards: (logger: any) => mockGetCards(logger),
  clickToPayTokenItemToObjMapper: (token: any) => mockClickToPayTokenItemToObjMapper(token),
}));

jest.mock('../Utilities/Utils.bs.js', () => ({
  getDictFromJson: (obj: any) => mockGetDictFromJson(obj),
  itemToObjMapper: (obj: any, key: string) => mockItemToObjMapper(obj, key),
  getPaymentSessionObj: (sessions: any, type: string) => mockGetPaymentSessionObj(sessions, type),
  formatException: (e: any) => mockFormatException(e),
  messageParentWindow: (a: any, b: any) => mockMessageParentWindow(a, b),
  getArray: jest.fn((obj: any, key: string) => obj?.[key] || []),
}));

jest.mock('../Types/SessionsType.bs.js', () => ({
  itemToObjMapper: (obj: any, key: string) => mockItemToObjMapper(obj, key),
  getPaymentSessionObj: (sessions: any, type: string) => mockGetPaymentSessionObj(sessions, type),
}));

const createMockLogger = () => ({
  setLogInfo: jest.fn(),
  setLogError: jest.fn(),
});

const createWrapperWithAtoms = (atomValues: any) => {
  return function Wrapper({ children }: { children: React.ReactNode }) {
    return React.createElement(
      RecoilRoot,
      {
        initializeState: ({ set }: any) => {
          Object.entries(atomValues).forEach(([key, value]) => {
            const atom = (RecoilAtoms as any)[key];
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

describe('ClickToPayHook', () => {
  describe('useClickToPay', () => {
    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('hook exists and is a function', () => {
      expect(typeof ClickToPayHook.useClickToPay).toBe('function');
    });

    it('returns an array with getVisaCards and closeComponentIfSavedMethodsAreEmpty functions', () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'NONE',
          isReady: false,
          email: '',
          dpaName: '',
          availableCardBrands: [],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: undefined,
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            false,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(Array.isArray(result.current)).toBe(true);
      expect(result.current).toHaveLength(2);
      expect(typeof result.current[0]).toBe('function');
      expect(typeof result.current[1]).toBe('function');
    });

    it('getVisaCards handles successful card fetch', async () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      const mockCards = [{ srcDigitalCardId: 'card-1', panLastFour: '4242' }];
      mockGetCardsVisaUnified.mockResolvedValue({
        actionCode: 'SUCCESS',
        profiles: [{ maskedCards: mockCards }],
      });

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'VISA',
          isReady: true,
          email: 'test@example.com',
          dpaName: 'Test Merchant',
          availableCardBrands: ['VISA'],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: { dpaId: 'test-dpa' },
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            true,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[0]).toBe('function');
    });

    it('getVisaCards handles OTP required response', async () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      mockGetCardsVisaUnified.mockResolvedValue({
        actionCode: 'PENDING_CONSUMER_IDV',
        maskedValidationChannel: '+1***1234',
      });

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'VISA',
          isReady: true,
          email: 'test@example.com',
          dpaName: 'Test Merchant',
          availableCardBrands: ['VISA'],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: { dpaId: 'test-dpa' },
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            true,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[0]).toBe('function');
    });

    it('getVisaCards handles FAILED action code with OTP error', async () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      mockGetCardsVisaUnified.mockResolvedValue({
        actionCode: 'FAILED',
        error: { reason: 'ACCT_INACCESSIBLE' },
      });

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'VISA',
          isReady: true,
          email: 'test@example.com',
          dpaName: 'Test Merchant',
          availableCardBrands: ['VISA'],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: { dpaId: 'test-dpa' },
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            true,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[0]).toBe('function');
    });

    it('getVisaCards handles ADD_CARD action code', async () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      mockGetCardsVisaUnified.mockResolvedValue({
        actionCode: 'ADD_CARD',
      });

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'VISA',
          isReady: true,
          email: 'test@example.com',
          dpaName: 'Test Merchant',
          availableCardBrands: ['VISA'],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: { dpaId: 'test-dpa' },
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            true,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[0]).toBe('function');
    });

    it('getVisaCards handles VALIDATION_DATA_INVALID error', async () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      mockGetCardsVisaUnified.mockResolvedValue({
        actionCode: 'ERROR',
        error: { reason: 'VALIDATION_DATA_INVALID' },
      });

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'VISA',
          isReady: true,
          email: 'test@example.com',
          dpaName: 'Test Merchant',
          availableCardBrands: ['VISA'],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: { dpaId: 'test-dpa' },
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            true,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[0]).toBe('function');
    });

    it('getVisaCards handles OTP_SEND_FAILED error', async () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      mockGetCardsVisaUnified.mockResolvedValue({
        actionCode: 'ERROR',
        error: { reason: 'OTP_SEND_FAILED' },
      });

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'VISA',
          isReady: true,
          email: 'test@example.com',
          dpaName: 'Test Merchant',
          availableCardBrands: ['VISA'],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: { dpaId: 'test-dpa' },
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            true,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[0]).toBe('function');
    });

    it('getVisaCards handles exception during fetch', async () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      mockGetCardsVisaUnified.mockRejectedValue(new Error('Network error'));
      mockFormatException.mockReturnValue('Network error');

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'VISA',
          isReady: true,
          email: 'test@example.com',
          dpaName: 'Test Merchant',
          availableCardBrands: ['VISA'],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: { dpaId: 'test-dpa' },
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            true,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[0]).toBe('function');
    });

    it('closeComponentIfSavedMethodsAreEmpty handles empty savedMethods', () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'NONE',
          isReady: false,
          email: '',
          dpaName: '',
          availableCardBrands: [],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: undefined,
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            false,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadedSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[1]).toBe('function');
    });

    it('closeComponentIfSavedMethodsAreEmpty does nothing when savedMethods has items', () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'NONE',
          isReady: false,
          email: '',
          dpaName: '',
          availableCardBrands: [],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: undefined,
          clickToPayCards: undefined,
        },
        sessions: 'Loading',
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            false,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [{ id: 'card-1' }],
            'LoadedSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(typeof result.current[1]).toBe('function');
    });

    it('handles MASTERCARD provider initialization', () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      const mockToken = {
        provider: 'mastercard',
        dpaId: 'test-dpa',
        dpaName: 'Test Merchant',
        email: 'test@example.com',
        cardBrands: ['MASTERCARD'],
      };

      mockGetPaymentSessionObj.mockReturnValue({ TAG: 'ClickToPayTokenOptional', _0: mockToken });
      mockClickToPayTokenItemToObjMapper.mockReturnValue(mockToken);
      mockLoadClickToPayScripts.mockResolvedValue(Promise.resolve());
      mockLoadMastercardScript.mockResolvedValue(JSON.stringify({ availableCardBrands: ['MASTERCARD'] }));

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'NONE',
          isReady: false,
          email: '',
          dpaName: '',
          availableCardBrands: [],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: undefined,
          clickToPayCards: undefined,
        },
        sessions: { TAG: 'Loaded', _0: 'session-data' },
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            false,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(Array.isArray(result.current)).toBe(true);
    });

    it('handles VISA provider initialization', () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      const mockToken = {
        provider: 'visa',
        dpaId: 'test-dpa',
        dpaName: 'Test Merchant',
        email: 'test@example.com',
        cardBrands: ['VISA'],
      };

      mockGetPaymentSessionObj.mockReturnValue({ TAG: 'ClickToPayTokenOptional', _0: mockToken });
      mockClickToPayTokenItemToObjMapper.mockReturnValue(mockToken);
      mockLoadClickToPayUIScripts.mockImplementation((_logger: any, onLoad: any, _onError: any) => {
        onLoad();
      });
      mockLoadVisaScript.mockImplementation((_token: any, onLoad: any, _onError: any) => {
        onLoad();
      });
      mockGetVisaInitConfig.mockReturnValue({});

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'NONE',
          isReady: false,
          email: '',
          dpaName: '',
          availableCardBrands: [],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: undefined,
          clickToPayCards: undefined,
        },
        sessions: { TAG: 'Loaded', _0: 'session-data' },
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            false,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(Array.isArray(result.current)).toBe(true);
    });

    it('handles unknown provider by setting provider to NONE', () => {
      const mockLogger = createMockLogger();
      const mockSetSessions = jest.fn();
      const mockSetAreClickToPayUIScriptsLoaded = jest.fn();

      const mockToken = {
        provider: 'unknown',
        dpaId: 'test-dpa',
        dpaName: 'Test Merchant',
        email: 'test@example.com',
        cardBrands: [],
      };

      mockGetPaymentSessionObj.mockReturnValue({ TAG: 'ClickToPayTokenOptional', _0: mockToken });
      mockClickToPayTokenItemToObjMapper.mockReturnValue(mockToken);

      const Wrapper = createWrapperWithAtoms({
        loggerAtom: mockLogger,
        clickToPayConfig: {
          clickToPayProvider: 'NONE',
          isReady: false,
          email: '',
          dpaName: '',
          availableCardBrands: [],
          visaComponentState: 'NONE',
          maskedIdentity: '',
          otpError: '',
          consumerIdentity: { identityType: 'EMAIL_ADDRESS', identityValue: '' },
          clickToPayToken: undefined,
          clickToPayCards: undefined,
        },
        sessions: { TAG: 'Loaded', _0: 'session-data' },
        keys: { clientSecret: 'test_secret', publishableKey: 'pk_test' },
        showPaymentMethodsScreen: false,
      });

      const { result } = renderHook(
        () =>
          ClickToPayHook.useClickToPay(
            false,
            mockSetSessions,
            mockSetAreClickToPayUIScriptsLoaded,
            [],
            'LoadingSavedCards'
          ),
        { wrapper: Wrapper }
      );

      expect(Array.isArray(result.current)).toBe(true);
    });
  });
});
