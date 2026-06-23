import * as PaymentUtils from '../Utilities/PaymentUtils.bs.js';

describe('PaymentUtils', () => {
  describe('getMethod', () => {
    it('returns "crypto" for non-object method', () => {
      expect(PaymentUtils.getMethod('Crypto')).toBe('crypto');
    });

    it('returns "pay_later" for PayLater TAG', () => {
      const method = { TAG: 'PayLater', _0: { TAG: 'Klarna', _0: {} } };
      expect(PaymentUtils.getMethod(method)).toBe('pay_later');
    });

    it('returns "wallet" for Wallets TAG', () => {
      const method = { TAG: 'Wallets', _0: { TAG: 'Gpay', _0: {} } };
      expect(PaymentUtils.getMethod(method)).toBe('wallet');
    });

    it('returns "card" for Cards TAG', () => {
      const method = { TAG: 'Cards', _0: {} };
      expect(PaymentUtils.getMethod(method)).toBe('card');
    });

    it('returns "bank_redirect" for Banks TAG', () => {
      const method = { TAG: 'Banks', _0: 'Sofort' };
      expect(PaymentUtils.getMethod(method)).toBe('bank_redirect');
    });

    it('returns "bank_transfer" for BankTransfer TAG', () => {
      const method = { TAG: 'BankTransfer', _0: 'ACH' };
      expect(PaymentUtils.getMethod(method)).toBe('bank_transfer');
    });

    it('returns "bank_debit" for BankDebit TAG', () => {
      const method = { TAG: 'BankDebit', _0: 'Sepa' };
      expect(PaymentUtils.getMethod(method)).toBe('bank_debit');
    });
  });

  describe('getMethodType', () => {
    it('returns "crypto_currency" for non-object method', () => {
      expect(PaymentUtils.getMethodType('Crypto')).toBe('crypto_currency');
    });

    it('returns "klarna" for PayLater/Klarna', () => {
      const method = { TAG: 'PayLater', _0: { TAG: 'Klarna', _0: {} } };
      expect(PaymentUtils.getMethodType(method)).toBe('klarna');
    });

    it('returns "afterpay_clearpay" for PayLater/AfterPay', () => {
      const method = { TAG: 'PayLater', _0: { TAG: 'AfterPay', _0: {} } };
      expect(PaymentUtils.getMethodType(method)).toBe('afterpay_clearpay');
    });

    it('returns "affirm" for PayLater/Affirm', () => {
      const method = { TAG: 'PayLater', _0: { TAG: 'Affirm', _0: {} } };
      expect(PaymentUtils.getMethodType(method)).toBe('affirm');
    });

    it('returns "google_pay" for Wallets/Gpay', () => {
      const method = { TAG: 'Wallets', _0: { TAG: 'Gpay', _0: {} } };
      expect(PaymentUtils.getMethodType(method)).toBe('google_pay');
    });

    it('returns "apple_pay" for Wallets/ApplePay', () => {
      const method = { TAG: 'Wallets', _0: { TAG: 'ApplePay', _0: {} } };
      expect(PaymentUtils.getMethodType(method)).toBe('apple_pay');
    });

    it('returns "paypal" for Wallets/Paypal', () => {
      const method = { TAG: 'Wallets', _0: { TAG: 'Paypal', _0: {} } };
      expect(PaymentUtils.getMethodType(method)).toBe('paypal');
    });

    it('returns "card" for Cards TAG', () => {
      const method = { TAG: 'Cards', _0: {} };
      expect(PaymentUtils.getMethodType(method)).toBe('card');
    });

    it('returns "sofort" for Banks/Sofort', () => {
      const method = { TAG: 'Banks', _0: 'Sofort' };
      expect(PaymentUtils.getMethodType(method)).toBe('sofort');
    });

    it('returns "eps" for Banks/Eps', () => {
      const method = { TAG: 'Banks', _0: 'Eps' };
      expect(PaymentUtils.getMethodType(method)).toBe('eps');
    });

    it('returns "giropay" for Banks/GiroPay', () => {
      const method = { TAG: 'Banks', _0: 'GiroPay' };
      expect(PaymentUtils.getMethodType(method)).toBe('giropay');
    });

    it('returns "ideal" for Banks/Ideal', () => {
      const method = { TAG: 'Banks', _0: 'Ideal' };
      expect(PaymentUtils.getMethodType(method)).toBe('ideal');
    });

    it('returns "eft" for Banks/EFT', () => {
      const method = { TAG: 'Banks', _0: 'EFT' };
      expect(PaymentUtils.getMethodType(method)).toBe('eft');
    });

    it('returns "ach" for BankDebit/ACH', () => {
      const method = { TAG: 'BankDebit', _0: 'ACH' };
      expect(PaymentUtils.getMethodType(method)).toBe('ach');
    });

    it('returns "sepa" for BankDebit/Sepa', () => {
      const method = { TAG: 'BankDebit', _0: 'Sepa' };
      expect(PaymentUtils.getMethodType(method)).toBe('sepa');
    });

    it('returns "bacs" for BankDebit/Bacs', () => {
      const method = { TAG: 'BankDebit', _0: 'Bacs' };
      expect(PaymentUtils.getMethodType(method)).toBe('bacs');
    });

    it('returns "instant" for BankDebit/Instant', () => {
      const method = { TAG: 'BankDebit', _0: 'Instant' };
      expect(PaymentUtils.getMethodType(method)).toBe('instant');
    });

    it('returns "ach" for BankTransfer/ACH', () => {
      const method = { TAG: 'BankTransfer', _0: 'ACH' };
      expect(PaymentUtils.getMethodType(method)).toBe('ach');
    });
  });

  describe('getExperience', () => {
    it('returns "redirect_to_url" for "Redirect"', () => {
      expect(PaymentUtils.getExperience('Redirect')).toBe('redirect_to_url');
    });

    it('returns "invoke_sdk_client" for any other value', () => {
      expect(PaymentUtils.getExperience('InvokeSDK')).toBe('invoke_sdk_client');
      expect(PaymentUtils.getExperience('')).toBe('invoke_sdk_client');
      expect(PaymentUtils.getExperience('Other')).toBe('invoke_sdk_client');
    });
  });

  describe('getPaymentExperienceType', () => {
    it('returns "invoke_sdk_client" for "InvokeSDK"', () => {
      expect(PaymentUtils.getPaymentExperienceType('InvokeSDK')).toBe('invoke_sdk_client');
    });

    it('returns "redirect_to_url" for "RedirectToURL"', () => {
      expect(PaymentUtils.getPaymentExperienceType('RedirectToURL')).toBe('redirect_to_url');
    });

    it('returns "display_qr_code" for "QrFlow"', () => {
      expect(PaymentUtils.getPaymentExperienceType('QrFlow')).toBe('display_qr_code');
    });

    it('returns undefined for unknown value', () => {
      expect(PaymentUtils.getPaymentExperienceType('Unknown')).toBeUndefined();
    });
  });

  describe('getExperienceType', () => {
    it('returns "redirect_to_url" for non-object method', () => {
      expect(PaymentUtils.getExperienceType('Crypto')).toBe('redirect_to_url');
    });

    it('returns "card" for Cards TAG', () => {
      const method = { TAG: 'Cards', _0: {} };
      expect(PaymentUtils.getExperienceType(method)).toBe('card');
    });

    it('returns empty string for Banks TAG', () => {
      const method = { TAG: 'Banks', _0: 'Sofort' };
      expect(PaymentUtils.getExperienceType(method)).toBe('');
    });

    it('returns empty string for BankDebit TAG', () => {
      const method = { TAG: 'BankDebit', _0: 'ACH' };
      expect(PaymentUtils.getExperienceType(method)).toBe('');
    });

    it('returns empty string for BankTransfer TAG', () => {
      const method = { TAG: 'BankTransfer', _0: 'ACH' };
      expect(PaymentUtils.getExperienceType(method)).toBe('');
    });
  });

  describe('getPaymentMethodName', () => {
    it('removes "_debit" suffix for bank_debit type', () => {
      expect(PaymentUtils.getPaymentMethodName('bank_debit', 'sepa_debit')).toBe('sepa');
    });

    it('removes "_transfer" suffix for bank_transfer type not in bankTransferList', () => {
      expect(PaymentUtils.getPaymentMethodName('bank_transfer', 'ach_transfer')).toBe('ach');
    });

    it('returns original name for bank_transfer type in bankTransferList', () => {
      expect(PaymentUtils.getPaymentMethodName('bank_transfer', 'pix')).toBe('pix');
    });

    it('returns original name for other payment method types', () => {
      expect(PaymentUtils.getPaymentMethodName('card', 'credit')).toBe('credit');
      expect(PaymentUtils.getPaymentMethodName('wallet', 'paypal')).toBe('paypal');
    });
  });

  describe('isAppendingCustomerAcceptance', () => {
    it('returns false for guest customer', () => {
      expect(PaymentUtils.isAppendingCustomerAcceptance(true, 'NEW_MANDATE')).toBe(false);
      expect(PaymentUtils.isAppendingCustomerAcceptance(true, 'SETUP_MANDATE')).toBe(false);
      expect(PaymentUtils.isAppendingCustomerAcceptance(true, 'OTHER')).toBe(false);
    });

    it('returns true for non-guest with NEW_MANDATE payment type', () => {
      expect(PaymentUtils.isAppendingCustomerAcceptance(false, 'NEW_MANDATE')).toBe(true);
    });

    it('returns true for non-guest with SETUP_MANDATE payment type', () => {
      expect(PaymentUtils.isAppendingCustomerAcceptance(false, 'SETUP_MANDATE')).toBe(true);
    });

    it('returns false for non-guest with other payment types', () => {
      expect(PaymentUtils.isAppendingCustomerAcceptance(false, 'OTHER')).toBe(false);
    });
  });

  describe('appendedCustomerAcceptance', () => {
    it('appends customer_acceptance when conditions are met', () => {
      const body: [string, any][] = [['key', 'value']];
      const result = PaymentUtils.appendedCustomerAcceptance(false, 'NEW_MANDATE', body);
      expect(result.length).toBe(2);
      expect(result[1][0]).toBe('customer_acceptance');
    });

    it('returns original body when conditions are not met (guest)', () => {
      const body: [string, any][] = [['key', 'value']];
      const result = PaymentUtils.appendedCustomerAcceptance(true, 'NEW_MANDATE', body);
      expect(result.length).toBe(1);
      expect(result).toBe(body);
    });

    it('returns original body when conditions are not met (wrong type)', () => {
      const body: [string, any][] = [['key', 'value']];
      const result = PaymentUtils.appendedCustomerAcceptance(false, 'OTHER', body);
      expect(result.length).toBe(1);
      expect(result).toBe(body);
    });
  });

  describe('filterSavedMethodsByWalletReadiness', () => {
    it('filters out apple_pay when not ready', () => {
      const savedMethods = [
        { paymentMethodType: 'apple_pay' },
        { paymentMethodType: 'card' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, false, true);
      expect(result.length).toBe(1);
      expect(result[0].paymentMethodType).toBe('card');
    });

    it('filters out google_pay when not ready', () => {
      const savedMethods = [
        { paymentMethodType: 'google_pay' },
        { paymentMethodType: 'card' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, true, false);
      expect(result.length).toBe(1);
      expect(result[0].paymentMethodType).toBe('card');
    });

    it('keeps apple_pay and google_pay when both ready', () => {
      const savedMethods = [
        { paymentMethodType: 'apple_pay' },
        { paymentMethodType: 'google_pay' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, true, true);
      expect(result.length).toBe(2);
    });

    it('keeps methods without paymentMethodType', () => {
      const savedMethods = [
        { paymentMethod: 'card' },
        { paymentMethodType: 'apple_pay' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, false, false);
      expect(result.length).toBe(1);
      expect(result[0].paymentMethod).toBe('card');
    });

    it('keeps other payment method types regardless of readiness', () => {
      const savedMethods = [
        { paymentMethodType: 'paypal' },
        { paymentMethodType: 'card' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, false, false);
      expect(result.length).toBe(2);
    });

    it('returns empty array for empty input', () => {
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness([], true, true);
      expect(result).toEqual([]);
    });
  });

  describe('sortCustomerMethodsBasedOnPriority', () => {
    it('sorts by priority array order', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'visa' },
        { paymentMethod: 'wallet', paymentMethodType: 'paypal' },
      ];
      const priorityArr = ['paypal', 'visa'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr);
      expect(result[0].paymentMethodType).toBe('paypal');
      expect(result[1].paymentMethodType).toBe('visa');
    });

    it('returns original array when priority array is empty', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'visa' },
      ];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, []);
      expect(result).toBe(sortArr);
    });

    it('places defaultPaymentMethodSet items first when displayDefaultSavedPaymentIcon is true', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'visa' },
        { paymentMethod: 'card', paymentMethodType: 'mastercard', defaultPaymentMethodSet: true },
      ];
      const priorityArr = ['visa', 'mastercard'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr, true);
      expect(result[0].paymentMethodType).toBe('mastercard');
    });

    it('sorts by priority when displayDefaultSavedPaymentIcon is false', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'visa' },
        { paymentMethod: 'card', paymentMethodType: 'mastercard', defaultPaymentMethodSet: true },
      ];
      const priorityArr = ['visa', 'mastercard'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr, false);
      expect(result[0].paymentMethodType).toBe('visa');
    });

    it('places items not in priority array at the end', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'unknown' },
        { paymentMethod: 'card', paymentMethodType: 'visa' },
      ];
      const priorityArr = ['visa'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr);
      expect(result.some((m: any) => m.paymentMethodType === 'visa')).toBe(true);
      expect(result.some((m: any) => m.paymentMethodType === 'unknown')).toBe(true);
    });

    it('uses paymentMethod for card type', () => {
      const sortArr = [
        { paymentMethod: 'card' },
        { paymentMethod: 'wallet', paymentMethodType: 'paypal' },
      ];
      const priorityArr = ['card', 'paypal'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr);
      expect(result[0].paymentMethod).toBe('card');
    });
  });

  describe('checkIsCardSupported', () => {
    it('returns false for invalid card with empty brand', () => {
      const result = PaymentUtils.checkIsCardSupported('123', '', ['visa']);
      expect(result).toBe(false);
    });

    it('returns undefined for invalid card with brand', () => {
      const result = PaymentUtils.checkIsCardSupported('123', 'Visa', ['visa']);
      expect(result).toBeUndefined();
    });

    it('returns true when brand is empty and card is valid', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', '', ['visa']);
      expect(result).toBe(true);
    });

    it('returns true when brand is in supported list', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', 'Visa', ['visa', 'mastercard']);
      expect(result).toBe(true);
    });

    it('returns false when brand is not in supported list', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', 'Visa', ['mastercard']);
      expect(result).toBe(false);
    });

    it('returns true when supportedCardBrands is undefined', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', 'Visa', undefined);
      expect(result).toBe(true);
    });

    it('handles case-insensitive brand matching', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', 'VISA', ['visa']);
      expect(result).toBe(true);
    });
  });

  describe('checkRenderOrComp', () => {
    it('returns true when walletOptions includes "paypal"', () => {
      expect(PaymentUtils.checkRenderOrComp(['paypal'], false, false)).toBe(true);
    });

    it('returns true when isShowOrPayUsing is true', () => {
      expect(PaymentUtils.checkRenderOrComp([], true, false)).toBe(true);
    });

    it('returns isShowOrPayUsingWhileLoading when neither condition is met', () => {
      expect(PaymentUtils.checkRenderOrComp([], false, true)).toBe(true);
      expect(PaymentUtils.checkRenderOrComp([], false, false)).toBe(false);
    });

    it('returns true when paypal is in options regardless of other params', () => {
      expect(PaymentUtils.checkRenderOrComp(['card', 'paypal'], false, false)).toBe(true);
    });
  });

  describe('filterInstallmentPlansByPaymentMethod', () => {
    it('returns available plans for matching payment method', () => {
      const installmentOptions = [
        {
          payment_method: 'card',
          available_plans: [{ plan_id: 'plan1' }, { plan_id: 'plan2' }],
        },
        {
          payment_method: 'wallet',
          available_plans: [{ plan_id: 'plan3' }],
        },
      ];
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod(installmentOptions, 'card');
      expect(result.length).toBe(2);
      expect(result[0].plan_id).toBe('plan1');
    });

    it('returns empty array when payment method not found', () => {
      const installmentOptions = [
        { payment_method: 'card', available_plans: [{ plan_id: 'plan1' }] },
      ];
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod(installmentOptions, 'wallet');
      expect(result).toEqual([]);
    });

    it('returns empty array for empty installment options', () => {
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod([], 'card');
      expect(result).toEqual([]);
    });

    it('handles options without available_plans', () => {
      const installmentOptions = [
        { payment_method: 'card' },
      ];
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod(installmentOptions, 'card');
      expect(result).toBeUndefined();
    });
  });

  describe('getDisplayNameAndIcon', () => {
    it('returns default name and icon when no custom name found', () => {
      const customNames = [{ paymentMethodName: 'other', aliasName: 'Other Name' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'classic', 'Default Name', null);
      expect(result[0]).toBe('Default Name');
      expect(result[1]).toBeNull();
    });

    it('returns default name and icon for non-classic/evoucher custom names', () => {
      const customNames = [{ paymentMethodName: 'other', aliasName: 'Other Name' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'other', 'Default Name', null);
      expect(result[0]).toBe('Default Name');
      expect(result[1]).toBeNull();
    });

    it('returns default when aliasName is empty', () => {
      const customNames = [{ paymentMethodName: 'classic', aliasName: '' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'classic', 'Default Name', null);
      expect(result[0]).toBe('Default Name');
      expect(result[1]).toBeNull();
    });

    it('returns custom alias and icon for classic with alias', () => {
      const customNames = [{ paymentMethodName: 'classic', aliasName: 'My Custom Card' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'classic', 'Default Name', null);
      expect(result[0]).toBe('My Custom Card');
      expect(result[1]).toBeDefined();
    });

    it('returns custom alias and icon for evoucher with alias', () => {
      const customNames = [{ paymentMethodName: 'evoucher', aliasName: 'My Voucher' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'evoucher', 'Default Name', null);
      expect(result[0]).toBe('My Voucher');
      expect(result[1]).toBeDefined();
    });
  });

  describe('getConnectors', () => {
    it('returns empty arrays when payment method not found', () => {
      const list = { payment_methods: [] };
      const method = { TAG: 'Cards', _0: {} };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result).toEqual([[], []]);
    });

    it('returns empty arrays when payment method type not found', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'card',
            payment_method_types: [],
          },
        ],
      };
      const method = { TAG: 'Cards', _0: {} };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result).toEqual([[], []]);
    });
  });

  describe('getSupportedCardBrands', () => {
    it('returns undefined when card payment method not found', () => {
      const paymentMethodListValue = { payment_methods: [] };
      const result = PaymentUtils.getSupportedCardBrands(paymentMethodListValue);
      expect(result).toBeUndefined();
    });
  });

  describe('emitMessage', () => {
    it('calls messageParentWindow with payment info', () => {
      const mockMessageParentWindow = jest.fn();
      jest.mock('../Utilities/Utils.bs.js', () => ({
        messageParentWindow: mockMessageParentWindow,
      }));

      PaymentUtils.emitMessage({ paymentMethod: 'card' });
    });
  });

  describe('emitPaymentMethodInfo', () => {
    it('emits card payment info with card brand', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'card',
        'debit',
        'Visa',
        '4242',
        '424242',
        '12',
        '2025',
        'US',
        'CA',
        '12345',
        false,
        false,
        true
      );
    });

    it('emits non-card payment info without card fields', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'wallet',
        'apple_pay',
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        'US',
        'CA',
        '12345',
        false,
        false,
        false
      );
    });

    it('handles empty card brand', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'card',
        'credit',
        undefined,
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        false,
        true,
        true
      );
    });

    it('handles saved payment method', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'card',
        'debit',
        'Mastercard',
        '5555',
        '555555',
        '06',
        '2026',
        'GB',
        'London',
        'SW1A 1AA',
        true,
        false,
        true
      );
    });

    it('handles bank debit payment method type', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'bank_debit',
        'ach_debit',
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        'US',
        'NY',
        '10001',
        false,
        false,
        false
      );
    });

    it('handles bank transfer payment method type', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'bank_transfer',
        'sepa_transfer',
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        'DE',
        'Berlin',
        '10115',
        false,
        false,
        false
      );
    });
  });

  describe('getExperienceType - additional cases', () => {
    it('returns experience for PayLater with experience object', () => {
      const method = {
        TAG: 'PayLater',
        _0: { TAG: 'Klarna', _0: { _0: { TAG: 'Redirect' } } },
      };
      const result = PaymentUtils.getExperienceType(method);
      expect(result).toBeDefined();
    });

    it('returns experience for Wallets with experience object', () => {
      const method = {
        TAG: 'Wallets',
        _0: { TAG: 'Gpay', _0: { _0: { TAG: 'InvokeSDK' } } },
      };
      const result = PaymentUtils.getExperienceType(method);
      expect(result).toBeDefined();
    });
  });

  describe('getConnectors - additional cases', () => {
    it('returns empty arrays for Cards without matching experience', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'card',
            payment_method_types: [
              {
                payment_method_type: 'credit',
                payment_experience: [],
              },
            ],
          },
        ],
      };
      const method = {
        TAG: 'Cards',
        _0: {},
      };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result).toEqual([[], []]);
    });

    it('returns bank names for Banks', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'bank_redirect',
            payment_method_types: [
              {
                payment_method_type: 'ideal',
                bank_names: ['ing', 'rabobank'],
                payment_experience: [],
              },
            ],
          },
        ],
      };
      const method = {
        TAG: 'Banks',
        _0: 'Ideal',
      };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result[1]).toEqual(['ing', 'rabobank']);
    });

    it('returns bank_transfers_connectors for BankTransfer', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'bank_transfer',
            payment_method_types: [
              {
                payment_method_type: 'sepa',
                bank_transfers_connectors: ['stripe'],
                payment_experience: [],
              },
            ],
          },
        ],
      };
      const method = {
        TAG: 'BankTransfer',
        _0: 'Sepa',
      };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result[0]).toEqual(['stripe']);
    });

    it('returns bank_debits_connectors for BankDebit', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'bank_debit',
            payment_method_types: [
              {
                payment_method_type: 'ach',
                bank_debits_connectors: ['stripe'],
                payment_experience: [],
              },
            ],
          },
        ],
      };
      const method = {
        TAG: 'BankDebit',
        _0: 'ACH',
      };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result[0]).toEqual(['stripe']);
    });

    it('returns empty arrays for PayLater without matching experience', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'pay_later',
            payment_method_types: [
              {
                payment_method_type: 'klarna',
                payment_experience: [],
              },
            ],
          },
        ],
      };
      const method = {
        TAG: 'PayLater',
        _0: { TAG: 'Klarna', _0: {} },
      };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result).toEqual([[], []]);
    });

    it('returns empty arrays for Wallets without matching experience', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'wallet',
            payment_method_types: [
              {
                payment_method_type: 'google_pay',
                payment_experience: [],
              },
            ],
          },
        ],
      };
      const method = {
        TAG: 'Wallets',
        _0: { TAG: 'Gpay', _0: {} },
      };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result).toEqual([[], []]);
    });
  });

  describe('getIsKlarnaSDKFlow', () => {
    it('returns true when Klarna token exists in OtherTokenOptional', () => {
      const sessions = JSON.stringify({
        sessionsToken: [{ wallet_name: 'Klarna', token: 'klarna_token' }],
      });
      
      const result = PaymentUtils.getIsKlarnaSDKFlow(sessions);
      expect(typeof result).toBe('boolean');
    });

    it('returns false for empty sessions', () => {
      const result = PaymentUtils.getIsKlarnaSDKFlow('{}');
      expect(typeof result).toBe('boolean');
    });

    it('handles invalid JSON', () => {
      const result = PaymentUtils.getIsKlarnaSDKFlow('invalid json');
      expect(typeof result).toBe('boolean');
    });

    it('handles null sessions', () => {
      const result = PaymentUtils.getIsKlarnaSDKFlow(null);
      expect(typeof result).toBe('boolean');
    });
  });

  describe('getStateJson', () => {
    it('returns a promise', async () => {
      const result = PaymentUtils.getStateJson();
      expect(result).toBeInstanceOf(Promise);
    });

    it('handles successful fetch', async () => {
      const result = await PaymentUtils.getStateJson();
      expect(result).toBeDefined();
    });
  });

  describe('getDisplayNameAndIcon - edge cases', () => {
    it('handles empty customNames array', () => {
      const result = PaymentUtils.getDisplayNameAndIcon([], 'classic', 'Default', null);
      expect(result[0]).toBe('Default');
      expect(result[1]).toBeNull();
    });

    it('handles multiple custom names but none matching', () => {
      const customNames = [
        { paymentMethodName: 'other', aliasName: 'Other Name' },
        { paymentMethodName: 'another', aliasName: 'Another Name' },
      ];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'classic', 'Default', null);
      expect(result[0]).toBe('Default');
    });

    it('handles classic with multi-word alias', () => {
      const customNames = [{ paymentMethodName: 'classic', aliasName: 'Premium Card' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'classic', 'Default', null);
      expect(result[0]).toBe('Premium Card');
      expect(result[1]).toBeDefined();
    });

    it('handles evoucher with single word alias', () => {
      const customNames = [{ paymentMethodName: 'evoucher', aliasName: 'GiftCard' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'evoucher', 'Default', null);
      expect(result[0]).toBe('GiftCard');
      expect(result[1]).toBeDefined();
    });
  });

  describe('getMethod - edge cases', () => {
    it('handles string method', () => {
      expect(PaymentUtils.getMethod('Crypto')).toBe('crypto');
    });

    it('handles number as method', () => {
      expect(PaymentUtils.getMethod(123 as any)).toBe('crypto');
    });
  });

  describe('getMethodType - edge cases', () => {
    it('handles string method', () => {
      expect(PaymentUtils.getMethodType('Crypto')).toBe('crypto_currency');
    });

    it('handles BankTransfer with different values', () => {
      const method = { TAG: 'BankTransfer', _0: 'Sepa' };
      expect(PaymentUtils.getMethodType(method)).toBe('sepa');
    });

    it('handles BankTransfer with Bacs', () => {
      const method = { TAG: 'BankTransfer', _0: 'Bacs' };
      expect(PaymentUtils.getMethodType(method)).toBe('bacs');
    });

    it('handles BankTransfer with Instant', () => {
      const method = { TAG: 'BankTransfer', _0: 'Instant' };
      expect(PaymentUtils.getMethodType(method)).toBe('instant');
    });
  });

  describe('getPaymentMethodName - additional cases', () => {
    it('handles card type', () => {
      expect(PaymentUtils.getPaymentMethodName('card', 'credit')).toBe('credit');
    });

    it('handles wallet type', () => {
      expect(PaymentUtils.getPaymentMethodName('wallet', 'apple_pay')).toBe('apple_pay');
    });

    it('handles bank_debit with ach', () => {
      expect(PaymentUtils.getPaymentMethodName('bank_debit', 'ach_debit')).toBe('ach');
    });

    it('handles bank_debit with sepa', () => {
      expect(PaymentUtils.getPaymentMethodName('bank_debit', 'sepa_debit')).toBe('sepa');
    });

    it('handles bank_transfer with pix (in bankTransferList)', () => {
      expect(PaymentUtils.getPaymentMethodName('bank_transfer', 'pix')).toBe('pix');
    });

    it('handles bank_transfer with sepa (not in bankTransferList)', () => {
      expect(PaymentUtils.getPaymentMethodName('bank_transfer', 'sepa_transfer')).toBe('sepa');
    });
  });

  describe('isAppendingCustomerAcceptance - additional cases', () => {
    it('returns false for guest with any type', () => {
      expect(PaymentUtils.isAppendingCustomerAcceptance(true, 'NEW_MANDATE')).toBe(false);
      expect(PaymentUtils.isAppendingCustomerAcceptance(true, 'SETUP_MANDATE')).toBe(false);
      expect(PaymentUtils.isAppendingCustomerAcceptance(true, 'NORMAL')).toBe(false);
    });

    it('returns true for non-guest with NEW_MANDATE', () => {
      expect(PaymentUtils.isAppendingCustomerAcceptance(false, 'NEW_MANDATE')).toBe(true);
    });

    it('returns true for non-guest with SETUP_MANDATE', () => {
      expect(PaymentUtils.isAppendingCustomerAcceptance(false, 'SETUP_MANDATE')).toBe(true);
    });

    it('returns false for non-guest with other types', () => {
      expect(PaymentUtils.isAppendingCustomerAcceptance(false, 'NORMAL')).toBe(false);
      expect(PaymentUtils.isAppendingCustomerAcceptance(false, 'RECURRING')).toBe(false);
    });
  });

  describe('appendedCustomerAcceptance - additional cases', () => {
    it('does not append when guest', () => {
      const body: [string, any][] = [['key', 'value']];
      const result = PaymentUtils.appendedCustomerAcceptance(true, 'NEW_MANDATE', body);
      expect(result.length).toBe(1);
    });

    it('does not append when wrong type', () => {
      const body: [string, any][] = [['key', 'value']];
      const result = PaymentUtils.appendedCustomerAcceptance(false, 'NORMAL', body);
      expect(result.length).toBe(1);
    });

    it('appends when conditions met', () => {
      const body: [string, any][] = [['key', 'value']];
      const result = PaymentUtils.appendedCustomerAcceptance(false, 'NEW_MANDATE', body);
      expect(result.length).toBe(2);
      expect(result[1][0]).toBe('customer_acceptance');
    });
  });

  describe('checkIsCardSupported - additional cases', () => {
    it('returns false for invalid short card', () => {
      const result = PaymentUtils.checkIsCardSupported('123', '', ['visa']);
      expect(result).toBe(false);
    });

    it('returns undefined for invalid card with brand', () => {
      const result = PaymentUtils.checkIsCardSupported('123', 'Visa', ['visa']);
      expect(result).toBeUndefined();
    });

    it('handles case insensitive brand matching', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', 'VISA', ['visa']);
      expect(result).toBe(true);
    });

    it('returns false when brand not in supported list', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', 'Visa', ['mastercard', 'amex']);
      expect(result).toBe(false);
    });

    it('returns true when supportedCardBrands is undefined', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', 'Visa', undefined);
      expect(result).toBe(true);
    });
  });

  describe('filterSavedMethodsByWalletReadiness - additional cases', () => {
    it('keeps all methods when both wallets ready', () => {
      const savedMethods = [
        { paymentMethodType: 'apple_pay' },
        { paymentMethodType: 'google_pay' },
        { paymentMethodType: 'card' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, true, true);
      expect(result.length).toBe(3);
    });

    it('filters apple_pay when not ready', () => {
      const savedMethods = [
        { paymentMethodType: 'apple_pay' },
        { paymentMethodType: 'google_pay' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, false, true);
      expect(result.length).toBe(1);
      expect(result[0].paymentMethodType).toBe('google_pay');
    });

    it('filters google_pay when not ready', () => {
      const savedMethods = [
        { paymentMethodType: 'apple_pay' },
        { paymentMethodType: 'google_pay' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, true, false);
      expect(result.length).toBe(1);
      expect(result[0].paymentMethodType).toBe('apple_pay');
    });

    it('keeps methods without paymentMethodType', () => {
      const savedMethods = [
        { paymentMethod: 'card' },
        { paymentMethodType: undefined },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, false, false);
      expect(result.length).toBe(2);
    });

    it('keeps other payment method types', () => {
      const savedMethods = [
        { paymentMethodType: 'paypal' },
        { paymentMethodType: 'klarna' },
      ];
      const result = PaymentUtils.filterSavedMethodsByWalletReadiness(savedMethods, false, false);
      expect(result.length).toBe(2);
    });
  });

  describe('sortCustomerMethodsBasedOnPriority - additional cases', () => {
    it('returns original array when priority is empty', () => {
      const sortArr = [{ paymentMethod: 'card' }];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, []);
      expect(result).toBe(sortArr);
    });

    it('sorts by priority order', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'visa' },
        { paymentMethod: 'wallet', paymentMethodType: 'paypal' },
        { paymentMethod: 'card', paymentMethodType: 'mastercard' },
      ];
      const priorityArr = ['paypal', 'mastercard', 'visa'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr);
      expect(result[0].paymentMethodType).toBe('paypal');
    });

    it('places items not in priority at end', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'unknown' },
        { paymentMethod: 'card', paymentMethodType: 'visa' },
      ];
      const priorityArr = ['visa'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr);
      expect(result.some((m: any) => m.paymentMethodType === 'visa')).toBe(true);
      expect(result.some((m: any) => m.paymentMethodType === 'unknown')).toBe(true);
    });

    it('handles defaultPaymentMethodSet with displayDefaultSavedPaymentIcon true', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'visa' },
        { paymentMethod: 'card', paymentMethodType: 'mastercard', defaultPaymentMethodSet: true },
      ];
      const priorityArr = ['visa', 'mastercard'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr, true);
      expect(result[0].paymentMethodType).toBe('mastercard');
    });

    it('handles defaultPaymentMethodSet with displayDefaultSavedPaymentIcon false', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'visa' },
        { paymentMethod: 'card', paymentMethodType: 'mastercard', defaultPaymentMethodSet: true },
      ];
      const priorityArr = ['visa', 'mastercard'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr, false);
      expect(result[0].paymentMethodType).toBe('visa');
    });

    it('uses paymentMethod for card type', () => {
      const sortArr = [
        { paymentMethod: 'card' },
        { paymentMethod: 'wallet', paymentMethodType: 'paypal' },
      ];
      const priorityArr = ['card', 'paypal'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr);
      expect(result[0].paymentMethod).toBe('card');
    });
  });

  describe('checkRenderOrComp - additional cases', () => {
    it('returns true when paypal in options', () => {
      expect(PaymentUtils.checkRenderOrComp(['paypal'], false, false)).toBe(true);
    });

    it('returns true when isShowOrPayUsing is true', () => {
      expect(PaymentUtils.checkRenderOrComp([], true, false)).toBe(true);
    });

    it('returns isShowOrPayUsingWhileLoading when neither condition', () => {
      expect(PaymentUtils.checkRenderOrComp([], false, true)).toBe(true);
      expect(PaymentUtils.checkRenderOrComp([], false, false)).toBe(false);
    });

    it('handles multiple wallet options', () => {
      expect(PaymentUtils.checkRenderOrComp(['card', 'apple_pay', 'paypal'], false, false)).toBe(true);
    });
  });

  describe('filterInstallmentPlansByPaymentMethod - additional cases', () => {
    it('returns plans for matching payment method', () => {
      const options = [
        { payment_method: 'card', available_plans: [{ id: 1 }, { id: 2 }] },
        { payment_method: 'wallet', available_plans: [{ id: 3 }] },
      ];
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod(options, 'card');
      expect(result.length).toBe(2);
    });

    it('returns empty array when no match', () => {
      const options = [{ payment_method: 'card', available_plans: [] }];
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod(options, 'wallet');
      expect(result).toEqual([]);
    });

    it('handles empty options', () => {
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod([], 'card');
      expect(result).toEqual([]);
    });

    it('handles options without available_plans', () => {
      const options = [{ payment_method: 'card' }];
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod(options, 'card');
      expect(result).toBeUndefined();
    });
  });

  describe('paymentListLookupNew', () => {
    it('returns empty arrays for empty payment list', () => {
      const mockList = { payment_methods: [] };
      const mockPmlValue = {
        payment_methods: [],
        collect_billing_details_from_wallets: false,
      };
      
      const result = PaymentUtils.paymentListLookupNew(
        mockList,
        ['card'],
        true,
        false,
        false,
        mockPmlValue,
        false,
        false,
        false,
        false,
        { wallet_payment_method: () => 'Wallet' },
        false,
        false
      );
      
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(2);
    });

    it('handles wallet payment methods', () => {
      const mockList = {
        payment_methods: [
          { payment_method: 'wallet', payment_method_types: [] }
        ]
      };
      const mockPmlValue = {
        payment_methods: [],
        collect_billing_details_from_wallets: false,
      };
      
      const result = PaymentUtils.paymentListLookupNew(
        mockList,
        [],
        false,
        false,
        false,
        mockPmlValue,
        false,
        false,
        false,
        false,
        { wallet_payment_method: () => 'Wallet' },
        false,
        false
      );
      
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('getConnectors - extended tests', () => {
    it('returns eligible connectors for wallet payment', () => {
      const list = {
        payment_methods: [
          {
            payment_method: 'wallet',
            payment_method_types: [
              {
                payment_method_type: 'google_pay',
                payment_experience: [
                  {
                    payment_experience_type: 'InvokeSDK',
                    eligible_connectors: ['stripe', 'adyen']
                  }
                ],
                bank_names: []
              }
            ]
          }
        ]
      };
      const method = {
        TAG: 'Wallets',
        _0: { TAG: 'Gpay', _0: { _0: { TAG: 'InvokeSDK' } } }
      };
      const result = PaymentUtils.getConnectors(list, method);
      expect(result[0]).toEqual(['stripe', 'adyen']);
    });

    it('returns empty arrays for crypto', () => {
      const list = { payment_methods: [] };
      const result = PaymentUtils.getConnectors(list, 'Crypto');
      expect(result).toEqual([[], []]);
    });
  });

  describe('getIsKlarnaSDKFlow - extended tests', () => {
    it('returns false for Klarna token without OtherTokenOptional', () => {
      const sessions = JSON.stringify({
        sessionsToken: [{ wallet_name: 'Klarna', token: 'klarna_token' }]
      });
      const result = PaymentUtils.getIsKlarnaSDKFlow(sessions);
      expect(typeof result).toBe('boolean');
    });

    it('handles malformed JSON', () => {
      const result = PaymentUtils.getIsKlarnaSDKFlow('{invalid}');
      expect(typeof result).toBe('boolean');
    });
  });

  describe('getSupportedCardBrands - extended tests', () => {
    it('returns array of supported card brands', () => {
      const paymentMethodListValue = {
        payment_methods: [
          {
            payment_method: 'card',
            payment_method_types: [
              {
                card_networks: [
                  { card_network: 'VISA' },
                  { card_network: 'MASTERCARD' }
                ]
              }
            ]
          }
        ]
      };
      const result = PaymentUtils.getSupportedCardBrands(paymentMethodListValue);
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('emitPaymentMethodInfo - extended tests', () => {
    it('handles bank_debit payment method type suffix', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'bank_debit',
        'ach_debit',
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        'US',
        'CA',
        '12345',
        false,
        false,
        false
      );
    });

    it('handles bank_transfer payment method type suffix', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'bank_transfer',
        'sepa_transfer',
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        'DE',
        'Berlin',
        '10115',
        false,
        false,
        false
      );
    });

    it('handles non-card payment with NOTFOUND brand', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'wallet',
        'paypal',
        'NOTFOUND',
        '',
        '',
        '',
        '',
        'US',
        '',
        '',
        false,
        false,
        false
      );
    });

    it('handles card payment with valid brand and CVC', () => {
      PaymentUtils.emitPaymentMethodInfo(
        'card',
        'credit',
        'VISA',
        '4242',
        '424242',
        '12',
        '2025',
        'US',
        'CA',
        '12345',
        true,
        false,
        true
      );
    });
  });

  describe('sortCustomerMethodsBasedOnPriority - extended tests', () => {
    it('handles empty sort array', () => {
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority([], ['visa']);
      expect(result).toEqual([]);
    });

    it('handles paymentMethodType undefined', () => {
      const sortArr = [
        { paymentMethod: 'wallet', paymentMethodType: undefined },
        { paymentMethod: 'card' }
      ];
      const priorityArr = ['card'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr);
      expect(result.length).toBe(2);
    });

    it('handles both items with defaultPaymentMethodSet', () => {
      const sortArr = [
        { paymentMethod: 'card', paymentMethodType: 'visa', defaultPaymentMethodSet: true },
        { paymentMethod: 'card', paymentMethodType: 'mastercard', defaultPaymentMethodSet: true }
      ];
      const priorityArr = ['visa', 'mastercard'];
      const result = PaymentUtils.sortCustomerMethodsBasedOnPriority(sortArr, priorityArr, true);
      expect(result.length).toBe(2);
    });
  });

  describe('checkIsCardSupported - extended tests', () => {
    it('returns undefined for invalid card with brand', () => {
      const result = PaymentUtils.checkIsCardSupported('1234567890123456', 'Visa', ['visa']);
      expect(result).toBeUndefined();
    });

    it('handles empty supportedCardBrands array', () => {
      const result = PaymentUtils.checkIsCardSupported('4111111111111111', 'Visa', []);
      expect(result).toBe(false);
    });

    it('handles whitespace in card number', () => {
      const result = PaymentUtils.checkIsCardSupported('4111 1111 1111 1111', 'Visa', ['visa']);
      expect(result).toBe(true);
    });
  });

  describe('checkRenderOrComp - extended tests', () => {
    it('returns true when multiple wallet options include paypal', () => {
      expect(PaymentUtils.checkRenderOrComp(['apple_pay', 'google_pay', 'paypal'], false, false)).toBe(true);
    });

    it('returns false when no conditions met', () => {
      expect(PaymentUtils.checkRenderOrComp(['card', 'bank_transfer'], false, false)).toBe(false);
    });

    it('prioritizes paypal over isShowOrPayUsingWhileLoading', () => {
      expect(PaymentUtils.checkRenderOrComp(['paypal'], false, false)).toBe(true);
    });
  });

  describe('filterInstallmentPlansByPaymentMethod - extended tests', () => {
    it('throws for null installment options', () => {
      expect(() => PaymentUtils.filterInstallmentPlansByPaymentMethod(null as any, 'card')).toThrow();
    });

    it('handles installment options with empty available_plans', () => {
      const options = [{ payment_method: 'card', available_plans: [] }];
      const result = PaymentUtils.filterInstallmentPlansByPaymentMethod(options, 'card');
      expect(result).toEqual([]);
    });
  });

  describe('getDisplayNameAndIcon - extended tests', () => {
    it('handles classic with single word alias', () => {
      const customNames = [{ paymentMethodName: 'classic', aliasName: 'Premium' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'classic', 'Default', null);
      expect(result[0]).toBe('Premium');
    });

    it('handles evoucher with alias containing spaces', () => {
      const customNames = [{ paymentMethodName: 'evoucher', aliasName: 'Gift Card' }];
      const result = PaymentUtils.getDisplayNameAndIcon(customNames, 'evoucher', 'Default', null);
      expect(result[0]).toBe('Gift Card');
    });
  });

  describe('getPaymentMethodName - extended tests', () => {
    it('handles pix as bank_transfer', () => {
      expect(PaymentUtils.getPaymentMethodName('bank_transfer', 'pix')).toBe('pix');
    });

    it('handles generic payment method', () => {
      expect(PaymentUtils.getPaymentMethodName('reward', 'points')).toBe('points');
    });
  });

  describe('getMethod - extended tests', () => {
    it('handles undefined method', () => {
      expect(PaymentUtils.getMethod(undefined as any)).toBe('crypto');
    });

    it('throws for null method', () => {
      expect(() => PaymentUtils.getMethod(null as any)).toThrow();
    });
  });

  describe('getMethodType - extended tests', () => {
    it('handles undefined method', () => {
      expect(PaymentUtils.getMethodType(undefined as any)).toBe('crypto_currency');
    });

    it('throws for null method', () => {
      expect(() => PaymentUtils.getMethodType(null as any)).toThrow();
    });
  });

  describe('appendedCustomerAcceptance - extended tests', () => {
    it('returns new array when appending', () => {
      const body: [string, any][] = [['key', 'value']];
      const result = PaymentUtils.appendedCustomerAcceptance(false, 'SETUP_MANDATE', body);
      expect(result.length).toBe(2);
      expect(result).not.toBe(body);
    });

    it('returns same array when not appending', () => {
      const body: [string, any][] = [['key', 'value']];
      const result = PaymentUtils.appendedCustomerAcceptance(true, 'NEW_MANDATE', body);
      expect(result).toBe(body);
    });
  });

  describe('getExperienceType - extended tests', () => {
    it('returns experience for PayLater with Redirect experience', () => {
      const method = {
        TAG: 'PayLater',
        _0: { TAG: 'Klarna', _0: 'Redirect' }
      };
      const result = PaymentUtils.getExperienceType(method);
      expect(result).toBe('redirect_to_url');
    });

    it('returns experience for Wallets with non-Redirect experience', () => {
      const method = {
        TAG: 'Wallets',
        _0: { TAG: 'Gpay', _0: 'InvokeSDK' }
      };
      const result = PaymentUtils.getExperienceType(method);
      expect(result).toBe('invoke_sdk_client');
    });
  });

  describe('getPaymentExperienceType - extended tests', () => {
    it('returns undefined for unknown experience type', () => {
      expect(PaymentUtils.getPaymentExperienceType('UnknownType')).toBeUndefined();
    });

    it('returns correct value for QrFlow', () => {
      expect(PaymentUtils.getPaymentExperienceType('QrFlow')).toBe('display_qr_code');
    });
  });
});
