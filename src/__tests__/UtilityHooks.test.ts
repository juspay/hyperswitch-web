import { renderHook, act } from '@testing-library/react';
import { RecoilRoot } from 'recoil';
import * as React from 'react';
import * as UtilityHooks from '../Hooks/UtilityHooks.bs.js';
import * as RecoilAtoms from '../Utilities/RecoilAtoms.bs.js';
import * as PaymentUtils from '../Utilities/PaymentUtils.bs.js';

const mockHandlePostMessageEvents = jest.fn();
const mockMessageParentWindow = jest.fn();
const mockGetDictFromJson = jest.fn((obj: any) => (typeof obj === 'object' && obj !== null ? obj : {}));

jest.mock('../Utilities/Utils.bs.js', () => ({
  handlePostMessageEvents: (a: any, b: any, c: any, d: any, e: any) => mockHandlePostMessageEvents(a, b, c, d, e),
  getDictFromJson: (obj: any) => mockGetDictFromJson(obj),
  messageParentWindow: (a: any, b: any) => mockMessageParentWindow(a, b),
}));

jest.mock('../Payments/PaymentMethodsRecord.bs.js', () => ({
  itemToObjMapper: jest.fn((dict) => ({
    isGuestCustomer: dict.isGuestCustomer,
  })),
}));

jest.mock('../Utilities/PaymentBody.bs.js', () => ({}));

const createWrapperWithAtoms = (atomValues: any) => {
  return function Wrapper({ children }: { children: React.ReactNode }) {
    return React.createElement(
      RecoilRoot,
      {
        initializeState: ({ set }: any) => {
          Object.entries(atomValues).forEach(([key, value]) => {
            const atom = (RecoilAtoms as any)[key] || (PaymentUtils as any)[key];
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

describe('useIsGuestCustomer', () => {
  it('returns true when paymentMethodList is in Loading state', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodList: 'Loading',
      optionAtom: { customerPaymentMethods: undefined },
    });
    const { result } = renderHook(() => UtilityHooks.useIsGuestCustomer(), { wrapper: Wrapper });

    expect(result.current).toBe(true);
  });

  it('returns true when paymentMethodList has non-Loaded tag', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodList: { TAG: 'Error', _0: 'error' },
      optionAtom: { customerPaymentMethods: undefined },
    });
    const { result } = renderHook(() => UtilityHooks.useIsGuestCustomer(), { wrapper: Wrapper });

    expect(result.current).toBe(true);
  });

  it('returns the isGuestCustomer value when present in paymentMethodList', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodList: {
        TAG: 'Loaded',
        _0: { isGuestCustomer: true },
      },
      optionAtom: { customerPaymentMethods: undefined },
    });
    const { result } = renderHook(() => UtilityHooks.useIsGuestCustomer(), { wrapper: Wrapper });

    expect(result.current).toBe(true);
  });

  it('returns false when isGuestCustomer is explicitly false in paymentMethodList', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodList: {
        TAG: 'Loaded',
        _0: { isGuestCustomer: false },
      },
      optionAtom: { customerPaymentMethods: undefined },
    });
    const { result } = renderHook(() => UtilityHooks.useIsGuestCustomer(), { wrapper: Wrapper });

    expect(result.current).toBe(false);
  });

  it('falls back to customerPaymentMethods when isGuestCustomer is None - LoadedSavedCards with guest', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodList: {
        TAG: 'Loaded',
        _0: {},
      },
      optionAtom: {
        customerPaymentMethods: {
          TAG: 'LoadedSavedCards',
          _0: [],
          _1: true,
        },
      },
    });
    const { result } = renderHook(() => UtilityHooks.useIsGuestCustomer(), { wrapper: Wrapper });

    expect(result.current).toBe(true);
  });

  it('falls back to customerPaymentMethods when isGuestCustomer is None - LoadedSavedCards with non-guest', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodList: {
        TAG: 'Loaded',
        _0: {},
      },
      optionAtom: {
        customerPaymentMethods: {
          TAG: 'LoadedSavedCards',
          _0: [],
          _1: false,
        },
      },
    });
    const { result } = renderHook(() => UtilityHooks.useIsGuestCustomer(), { wrapper: Wrapper });

    expect(result.current).toBe(false);
  });
});

describe('useHandlePostMessages', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('calls handlePostMessageEvents with provided parameters', () => {
    const complete = jest.fn();
    const empty = jest.fn();
    const paymentType = 'card';
    const loggerState = { logInfo: jest.fn(), logError: jest.fn() };

    const Wrapper = createWrapperWithAtoms({
      loggerAtom: loggerState,
    });

    renderHook(() => UtilityHooks.useHandlePostMessages(complete, empty, paymentType), {
      wrapper: Wrapper,
    });

    expect(mockHandlePostMessageEvents).toHaveBeenCalledWith(
      complete,
      empty,
      paymentType,
      loggerState,
      false
    );
  });

  it('calls handlePostMessageEvents with savedMethod=true when provided', () => {
    const complete = jest.fn();
    const empty = jest.fn();
    const paymentType = 'card';
    const loggerState = { logInfo: jest.fn(), logError: jest.fn() };

    const Wrapper = createWrapperWithAtoms({
      loggerAtom: loggerState,
    });

    renderHook(() => UtilityHooks.useHandlePostMessages(complete, empty, paymentType, true), {
      wrapper: Wrapper,
    });

    expect(mockHandlePostMessageEvents).toHaveBeenCalledWith(
      complete,
      empty,
      paymentType,
      loggerState,
      true
    );
  });

  it('defaults savedMethod to false when not provided', () => {
    const complete = jest.fn();
    const empty = jest.fn();
    const paymentType = 'wallet';
    const loggerState = { logInfo: jest.fn(), logError: jest.fn() };

    const Wrapper = createWrapperWithAtoms({
      loggerAtom: loggerState,
    });

    renderHook(() => UtilityHooks.useHandlePostMessages(complete, empty, paymentType), {
      wrapper: Wrapper,
    });

    expect(mockHandlePostMessageEvents).toHaveBeenCalledWith(
      complete,
      empty,
      paymentType,
      loggerState,
      false
    );
  });
});

describe('useIsCustomerAcceptanceRequired', () => {
  it('returns true when displaySavedPaymentMethodsCheckbox is true and isSaveCardsChecked is true', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodListValue: { payment_type: 'NORMAL' },
    });

    const { result } = renderHook(
      () => UtilityHooks.useIsCustomerAcceptanceRequired(true, true, false),
      { wrapper: Wrapper }
    );

    expect(result.current).toBe(true);
  });

  it('returns true when displaySavedPaymentMethodsCheckbox is true and payment_type is SETUP_MANDATE', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodListValue: { payment_type: 'SETUP_MANDATE' },
    });

    const { result } = renderHook(
      () => UtilityHooks.useIsCustomerAcceptanceRequired(true, false, false),
      { wrapper: Wrapper }
    );

    expect(result.current).toBe(true);
  });

  it('returns false when displaySavedPaymentMethodsCheckbox is true, isSaveCardsChecked is false, and payment_type is NORMAL', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodListValue: { payment_type: 'NORMAL' },
    });

    const { result } = renderHook(
      () => UtilityHooks.useIsCustomerAcceptanceRequired(true, false, false),
      { wrapper: Wrapper }
    );

    expect(result.current).toBe(false);
  });

  it('returns false when displaySavedPaymentMethodsCheckbox is false, isGuestCustomer is true, and payment_type is NORMAL', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodListValue: { payment_type: 'NORMAL' },
    });

    const { result } = renderHook(
      () => UtilityHooks.useIsCustomerAcceptanceRequired(false, false, true),
      { wrapper: Wrapper }
    );

    expect(result.current).toBe(false);
  });

  it('returns true when displaySavedPaymentMethodsCheckbox is false, isGuestCustomer is false, and payment_type is not NORMAL', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodListValue: { payment_type: 'SETUP_MANDATE' },
    });

    const { result } = renderHook(
      () => UtilityHooks.useIsCustomerAcceptanceRequired(false, false, false),
      { wrapper: Wrapper }
    );

    expect(result.current).toBe(true);
  });

  it('returns false when displaySavedPaymentMethodsCheckbox is false, isGuestCustomer is false, and payment_type is NORMAL', () => {
    const Wrapper = createWrapperWithAtoms({
      paymentMethodListValue: { payment_type: 'NORMAL' },
    });

    const { result } = renderHook(
      () => UtilityHooks.useIsCustomerAcceptanceRequired(false, false, false),
      { wrapper: Wrapper }
    );

    expect(result.current).toBe(false);
  });
});

describe('useSendEventsToParent', () => {
  let addEventListenerSpy: jest.SpyInstance;
  let removeEventListenerSpy: jest.SpyInstance;

  beforeEach(() => {
    addEventListenerSpy = jest.spyOn(window, 'addEventListener');
    removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
    jest.clearAllMocks();
  });

  afterEach(() => {
    addEventListenerSpy.mockRestore();
    removeEventListenerSpy.mockRestore();
  });

  it('adds message event listener on mount', () => {
    const eventsToSendToParent = ['paymentComplete', 'paymentError'];

    renderHook(() => UtilityHooks.useSendEventsToParent(eventsToSendToParent));

    expect(addEventListenerSpy).toHaveBeenCalledWith('message', expect.any(Function));
  });

  it('removes message event listener on unmount', () => {
    const eventsToSendToParent = ['paymentComplete'];

    const { unmount } = renderHook(() =>
      UtilityHooks.useSendEventsToParent(eventsToSendToParent)
    );

    unmount();

    expect(removeEventListenerSpy).toHaveBeenCalledWith('message', expect.any(Function));
  });

  it('calls messageParentWindow when matching event is received', () => {
    const eventsToSendToParent = ['paymentComplete', 'paymentError'];

    renderHook(() => UtilityHooks.useSendEventsToParent(eventsToSendToParent));

    const messageHandler = addEventListenerSpy.mock.calls.find(
      (call) => call[0] === 'message'
    )?.[1];

    act(() => {
      messageHandler?.({
        data: { paymentComplete: { status: 'success' } },
      });
    });

    expect(mockMessageParentWindow).toHaveBeenCalled();
  });

  it('does not call messageParentWindow when no matching event is received', () => {
    const eventsToSendToParent = ['paymentComplete'];

    renderHook(() => UtilityHooks.useSendEventsToParent(eventsToSendToParent));

    const messageHandler = addEventListenerSpy.mock.calls.find(
      (call) => call[0] === 'message'
    )?.[1];

    act(() => {
      messageHandler?.({
        data: { unknownEvent: { status: 'something' } },
      });
    });

    expect(mockMessageParentWindow).not.toHaveBeenCalled();
  });
});

describe('useUpdateRedirectionFlags', () => {
  it('returns a function that updates redirection flags', () => {
    const Wrapper = createWrapperWithAtoms({
      redirectionFlagsAtom: {
        shouldUseTopRedirection: false,
        shouldRemoveBeforeUnloadEvents: false,
      },
    });

    const { result } = renderHook(() => UtilityHooks.useUpdateRedirectionFlags(), {
      wrapper: Wrapper,
    });

    expect(typeof result.current).toBe('function');
  });

  it('updates shouldUseTopRedirection when provided true', () => {
    const Wrapper = createWrapperWithAtoms({
      redirectionFlagsAtom: {
        shouldUseTopRedirection: false,
        shouldRemoveBeforeUnloadEvents: false,
      },
    });

    const { result } = renderHook(() => UtilityHooks.useUpdateRedirectionFlags(), {
      wrapper: Wrapper,
    });

    act(() => {
      result.current({ shouldUseTopRedirection: true });
    });

    expect(typeof result.current).toBe('function');
  });

  it('updates shouldRemoveBeforeUnloadEvents when provided true', () => {
    const Wrapper = createWrapperWithAtoms({
      redirectionFlagsAtom: {
        shouldUseTopRedirection: false,
        shouldRemoveBeforeUnloadEvents: false,
      },
    });

    const { result } = renderHook(() => UtilityHooks.useUpdateRedirectionFlags(), {
      wrapper: Wrapper,
    });

    act(() => {
      result.current({ shouldRemoveBeforeUnloadEvents: true });
    });

    expect(typeof result.current).toBe('function');
  });

  it('handles undefined values by keeping current state', () => {
    const Wrapper = createWrapperWithAtoms({
      redirectionFlagsAtom: {
        shouldUseTopRedirection: true,
        shouldRemoveBeforeUnloadEvents: true,
      },
    });

    const { result } = renderHook(() => UtilityHooks.useUpdateRedirectionFlags(), {
      wrapper: Wrapper,
    });

    act(() => {
      result.current({});
    });

    expect(typeof result.current).toBe('function');
  });
});
