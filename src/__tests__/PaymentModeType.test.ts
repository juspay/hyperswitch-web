import { paymentMode, defaultOrder } from '../Types/PaymentModeType.bs.js';

describe('PaymentModeType', () => {
  describe('paymentMode', () => {
    describe('happy path - card payments', () => {
      it('should return "Card" for "card"', () => {
        expect(paymentMode('card')).toBe('Card');
      });
    });

    describe('happy path - bank debits', () => {
      it('should return "ACHBankDebit" for "ach_debit"', () => {
        expect(paymentMode('ach_debit')).toBe('ACHBankDebit');
      });

      it('should return "BacsBankDebit" for "bacs_debit"', () => {
        expect(paymentMode('bacs_debit')).toBe('BacsBankDebit');
      });

      it('should return "BecsBankDebit" for "becs_debit"', () => {
        expect(paymentMode('becs_debit')).toBe('BecsBankDebit');
      });

      it('should return "SepaBankDebit" for "sepa_debit"', () => {
        expect(paymentMode('sepa_debit')).toBe('SepaBankDebit');
      });
    });

    describe('happy path - bank transfers', () => {
      it('should return "ACHTransfer" for "ach_transfer"', () => {
        expect(paymentMode('ach_transfer')).toBe('ACHTransfer');
      });

      it('should return "BacsTransfer" for "bacs_transfer"', () => {
        expect(paymentMode('bacs_transfer')).toBe('BacsTransfer');
      });

      it('should return "SepaTransfer" for "sepa_bank_transfer"', () => {
        expect(paymentMode('sepa_bank_transfer')).toBe('SepaTransfer');
      });
    });

    describe('happy path - wallets', () => {
      it('should return "ApplePay" for "apple_pay"', () => {
        expect(paymentMode('apple_pay')).toBe('ApplePay');
      });

      it('should return "GooglePay" for "google_pay"', () => {
        expect(paymentMode('google_pay')).toBe('GooglePay');
      });

      it('should return "SamsungPay" for "samsung_pay"', () => {
        expect(paymentMode('samsung_pay')).toBe('SamsungPay');
      });

      it('should return "PayPal" for "paypal"', () => {
        expect(paymentMode('paypal')).toBe('PayPal');
      });
    });

    describe('happy path - buy now pay later', () => {
      it('should return "Affirm" for "affirm"', () => {
        expect(paymentMode('affirm')).toBe('Affirm');
      });

      it('should return "AfterPay" for "afterpay_clearpay"', () => {
        expect(paymentMode('afterpay_clearpay')).toBe('AfterPay');
      });

      it('should return "Klarna" for "klarna"', () => {
        expect(paymentMode('klarna')).toBe('Klarna');
      });
    });

    describe('happy path - bank redirects', () => {
      it('should return "GiroPay" for "giropay"', () => {
        expect(paymentMode('giropay')).toBe('GiroPay');
      });

      it('should return "Ideal" for "ideal"', () => {
        expect(paymentMode('ideal')).toBe('Ideal');
      });

      it('should return "Sofort" for "sofort"', () => {
        expect(paymentMode('sofort')).toBe('Sofort');
      });

      it('should return "EPS" for "eps"', () => {
        expect(paymentMode('eps')).toBe('EPS');
      });
    });

    describe('happy path - other payment methods', () => {
      it('should return "Boleto" for "boleto"', () => {
        expect(paymentMode('boleto')).toBe('Boleto');
      });

      it('should return "BanContactCard" for "bancontact_card"', () => {
        expect(paymentMode('bancontact_card')).toBe('BanContactCard');
      });

      it('should return "CryptoCurrency" for "crypto_currency"', () => {
        expect(paymentMode('crypto_currency')).toBe('CryptoCurrency');
      });

      it('should return "EFT" for "eft"', () => {
        expect(paymentMode('eft')).toBe('EFT');
      });

      it('should return "RevolutPay" for "revolut_pay"', () => {
        expect(paymentMode('revolut_pay')).toBe('RevolutPay');
      });

      it('should return "Givex" for "givex"', () => {
        expect(paymentMode('givex')).toBe('Givex');
      });
    });

    describe('happy path - instant bank transfers', () => {
      it('should return "InstantTransfer" for "instant_bank_transfer"', () => {
        expect(paymentMode('instant_bank_transfer')).toBe('InstantTransfer');
      });

      it('should return "InstantTransferFinland" for "instant_bank_transfer_finland"', () => {
        expect(paymentMode('instant_bank_transfer_finland')).toBe('InstantTransferFinland');
      });

      it('should return "InstantTransferPoland" for "instant_bank_transfer_poland"', () => {
        expect(paymentMode('instant_bank_transfer_poland')).toBe('InstantTransferPoland');
      });
    });

    describe('happy path - saved methods', () => {
      it('should return "SavedMethods" for "saved_methods"', () => {
        expect(paymentMode('saved_methods')).toBe('SavedMethods');
      });
    });

    describe('edge cases', () => {
      it('should return "Unknown" for empty string', () => {
        expect(paymentMode('')).toBe('Unknown');
      });

      it('should return "Unknown" for unrecognized string', () => {
        expect(paymentMode('unknown_method')).toBe('Unknown');
      });

      it('should be case sensitive', () => {
        expect(paymentMode('CARD')).toBe('Unknown');
        expect(paymentMode('Apple_Pay')).toBe('Unknown');
        expect(paymentMode('GOOGLE_PAY')).toBe('Unknown');
      });
    });

    describe('error/boundary', () => {
      it('should return "Unknown" for random strings', () => {
        expect(paymentMode('xyz123')).toBe('Unknown');
        expect(paymentMode('test_payment')).toBe('Unknown');
      });

      it('should handle strings with special characters', () => {
        expect(paymentMode('card!')).toBe('Unknown');
        expect(paymentMode('apple-pay')).toBe('Unknown');
      });

      it('should not match partial strings', () => {
        expect(paymentMode('card_payment')).toBe('Unknown');
        expect(paymentMode('apple_pay_v2')).toBe('Unknown');
      });
    });
  });

  describe('defaultOrder', () => {
    describe('structure', () => {
      it('should be an array', () => {
        expect(Array.isArray(defaultOrder)).toBe(true);
      });

      it('should have expected length', () => {
        expect(defaultOrder.length).toBe(29);
      });
    });

    describe('ordering', () => {
      it('should have saved_methods first', () => {
        expect(defaultOrder[0]).toBe('saved_methods');
      });

      it('should have card second', () => {
        expect(defaultOrder[1]).toBe('card');
      });

      it('should have wallets early in the list', () => {
        expect(defaultOrder).toContain('apple_pay');
        expect(defaultOrder).toContain('google_pay');
        expect(defaultOrder).toContain('paypal');
        expect(defaultOrder).toContain('samsung_pay');
        expect(defaultOrder).toContain('klarna');
      });

      it('should have bank debits after transfers', () => {
        const transferIndex = defaultOrder.indexOf('ach_transfer');
        const debitIndex = defaultOrder.indexOf('ach_debit');
        expect(transferIndex).toBeLessThan(debitIndex);
      });
    });

    describe('contents', () => {
      it('should contain all expected payment methods', () => {
        const expectedMethods = [
          'saved_methods', 'card', 'apple_pay', 'google_pay', 'paypal',
          'klarna', 'samsung_pay', 'affirm', 'afterpay_clearpay',
          'ach_transfer', 'sepa_bank_transfer', 'instant_bank_transfer',
          'instant_bank_transfer_finland', 'instant_bank_transfer_poland',
          'bacs_transfer', 'ach_debit', 'sepa_debit', 'bacs_debit',
          'becs_debit', 'sofort', 'giropay', 'ideal', 'eps', 'crypto',
          'bancontact_card', 'boleto', 'eft', 'revolut_pay', 'givex',
        ];
        expectedMethods.forEach((method) => {
          expect(defaultOrder).toContain(method);
        });
      });

      it('should not contain duplicates', () => {
        const uniqueMethods = new Set(defaultOrder);
        expect(uniqueMethods.size).toBe(defaultOrder.length);
      });
    });
  });
});
