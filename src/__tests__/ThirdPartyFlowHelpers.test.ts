import { renderHook } from '@testing-library/react';
import { RecoilRoot } from 'recoil';
import * as React from 'react';
import * as ThirdPartyFlowHelpers from '../Hooks/ThirdPartyFlowHelpers.bs.js';
import * as RecoilAtoms from '../Utilities/RecoilAtoms.bs.js';

jest.mock('../Utilities/Utils.bs.js', () => ({
  getDictFromJson: jest.fn((obj) => (typeof obj === 'object' && obj !== null ? obj : {})),
  getDecodedBoolFromJson: jest.fn((json, callback, defaultValue) => {
    if (typeof json === 'object' && json !== null) {
      const result = callback(json);
      return result !== undefined ? result : defaultValue;
    }
    return defaultValue;
  }),
}));

jest.mock('../Types/SessionsType.bs.js', () => ({
  itemToObjMapper: jest.fn((dict, returnType) => {
    const token = dict.session_token || [];
    return {
      paymentId: dict.payment_id || '',
      clientSecret: dict.client_secret || '',
      sessionsToken: {
        TAG: returnType === 'ApplePayObject' ? 'ApplePayToken' : 'GooglePayThirdPartyToken',
        _0: token,
      },
    };
  }),
  getPaymentSessionObj: jest.fn((sessionsToken, walletType) => {
    const tokens = sessionsToken._0 || [];
    const token = tokens.find((t: any) => t && t.wallet_name === walletType.toLowerCase().replace('applepay', 'apple_pay').replace('gpay', 'google_pay'));
    if (token) {
      return {
        TAG: sessionsToken.TAG === 'ApplePayToken' ? 'ApplePayTokenOptional' : 'GooglePayThirdPartyTokenOptional',
        _0: token,
      };
    }
    return {
      TAG: sessionsToken.TAG === 'ApplePayToken' ? 'ApplePayTokenOptional' : 'GooglePayThirdPartyTokenOptional',
      _0: undefined,
    };
  }),
}));

const createWrapper = (sessionsValue: any) => {
  return function Wrapper({ children }: { children: React.ReactNode }) {
    return React.createElement(
      RecoilRoot,
      {
        initializeState: ({ set }: any) => {
          set(RecoilAtoms.sessions, sessionsValue);
        },
      },
      children
    );
  };
};

describe('useIsApplePayDelayedSessionFlow', () => {
  it('returns false when sessions is in Loading state', () => {
    const Wrapper = createWrapper('Loading');
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsApplePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });

  it('returns false when sessions object has no ApplePayObject', () => {
    const sessionsValue = {
      TAG: 'Loaded',
      _0: {},
    };
    const Wrapper = createWrapper(sessionsValue);
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsApplePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });

  it('returns false when ApplePay session token has no delayed_session_token', () => {
    const sessionsValue = {
      TAG: 'Loaded',
      _0: {
        session_token: [
          {
            wallet_name: 'apple_pay',
            someOtherField: 'value',
          },
        ],
      },
    };
    const Wrapper = createWrapper(sessionsValue);
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsApplePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });

  it('returns true when ApplePay session token has delayed_session_token set to true', () => {
    const sessionsValue = {
      TAG: 'Loaded',
      _0: {
        session_token: [
          {
            wallet_name: 'apple_pay',
            delayed_session_token: true,
          },
        ],
      },
    };
    const Wrapper = createWrapper(sessionsValue);
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsApplePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(true);
  });

  it('returns false when ApplePay session token has delayed_session_token set to false', () => {
    const sessionsValue = {
      TAG: 'Loaded',
      _0: {
        session_token: [
          {
            wallet_name: 'apple_pay',
            delayed_session_token: false,
          },
        ],
      },
    };
    const Wrapper = createWrapper(sessionsValue);
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsApplePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });

  it('returns false for non-Loaded session types', () => {
    const Wrapper = createWrapper('NotLoaded');
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsApplePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });
});

describe('useIsGooglePayDelayedSessionFlow', () => {
  it('returns false when sessions is in Loading state', () => {
    const Wrapper = createWrapper('Loading');
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsGooglePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });

  it('returns false when sessions object has no GooglePayThirdPartyObject', () => {
    const sessionsValue = {
      TAG: 'Loaded',
      _0: {},
    };
    const Wrapper = createWrapper(sessionsValue);
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsGooglePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });

  it('returns false when GooglePay session token has no delayed_session_token', () => {
    const sessionsValue = {
      TAG: 'Loaded',
      _0: {
        session_token: [
          {
            wallet_name: 'google_pay',
            someOtherField: 'value',
          },
        ],
      },
    };
    const Wrapper = createWrapper(sessionsValue);
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsGooglePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });

  it('returns true when GooglePay session token has delayed_session_token set to true', () => {
    const sessionsValue = {
      TAG: 'Loaded',
      _0: {
        session_token: [
          {
            wallet_name: 'google_pay',
            delayed_session_token: true,
          },
        ],
      },
    };
    const Wrapper = createWrapper(sessionsValue);
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsGooglePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(true);
  });

  it('returns false when GooglePay session token has delayed_session_token set to false', () => {
    const sessionsValue = {
      TAG: 'Loaded',
      _0: {
        session_token: [
          {
            wallet_name: 'google_pay',
            delayed_session_token: false,
          },
        ],
      },
    };
    const Wrapper = createWrapper(sessionsValue);
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsGooglePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });

  it('returns false for non-Loaded session types', () => {
    const Wrapper = createWrapper('NotLoaded');
    const { result } = renderHook(() => ThirdPartyFlowHelpers.useIsGooglePayDelayedSessionFlow(), {
      wrapper: Wrapper,
    });

    expect(result.current).toBe(false);
  });
});
