import {
  getPaymentMethodsFieldsOrder,
  sortPaymentMethodFields,
  getPaymentMethodsFieldTypeFromString,
  getIsBillingField,
  getIsAnyBillingDetailEmpty,
  getPaymentExperienceType,
  paymentTypeMapper,
  paymentTypeToStringMapper,
  getCardNetworks,
  getBankNames,
  getAchConnectors,
  getAmountDetails,
  getInstallmentPlan,
  getOptionalMandateType,
  getMandate,
  getIntentData,
  getSurchargeDetails,
  getFieldType,
  getPaymentMethodsFieldTypeFromDict,
  getPaymentMethodTypeFromList,
  getCardNetwork,
  defaultCardNetworks,
  defaultMethods,
  defaultPaymentMethodType,
  defaultList,
  defaultIntentData,
} from '../Payments/PaymentMethodsRecord.bs.js';

describe('PaymentMethodsRecord', () => {
  describe('getPaymentMethodsFieldsOrder', () => {
    it('should return 0 for CardNumber', () => {
      expect(getPaymentMethodsFieldsOrder('CardNumber')).toBe(0);
    });

    it('should return 1 for CardExpiryMonth', () => {
      expect(getPaymentMethodsFieldsOrder('CardExpiryMonth')).toBe(1);
    });

    it('should return 1 for CardExpiryYear', () => {
      expect(getPaymentMethodsFieldsOrder('CardExpiryYear')).toBe(1);
    });

    it('should return 1 for CardExpiryMonthAndYear', () => {
      expect(getPaymentMethodsFieldsOrder('CardExpiryMonthAndYear')).toBe(1);
    });

    it('should return 2 for CardCvc', () => {
      expect(getPaymentMethodsFieldsOrder('CardCvc')).toBe(2);
    });

    it('should return 2 for CardExpiryAndCvc', () => {
      expect(getPaymentMethodsFieldsOrder('CardExpiryAndCvc')).toBe(2);
    });

    it('should return 4 for AddressLine1', () => {
      expect(getPaymentMethodsFieldsOrder('AddressLine1')).toBe(4);
    });

    it('should return 5 for AddressLine2', () => {
      expect(getPaymentMethodsFieldsOrder('AddressLine2')).toBe(5);
    });

    it('should return 6 for AddressCity', () => {
      expect(getPaymentMethodsFieldsOrder('AddressCity')).toBe(6);
    });

    it('should return 7 for AddressState', () => {
      expect(getPaymentMethodsFieldsOrder('AddressState')).toBe(7);
    });

    it('should return 7 for StateAndCity', () => {
      expect(getPaymentMethodsFieldsOrder('StateAndCity')).toBe(7);
    });

    it('should return 99 for InfoElement', () => {
      expect(getPaymentMethodsFieldsOrder('InfoElement')).toBe(99);
    });

    it('should return 9 for AddressPincode', () => {
      expect(getPaymentMethodsFieldsOrder('AddressPincode')).toBe(9);
    });

    it('should return 9 for PixCPF', () => {
      expect(getPaymentMethodsFieldsOrder('PixCPF')).toBe(9);
    });

    it('should return 10 for PixCNPJ', () => {
      expect(getPaymentMethodsFieldsOrder('PixCNPJ')).toBe(10);
    });

    it('should return 3 for Email', () => {
      expect(getPaymentMethodsFieldsOrder('Email')).toBe(3);
    });

    it('should return 8 for CountryAndPincode object', () => {
      expect(getPaymentMethodsFieldsOrder({ TAG: 'CountryAndPincode', _0: 'test' })).toBe(8);
    });

    it('should return 8 for AddressCountry object', () => {
      expect(getPaymentMethodsFieldsOrder({ TAG: 'AddressCountry', _0: [] })).toBe(8);
    });

    it('should return 3 for unknown string field', () => {
      expect(getPaymentMethodsFieldsOrder('UnknownField')).toBe(3);
    });
  });

  describe('sortPaymentMethodFields', () => {
    it('should return negative when first field has lower order', () => {
      const result = sortPaymentMethodFields('CardNumber', 'CardCvc');
      expect(result).toBeLessThan(0);
    });

    it('should return positive when first field has higher order', () => {
      const result = sortPaymentMethodFields('CardCvc', 'CardNumber');
      expect(result).toBeGreaterThan(0);
    });

    it('should return 0 when fields have same order', () => {
      const result = sortPaymentMethodFields('CardExpiryMonth', 'CardExpiryYear');
      expect(result).toBe(0);
    });
  });

  describe('getPaymentMethodsFieldTypeFromString', () => {
    it('should return "AddressCity" for "user_address_city"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_address_city', false)).toBe('AddressCity');
    });

    it('should return "AddressLine1" for "user_address_line1"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_address_line1', false)).toBe('AddressLine1');
    });

    it('should return "Bank" for "user_bank"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_bank', false)).toBe('Bank');
    });

    it('should return "Email" for "user_email_address"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_email_address', false)).toBe('Email');
    });

    it('should return "PhoneNumber" for "user_phone_number"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_phone_number', false)).toBe('PhoneNumber');
    });

    it('should return "PixKey" for "user_pix_key"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_pix_key', false)).toBe('PixKey');
    });

    it('should return "CardNumber" for "user_card_number" when isBancontact is true', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_card_number', true)).toBe('CardNumber');
    });

    it('should return "None" for "user_card_number" when isBancontact is false', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_card_number', false)).toBe('None');
    });

    it('should return "CardCvc" for "user_card_cvc" when isBancontact is true', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_card_cvc', true)).toBe('CardCvc');
    });

    it('should return "None" for "user_card_cvc" when isBancontact is false', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_card_cvc', false)).toBe('None');
    });

    it('should return "None" for unknown field type', () => {
      expect(getPaymentMethodsFieldTypeFromString('unknown_field', false)).toBe('None');
    });

    it('should return "VpaId" for "user_vpa_id"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_vpa_id', false)).toBe('VpaId');
    });

    it('should return "BankAccountNumber" for "user_iban"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_iban', false)).toBe('BankAccountNumber');
    });

    it('should return "CryptoCurrencyNetworks" for "user_crypto_currency_network"', () => {
      expect(getPaymentMethodsFieldTypeFromString('user_crypto_currency_network', false)).toBe('CryptoCurrencyNetworks');
    });
  });

  describe('getIsBillingField', () => {
    it('should return true for AddressLine1', () => {
      expect(getIsBillingField('AddressLine1')).toBe(true);
    });

    it('should return true for AddressLine2', () => {
      expect(getIsBillingField('AddressLine2')).toBe(true);
    });

    it('should return true for AddressCity', () => {
      expect(getIsBillingField('AddressCity')).toBe(true);
    });

    it('should return true for AddressPincode', () => {
      expect(getIsBillingField('AddressPincode')).toBe(true);
    });

    it('should return true for AddressState', () => {
      expect(getIsBillingField('AddressState')).toBe(true);
    });

    it('should return true for AddressCountry object', () => {
      expect(getIsBillingField({ TAG: 'AddressCountry', _0: [] })).toBe(true);
    });

    it('should return false for non-billing fields', () => {
      expect(getIsBillingField('Email')).toBe(false);
    });

    it('should return false for CardNumber', () => {
      expect(getIsBillingField('CardNumber')).toBe(false);
    });

    it('should return false for ShippingAddressCountry object', () => {
      expect(getIsBillingField({ TAG: 'ShippingAddressCountry', _0: [] })).toBe(false);
    });
  });

  describe('getIsAnyBillingDetailEmpty', () => {
    it('should return true when a billing field has empty value', () => {
      const requiredFields = [
        { field_type: 'AddressLine1', value: '', display_name: 'address_line1' },
        { field_type: 'Email', value: 'test@example.com', display_name: 'email' },
      ];
      expect(getIsAnyBillingDetailEmpty(requiredFields)).toBe(true);
    });

    it('should return false when all billing fields have values', () => {
      const requiredFields = [
        { field_type: 'AddressLine1', value: '123 Main St', display_name: 'address_line1' },
        { field_type: 'Email', value: 'test@example.com', display_name: 'email' },
      ];
      expect(getIsAnyBillingDetailEmpty(requiredFields)).toBe(false);
    });

    it('should return false when no billing fields are present', () => {
      const requiredFields = [
        { field_type: 'Email', value: '', display_name: 'email' },
        { field_type: 'PhoneNumber', value: '', display_name: 'phone' },
      ];
      expect(getIsAnyBillingDetailEmpty(requiredFields)).toBe(false);
    });

    it('should return false for empty array', () => {
      expect(getIsAnyBillingDetailEmpty([])).toBe(false);
    });
  });

  describe('getPaymentExperienceType', () => {
    it('should return "QrFlow" for "display_qr_code"', () => {
      expect(getPaymentExperienceType('display_qr_code')).toBe('QrFlow');
    });

    it('should return "InvokeSDK" for "invoke_sdk_client"', () => {
      expect(getPaymentExperienceType('invoke_sdk_client')).toBe('InvokeSDK');
    });

    it('should return "RedirectToURL" for unknown type', () => {
      expect(getPaymentExperienceType('unknown')).toBe('RedirectToURL');
    });

    it('should return "RedirectToURL" for empty string', () => {
      expect(getPaymentExperienceType('')).toBe('RedirectToURL');
    });
  });

  describe('paymentTypeMapper', () => {
    it('should return "NEW_MANDATE" for "new_mandate"', () => {
      expect(paymentTypeMapper('new_mandate')).toBe('NEW_MANDATE');
    });

    it('should return "NORMAL" for "normal"', () => {
      expect(paymentTypeMapper('normal')).toBe('NORMAL');
    });

    it('should return "SETUP_MANDATE" for "setup_mandate"', () => {
      expect(paymentTypeMapper('setup_mandate')).toBe('SETUP_MANDATE');
    });

    it('should return "NONE" for unknown type', () => {
      expect(paymentTypeMapper('unknown')).toBe('NONE');
    });

    it('should return "NONE" for empty string', () => {
      expect(paymentTypeMapper('')).toBe('NONE');
    });
  });

  describe('paymentTypeToStringMapper', () => {
    it('should return "normal" for "NORMAL"', () => {
      expect(paymentTypeToStringMapper('NORMAL')).toBe('normal');
    });

    it('should return "new_mandate" for "NEW_MANDATE"', () => {
      expect(paymentTypeToStringMapper('NEW_MANDATE')).toBe('new_mandate');
    });

    it('should return "setup_mandate" for "SETUP_MANDATE"', () => {
      expect(paymentTypeToStringMapper('SETUP_MANDATE')).toBe('setup_mandate');
    });

    it('should return "" for "NONE"', () => {
      expect(paymentTypeToStringMapper('NONE')).toBe('');
    });
  });

  describe('getAmountDetails', () => {
    it('should extract amount details from dict', () => {
      const dict = {
        amount_per_installment: 50.0,
        total_amount: 150.0,
      };
      const result = getAmountDetails(dict);
      expect(result.amount_per_installment).toBe(50.0);
      expect(result.total_amount).toBe(150.0);
    });

    it('should return 0 for missing fields', () => {
      const result = getAmountDetails({});
      expect(result.amount_per_installment).toBe(0);
      expect(result.total_amount).toBe(0);
    });
  });

  describe('getInstallmentPlan', () => {
    it('should extract installment plan from dict', () => {
      const dict = {
        interest_rate: 5.0,
        number_of_installments: 3,
        billing_frequency: 'MONTHLY',
        amount_details: {
          amount_per_installment: 100.0,
          total_amount: 300.0,
        },
      };
      const result = getInstallmentPlan(dict);
      expect(result.interest_rate).toBe(5.0);
      expect(result.number_of_installments).toBe(3);
      expect(result.billing_frequency).toBe('MONTHLY');
      expect(result.amount_details.amount_per_installment).toBe(100.0);
      expect(result.amount_details.total_amount).toBe(300.0);
    });

    it('should handle missing fields with defaults', () => {
      const result = getInstallmentPlan({});
      expect(result.interest_rate).toBe(0);
      expect(result.number_of_installments).toBe(0);
      expect(result.billing_frequency).toBe('');
    });
  });

  describe('getOptionalMandateType', () => {
    it('should extract mandate type from dict', () => {
      const dict = {
        single_use: {
          amount: 100,
          currency: 'USD',
        },
      };
      const result = getOptionalMandateType(dict, 'single_use');
      expect(result).toBeDefined();
      if (result !== undefined) {
        expect(result.amount).toBe(100);
        expect(result.currency).toBe('USD');
      }
    });

    it('should return undefined for missing key', () => {
      const result = getOptionalMandateType({}, 'single_use');
      expect(result).toBeUndefined();
    });
  });

  describe('getMandate', () => {
    it('should extract mandate from dict', () => {
      const dict = {
        mandate_payment: {
          single_use: {
            amount: 100,
            currency: 'USD',
          },
          multi_use: {
            amount: 500,
            currency: 'EUR',
          },
        },
      };
      const result = getMandate(dict, 'mandate_payment');
      expect(result).toBeDefined();
    });

    it('should return undefined for missing key', () => {
      const result = getMandate({}, 'mandate_payment');
      expect(result).toBeUndefined();
    });
  });

  describe('getIntentData', () => {
    it('should extract intent data from dict', () => {
      const dict = {
        currency: 'USD',
        intent_data: {
          installment_options: [],
        },
      };
      const result = getIntentData(dict);
      expect(result.currency).toBe('USD');
    });

    it('should handle missing fields with defaults', () => {
      const result = getIntentData({});
      expect(result.currency).toBe('');
    });
  });

  describe('getSurchargeDetails', () => {
    it('should extract surcharge details when displayTotalSurchargeAmount is non-zero', () => {
      const dict = {
        surcharge_details: {
          display_total_surcharge_amount: 10.5,
        },
      };
      const result = getSurchargeDetails(dict);
      expect(result).toBeDefined();
      expect(result?.displayTotalSurchargeAmount).toBe(10.5);
    });

    it('should return undefined when displayTotalSurchargeAmount is 0', () => {
      const dict = {
        surcharge_details: {
          display_total_surcharge_amount: 0.0,
        },
      };
      const result = getSurchargeDetails(dict);
      expect(result).toBeUndefined();
    });

    it('should return undefined when surcharge_details is missing', () => {
      const result = getSurchargeDetails({});
      expect(result).toBeUndefined();
    });
  });

  describe('defaultCardNetworks', () => {
    it('should have card_network "NOTFOUND"', () => {
      expect(defaultCardNetworks.card_network).toBe('NOTFOUND');
    });

    it('should have empty eligible_connectors', () => {
      expect(defaultCardNetworks.eligible_connectors).toEqual([]);
    });
  });

  describe('defaultMethods', () => {
    it('should have payment_method "card"', () => {
      expect(defaultMethods.payment_method).toBe('card');
    });

    it('should have empty payment_method_types', () => {
      expect(defaultMethods.payment_method_types).toEqual([]);
    });
  });

  describe('defaultPaymentMethodType', () => {
    it('should have empty payment_method_type', () => {
      expect(defaultPaymentMethodType.payment_method_type).toBe('');
    });

    it('should have empty arrays for collections', () => {
      expect(defaultPaymentMethodType.card_networks).toEqual([]);
      expect(defaultPaymentMethodType.bank_names).toEqual([]);
      expect(defaultPaymentMethodType.required_fields).toEqual([]);
    });
  });

  describe('defaultList', () => {
    it('should have empty redirect_url', () => {
      expect(defaultList.redirect_url).toBe('');
    });

    it('should have empty currency', () => {
      expect(defaultList.currency).toBe('');
    });

    it('should have payment_type "NONE"', () => {
      expect(defaultList.payment_type).toBe('NONE');
    });

    it('should have collect_billing_details_from_wallets true', () => {
      expect(defaultList.collect_billing_details_from_wallets).toBe(true);
    });

    it('should have is_tax_calculation_enabled false', () => {
      expect(defaultList.is_tax_calculation_enabled).toBe(false);
    });
  });

  describe('defaultIntentData', () => {
    it('should have empty currency', () => {
      expect(defaultIntentData.currency).toBe('');
    });

    it('should have undefined installment_options', () => {
      expect(defaultIntentData.installment_options).toBeUndefined();
    });
  });

  describe('getFieldType', () => {
    it('should return field type from string field_type', () => {
      const dict = { field_type: 'user_email_address' };
      const result = getFieldType(dict, false);
      expect(result).toBe('Email');
    });

    it('should return "None" for non-string field_type', () => {
      const dict = { field_type: 123 };
      const result = getFieldType(dict, false);
      expect(result).toBe('None');
    });

    it('should return "None" for missing field_type', () => {
      const result = getFieldType({}, false);
      expect(result).toBe('None');
    });

    it('should handle bancontact card number field', () => {
      const dict = { field_type: 'user_card_number' };
      const result = getFieldType(dict, true);
      expect(result).toBe('CardNumber');
    });

    it('should return "None" for card fields when not bancontact', () => {
      const dict = { field_type: 'user_card_number' };
      const result = getFieldType(dict, false);
      expect(result).toBe('None');
    });
  });

  describe('getPaymentMethodsFieldTypeFromDict', () => {
    it('should return LanguagePreference for language_preference key', () => {
      const dict = {
        language_preference: {
          options: ['en', 'fr'],
        },
      };
      const result = getPaymentMethodsFieldTypeFromDict(dict);
      expect(typeof result).toBe('object');
      if (typeof result === 'object' && result !== null && 'TAG' in result) {
        expect(result.TAG).toBe('LanguagePreference');
      }
    });

    it('should return BankList for user_bank_options key', () => {
      const dict = {
        user_bank_options: {
          options: ['bank1', 'bank2'],
        },
      };
      const result = getPaymentMethodsFieldTypeFromDict(dict);
      expect(typeof result).toBe('object');
      if (typeof result === 'object' && result !== null && 'TAG' in result) {
        expect(result.TAG).toBe('BankList');
      }
    });

    it('should return Currency for user_currency key', () => {
      const dict = {
        user_currency: {
          options: ['USD', 'EUR'],
        },
      };
      const result = getPaymentMethodsFieldTypeFromDict(dict);
      expect(typeof result).toBe('object');
      if (typeof result === 'object' && result !== null && 'TAG' in result) {
        expect(result.TAG).toBe('Currency');
      }
    });

    it('should return DocumentType for user_document_type key', () => {
      const dict = {
        user_document_type: {
          options: ['passport', 'id_card'],
        },
      };
      const result = getPaymentMethodsFieldTypeFromDict(dict);
      expect(typeof result).toBe('object');
      if (typeof result === 'object' && result !== null && 'TAG' in result) {
        expect(result.TAG).toBe('DocumentType');
      }
    });

    it('should return "None" for unknown key', () => {
      const dict = { unknown_key: {} };
      const result = getPaymentMethodsFieldTypeFromDict(dict);
      expect(result).toBe('None');
    });
  });

  describe('getPaymentMethodTypeFromList', () => {
    it('should return payment method type from list', () => {
      const paymentMethodListValue = {
        payment_methods: [
          {
            payment_method: 'card',
            payment_method_types: [
              { payment_method_type: 'credit', card_networks: [], bank_names: [] },
              { payment_method_type: 'debit', card_networks: [], bank_names: [] },
            ],
          },
        ],
      };
      const result = getPaymentMethodTypeFromList(paymentMethodListValue, 'card', 'credit');
      expect(result).toBeDefined();
      expect(result?.payment_method_type).toBe('credit');
    });

    it('should return undefined for non-existent payment method', () => {
      const paymentMethodListValue = {
        payment_methods: [
          {
            payment_method: 'card',
            payment_method_types: [],
          },
        ],
      };
      const result = getPaymentMethodTypeFromList(paymentMethodListValue, 'wallet', 'apple_pay');
      expect(result).toBeUndefined();
    });

    it('should return undefined for non-existent payment method type', () => {
      const paymentMethodListValue = {
        payment_methods: [
          {
            payment_method: 'card',
            payment_method_types: [
              { payment_method_type: 'credit', card_networks: [], bank_names: [] },
            ],
          },
        ],
      };
      const result = getPaymentMethodTypeFromList(paymentMethodListValue, 'card', 'debit');
      expect(result).toBeUndefined();
    });
  });

  describe('getCardNetwork', () => {
    it('should return matching card network', () => {
      const paymentMethodType = {
        payment_method_type: 'credit',
        card_networks: [
          { card_network: 'visa', eligible_connectors: ['connector1'] },
          { card_network: 'mastercard', eligible_connectors: ['connector2'] },
        ],
        bank_names: [],
      };
      const result = getCardNetwork(paymentMethodType, 'visa');
      expect(result.card_network).toBe('visa');
      expect(result.eligible_connectors).toEqual(['connector1']);
    });

    it('should return default card network for non-matching brand', () => {
      const paymentMethodType = {
        payment_method_type: 'credit',
        card_networks: [
          { card_network: 'visa', eligible_connectors: ['connector1'] },
        ],
        bank_names: [],
      };
      const result = getCardNetwork(paymentMethodType, 'amex');
      expect(result.card_network).toBe('NOTFOUND');
    });

    it('should return default for empty card networks', () => {
      const paymentMethodType = {
        payment_method_type: 'credit',
        card_networks: [],
        bank_names: [],
      };
      const result = getCardNetwork(paymentMethodType, 'visa');
      expect(result.card_network).toBe('NOTFOUND');
    });
  });
});
