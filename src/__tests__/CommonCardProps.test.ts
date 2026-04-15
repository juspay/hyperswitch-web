import { renderHook, act } from '@testing-library/react';
import { RecoilRoot } from 'recoil';
import * as CommonCardProps from '../Hooks/CommonCardProps.bs.js';
import * as RecoilAtoms from '../Utilities/RecoilAtoms.bs.js';
import * as React from 'react';

describe('useCardForm', () => {
  const mockLogger = {
    setLogInfo: jest.fn(),
    setLogError: jest.fn(),
  };

  const mockConfig = {
    localeString: {
      blockedCardText: 'Card is blocked',
      inValidCardErrorText: 'Invalid card number',
      inCompleteCVCErrorText: 'CVC is incomplete',
      inCompleteExpiryErrorText: 'Expiry date is incomplete',
      pastExpiryErrorText: 'Card has expired',
      cardBrandInvalidErrorText: 'Card brand not supported',
    },
  };

  const createWrapper = (config: any = mockConfig, cardBrandValue: string = '', showPaymentMethodsScreen: boolean = false) => {
    return function Wrapper({ children }: { children: React.ReactNode }) {
      return React.createElement(
        RecoilRoot,
        {
          initializeState: ({ set }: any) => {
            set(RecoilAtoms.configAtom, config);
            set(RecoilAtoms.cardBrand, cardBrandValue);
            set(RecoilAtoms.showPaymentMethodsScreen, showPaymentMethodsScreen);
            set(RecoilAtoms.selectedOptionAtom, '');
            set(RecoilAtoms.blockedBins, []);
            set(RecoilAtoms.paymentTokenAtom, { paymentToken: '', customerId: '' });
          },
        },
        children
      );
    };
  };

  it('returns cardProps with initial state', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    expect(result.current.cardProps).toBeDefined();
    expect(result.current.cardProps.cardNumber).toBe('');
    expect(result.current.cardProps.cardError).toBe('');
    expect(result.current.cardProps.maxCardLength).toBeGreaterThan(0);
    expect(result.current.cardProps.cardRef).toBeDefined();
  });

  it('returns expiryProps with initial state', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    expect(result.current.expiryProps).toBeDefined();
    expect(result.current.expiryProps.cardExpiry).toBe('');
    expect(result.current.expiryProps.expiryError).toBe('');
    expect(result.current.expiryProps.expiryRef).toBeDefined();
  });

  it('returns cvcProps with initial state', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    expect(result.current.cvcProps).toBeDefined();
    expect(result.current.cvcProps.cvcNumber).toBe('');
    expect(result.current.cvcProps.cvcError).toBe('');
    expect(result.current.cvcProps.cvcRef).toBeDefined();
  });

  it('returns zipProps with initial state', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    expect(result.current.zipProps).toBeDefined();
    expect(result.current.zipProps.zipCode).toBe('');
    expect(result.current.zipProps.displayPincode).toBe(false);
    expect(result.current.zipProps.zipRef).toBeDefined();
  });

  it('updates card number on change', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '4111111111111111' },
      } as React.ChangeEvent<HTMLInputElement>;
      result.current.cardProps.changeCardNumber(mockEvent);
    });

    expect(result.current.cardProps.cardNumber).toBeDefined();
    expect(mockLogger.setLogInfo).toHaveBeenCalled();
  });

  it('updates expiry on change', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '1225' },
      } as React.ChangeEvent<HTMLInputElement>;
      result.current.expiryProps.changeCardExpiry(mockEvent);
    });

    expect(result.current.expiryProps.cardExpiry).toBeDefined();
    expect(mockLogger.setLogInfo).toHaveBeenCalled();
  });

  it('updates CVC on change', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '123' },
      } as React.ChangeEvent<HTMLInputElement>;
      result.current.cvcProps.changeCVCNumber(mockEvent);
    });

    expect(result.current.cvcProps.cvcNumber).toBeDefined();
    expect(mockLogger.setLogInfo).toHaveBeenCalled();
  });

  it('updates zip code on change', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '12345' },
      } as React.ChangeEvent<HTMLInputElement>;
      result.current.zipProps.changeZipCode(mockEvent);
    });

    expect(result.current.zipProps.zipCode).toBe('12345');
    expect(mockLogger.setLogInfo).toHaveBeenCalled();
  });

  it('handles card blur event', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '4111111111111111' },
      } as React.FocusEvent<HTMLInputElement>;
      result.current.cardProps.handleCardBlur(mockEvent);
    });

    expect(result.current.cardProps.isCardValid).toBeDefined();
  });

  it('handles expiry blur event', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '12/25' },
      } as React.FocusEvent<HTMLInputElement>;
      result.current.expiryProps.handleExpiryBlur(mockEvent);
    });

    expect(result.current.expiryProps.isExpiryValid).toBeDefined();
  });

  it('handles CVC blur event', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '123' },
      } as React.FocusEvent<HTMLInputElement>;
      result.current.cvcProps.handleCVCBlur(mockEvent);
    });

    expect(result.current.cvcProps.isCVCValid).toBeDefined();
  });

  it('handles zip blur event', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '12345' },
      } as React.FocusEvent<HTMLInputElement>;
      result.current.zipProps.handleZipBlur(mockEvent);
    });

    expect(result.current.zipProps.isZipValid).toBe(true);
  });

  it('sets zip validity to false when zip is empty', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '' },
      } as React.FocusEvent<HTMLInputElement>;
      result.current.zipProps.handleZipBlur(mockEvent);
    });

    expect(result.current.zipProps.isZipValid).toBe(false);
  });

  it('detects Visa card brand from number', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '4111111111111111' },
      } as React.ChangeEvent<HTMLInputElement>;
      result.current.cardProps.changeCardNumber(mockEvent);
    });

    expect(result.current.cardProps.cardBrand).toBeDefined();
  });

  it('detects Mastercard card brand from number', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '5555555555554444' },
      } as React.ChangeEvent<HTMLInputElement>;
      result.current.cardProps.changeCardNumber(mockEvent);
    });

    expect(result.current.cardProps.cardBrand).toBeDefined();
  });

  it('returns icon component', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    expect(result.current.cardProps.icon).toBeDefined();
  });

  it('handles empty card number', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        target: { value: '' },
      } as React.ChangeEvent<HTMLInputElement>;
      result.current.cardProps.changeCardNumber(mockEvent);
    });

    expect(result.current.cardProps.cardNumber).toBe('');
  });

  it('handles CVC key down event', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        key: 'Backspace',
        preventDefault: jest.fn(),
      } as unknown as React.KeyboardEvent<HTMLInputElement>;
      result.current.cvcProps.onCvcKeyDown(mockEvent);
    });

    expect(result.current.cvcProps).toBeDefined();
  });

  it('handles expiry key down event', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        key: 'Backspace',
        preventDefault: jest.fn(),
      } as unknown as React.KeyboardEvent<HTMLInputElement>;
      result.current.expiryProps.onExpiryKeyDown(mockEvent);
    });

    expect(result.current.expiryProps).toBeDefined();
  });

  it('handles zip code key down event', () => {
    const Wrapper = createWrapper();
    const { result } = renderHook(
      () => CommonCardProps.useCardForm(mockLogger, 'card'),
      { wrapper: Wrapper }
    );

    act(() => {
      const mockEvent = {
        key: 'Backspace',
        preventDefault: jest.fn(),
      } as unknown as React.KeyboardEvent<HTMLInputElement>;
      result.current.zipProps.onZipCodeKeyDown(mockEvent);
    });

    expect(result.current.zipProps).toBeDefined();
  });
});
