import {
  defaultAuthenticationDetails,
  defaultNextAction,
  defaultIntent,
  defaultToken,
  defaultAssociatedPaymentMethodObj,
  getNextAction,
  getAuthenticationDetails,
  getAssociatedPaymentMethods,
  itemToPMMConfirmMapper,
} from '../Types/PaymentConfirmTypesV2.bs.js';

describe('PaymentConfirmTypesV2', () => {
  describe('defaultAuthenticationDetails', () => {
    it('should have empty default values', () => {
      expect(defaultAuthenticationDetails.status).toBe('');
      expect(defaultAuthenticationDetails.error).toBe('');
    });
  });

  describe('defaultNextAction', () => {
    it('should have empty default values', () => {
      expect(defaultNextAction.redirectToUrl).toBe('');
      expect(defaultNextAction.type_).toBe('');
      expect(defaultNextAction.next_action_data).toBeUndefined();
    });
  });

  describe('defaultIntent', () => {
    it('should have empty default values', () => {
      expect(defaultIntent.id).toBe('');
      expect(defaultIntent.customerId).toBe('');
      expect(defaultIntent.clientSecret).toBe('');
      expect(defaultIntent.associatedPaymentMethods).toEqual([]);
    });
  });

  describe('defaultToken', () => {
    it('should have empty default values', () => {
      expect(defaultToken.type).toBe('');
      expect(defaultToken.data).toBe('');
    });
  });

  describe('defaultAssociatedPaymentMethodObj', () => {
    it('should have correct default structure', () => {
      expect(defaultAssociatedPaymentMethodObj.token).toEqual(defaultToken);
      expect(defaultAssociatedPaymentMethodObj.paymentMethodType).toBe('');
      expect(defaultAssociatedPaymentMethodObj.paymentMethodSubType).toBe('');
    });
  });

  describe('getNextAction', () => {
    it('should extract next action from dict', () => {
      const dict = {
        next_action: {
          redirect_to_url: 'https://example.com/redirect',
          type: 'redirect',
        },
      };
      const result = getNextAction(dict, 'next_action');
      expect(result.redirectToUrl).toBe('https://example.com/redirect');
      expect(result.type_).toBe('redirect');
    });

    it('should return default values when key not found', () => {
      const dict = {};
      const result = getNextAction(dict, 'next_action');
      expect(result).toEqual(defaultNextAction);
    });

    it('should handle next_action_data', () => {
      const dict = {
        next_action: {
          type: 'three_ds',
          next_action_data: {
            acs_url: 'https://acs.example.com',
          },
        },
      };
      const result = getNextAction(dict, 'next_action');
      expect(result.type_).toBe('three_ds');
      expect(result.next_action_data).toEqual({ acs_url: 'https://acs.example.com' });
    });

    it('should return default when value is null', () => {
      const dict = { next_action: null };
      const result = getNextAction(dict, 'next_action');
      expect(result).toEqual(defaultNextAction);
    });
  });

  describe('getAuthenticationDetails', () => {
    it('should extract authentication details from dict', () => {
      const dict = {
        authentication_details: {
          status: 'success',
          error: '',
        },
      };
      const result = getAuthenticationDetails(dict, 'authentication_details');
      expect(result.status).toBe('success');
      expect(result.error).toBe('success');
    });

    it('should return default values when key not found', () => {
      const dict = {};
      const result = getAuthenticationDetails(dict, 'authentication_details');
      expect(result).toEqual(defaultAuthenticationDetails);
    });

    it('should handle null value', () => {
      const dict = { authentication_details: null };
      const result = getAuthenticationDetails(dict, 'authentication_details');
      expect(result).toEqual(defaultAuthenticationDetails);
    });
  });

  describe('getAssociatedPaymentMethods', () => {
    it('should extract associated payment methods from dict', () => {
      const dict = {
        associated_payment_methods: [
          {
            payment_method_token: {
              type: 'network_token',
              data: 'token_123',
            },
            payment_method_type: 'card',
            payment_method_subtype: 'credit',
          },
        ],
      };
      const result = getAssociatedPaymentMethods(dict);
      expect(result).toHaveLength(1);
      expect(result[0].token.type).toBe('network_token');
      expect(result[0].token.data).toBe('token_123');
      expect(result[0].paymentMethodType).toBe('card');
      expect(result[0].paymentMethodSubType).toBe('credit');
    });

    it('should return empty array when no associated payment methods', () => {
      const dict = {};
      const result = getAssociatedPaymentMethods(dict);
      expect(result).toEqual([]);
    });

    it('should handle multiple payment methods', () => {
      const dict = {
        associated_payment_methods: [
          {
            payment_method_token: { type: 'token1', data: 'data1' },
            payment_method_type: 'card',
            payment_method_subtype: 'credit',
          },
          {
            payment_method_token: { type: 'token2', data: 'data2' },
            payment_method_type: 'wallet',
            payment_method_subtype: 'apple_pay',
          },
        ],
      };
      const result = getAssociatedPaymentMethods(dict);
      expect(result).toHaveLength(2);
      expect(result[0].paymentMethodType).toBe('card');
      expect(result[1].paymentMethodType).toBe('wallet');
    });

    it('should handle empty array', () => {
      const dict = {
        associated_payment_methods: [],
      };
      const result = getAssociatedPaymentMethods(dict);
      expect(result).toEqual([]);
    });

    it('should use defaults for missing fields', () => {
      const dict = {
        associated_payment_methods: [{}],
      };
      const result = getAssociatedPaymentMethods(dict);
      expect(result).toHaveLength(1);
      expect(result[0].token.type).toBe('');
      expect(result[0].token.data).toBe('');
      expect(result[0].paymentMethodType).toBe('');
    });
  });

  describe('itemToPMMConfirmMapper', () => {
    it('should map dict to PMM confirm object', () => {
      const dict = {
        next_action: {
          redirect_to_url: 'https://example.com/redirect',
          type: 'redirect',
        },
        id: 'pi_123',
        customer_id: 'cus_123',
        client_secret: 'secret_123',
        authentication_details: {
          status: 'success',
        },
        associated_payment_methods: [],
      };
      const result = itemToPMMConfirmMapper(dict);
      expect(result.id).toBe('pi_123');
      expect(result.customerId).toBe('cus_123');
      expect(result.clientSecret).toBe('secret_123');
      expect(result.nextAction.redirectToUrl).toBe('https://example.com/redirect');
    });

    it('should use default values for missing fields', () => {
      const dict = {};
      const result = itemToPMMConfirmMapper(dict);
      expect(result.id).toBe('');
      expect(result.customerId).toBe('');
      expect(result.clientSecret).toBe('');
      expect(result.nextAction).toEqual(defaultNextAction);
      expect(result.authenticationDetails).toEqual(defaultAuthenticationDetails);
      expect(result.associatedPaymentMethods).toEqual([]);
    });

    it('should handle partial data', () => {
      const dict = {
        id: 'pi_456',
        client_secret: 'secret_456',
      };
      const result = itemToPMMConfirmMapper(dict);
      expect(result.id).toBe('pi_456');
      expect(result.clientSecret).toBe('secret_456');
      expect(result.customerId).toBe('');
    });
  });
});
