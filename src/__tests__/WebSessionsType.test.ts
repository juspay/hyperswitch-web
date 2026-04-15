import {
  defaultToken,
  getWallet,
  getSessionsToken,
  getSessionsTokenJson,
  itemToObjMapper,
  getWalletFromTokenType,
  getPaymentSessionObj,
} from '../Types/SessionsType.bs.js';

describe('SessionsType', () => {
  describe('defaultToken', () => {
    it('should have correct default values', () => {
      expect(defaultToken.walletName).toBe('NONE');
      expect(defaultToken.token).toBe('');
      expect(defaultToken.sessionId).toBe('');
      expect(defaultToken.allowed_payment_methods).toEqual([]);
      expect(defaultToken.transaction_info).toEqual({});
      expect(defaultToken.merchant_info).toEqual({});
      expect(defaultToken.shippingAddressRequired).toBe(false);
      expect(defaultToken.emailRequired).toBe(false);
      expect(defaultToken.shippingAddressParameters).toEqual({});
      expect(defaultToken.orderDetails).toEqual({});
      expect(defaultToken.connector).toBe('');
      expect(defaultToken.clientId).toBe('');
      expect(defaultToken.clientName).toBe('');
      expect(defaultToken.clientProfileId).toBe('');
      expect(defaultToken.email_address).toBe('');
      expect(defaultToken.transaction_amount).toBe('');
      expect(defaultToken.transaction_currency_code).toBe('');
    });
  });

  describe('getWallet', () => {
    it('should return "ApplePay" for "apple_pay"', () => {
      expect(getWallet('apple_pay')).toBe('ApplePay');
    });

    it('should return "ClickToPay" for "click_to_pay"', () => {
      expect(getWallet('click_to_pay')).toBe('ClickToPay');
    });

    it('should return "Gpay" for "google_pay"', () => {
      expect(getWallet('google_pay')).toBe('Gpay');
    });

    it('should return "Klarna" for "klarna"', () => {
      expect(getWallet('klarna')).toBe('Klarna');
    });

    it('should return "Paypal" for "paypal"', () => {
      expect(getWallet('paypal')).toBe('Paypal');
    });

    it('should return "Paze" for "paze"', () => {
      expect(getWallet('paze')).toBe('Paze');
    });

    it('should return "SamsungPay" for "samsung_pay"', () => {
      expect(getWallet('samsung_pay')).toBe('SamsungPay');
    });

    it('should return "NONE" for unknown wallet name', () => {
      expect(getWallet('unknown')).toBe('NONE');
    });

    it('should return "NONE" for empty string', () => {
      expect(getWallet('')).toBe('NONE');
    });
  });

  describe('getSessionsToken', () => {
    it('should parse session tokens from dict', () => {
      const dict = {
        session_token: [
          {
            wallet_name: 'google_pay',
            session_token: 'token123',
            session_id: 'session456',
            allowed_payment_methods: ['CARD'],
            transaction_info: { amount: '100' },
            merchant_info: { name: 'Test' },
            shipping_address_required: true,
            email_required: false,
            shipping_address_parameters: { allowedCountries: ['US'] },
            order_details: { orderId: '123' },
            connector: 'stripe',
            client_id: 'client123',
            client_name: 'Test Client',
            client_profile_id: 'profile123',
            email_address: 'test@example.com',
            transaction_amount: '100.00',
            transaction_currency_code: 'USD',
          },
        ],
      };
      const result = getSessionsToken(dict, 'session_token');
      expect(result).toHaveLength(1);
      expect(result[0].walletName).toBe('Gpay');
      expect(result[0].token).toBe('token123');
      expect(result[0].sessionId).toBe('session456');
      expect(result[0].shippingAddressRequired).toBe(true);
      expect(result[0].emailRequired).toBe(false);
      expect(result[0].connector).toBe('stripe');
    });

    it('should return defaultToken array when key not found', () => {
      const dict = {};
      const result = getSessionsToken(dict, 'nonexistent');
      expect(result).toEqual([defaultToken]);
    });

    it('should return defaultToken array when value is null', () => {
      const dict = { session_token: null };
      const result = getSessionsToken(dict, 'session_token');
      expect(result).toEqual([defaultToken]);
    });

    it('should handle empty array', () => {
      const dict = { session_token: [] };
      const result = getSessionsToken(dict, 'session_token');
      expect(result).toEqual([]);
    });

    it('should handle multiple session tokens', () => {
      const dict = {
        session_token: [
          { wallet_name: 'google_pay', session_token: 'gpay_token' },
          { wallet_name: 'apple_pay', session_token: 'apple_token' },
        ],
      };
      const result = getSessionsToken(dict, 'session_token');
      expect(result).toHaveLength(2);
      expect(result[0].walletName).toBe('Gpay');
      expect(result[1].walletName).toBe('ApplePay');
    });
  });

  describe('getSessionsTokenJson', () => {
    it('should return JSON array from dict', () => {
      const dict = {
        session_token: [{ wallet_name: 'google_pay' }, { wallet_name: 'apple_pay' }],
      };
      const result = getSessionsTokenJson(dict, 'session_token');
      expect(result).toHaveLength(2);
    });

    it('should return empty array when key not found', () => {
      const dict = {};
      const result = getSessionsTokenJson(dict, 'nonexistent');
      expect(result).toEqual([]);
    });

    it('should return empty array when value is null', () => {
      const dict = { session_token: null };
      const result = getSessionsTokenJson(dict, 'session_token');
      expect(result).toEqual([]);
    });
  });

  describe('itemToObjMapper', () => {
    it('should map to ApplePayObject', () => {
      const dict = {
        payment_id: 'pay_123',
        client_secret: 'secret_456',
        session_token: [{ wallet_name: 'apple_pay' }],
      };
      const result = itemToObjMapper(dict, 'ApplePayObject');
      expect(result.paymentId).toBe('pay_123');
      expect(result.clientSecret).toBe('secret_456');
      expect(result.sessionsToken.TAG).toBe('ApplePayToken');
    });

    it('should map to GooglePayThirdPartyObject', () => {
      const dict = {
        payment_id: 'pay_123',
        client_secret: 'secret_456',
        session_token: [{ wallet_name: 'google_pay' }],
      };
      const result = itemToObjMapper(dict, 'GooglePayThirdPartyObject');
      expect(result.paymentId).toBe('pay_123');
      expect(result.sessionsToken.TAG).toBe('GooglePayThirdPartyToken');
    });

    it('should map to SamsungPayObject', () => {
      const dict = {
        payment_id: 'pay_123',
        client_secret: 'secret_456',
        session_token: [{ wallet_name: 'samsung_pay' }],
      };
      const result = itemToObjMapper(dict, 'SamsungPayObject');
      expect(result.sessionsToken.TAG).toBe('SamsungPayToken');
    });

    it('should map to PazeObject', () => {
      const dict = {
        payment_id: 'pay_123',
        client_secret: 'secret_456',
        session_token: [{ wallet_name: 'paze' }],
      };
      const result = itemToObjMapper(dict, 'PazeObject');
      expect(result.sessionsToken.TAG).toBe('PazeToken');
    });

    it('should map to ClickToPayObject', () => {
      const dict = {
        payment_id: 'pay_123',
        client_secret: 'secret_456',
        session_token: [{ wallet_name: 'click_to_pay' }],
      };
      const result = itemToObjMapper(dict, 'ClickToPayObject');
      expect(result.sessionsToken.TAG).toBe('ClickToPayToken');
    });

    it('should map to Others', () => {
      const dict = {
        payment_id: 'pay_123',
        client_secret: 'secret_456',
        session_token: [{ wallet_name: 'klarna' }],
      };
      const result = itemToObjMapper(dict, 'Others');
      expect(result.sessionsToken.TAG).toBe('OtherToken');
    });

    it('should handle empty dict with defaults', () => {
      const result = itemToObjMapper({}, 'ApplePayObject');
      expect(result.paymentId).toBe('');
      expect(result.clientSecret).toBe('');
    });
  });

  describe('getWalletFromTokenType', () => {
    it('should find wallet in token array', () => {
      const arr = [
        { wallet_name: 'google_pay' },
        { wallet_name: 'apple_pay' },
        { wallet_name: 'samsung_pay' },
      ];
      const result = getWalletFromTokenType(arr, 'Gpay');
      expect(result).toBeDefined();
    });

    it('should return undefined when wallet not found', () => {
      const arr = [{ wallet_name: 'google_pay' }];
      const result = getWalletFromTokenType(arr, 'ApplePay');
      expect(result).toBeUndefined();
    });

    it('should handle empty array', () => {
      const result = getWalletFromTokenType([], 'Gpay');
      expect(result).toBeUndefined();
    });
  });

  describe('getPaymentSessionObj', () => {
    it('should return ApplePayTokenOptional for ApplePayToken', () => {
      const tokenType = { TAG: 'ApplePayToken', _0: [{ wallet_name: 'apple_pay' }] };
      const result = getPaymentSessionObj(tokenType, 'ApplePay');
      expect(result.TAG).toBe('ApplePayTokenOptional');
    });

    it('should return GooglePayThirdPartyTokenOptional for GooglePayThirdPartyToken', () => {
      const tokenType = { TAG: 'GooglePayThirdPartyToken', _0: [{ wallet_name: 'google_pay' }] };
      const result = getPaymentSessionObj(tokenType, 'Gpay');
      expect(result.TAG).toBe('GooglePayThirdPartyTokenOptional');
    });

    it('should return PazeTokenOptional for PazeToken', () => {
      const tokenType = { TAG: 'PazeToken', _0: [{ wallet_name: 'paze' }] };
      const result = getPaymentSessionObj(tokenType, 'Paze');
      expect(result.TAG).toBe('PazeTokenOptional');
    });

    it('should return SamsungPayTokenOptional for SamsungPayToken', () => {
      const tokenType = { TAG: 'SamsungPayToken', _0: [{ wallet_name: 'samsung_pay' }] };
      const result = getPaymentSessionObj(tokenType, 'SamsungPay');
      expect(result.TAG).toBe('SamsungPayTokenOptional');
    });

    it('should return ClickToPayTokenOptional for ClickToPayToken', () => {
      const tokenType = { TAG: 'ClickToPayToken', _0: [{ wallet_name: 'click_to_pay' }] };
      const result = getPaymentSessionObj(tokenType, 'ClickToPay');
      expect(result.TAG).toBe('ClickToPayTokenOptional');
    });

    it('should return OtherTokenOptional for OtherToken', () => {
      const tokenType = {
        TAG: 'OtherToken',
        _0: [{ walletName: 'Klarna', token: 'token123' }],
      };
      const result = getPaymentSessionObj(tokenType, 'Klarna');
      expect(result.TAG).toBe('OtherTokenOptional');
    });

    it('should return undefined _0 when wallet not found in OtherToken', () => {
      const tokenType = {
        TAG: 'OtherToken',
        _0: [{ walletName: 'Klarna', token: 'token123' }],
      };
      const result = getPaymentSessionObj(tokenType, 'Paypal');
      expect(result._0).toBeUndefined();
    });
  });
});
