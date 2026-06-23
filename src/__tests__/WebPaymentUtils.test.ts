import {
  getMethod,
  getMethodType,
  getExperience,
  getPaymentExperienceType,
  getPaymentMethodName,
  isAppendingCustomerAcceptance,
  appendedCustomerAcceptance,
  getIsKlarnaSDKFlow,
  sortCustomerMethodsBasedOnPriority,
  getSupportedCardBrands,
  checkIsCardSupported,
} from '../Utilities/PaymentUtils.bs.js';

describe('WebPaymentUtils', () => {
  describe('getMethod', () => {
    it('should return card for Cards', () => {
      expect(getMethod({ TAG: 'Cards', _0: 'Credit' })).toBe('card');
    });

    it('should return wallet for Wallets', () => {
      expect(getMethod({ TAG: 'Wallets', _0: { TAG: 'Gpay', _0: 'Redirect' } })).toBe('wallet');
    });

    it('should return bank_redirect for Banks', () => {
      expect(getMethod({ TAG: 'Banks', _0: 'Sofort' })).toBe('bank_redirect');
    });

    it('should return bank_debit for BankDebit', () => {
      expect(getMethod({ TAG: 'BankDebit', _0: 'ACH' })).toBe('bank_debit');
    });

    it('should return bank_transfer for BankTransfer', () => {
      expect(getMethod({ TAG: 'BankTransfer', _0: 'ACH' })).toBe('bank_transfer');
    });

    it('should return pay_later for PayLater', () => {
      expect(getMethod({ TAG: 'PayLater', _0: { TAG: 'Klarna', _0: 'Redirect' } })).toBe('pay_later');
    });
  });

  describe('getMethodType', () => {
    it('should return card for Cards', () => {
      expect(getMethodType({ TAG: 'Cards', _0: 'Credit' })).toBe('card');
    });

    it('should return google_pay for Gpay', () => {
      expect(getMethodType({ TAG: 'Wallets', _0: { TAG: 'Gpay', _0: 'Redirect' } })).toBe('google_pay');
    });

    it('should return apple_pay for ApplePay', () => {
      expect(getMethodType({ TAG: 'Wallets', _0: { TAG: 'ApplePay', _0: 'Redirect' } })).toBe('apple_pay');
    });

    it('should return paypal for Paypal', () => {
      expect(getMethodType({ TAG: 'Wallets', _0: { TAG: 'Paypal', _0: 'Redirect' } })).toBe('paypal');
    });

    it('should return sofort for Sofort bank redirect', () => {
      expect(getMethodType({ TAG: 'Banks', _0: 'Sofort' })).toBe('sofort');
    });

    it('should return ach for ACH bank debit', () => {
      expect(getMethodType({ TAG: 'BankDebit', _0: 'ACH' })).toBe('ach');
    });

    it('should return sepa for Sepa bank transfer', () => {
      expect(getMethodType({ TAG: 'BankTransfer', _0: 'Sepa' })).toBe('sepa');
    });
  });

  describe('getExperience', () => {
    it('should return redirect_to_url for Redirect', () => {
      expect(getExperience('Redirect')).toBe('redirect_to_url');
    });

    it('should return invoke_sdk_client for InvokeSDK', () => {
      expect(getExperience('InvokeSDK')).toBe('invoke_sdk_client');
    });
  });

  describe('getPaymentExperienceType', () => {
    it('should return invoke_sdk_client for InvokeSDK', () => {
      expect(getPaymentExperienceType('InvokeSDK')).toBe('invoke_sdk_client');
    });

    it('should return redirect_to_url for RedirectToURL', () => {
      expect(getPaymentExperienceType('RedirectToURL')).toBe('redirect_to_url');
    });

    it('should return display_qr_code for QrFlow', () => {
      expect(getPaymentExperienceType('QrFlow')).toBe('display_qr_code');
    });
  });

  describe('getPaymentMethodName', () => {
    it('should remove _debit suffix for bank_debit', () => {
      expect(getPaymentMethodName('bank_debit', 'ach_debit')).toBe('ach');
    });

    it('should remove _transfer suffix for non-listed bank_transfer', () => {
      expect(getPaymentMethodName('bank_transfer', 'ach_transfer')).toBe('ach');
    });

    it('should return unchanged for other payment methods', () => {
      expect(getPaymentMethodName('card', 'credit')).toBe('credit');
    });
  });

  describe('isAppendingCustomerAcceptance', () => {
    it('should return true for NEW_MANDATE with non-guest', () => {
      expect(isAppendingCustomerAcceptance(false, 'NEW_MANDATE')).toBe(true);
    });

    it('should return true for SETUP_MANDATE with non-guest', () => {
      expect(isAppendingCustomerAcceptance(false, 'SETUP_MANDATE')).toBe(true);
    });

    it('should return false for guest customer', () => {
      expect(isAppendingCustomerAcceptance(true, 'NEW_MANDATE')).toBe(false);
    });

    it('should return false for non-mandate payment type', () => {
      expect(isAppendingCustomerAcceptance(false, 'NORMAL')).toBe(false);
    });
  });

  describe('appendedCustomerAcceptance', () => {
    it('should append customer acceptance when required', () => {
      const body = [['payment_method', 'card']];
      const result = appendedCustomerAcceptance(false, 'NEW_MANDATE', body);
      const caEntry = result.find((entry: any) => entry[0] === 'customer_acceptance');
      expect(caEntry).toBeDefined();
    });

    it('should not append when not required', () => {
      const body = [['payment_method', 'card']];
      const result = appendedCustomerAcceptance(true, 'NORMAL', body);
      const caEntry = result.find((entry: any) => entry[0] === 'customer_acceptance');
      expect(caEntry).toBeUndefined();
    });
  });

  describe('sortCustomerMethodsBasedOnPriority', () => {
    it('should sort by priority array', () => {
      const methods = [
        { paymentMethod: 'card', paymentMethodType: undefined, defaultPaymentMethodSet: false },
        { paymentMethod: 'wallet', paymentMethodType: 'paypal', defaultPaymentMethodSet: false },
      ];
      const priority = ['paypal', 'card'];
      const result = sortCustomerMethodsBasedOnPriority(methods, priority);
      expect(result[0].paymentMethodType).toBe('paypal');
    });

    it('should return original array for empty priority', () => {
      const methods = [
        { paymentMethod: 'card', defaultPaymentMethodSet: false },
      ];
      const result = sortCustomerMethodsBasedOnPriority(methods, []);
      expect(result).toEqual(methods);
    });

    it('should handle empty methods array', () => {
      expect(sortCustomerMethodsBasedOnPriority([], ['card'])).toEqual([]);
    });
  });

  describe('getSupportedCardBrands', () => {
    it('should return undefined when no card payment method', () => {
      const list = {
        payment_methods: [],
      };
      expect(getSupportedCardBrands(list)).toBeUndefined();
    });

    it('should return card brands when card payment method exists', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'card',
            payment_method_types: [
              { card_networks: [{ card_network: 'VISA' }, { card_network: 'MASTERCARD' }] },
            ],
          },
        ],
      };
      const result = getSupportedCardBrands(list);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('checkIsCardSupported', () => {
    it('should return true for valid card with supported brand', () => {
      const result = checkIsCardSupported('4111111111111111', 'Visa', ['visa', 'mastercard']);
      expect(result).toBe(true);
    });

    it('should return false for card not in supported list', () => {
      const result = checkIsCardSupported('4111111111111111', 'Visa', ['amex', 'mastercard']);
      expect(result).toBe(false);
    });

    it('should return undefined for empty card brand', () => {
      const result = checkIsCardSupported('1234', '', undefined);
      expect(result).toBe(false);
    });

    it('should return true when supportedCardBrands is undefined', () => {
      const result = checkIsCardSupported('4111111111111111', 'Visa', undefined);
      expect(result).toBe(true);
    });
  });
});
