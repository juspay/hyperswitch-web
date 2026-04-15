import { renderHook } from '@testing-library/react';
import { RecoilRoot } from 'recoil';
import * as CustomPaymentMethodsConfig from '../Hooks/CustomPaymentMethodsConfig.bs.js';
import * as RecoilAtoms from '../Utilities/RecoilAtoms.bs.js';
import * as React from 'react';

describe('useCustomPaymentMethodConfigs', () => {
  const mockConfigWithPaymentMethods = {
    paymentMethodsConfig: [
      {
        paymentMethod: 'card',
        paymentMethodTypes: [
          {
            paymentMethodType: 'credit',
            displayName: 'Credit Card',
          },
          {
            paymentMethodType: 'debit',
            displayName: 'Debit Card',
          },
        ],
      },
      {
        paymentMethod: 'wallet',
        paymentMethodTypes: [
          {
            paymentMethodType: 'paypal',
            displayName: 'PayPal',
          },
          {
            paymentMethodType: 'google_pay',
            displayName: 'Google Pay',
          },
        ],
      },
    ],
  };

  const mockConfigDebitFirst = {
    paymentMethodsConfig: [
      {
        paymentMethod: 'card',
        paymentMethodTypes: [
          {
            paymentMethodType: 'debit',
            displayName: 'Debit Card',
          },
          {
            paymentMethodType: 'credit',
            displayName: 'Credit Card',
          },
        ],
      },
    ],
  };

  const createWrapper = (config: any) => {
    return function Wrapper({ children }: { children: React.ReactNode }) {
      return React.createElement(
        RecoilRoot,
        {
          initializeState: ({ set }: any) => {
            set(RecoilAtoms.optionAtom, config);
          },
        },
        children
      );
    };
  };

  it('returns the first allowed card payment method type when searching for card', () => {
    const Wrapper = createWrapper(mockConfigWithPaymentMethods);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'debit'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toEqual({
      paymentMethodType: 'credit',
      displayName: 'Credit Card',
    });
  });

  it('returns debit when it appears first in the config', () => {
    const Wrapper = createWrapper(mockConfigDebitFirst);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'debit'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toEqual({
      paymentMethodType: 'debit',
      displayName: 'Debit Card',
    });
  });

  it('returns the matching payment method type config for non-card payment methods', () => {
    const Wrapper = createWrapper(mockConfigWithPaymentMethods);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('wallet', 'paypal'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toEqual({
      paymentMethodType: 'paypal',
      displayName: 'PayPal',
    });
  });

  it('returns undefined when payment method is not found', () => {
    const Wrapper = createWrapper(mockConfigWithPaymentMethods);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('crypto', 'bitcoin'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toBeUndefined();
  });

  it('returns undefined when payment method type is not found for non-card methods', () => {
    const Wrapper = createWrapper(mockConfigWithPaymentMethods);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('wallet', 'apple_pay'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toBeUndefined();
  });

  it('handles empty paymentMethodsConfig array', () => {
    const emptyConfig = { paymentMethodsConfig: [] };
    const Wrapper = createWrapper(emptyConfig);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'debit'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toBeUndefined();
  });

  it('handles paymentMethodsConfig with empty paymentMethodTypes', () => {
    const configWithEmptyTypes = {
      paymentMethodsConfig: [
        {
          paymentMethod: 'card',
          paymentMethodTypes: [],
        },
      ],
    };
    const Wrapper = createWrapper(configWithEmptyTypes);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'debit'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toBeUndefined();
  });

  it('filters card payment method types to only allow debit and credit', () => {
    const configWithExtraTypes = {
      paymentMethodsConfig: [
        {
          paymentMethod: 'card',
          paymentMethodTypes: [
            {
              paymentMethodType: 'prepaid',
              displayName: 'Prepaid Card',
            },
            {
              paymentMethodType: 'credit',
              displayName: 'Credit Card',
            },
          ],
        },
      ],
    };
    const Wrapper = createWrapper(configWithExtraTypes);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'credit'),
      {
        wrapper: Wrapper,
      }
    );
    expect(result.current).toEqual({
      paymentMethodType: 'credit',
      displayName: 'Credit Card',
    });
  });

  it('returns undefined for prepaid card type which is not allowed', () => {
    const configWithPrepaid = {
      paymentMethodsConfig: [
        {
          paymentMethod: 'card',
          paymentMethodTypes: [
            {
              paymentMethodType: 'prepaid',
              displayName: 'Prepaid Card',
            },
          ],
        },
      ],
    };
    const Wrapper = createWrapper(configWithPrepaid);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'prepaid'),
      {
        wrapper: Wrapper,
      }
    );
    expect(result.current).toBeUndefined();
  });

  it('recomputes when paymentMethod changes', () => {
    const Wrapper = createWrapper(mockConfigWithPaymentMethods);
    const { result, rerender } = renderHook(
      (props) => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs(props.paymentMethod, 'debit'),
      {
        wrapper: Wrapper,
        initialProps: { paymentMethod: 'card' },
      }
    );

    expect(result.current).toEqual({
      paymentMethodType: 'credit',
      displayName: 'Credit Card',
    });

    rerender({ paymentMethod: 'wallet' });

    expect(result.current).toBeUndefined();
  });

  it('recomputes when paymentMethodType changes for non-card methods', () => {
    const Wrapper = createWrapper(mockConfigWithPaymentMethods);
    const { result, rerender } = renderHook(
      (props) => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('wallet', props.paymentMethodType),
      {
        wrapper: Wrapper,
        initialProps: { paymentMethodType: 'paypal' },
      }
    );

    expect(result.current).toEqual({
      paymentMethodType: 'paypal',
      displayName: 'PayPal',
    });

    rerender({ paymentMethodType: 'google_pay' });

    expect(result.current).toEqual({
      paymentMethodType: 'google_pay',
      displayName: 'Google Pay',
    });
  });

  it('returns first matching payment method type config when multiple exist', () => {
    const configWithDuplicates = {
      paymentMethodsConfig: [
        {
          paymentMethod: 'card',
          paymentMethodTypes: [
            {
              paymentMethodType: 'credit',
              displayName: 'Credit Card 1',
            },
          ],
        },
        {
          paymentMethod: 'card',
          paymentMethodTypes: [
            {
              paymentMethodType: 'credit',
              displayName: 'Credit Card 2',
            },
          ],
        },
      ],
    };
    const Wrapper = createWrapper(configWithDuplicates);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'credit'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toEqual({
      paymentMethodType: 'credit',
      displayName: 'Credit Card 1',
    });
  });

  it('handles complex nested config structure', () => {
    const complexConfig = {
      paymentMethodsConfig: [
        {
          paymentMethod: 'card',
          paymentMethodTypes: [
            {
              paymentMethodType: 'credit',
              displayName: 'Credit Card',
              requiredFields: ['name', 'number', 'expiry', 'cvv'],
            },
            {
              paymentMethodType: 'debit',
              displayName: 'Debit Card',
              requiredFields: ['name', 'number', 'expiry', 'cvv'],
            },
          ],
        },
      ],
    };
    const Wrapper = createWrapper(complexConfig);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'credit'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toBeDefined();
    expect(result.current.paymentMethodType).toBe('credit');
    expect(result.current.displayName).toBe('Credit Card');
    expect(result.current.requiredFields).toEqual(['name', 'number', 'expiry', 'cvv']);
  });

  it('memoizes results and only recalculates when dependencies change', () => {
    let recoilSetCount = 0;
    const Wrapper = createWrapper(mockConfigWithPaymentMethods);
    
    const { result, rerender } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('card', 'debit'),
      {
        wrapper: Wrapper,
      }
    );

    const firstResult = result.current;
    
    rerender();
    
    expect(result.current).toBe(firstResult);
  });

  it('handles wallet with google_pay type', () => {
    const Wrapper = createWrapper(mockConfigWithPaymentMethods);
    const { result } = renderHook(
      () => CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs('wallet', 'google_pay'),
      {
        wrapper: Wrapper,
      }
    );

    expect(result.current).toEqual({
      paymentMethodType: 'google_pay',
      displayName: 'Google Pay',
    });
  });
});
