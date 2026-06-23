import {
  getCardDetails,
  itemToCustomerMapper,
  getDynamicFieldsFromJsonDictV2,
  getCardNetworks,
  itemToPaymentsEnabledMapper,
  itemToPaymentsObjMapper,
  createPaymentsObjArr,
  itemToPaymentDetails,
  itemToPaymentMethodsUpdateMapper,
  defaultAddress,
  defaultBilling,
  defaultPaymentMethods,
  defaultCustomerMethods,
  defaultPaymentsList,
} from '../Utilities/UnifiedHelpersV2.bs.js';

describe('UnifiedHelpersV2', () => {
  describe('getCardDetails', () => {
    it('should extract all card details from complete dict', () => {
      const cardDict = {
        card_network: 'visa',
        last4_digits: '4242',
        expiry_month: '12',
        expiry_year: '2025',
        card_holder_name: 'John Doe',
        nick_name: 'My Visa',
        card_issuer: 'US',
        card_fingerprint: 'abc123',
        card_isin: '424242',
        card_type: 'credit',
        saved_to_locker: true,
      };

      const result = getCardDetails(cardDict);

      expect(result.network).toBe('visa');
      expect(result.last4Digits).toBe('4242');
      expect(result.expiryMonth).toBe('12');
      expect(result.expiryYear).toBe('2025');
      expect(result.cardHolderName).toBe('John Doe');
      expect(result.nickname).toBe('My Visa');
      expect(result.issuerCountry).toBe('US');
      expect(result.cardFingerprint).toBe('abc123');
      expect(result.cardIsin).toBe('424242');
      expect(result.cardIssuer).toBe('US');
      expect(result.cardType).toBe('credit');
      expect(result.savedToLocker).toBe(true);
    });

    it('should return default values for missing fields', () => {
      const cardDict = {};

      const result = getCardDetails(cardDict);

      expect(result.network).toBeUndefined();
      expect(result.last4Digits).toBe('');
      expect(result.expiryMonth).toBe('');
      expect(result.expiryYear).toBe('');
      expect(result.cardHolderName).toBeUndefined();
      expect(result.nickname).toBeUndefined();
      expect(result.issuerCountry).toBeUndefined();
      expect(result.cardFingerprint).toBe('');
      expect(result.cardIsin).toBe('');
      expect(result.cardIssuer).toBe('');
      expect(result.cardType).toBe('');
      expect(result.savedToLocker).toBe(false);
    });

    it('should handle partial card data', () => {
      const cardDict = {
        card_network: 'mastercard',
        last4_digits: '5555',
      };

      const result = getCardDetails(cardDict);

      expect(result.network).toBe('mastercard');
      expect(result.last4Digits).toBe('5555');
      expect(result.expiryMonth).toBe('');
      expect(result.savedToLocker).toBe(false);
    });
  });

  describe('itemToCustomerMapper', () => {
    it('should map customer array to payment methods', () => {
      const customerArray = [
        {
          payment_method_token: 'token123',
          customer_id: 'cust_123',
          payment_method_type: 'card',
          payment_method_subtype: 'credit',
          recurring_enabled: true,
          is_default: true,
          requires_cvv: true,
          last_used_at: '2024-01-01',
          created: '2023-01-01',
          payment_method_data: {
            card: {
              card_network: 'visa',
              last4_digits: '4242',
              expiry_month: '12',
              expiry_year: '2025',
              card_fingerprint: 'fp123',
              card_isin: '424242',
              card_type: 'credit',
              saved_to_locker: true,
            },
          },
        },
      ];

      const result = itemToCustomerMapper(customerArray);

      expect(result.length).toBe(1);
      expect(result[0].paymentToken).toBe('token123');
      expect(result[0].customerId).toBe('cust_123');
      expect(result[0].paymentMethodType).toBe('card');
      expect(result[0].paymentMethodSubType).toBe('credit');
      expect(result[0].recurringEnabled).toBe(true);
      expect(result[0].isDefault).toBe(true);
      expect(result[0].requiresCvv).toBe(true);
      expect(result[0].paymentMethodData.card.last4Digits).toBe('4242');
      expect(result[0].bank.mask).toBe('');
    });

    it('should return empty array for empty input', () => {
      const result = itemToCustomerMapper([]);
      expect(result).toEqual([]);
    });

    it('should handle invalid items in array', () => {
      const customerArray = [null, undefined, 'invalid'];
      const result = itemToCustomerMapper(customerArray);
      expect(result).toEqual([]);
    });

    it('should handle items with missing payment_method_data', () => {
      const customerArray = [
        {
          payment_method_token: 'token456',
          customer_id: 'cust_456',
          payment_method_type: 'card',
          payment_method_subtype: 'debit',
        },
      ];

      const result = itemToCustomerMapper(customerArray);

      expect(result.length).toBe(1);
      expect(result[0].paymentToken).toBe('token456');
      expect(result[0].paymentMethodData.card.last4Digits).toBe('');
    });
  });

  describe('getDynamicFieldsFromJsonDictV2', () => {
    it('should extract required fields from dict', () => {
      const dict = {
        required_fields: [
          {
            required_field: 'payment_method_data.billing.address.line1',
            display_name: 'Address Line 1',
            field_type: 'AddressLine1',
            value: '123 Main St',
          },
          {
            required_field: 'payment_method_data.email',
            display_name: 'Email',
            field_type: 'Email',
            value: 'test@example.com',
          },
        ],
      };

      const result = getDynamicFieldsFromJsonDictV2(dict, false);

      expect(result.length).toBe(2);
      expect(result[0].required_field).toBe('payment_method_data.billing.address.line1');
      expect(result[0].display_name).toBe('Address Line 1');
      expect(result[0].value).toBe('123 Main St');
    });

    it('should return empty array for dict without required_fields', () => {
      const dict = {};
      const result = getDynamicFieldsFromJsonDictV2(dict, false);
      expect(result).toEqual([]);
    });

    it('should handle bancontact payment method type', () => {
      const dict = {
        required_fields: [
          JSON.stringify({
            required_field: 'payment_method_data.billing.address.line1',
            display_name: 'Address',
            field_type: 'AddressLine1',
            value: '',
          }),
        ],
      };

      const result = getDynamicFieldsFromJsonDictV2(dict, true);
      expect(result.length).toBe(1);
    });
  });

  describe('getCardNetworks', () => {
    it('should extract card networks from array', () => {
      const networksArr = [
        {
          card_network: 'Visa',
          eligible_connectors: ['connector1', 'connector2'],
          surcharge_details: {
            surcharge_amount: 100,
          },
        },
        {
          card_network: 'Mastercard',
          eligible_connectors: ['connector3'],
          surcharge_details: null,
        },
      ];

      const result = getCardNetworks(networksArr);

      expect(result.length).toBe(2);
      expect(result[0].cardNetwork).toBe('VISA');
      expect(result[0].eligibleConnectors).toEqual(['connector1', 'connector2']);
      expect(result[1].cardNetwork).toBe('MASTERCARD');
    });

    it('should return empty array for empty input', () => {
      const result = getCardNetworks([]);
      expect(result).toEqual([]);
    });

    it('should handle invalid items in array', () => {
      const networksArr = [null, undefined, 'invalid'];
      const result = getCardNetworks(networksArr);
      expect(result).toEqual([]);
    });
  });

  describe('itemToPaymentsEnabledMapper', () => {
    it('should map payment methods enabled array', () => {
      const methodsArray = [
        {
          payment_method_type: 'card',
          payment_method_subtype: 'credit',
          bank_names: [],
          card_networks: [
            {
              card_network: 'Visa',
              eligible_connectors: ['stripe'],
            },
          ],
          required_fields: [
            {
              required_field: 'payment_method_data.email',
              display_name: 'Email',
              field_type: 'Email',
              value: '',
            },
          ],
          payment_experience: ['ADD_AND_PAY'],
        },
      ];

      const result = itemToPaymentsEnabledMapper(methodsArray);

      expect(result.length).toBe(1);
      expect(result[0].paymentMethodType).toBe('card');
      expect(result[0].paymentMethodSubtype).toBe('credit');
      expect(result[0].cardNetworks.length).toBe(1);
      expect(result[0].cardNetworks[0].cardNetwork).toBe('VISA');
      expect(result[0].requiredFields.length).toBe(1);
      expect(result[0].paymentExperience.length).toBe(1);
    });

    it('should return empty array for empty input', () => {
      const result = itemToPaymentsEnabledMapper([]);
      expect(result).toEqual([]);
    });

    it('should handle bancontact_card subtype', () => {
      const methodsArray = [
        {
          payment_method_type: 'card',
          payment_method_subtype: 'bancontact_card',
          bank_names: [],
          card_networks: [],
          required_fields: [],
          payment_experience: [],
        },
      ];

      const result = itemToPaymentsEnabledMapper(methodsArray);

      expect(result.length).toBe(1);
      expect(result[0].paymentMethodSubtype).toBe('bancontact_card');
    });
  });

  describe('itemToPaymentsObjMapper', () => {
    it('should map customer dict to payments object', () => {
      const customerDict = {
        payment_methods_enabled: [
          {
            payment_method_type: 'card',
            payment_method_subtype: 'credit',
            bank_names: [],
            card_networks: [],
            required_fields: [],
            payment_experience: [],
          },
        ],
        customer_payment_methods: [
          {
            payment_method_token: 'token123',
            customer_id: 'cust_123',
            payment_method_type: 'card',
            payment_method_subtype: 'credit',
            payment_method_data: {
              card: {
                card_network: 'visa',
                last4_digits: '4242',
              },
            },
          },
        ],
      };

      const result = itemToPaymentsObjMapper(customerDict);

      expect(result.paymentMethodsEnabled.length).toBe(1);
      expect(result.customerPaymentMethods.length).toBe(1);
      expect(result.customerPaymentMethods[0].paymentToken).toBe('token123');
    });

    it('should handle empty dict', () => {
      const result = itemToPaymentsObjMapper({});

      expect(result.paymentMethodsEnabled).toEqual([]);
      expect(result.customerPaymentMethods).toEqual([]);
    });
  });

  describe('createPaymentsObjArr', () => {
    it('should create payments object array from dict', () => {
      const dict = {
        payments: {
          payment_methods_enabled: [
            {
              payment_method_type: 'card',
              payment_method_subtype: 'credit',
              bank_names: [],
              card_networks: [],
              required_fields: [],
              payment_experience: [],
            },
          ],
          customer_payment_methods: [],
        },
      };

      const result = createPaymentsObjArr(dict, 'payments');

      expect(result.TAG).toBe('LoadedV2');
      expect(result._0.paymentMethodsEnabled.length).toBe(1);
    });

    it('should handle missing key in dict', () => {
      const dict = {};
      const result = createPaymentsObjArr(dict, 'missing_key');

      expect(result.TAG).toBe('LoadedV2');
      expect(result._0.paymentMethodsEnabled).toEqual([]);
      expect(result._0.customerPaymentMethods).toEqual([]);
    });

    it('should handle null value for key', () => {
      const dict = {
        payments: null,
      };
      const result = createPaymentsObjArr(dict, 'payments');

      expect(result.TAG).toBe('LoadedV2');
    });
  });

  describe('itemToPaymentDetails', () => {
    it('should extract payment details from dict', () => {
      const dict = {
        payment_method_token: 'token789',
        customer_id: 'cust_789',
        payment_method_type: 'card',
        payment_method_subtype: 'debit',
        recurring_enabled: false,
        is_default: false,
        requires_cvv: true,
        last_used_at: '2024-06-01',
        created: '2024-01-01',
        payment_method_data: {
          card: {
            card_network: 'mastercard',
            last4_digits: '5555',
            expiry_month: '06',
            expiry_year: '2026',
            card_fingerprint: 'fp456',
            card_isin: '555555',
            card_type: 'debit',
            saved_to_locker: true,
          },
        },
      };

      const result = itemToPaymentDetails(dict);

      expect(result.paymentToken).toBe('token789');
      expect(result.customerId).toBe('cust_789');
      expect(result.paymentMethodType).toBe('card');
      expect(result.paymentMethodSubType).toBe('debit');
      expect(result.recurringEnabled).toBe(false);
      expect(result.isDefault).toBe(false);
      expect(result.requiresCvv).toBe(true);
      expect(result.paymentMethodData.card.last4Digits).toBe('5555');
      expect(result.paymentMethodData.card.network).toBe('mastercard');
      expect(result.bank.mask).toBe('');
    });

    it('should handle dict with missing payment_method_data', () => {
      const dict = {
        payment_method_token: 'token999',
        customer_id: 'cust_999',
        payment_method_type: 'card',
      };

      const result = itemToPaymentDetails(dict);

      expect(result.paymentToken).toBe('token999');
      expect(result.paymentMethodData.card.last4Digits).toBe('');
    });

    it('should return default values for empty dict', () => {
      const result = itemToPaymentDetails({});

      expect(result.paymentToken).toBe('');
      expect(result.customerId).toBe('');
      expect(result.recurringEnabled).toBe(false);
      expect(result.isDefault).toBe(false);
    });
  });

  describe('itemToPaymentMethodsUpdateMapper', () => {
    it('should map payment methods update dict', () => {
      const dict = {
        payment_method_data: {
          card: {
            card_network: 'visa',
            last4_digits: '1234',
            expiry_month: '01',
            expiry_year: '2027',
            card_fingerprint: 'fp789',
            card_isin: '123456',
            card_type: 'credit',
            saved_to_locker: false,
          },
        },
        associated_payment_methods: [],
      };

      const result = itemToPaymentMethodsUpdateMapper(dict);

      expect(result.paymentMethodData.card.last4Digits).toBe('1234');
      expect(result.paymentMethodData.card.network).toBe('visa');
      expect(result.associatedPaymentMethods).toEqual([]);
    });

    it('should handle missing payment_method_data', () => {
      const dict = {
        associated_payment_methods: [],
      };

      const result = itemToPaymentMethodsUpdateMapper(dict);

      expect(result.paymentMethodData.card.last4Digits).toBe('');
    });

    it('should handle empty dict', () => {
      const result = itemToPaymentMethodsUpdateMapper({});

      expect(result.paymentMethodData.card.last4Digits).toBe('');
    });
  });

  describe('default objects', () => {
    it('defaultAddress should have expected structure', () => {
      expect(defaultAddress.city).toBe('');
      expect(defaultAddress.country).toBe('');
      expect(defaultAddress.line1).toBe('');
      expect(defaultAddress.line2).toBe('');
      expect(defaultAddress.line3).toBe('');
      expect(defaultAddress.zip).toBe('');
      expect(defaultAddress.state).toBe('');
      expect(defaultAddress.firstName).toBe('');
      expect(defaultAddress.lastName).toBe('');
    });

    it('defaultBilling should have expected structure', () => {
      expect(defaultBilling.address).toEqual(defaultAddress);
      expect(defaultBilling.phone.number).toBe('');
      expect(defaultBilling.phone.countryCode).toBe('');
      expect(defaultBilling.email).toBe('');
    });

    it('defaultPaymentMethods should have expected structure', () => {
      expect(defaultPaymentMethods.paymentMethodType).toBe('');
      expect(defaultPaymentMethods.paymentMethodSubtype).toBe('');
      expect(defaultPaymentMethods.requiredFields).toEqual([]);
      expect(defaultPaymentMethods.paymentExperience).toEqual([]);
    });

    it('defaultCustomerMethods should have expected structure', () => {
      expect(defaultCustomerMethods.paymentToken).toBe('');
      expect(defaultCustomerMethods.customerId).toBe('');
      expect(defaultCustomerMethods.paymentMethodType).toBe('');
      expect(defaultCustomerMethods.recurringEnabled).toBe(false);
      expect(defaultCustomerMethods.isDefault).toBe(false);
      expect(defaultCustomerMethods.bank.mask).toBe('');
    });

    it('defaultPaymentsList should have expected structure', () => {
      expect(Array.isArray(defaultPaymentsList.paymentMethodsEnabled)).toBe(true);
      expect(Array.isArray(defaultPaymentsList.customerPaymentMethods)).toBe(true);
    });
  });
});
