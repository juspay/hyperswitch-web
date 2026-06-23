import {
  paymentListLookupNew,
  getCreditFieldsRequired,
  getPaymentMethodTypeFromListV2,
} from '../Utilities/PaymentUtilsV2.bs.js';
import { defaultPaymentMethods } from '../Utilities/UnifiedHelpersV2.bs.js';

describe('PaymentUtilsV2', () => {
  describe('paymentListLookupNew', () => {
    it('should return empty lists for empty payment methods', () => {
      const paymentMethodListValue = {
        paymentMethodsEnabled: [],
      };

      const result = paymentListLookupNew(paymentMethodListValue);

      expect(result.walletsList).toEqual([]);
      expect(result.otherPaymentList).toEqual([]);
    });

    it('should add card to otherPaymentList when card payment method exists', () => {
      const paymentMethodListValue = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card' },
          { paymentMethodType: 'wallet' },
        ],
      };

      const result = paymentListLookupNew(paymentMethodListValue);

      expect(result.otherPaymentList).toContain('card');
      expect(result.walletsList).toEqual([]);
    });

    it('should not add non-card payment methods to otherPaymentList', () => {
      const paymentMethodListValue = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'bank_redirect' },
          { paymentMethodType: 'wallet' },
        ],
      };

      const result = paymentListLookupNew(paymentMethodListValue);

      expect(result.otherPaymentList).toEqual([]);
    });

    it('should handle payment methods without paymentMethodType field', () => {
      const paymentMethodListValue = {
        paymentMethodsEnabled: [
          { paymentMethod: 'card' },
          { paymentMethodType: 'card' },
        ],
      };

      const result = paymentListLookupNew(paymentMethodListValue);

      expect(result.otherPaymentList).toContain('card');
    });

    it('should remove duplicates from otherPaymentList', () => {
      const paymentMethodListValue = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card' },
          { paymentMethodType: 'card' },
          { paymentMethodType: 'card' },
        ],
      };

      const result = paymentListLookupNew(paymentMethodListValue);

      expect(result.otherPaymentList.length).toBe(1);
      expect(result.otherPaymentList).toEqual(['card']);
    });
  });

  describe('getCreditFieldsRequired', () => {
    it('should return credit card payment methods only', () => {
      const paymentManagementListValue = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card', paymentMethodSubtype: 'credit' },
          { paymentMethodType: 'card', paymentMethodSubtype: 'debit' },
          { paymentMethodType: 'wallet', paymentMethodSubtype: 'paypal' },
        ],
      };

      const result = getCreditFieldsRequired(paymentManagementListValue);

      expect(result.length).toBe(1);
      expect(result[0].paymentMethodSubtype).toBe('credit');
    });

    it('should return empty array when no credit cards exist', () => {
      const paymentManagementListValue = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card', paymentMethodSubtype: 'debit' },
          { paymentMethodType: 'wallet', paymentMethodSubtype: 'paypal' },
        ],
      };

      const result = getCreditFieldsRequired(paymentManagementListValue);

      expect(result).toEqual([]);
    });

    it('should return empty array for empty payment methods', () => {
      const paymentManagementListValue = {
        paymentMethodsEnabled: [],
      };

      const result = getCreditFieldsRequired(paymentManagementListValue);

      expect(result).toEqual([]);
    });

    it('should return multiple credit cards if present', () => {
      const paymentManagementListValue = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card', paymentMethodSubtype: 'credit', cardBrand: 'visa' },
          { paymentMethodType: 'card', paymentMethodSubtype: 'credit', cardBrand: 'mastercard' },
        ],
      };

      const result = getCreditFieldsRequired(paymentManagementListValue);

      expect(result.length).toBe(2);
    });

    it('should handle undefined paymentMethodSubtype', () => {
      const paymentManagementListValue = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card' },
        ],
      };

      const result = getCreditFieldsRequired(paymentManagementListValue);

      expect(result).toEqual([]);
    });
  });

  describe('getPaymentMethodTypeFromListV2', () => {
    it('should find matching payment method by type and subtype', () => {
      const paymentsListValueV2 = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card', paymentMethodSubtype: 'credit', cardBrand: 'visa' },
          { paymentMethodType: 'card', paymentMethodSubtype: 'debit', cardBrand: 'mastercard' },
        ],
      };

      const result = getPaymentMethodTypeFromListV2(paymentsListValueV2, 'card', 'credit');

      expect(result.paymentMethodType).toBe('card');
      expect(result.paymentMethodSubtype).toBe('credit');
    });

    it('should return default when no match found', () => {
      const paymentsListValueV2 = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'wallet', paymentMethodSubtype: 'paypal' },
        ],
      };

      const result = getPaymentMethodTypeFromListV2(paymentsListValueV2, 'card', 'credit');

      expect(result).toEqual(defaultPaymentMethods);
    });

    it('should return default for empty list', () => {
      const paymentsListValueV2 = {
        paymentMethodsEnabled: [],
      };

      const result = getPaymentMethodTypeFromListV2(paymentsListValueV2, 'card', 'credit');

      expect(result).toEqual(defaultPaymentMethods);
    });

    it('should match exact paymentMethodSubtype', () => {
      const paymentsListValueV2 = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card', paymentMethodSubtype: 'credit' },
          { paymentMethodType: 'card', paymentMethodSubtype: 'debit' },
        ],
      };

      const result = getPaymentMethodTypeFromListV2(paymentsListValueV2, 'card', 'debit');

      expect(result.paymentMethodSubtype).toBe('debit');
    });

    it('should not match when paymentMethodType differs', () => {
      const paymentsListValueV2 = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card', paymentMethodSubtype: 'credit' },
        ],
      };

      const result = getPaymentMethodTypeFromListV2(paymentsListValueV2, 'wallet', 'credit');

      expect(result).toEqual(defaultPaymentMethods);
    });

    it('should return first match when multiple matches exist', () => {
      const paymentsListValueV2 = {
        paymentMethodsEnabled: [
          { paymentMethodType: 'card', paymentMethodSubtype: 'credit', id: 'first' },
          { paymentMethodType: 'card', paymentMethodSubtype: 'credit', id: 'second' },
        ],
      };

      const result = getPaymentMethodTypeFromListV2(paymentsListValueV2, 'card', 'credit');

      expect(result.id).toBe('first');
    });

    it('should have correct default structure', () => {
      const paymentsListValueV2 = {
        paymentMethodsEnabled: [],
      };

      const result = getPaymentMethodTypeFromListV2(paymentsListValueV2, 'card', 'credit');

      expect(result.paymentMethodType).toBe('');
      expect(result.paymentMethodSubtype).toBe('');
      expect(result.requiredFields).toEqual([]);
      expect(result.paymentExperience).toEqual([]);
    });
  });
});
