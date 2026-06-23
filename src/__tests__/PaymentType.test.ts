import {
  getMessageDisplayMode,
  getPaymentMethodsArrangementForTabs,
  getShowType,
  getApplePayType,
  getGooglePayType,
  getSamsungPayType,
  getPayPalType,
  getTypeArray,
  getShowTerms,
  getGroupingBehaviorFromString,
  getTheme,
  normalizePath,
  isPathStartsWithPattern,
  shouldMaskField,
  getIsStoredPaymentMethodHasName,
  getConfirmParams,
  getSdkHandleConfirmPaymentProps,
  getSdkHandleSavePaymentProps,
  getCardDetails,
  getAddressDetails,
  getBank,
  getMaxItems,
  defaultCardDetails,
  defaultAddressDetails,
  defaultDisplayBillingDetails,
  defaultCustomerMethods,
  defaultGroupingBehavior,
  defaultSavedMethodCustomization,
  defaultLayout,
  defaultAddress,
  defaultBillingDetails,
  defaultBusiness,
  defaultDefaultValues,
  defaultshowAddress,
  defaultNeverShowAddress,
  defaultBilling,
  defaultNeverBilling,
  defaultTerms,
  defaultFields,
  defaultStyle,
  defaultWallets,
  defaultBillingAddress,
  defaultSdkHandleConfirmPayment,
  defaultSdkHandleSavePayment,
  defaultOptions,
  fieldsToExcludeFromMasking,
  overrideFieldsToExcludeFromMasking,
  getLayout,
  getAddress,
  getBillingDetails,
  getDefaultValues,
  getBusiness,
  getShowDetails,
  getShowAddressDetails,
  getShowAddress,
  getDeatils,
  getBilling,
  getFields,
  getGroupingBehaviorFromObject,
  getGroupingBehavior,
  getSavedMethodCustomization,
  getLayoutValues,
  getTerms,
  getApplePayHeight,
  getGooglePayHeight,
  getSamsungPayHeight,
  getPaypalHeight,
  getKlarnaHeight,
  getHeightArray,
  getStyle,
  getWallets,
  getBillingAddressPaymentMethod,
  getPaymentMethodType,
  itemToCustomerObjMapper,
  createCustomerObjArr,
  getCustomerMethods,
  getCustomMethodNames,
  getBillingAddress,
  sanitizePaymentElementOptions,
  sanitizePreloadSdkParms,
  itemToObjMapper,
  itemToPayerDetailsObjectMapper,
  convertClickToPayCardToCustomerMethod,
} from '../Types/PaymentType.bs.js';

describe('PaymentType', () => {
  describe('getMessageDisplayMode', () => {
    it('should return "CustomMessage" for "custom_message"', () => {
      expect(getMessageDisplayMode('custom_message', 'test.key')).toBe('CustomMessage');
    });

    it('should return "DefaultSdkMessage" for "default_sdk_message"', () => {
      expect(getMessageDisplayMode('default_sdk_message', 'test.key')).toBe('DefaultSdkMessage');
    });

    it('should return "Hidden" for "hidden"', () => {
      expect(getMessageDisplayMode('hidden', 'test.key')).toBe('Hidden');
    });

    it('should return "DefaultSdkMessage" for unknown values', () => {
      expect(getMessageDisplayMode('unknown', 'test.key')).toBe('DefaultSdkMessage');
    });

    it('should return "DefaultSdkMessage" for empty string', () => {
      expect(getMessageDisplayMode('', 'test.key')).toBe('DefaultSdkMessage');
    });
  });



  describe('getPaymentMethodsArrangementForTabs', () => {
    it('should return "Default" for "default"', () => {
      expect(getPaymentMethodsArrangementForTabs('default')).toBe('Default');
    });

    it('should return "Grid" for "grid"', () => {
      expect(getPaymentMethodsArrangementForTabs('grid')).toBe('Grid');
    });

    it('should return "Default" for unknown values', () => {
      expect(getPaymentMethodsArrangementForTabs('unknown')).toBe('Default');
    });

    it('should return "Default" for empty string', () => {
      expect(getPaymentMethodsArrangementForTabs('')).toBe('Default');
    });
  });

  describe('getShowType', () => {
    it('should return "Auto" for "auto"', () => {
      expect(getShowType('auto', 'test.key')).toBe('Auto');
    });

    it('should return "Never" for "never"', () => {
      expect(getShowType('never', 'test.key')).toBe('Never');
    });

    it('should return "Auto" for unknown values', () => {
      expect(getShowType('unknown', 'test.key')).toBe('Auto');
    });

    it('should return "Auto" for empty string', () => {
      expect(getShowType('', 'test.key')).toBe('Auto');
    });
  });

  describe('getApplePayType', () => {
    it('should return "Addmoney" for "add-money"', () => {
      const result = getApplePayType('add-money');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Addmoney');
    });

    it('should return "Addmoney" for "addmoney"', () => {
      const result = getApplePayType('addmoney');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Addmoney');
    });

    it('should return "Buy" for "buy"', () => {
      const result = getApplePayType('buy');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Buy');
    });

    it('should return "Buy" for "buynow"', () => {
      const result = getApplePayType('buynow');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Buy');
    });

    it('should return "Checkout" for "checkout"', () => {
      const result = getApplePayType('checkout');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Checkout');
    });

    it('should return "Donate" for "donate"', () => {
      const result = getApplePayType('donate');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Donate');
    });

    it('should return "Subscribe" for "subscribe"', () => {
      const result = getApplePayType('subscribe');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Subscribe');
    });

    it('should return "Default" for unknown values', () => {
      const result = getApplePayType('unknown');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Default');
    });
  });

  describe('getGooglePayType', () => {
    it('should return "Book" for "book"', () => {
      const result = getGooglePayType('book');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Book');
    });

    it('should return "Buy" for "buy"', () => {
      const result = getGooglePayType('buy');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Buy');
    });

    it('should return "Buy" for "buynow"', () => {
      const result = getGooglePayType('buynow');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Buy');
    });

    it('should return "Checkout" for "checkout"', () => {
      const result = getGooglePayType('checkout');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Checkout');
    });

    it('should return "Donate" for "donate"', () => {
      const result = getGooglePayType('donate');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Donate');
    });

    it('should return "Pay" for "pay"', () => {
      const result = getGooglePayType('pay');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Pay');
    });

    it('should return "Default" for unknown values', () => {
      const result = getGooglePayType('unknown');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Default');
    });
  });

  describe('getSamsungPayType', () => {
    it('should return "Buy" for any value', () => {
      const result = getSamsungPayType('any');
      expect(result.TAG).toBe('SamsungPay');
      expect(result._0).toBe('Buy');
    });

    it('should return "Buy" for empty string', () => {
      const result = getSamsungPayType('');
      expect(result.TAG).toBe('SamsungPay');
      expect(result._0).toBe('Buy');
    });
  });

  describe('getPayPalType', () => {
    it('should return "Buynow" for "buy"', () => {
      const result = getPayPalType('buy');
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe('Buynow');
    });

    it('should return "Buynow" for "buynow"', () => {
      const result = getPayPalType('buynow');
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe('Buynow');
    });

    it('should return "Checkout" for "checkout"', () => {
      const result = getPayPalType('checkout');
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe('Checkout');
    });

    it('should return "Installment" for "installment"', () => {
      const result = getPayPalType('installment');
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe('Installment');
    });

    it('should return "Pay" for "pay"', () => {
      const result = getPayPalType('pay');
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe('Pay');
    });

    it('should return "Paypal" for unknown values', () => {
      const result = getPayPalType('unknown');
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe('Paypal');
    });
  });

  describe('getTypeArray', () => {
    it('should return array of wallet type objects', () => {
      const result = getTypeArray('buy');
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(4);
    });

    it('should include ApplePay, GooglePay, Paypal, SamsungPay', () => {
      const result = getTypeArray('buy');
      expect(result[0].TAG).toBe('ApplePay');
      expect(result[1].TAG).toBe('GooglePay');
      expect(result[2].TAG).toBe('Paypal');
      expect(result[3].TAG).toBe('SamsungPay');
    });
  });

  describe('getShowTerms', () => {
    it('should return "Always" for "always"', () => {
      expect(getShowTerms('always', 'test.key')).toBe('Always');
    });

    it('should return "Auto" for "auto"', () => {
      expect(getShowTerms('auto', 'test.key')).toBe('Auto');
    });

    it('should return "Never" for "never"', () => {
      expect(getShowTerms('never', 'test.key')).toBe('Never');
    });

    it('should return "Auto" for unknown values', () => {
      expect(getShowTerms('unknown', 'test.key')).toBe('Auto');
    });
  });

  describe('getGroupingBehaviorFromString', () => {
    it('should return defaultGroupingBehavior for "default"', () => {
      const result = getGroupingBehaviorFromString('default');
      expect(result.displayInSeparateScreen).toBe(true);
      expect(result.groupByPaymentMethods).toBe(false);
    });

    it('should return grouped behavior for "groupByPaymentMethods"', () => {
      const result = getGroupingBehaviorFromString('groupByPaymentMethods');
      expect(result.displayInSeparateScreen).toBe(false);
      expect(result.groupByPaymentMethods).toBe(true);
    });

    it('should return default for unknown values', () => {
      const result = getGroupingBehaviorFromString('unknown');
      expect(result.displayInSeparateScreen).toBe(true);
      expect(result.groupByPaymentMethods).toBe(false);
    });
  });

  describe('getTheme', () => {
    it('should return "Dark" for "dark"', () => {
      expect(getTheme('dark')).toBe('Dark');
    });

    it('should return "Light" for "light"', () => {
      expect(getTheme('light')).toBe('Light');
    });

    it('should return "Outline" for "outline"', () => {
      expect(getTheme('outline')).toBe('Outline');
    });

    it('should return "Dark" for unknown values', () => {
      expect(getTheme('unknown')).toBe('Dark');
    });

    it('should return "Dark" for empty string', () => {
      expect(getTheme('')).toBe('Dark');
    });
  });

  describe('normalizePath', () => {
    it('should remove array index notation from path', () => {
      expect(normalizePath('field[0]')).toBe('field');
    });

    it('should handle multiple array indices', () => {
      expect(normalizePath('fields[0].subfield[1]')).toBe('fields.subfield');
    });

    it('should return path unchanged if no array indices', () => {
      expect(normalizePath('simple.path')).toBe('simple.path');
    });

    it('should handle empty string', () => {
      expect(normalizePath('')).toBe('');
    });

    it('should handle path with only array index', () => {
      expect(normalizePath('[0]')).toBe('');
    });
  });

  describe('isPathStartsWithPattern', () => {
    it('should return true when paths are equal', () => {
      expect(isPathStartsWithPattern('field', 'field')).toBe(true);
    });

    it('should return true when path starts with pattern followed by dot', () => {
      expect(isPathStartsWithPattern('field.subfield', 'field')).toBe(true);
    });

    it('should return false when path does not start with pattern', () => {
      expect(isPathStartsWithPattern('other.subfield', 'field')).toBe(false);
    });

    it('should return false when path starts with pattern prefix but not followed by dot', () => {
      expect(isPathStartsWithPattern('fieldExtra', 'field')).toBe(false);
    });
  });

  describe('shouldMaskField', () => {
    it('should return true for overridden paths', () => {
      expect(shouldMaskField('wallets.walletReturnUrl')).toBe(true);
    });

    it('should return true for non-excluded paths', () => {
      expect(shouldMaskField('someOtherField')).toBe(true);
    });

    it('should return false for excluded layout field', () => {
      expect(shouldMaskField('layout')).toBe(false);
    });

    it('should return false for excluded wallets field', () => {
      expect(shouldMaskField('wallets')).toBe(false);
    });

    it('should return false for nested excluded field', () => {
      expect(shouldMaskField('layout.someNestedField')).toBe(false);
    });

    it('should return true for paymentMethodsConfig.message.value', () => {
      expect(shouldMaskField('paymentMethodsConfig.paymentMethodTypes.message.value')).toBe(true);
    });
  });

  describe('getIsStoredPaymentMethodHasName', () => {
    it('should return true when cardHolderName is present', () => {
      const savedMethod = {
        card: {
          cardHolderName: 'John Doe',
          scheme: 'Visa',
          last4Digits: '4242',
          expiryMonth: '12',
          expiryYear: '2025',
          cardToken: 'token',
          nickname: '',
          isClickToPayCard: false,
          cardBin: '424242',
        },
      };
      expect(getIsStoredPaymentMethodHasName(savedMethod)).toBe(true);
    });

    it('should return false when cardHolderName is undefined', () => {
      const savedMethod = {
        card: {
          cardHolderName: undefined,
          scheme: 'Visa',
          last4Digits: '4242',
          expiryMonth: '12',
          expiryYear: '2025',
          cardToken: 'token',
          nickname: '',
          isClickToPayCard: false,
          cardBin: '424242',
        },
      };
      expect(getIsStoredPaymentMethodHasName(savedMethod)).toBe(false);
    });

    it('should return false when cardHolderName is empty string', () => {
      const savedMethod = {
        card: {
          cardHolderName: '',
          scheme: 'Visa',
          last4Digits: '4242',
          expiryMonth: '12',
          expiryYear: '2025',
          cardToken: 'token',
          nickname: '',
          isClickToPayCard: false,
          cardBin: '424242',
        },
      };
      expect(getIsStoredPaymentMethodHasName(savedMethod)).toBe(false);
    });
  });

  describe('getConfirmParams', () => {
    it('should extract confirm params from dict', () => {
      const dict = {
        return_url: 'https://example.com/return',
        publishableKey: 'pk_test_123',
        redirect: 'if_required',
      };
      const result = getConfirmParams(dict);
      expect(result.return_url).toBe('https://example.com/return');
      expect(result.publishableKey).toBe('pk_test_123');
      expect(result.redirect).toBe('if_required');
    });

    it('should handle missing fields with defaults', () => {
      const result = getConfirmParams({});
      expect(result.return_url).toBe('');
      expect(result.publishableKey).toBe('');
      expect(result.redirect).toBe('if_required');
    });

    it('should use default redirect when not specified', () => {
      const dict = { return_url: 'https://test.com' };
      const result = getConfirmParams(dict);
      expect(result.redirect).toBe('if_required');
    });
  });

  describe('getSdkHandleConfirmPaymentProps', () => {
    it('should extract SDK handle confirm payment props', () => {
      const dict = {
        handleConfirm: true,
        buttonText: 'Pay Now',
        confirmParams: {
          return_url: 'https://example.com/return',
        },
      };
      const result = getSdkHandleConfirmPaymentProps(dict);
      expect(result.handleConfirm).toBe(true);
      expect(result.buttonText).toBe('Pay Now');
      expect(result.confirmParams.return_url).toBe('https://example.com/return');
    });

    it('should handle missing optional fields', () => {
      const dict = {
        handleConfirm: false,
        confirmParams: {},
      };
      const result = getSdkHandleConfirmPaymentProps(dict);
      expect(result.handleConfirm).toBe(false);
      expect(result.buttonText).toBeUndefined();
    });
  });

  describe('getSdkHandleSavePaymentProps', () => {
    it('should extract SDK handle save payment props', () => {
      const dict = {
        handleSave: true,
        buttonText: 'Save Card',
        confirmParams: {
          return_url: 'https://example.com/return',
        },
      };
      const result = getSdkHandleSavePaymentProps(dict);
      expect(result.handleSave).toBe(true);
      expect(result.buttonText).toBe('Save Card');
      expect(result.confirmParams.return_url).toBe('https://example.com/return');
    });

    it('should handle missing optional fields', () => {
      const dict = {
        handleSave: false,
        confirmParams: {},
      };
      const result = getSdkHandleSavePaymentProps(dict);
      expect(result.handleSave).toBe(false);
      expect(result.buttonText).toBeUndefined();
    });
  });

  describe('defaultCardDetails', () => {
    it('should have expected default values', () => {
      expect(defaultCardDetails.scheme).toBeUndefined();
      expect(defaultCardDetails.last4Digits).toBe('');
      expect(defaultCardDetails.expiryMonth).toBe('');
      expect(defaultCardDetails.expiryYear).toBe('');
      expect(defaultCardDetails.cardToken).toBe('');
      expect(defaultCardDetails.cardHolderName).toBeUndefined();
      expect(defaultCardDetails.nickname).toBe('');
      expect(defaultCardDetails.isClickToPayCard).toBe(false);
      expect(defaultCardDetails.cardBin).toBe('');
    });
  });

  describe('defaultAddressDetails', () => {
    it('should have expected default values', () => {
      expect(defaultAddressDetails.line1).toBeUndefined();
      expect(defaultAddressDetails.line2).toBeUndefined();
      expect(defaultAddressDetails.city).toBeUndefined();
      expect(defaultAddressDetails.state).toBeUndefined();
      expect(defaultAddressDetails.country).toBeUndefined();
      expect(defaultAddressDetails.zip).toBeUndefined();
    });
  });

  describe('defaultGroupingBehavior', () => {
    it('should have expected default values', () => {
      expect(defaultGroupingBehavior.displayInSeparateScreen).toBe(true);
      expect(defaultGroupingBehavior.groupByPaymentMethods).toBe(false);
    });
  });

  describe('defaultSavedMethodCustomization', () => {
    it('should have expected default values', () => {
      expect(defaultSavedMethodCustomization.maxItems).toBe(4);
      expect(defaultSavedMethodCustomization.hideCardExpiry).toBe(false);
    });
  });

  describe('defaultLayout', () => {
    it('should have expected default values', () => {
      expect(defaultLayout.defaultCollapsed).toBe(false);
      expect(defaultLayout.radios).toBe(false);
      expect(defaultLayout.type).toBe('Tabs');
      expect(defaultLayout.maxAccordionItems).toBe(4);
    });
  });

  describe('defaultStyle', () => {
    it('should have expected default values', () => {
      expect(defaultStyle.theme).toBe('Light');
      expect(defaultStyle.buttonRadius).toBe(2);
    });
  });

  describe('defaultWallets', () => {
    it('should have expected default values', () => {
      expect(defaultWallets.walletReturnUrl).toBe('');
      expect(defaultWallets.applePay).toBe('Auto');
      expect(defaultWallets.googlePay).toBe('Auto');
      expect(defaultWallets.payPal).toBe('Auto');
    });
  });

  describe('defaultBillingAddress', () => {
    it('should have expected default values', () => {
      expect(defaultBillingAddress.isUseBillingAddress).toBe(false);
      expect(defaultBillingAddress.usePrefilledValues).toBe('Auto');
    });
  });

  describe('defaultTerms', () => {
    it('should have expected default values', () => {
      expect(defaultTerms.card).toBe('Auto');
      expect(defaultTerms.ideal).toBe('Auto');
      expect(defaultTerms.sofort).toBe('Auto');
    });
  });

  describe('fieldsToExcludeFromMasking', () => {
    it('should contain expected fields', () => {
      expect(fieldsToExcludeFromMasking).toContain('layout');
      expect(fieldsToExcludeFromMasking).toContain('wallets');
      expect(fieldsToExcludeFromMasking).toContain('paymentMethodsConfig');
      expect(fieldsToExcludeFromMasking).toContain('terms');
    });
  });

  describe('overrideFieldsToExcludeFromMasking', () => {
    it('should contain expected override fields', () => {
      expect(overrideFieldsToExcludeFromMasking).toContain('wallets.walletReturnUrl');
    });
  });

  describe('getCardDetails', () => {
    it('should extract card details from dict', () => {
      const dict = {
        card: {
          scheme: 'Visa',
          last4_digits: '4242',
          expiry_month: '12',
          expiry_year: '2025',
          card_token: 'tok_123',
          card_holder_name: 'John Doe',
          nick_name: 'My Card',
          card_isin: '424242',
        },
      };
      const result = getCardDetails(dict, 'card');
      expect(result.scheme).toBe('Visa');
      expect(result.last4Digits).toBe('4242');
      expect(result.expiryMonth).toBe('12');
      expect(result.expiryYear).toBe('2025');
      expect(result.cardToken).toBe('tok_123');
      expect(result.cardHolderName).toBe('John Doe');
      expect(result.nickname).toBe('My Card');
      expect(result.cardBin).toBe('424242');
    });

    it('should return defaultCardDetails when card key not present', () => {
      const result = getCardDetails({}, 'card');
      expect(result.scheme).toBeUndefined();
      expect(result.last4Digits).toBe('');
      expect(result.expiryMonth).toBe('');
    });

    it('should handle missing optional fields', () => {
      const dict = {
        card: {
          scheme: 'Mastercard',
          last4_digits: '1234',
        },
      };
      const result = getCardDetails(dict, 'card');
      expect(result.scheme).toBe('Mastercard');
      expect(result.last4Digits).toBe('1234');
      expect(result.cardHolderName).toBeUndefined();
    });
  });

  describe('getAddressDetails', () => {
    it('should extract address details from dict', () => {
      const dict = {
        address: {
          line1: '123 Main St',
          line2: 'Apt 4B',
          line3: 'Suite 100',
          city: 'New York',
          state: 'NY',
          country: 'US',
          zip: '10001',
        },
      };
      const result = getAddressDetails(dict, 'address');
      expect(result.line1).toBe('123 Main St');
      expect(result.line2).toBe('Apt 4B');
      expect(result.line3).toBe('Suite 100');
      expect(result.city).toBe('New York');
      expect(result.state).toBe('NY');
      expect(result.country).toBe('US');
      expect(result.zip).toBe('10001');
    });

    it('should return defaultAddressDetails when key not present', () => {
      const result = getAddressDetails({}, 'address');
      expect(result.line1).toBeUndefined();
      expect(result.city).toBeUndefined();
    });

    it('should handle partial address data', () => {
      const dict = {
        address: {
          city: 'Los Angeles',
          country: 'US',
        },
      };
      const result = getAddressDetails(dict, 'address');
      expect(result.city).toBe('Los Angeles');
      expect(result.country).toBe('US');
      expect(result.line1).toBe('');
    });
  });

  describe('getBank', () => {
    it('should extract bank details from dict', () => {
      const dict = {
        bank: {
          mask: '****1234',
        },
      };
      const result = getBank(dict);
      expect(result.mask).toBe('****1234');
    });

    it('should return empty mask for missing bank', () => {
      const result = getBank({});
      expect(result.mask).toBe('');
    });

    it('should handle empty bank object', () => {
      const dict = { bank: {} };
      const result = getBank(dict);
      expect(result.mask).toBe('');
    });
  });

  describe('getMaxItems', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return value when positive', () => {
      const dict = { maxItems: 10 };
      const result = getMaxItems(dict, 'maxItems', 4, mockLogger);
      expect(result).toBe(10);
    });

    it('should return default when value is zero', () => {
      const dict = { maxItems: 0 };
      const result = getMaxItems(dict, 'maxItems', 4, mockLogger);
      expect(result).toBe(4);
    });

    it('should return default when value is negative', () => {
      const dict = { maxItems: -5 };
      const result = getMaxItems(dict, 'maxItems', 4, mockLogger);
      expect(result).toBe(4);
    });

    it('should return default when key is missing', () => {
      const result = getMaxItems({}, 'maxItems', 4, mockLogger);
      expect(result).toBe(4);
    });
  });

  describe('getLayout', () => {
    it('should return ObjectLayout for dict with layout values', () => {
      const dict = {
        layout: { type: 'tabs' },
      };
      const result = getLayout(dict, 'layout');
      expect(result.TAG).toBe('ObjectLayout');
    });

    it('should return default ObjectLayout when key not present', () => {
      const result = getLayout({}, 'layout');
      expect(result.TAG).toBe('ObjectLayout');
      expect((result as any)._0.type).toBe('Tabs');
    });
  });

  describe('getAddress', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract address from dict', () => {
      const dict = {
        address: {
          line1: '123 Main St',
          line2: 'Apt 4B',
          city: 'New York',
          state: 'NY',
          country: 'US',
          postal_code: '10001',
        },
      };
      const result = getAddress(dict, 'address', mockLogger);
      expect(result.line1).toBe('123 Main St');
      expect(result.city).toBe('New York');
      expect(result.country).toBe('US');
      expect(result.postal_code).toBe('10001');
    });

    it('should return defaultAddress when key not present', () => {
      const result = getAddress({}, 'address', mockLogger);
      expect(result.line1).toBe('');
      expect(result.city).toBe('');
    });

    it('should handle partial address data', () => {
      const dict = {
        address: {
          city: 'Los Angeles',
          country: 'US',
        },
      };
      const result = getAddress(dict, 'address', mockLogger);
      expect(result.city).toBe('Los Angeles');
      expect(result.line1).toBe('');
    });
  });

  describe('getBillingDetails', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract billing details from dict', () => {
      const dict = {
        billingDetails: {
          name: 'John Doe',
          email: 'john@example.com',
          phone: '+1234567890',
          address: {
            line1: '123 Main St',
            city: 'New York',
            state: 'NY',
            country: 'US',
            postal_code: '10001',
          },
        },
      };
      const result = getBillingDetails(dict, 'billingDetails', mockLogger);
      expect(result.name).toBe('John Doe');
      expect(result.email).toBe('john@example.com');
      expect(result.phone).toBe('+1234567890');
    });

    it('should return defaultBillingDetails when key not present', () => {
      const result = getBillingDetails({}, 'billingDetails', mockLogger);
      expect(result.name).toBe('');
      expect(result.email).toBe('');
    });
  });

  describe('getDefaultValues', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract default values from dict', () => {
      const dict = {
        defaultValues: {
          billingDetails: {
            name: 'Jane Doe',
            email: 'jane@example.com',
            phone: '+0987654321',
            address: {
              line1: '456 Oak St',
              city: 'Boston',
              state: 'MA',
              country: 'US',
              postal_code: '02101',
            },
          },
        },
      };
      const result = getDefaultValues(dict, 'defaultValues', mockLogger);
      expect(result.billingDetails.name).toBe('Jane Doe');
    });

    it('should return defaultDefaultValues when key not present', () => {
      const result = getDefaultValues({}, 'defaultValues', mockLogger);
      expect(result.billingDetails.name).toBe('');
    });
  });

  describe('getBusiness', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract business name from dict', () => {
      const dict = {
        business: {
          name: 'Acme Corp',
        },
      };
      const result = getBusiness(dict, 'business', mockLogger);
      expect(result.name).toBe('Acme Corp');
    });

    it('should return defaultBusiness when key not present', () => {
      const result = getBusiness({}, 'business', mockLogger);
      expect(result.name).toBe('');
    });
  });

  describe('getApplePayType additional cases', () => {
    it('should return "Order" for "order"', () => {
      const result = getApplePayType('order');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Order');
    });

    it('should return "Reload" for "reload"', () => {
      const result = getApplePayType('reload');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Reload');
    });

    it('should return "Rent" for "rent"', () => {
      const result = getApplePayType('rent');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Rent');
    });

    it('should return "Contribute" for "contribute"', () => {
      const result = getApplePayType('contribute');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Contribute');
    });

    it('should return "Support" for "support"', () => {
      const result = getApplePayType('support');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Support');
    });

    it('should return "Tip" for "tip"', () => {
      const result = getApplePayType('tip');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Tip');
    });

    it('should return "Topup" for "top-up"', () => {
      const result = getApplePayType('top-up');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Topup');
    });

    it('should return "Topup" for "topup"', () => {
      const result = getApplePayType('topup');
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe('Topup');
    });
  });

  describe('getGooglePayType additional cases', () => {
    it('should return "Order" for "order"', () => {
      const result = getGooglePayType('order');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Order');
    });

    it('should return "Subscribe" for "subscribe"', () => {
      const result = getGooglePayType('subscribe');
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe('Subscribe');
    });
  });

  describe('getShowDetails', () => {
    it('should return defaultBilling for JSONString with auto', () => {
      const input = { TAG: 'JSONString', _0: 'auto' };
      const result = getShowDetails(input);
      expect(result.name).toBe('Auto');
      expect(result.email).toBe('Auto');
    });

    it('should return defaultNeverBilling for JSONString with never', () => {
      const input = { TAG: 'JSONString', _0: 'never' };
      const result = getShowDetails(input);
      expect(result.name).toBe('Never');
      expect(result.email).toBe('Never');
    });

    it('should return inner object for JSONObject', () => {
      const innerObj = { name: 'Auto', email: 'Never' };
      const input = { TAG: 'JSONObject', _0: innerObj };
      const result = getShowDetails(input);
      expect(result).toBe(innerObj);
    });
  });

  describe('getShowAddressDetails', () => {
    it('should return defaultshowAddress for JSONString with auto', () => {
      const input = { TAG: 'JSONString', _0: 'auto' };
      const result = getShowAddressDetails(input);
      expect(result.line1).toBe('Auto');
      expect(result.city).toBe('Auto');
    });

    it('should return defaultNeverShowAddress for JSONString with never', () => {
      const input = { TAG: 'JSONString', _0: 'never' };
      const result = getShowAddressDetails(input);
      expect(result.line1).toBe('Never');
    });

    it('should return inner address for JSONObject', () => {
      const innerAddress = { line1: 'Auto', city: 'Never' };
      const input = {
        TAG: 'JSONObject',
        _0: {
          name: 'Auto',
          email: 'Auto',
          phone: 'Auto',
          address: { TAG: 'JSONObject', _0: innerAddress },
        },
      };
      const result = getShowAddressDetails(input);
      expect(result).toBe(innerAddress);
    });
  });

  describe('getShowAddress', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract show address settings from dict', () => {
      const dict = {
        address: {
          line1: 'auto',
          line2: 'never',
          city: 'auto',
          state: 'auto',
          country: 'auto',
          postal_code: 'auto',
        },
      };
      const result = getShowAddress(dict, 'address', mockLogger);
      expect(result.line1).toBe('Auto');
      expect(result.line2).toBe('Never');
      expect(result.city).toBe('Auto');
    });

    it('should return defaultshowAddress when key not present', () => {
      const result = getShowAddress({}, 'address', mockLogger);
      expect(result.line1).toBe('Auto');
    });
  });

  describe('getDeatils', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return JSONString for string values', () => {
      const result = getDeatils('auto', mockLogger);
      expect(result.TAG).toBe('JSONString');
      expect(result._0).toBe('auto');
    });

    it('should return JSONObject for object values', () => {
      const input = {
        name: 'auto',
        email: 'never',
        phone: 'auto',
        address: {
          line1: 'auto',
          city: 'auto',
        },
      };
      const result = getDeatils(input, mockLogger);
      expect(result.TAG).toBe('JSONObject');
      expect(result._0.name).toBe('Auto');
      expect(result._0.email).toBe('Never');
    });

    it('should return JSONString with empty string for null', () => {
      const result = getDeatils(null, mockLogger);
      expect(result.TAG).toBe('JSONString');
      expect(result._0).toBe('');
    });

    it('should return JSONString with empty string for number', () => {
      const result = getDeatils(42, mockLogger);
      expect(result.TAG).toBe('JSONString');
      expect(result._0).toBe('');
    });
  });

  describe('getBilling', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract billing details from dict', () => {
      const dict = {
        billingDetails: 'auto',
      };
      const result = getBilling(dict, 'billingDetails', mockLogger);
      expect(result.TAG).toBe('JSONString');
      expect(result._0).toBe('auto');
    });

    it('should return default when key not present', () => {
      const result = getBilling({}, 'billingDetails', mockLogger);
      expect(result.TAG).toBe('JSONObject');
    });
  });

  describe('getFields', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract fields from dict', () => {
      const dict = {
        fields: {
          billingDetails: { TAG: 'JSONString', _0: 'auto' },
        },
      };
      const result = getFields(dict, 'fields', mockLogger);
      expect(result.billingDetails).toBeDefined();
    });

    it('should return defaultFields when key not present', () => {
      const result = getFields({}, 'fields', mockLogger);
      expect(result.billingDetails).toBeDefined();
    });
  });

  describe('getGroupingBehaviorFromObject', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract grouping behavior from object', () => {
      const json = {
        displayInSeparateScreen: false,
        groupByPaymentMethods: true,
      };
      const result = getGroupingBehaviorFromObject(json, mockLogger);
      expect(result.displayInSeparateScreen).toBe(false);
      expect(result.groupByPaymentMethods).toBe(true);
    });

    it('should use defaults for missing fields', () => {
      const result = getGroupingBehaviorFromObject({}, mockLogger);
      expect(result.displayInSeparateScreen).toBe(true);
      expect(result.groupByPaymentMethods).toBe(false);
    });
  });

  describe('getGroupingBehavior', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return default for missing groupingBehavior', () => {
      const result = getGroupingBehavior({}, mockLogger);
      expect(result.displayInSeparateScreen).toBe(true);
      expect(result.groupByPaymentMethods).toBe(false);
    });

    it('should parse string groupingBehavior', () => {
      const dict = {
        groupingBehavior: 'groupByPaymentMethods',
      };
      const result = getGroupingBehavior(dict, mockLogger);
      expect(result.groupByPaymentMethods).toBe(true);
    });

    it('should parse object groupingBehavior', () => {
      const dict = {
        groupingBehavior: {
          displayInSeparateScreen: false,
          groupByPaymentMethods: true,
        },
      };
      const result = getGroupingBehavior(dict, mockLogger);
      expect(result.displayInSeparateScreen).toBe(false);
      expect(result.groupByPaymentMethods).toBe(true);
    });
  });

  describe('getSavedMethodCustomization', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract saved method customization from dict', () => {
      const dict = {
        savedMethodCustomization: {
          groupingBehavior: 'default',
          maxItems: 6,
          hideCardExpiry: true,
        },
      };
      const result = getSavedMethodCustomization(dict, 'savedMethodCustomization', mockLogger);
      expect(result.maxItems).toBe(6);
      expect(result.hideCardExpiry).toBe(true);
    });

    it('should return default when key not present', () => {
      const result = getSavedMethodCustomization({}, 'savedMethodCustomization', mockLogger);
      expect(result.maxItems).toBe(4);
      expect(result.hideCardExpiry).toBe(false);
    });
  });

  describe('getLayoutValues', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return StringLayout for string values', () => {
      const result = getLayoutValues('accordion', mockLogger);
      expect(result.TAG).toBe('StringLayout');
      expect(result._0).toBe('Accordion');
    });

    it('should return ObjectLayout for object values', () => {
      const val = {
        type: 'tabs',
        defaultCollapsed: true,
        radios: true,
        spacedAccordionItems: false,
        maxAccordionItems: 5,
        savedMethodCustomization: {
          groupingBehavior: 'default',
          maxItems: 4,
          hideCardExpiry: false,
        },
        paymentMethodsArrangementForTabs: 'grid',
        displayOneClickPaymentMethodsOnTop: false,
      };
      const result = getLayoutValues(val, mockLogger);
      expect(result.TAG).toBe('ObjectLayout');
      const layoutObj = result._0 as any;
      expect(layoutObj.type).toBe('Tabs');
      expect(layoutObj.defaultCollapsed).toBe(true);
    });

    it('should return default StringLayout for null', () => {
      const result = getLayoutValues(null, mockLogger);
      expect(result.TAG).toBe('StringLayout');
      expect(result._0).toBe('Tabs');
    });
  });

  describe('getApplePayHeight', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return value when >= 45', () => {
      const result = getApplePayHeight(50, mockLogger);
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe(50);
    });

    it('should return min value when < 45', () => {
      const result = getApplePayHeight(40, mockLogger);
      expect(result.TAG).toBe('ApplePay');
      expect(result._0).toBe(48);
    });
  });

  describe('getGooglePayHeight', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return value when >= 45', () => {
      const result = getGooglePayHeight(55, mockLogger);
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe(55);
    });

    it('should return min value when < 45', () => {
      const result = getGooglePayHeight(30, mockLogger);
      expect(result.TAG).toBe('GooglePay');
      expect(result._0).toBe(48);
    });
  });

  describe('getSamsungPayHeight', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return value when >= 45', () => {
      const result = getSamsungPayHeight(60, mockLogger);
      expect(result.TAG).toBe('SamsungPay');
      expect(result._0).toBe(60);
    });

    it('should return min value when < 45', () => {
      const result = getSamsungPayHeight(40, mockLogger);
      expect(result.TAG).toBe('SamsungPay');
      expect(result._0).toBe(48);
    });
  });

  describe('getPaypalHeight', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return value when in range 25-55', () => {
      const result = getPaypalHeight(40, mockLogger);
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe(40);
    });

    it('should return min value when < 25', () => {
      const result = getPaypalHeight(20, mockLogger);
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe(25);
    });

    it('should return max value when > 55', () => {
      const result = getPaypalHeight(60, mockLogger);
      expect(result.TAG).toBe('Paypal');
      expect(result._0).toBe(55);
    });
  });

  describe('getKlarnaHeight', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return value when in range 40-60', () => {
      const result = getKlarnaHeight(50, mockLogger);
      expect(result.TAG).toBe('Klarna');
      expect(result._0).toBe(50);
    });

    it('should return min value when < 40', () => {
      const result = getKlarnaHeight(30, mockLogger);
      expect(result.TAG).toBe('Klarna');
      expect(result._0).toBe(40);
    });

    it('should return max value when > 60', () => {
      const result = getKlarnaHeight(70, mockLogger);
      expect(result.TAG).toBe('Klarna');
      expect(result._0).toBe(60);
    });
  });

  describe('getHeightArray', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should return array of height objects', () => {
      const result = getHeightArray(48, mockLogger);
      expect(result).toHaveLength(5);
      expect(result[0].TAG).toBe('ApplePay');
      expect(result[1].TAG).toBe('GooglePay');
      expect(result[2].TAG).toBe('Paypal');
      expect(result[3].TAG).toBe('Klarna');
      expect(result[4].TAG).toBe('SamsungPay');
    });
  });

  describe('getStyle', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract style from dict', () => {
      const dict = {
        style: {
          type: 'buy',
          theme: 'dark',
          height: 50,
          buttonRadius: 4,
        },
      };
      const result = getStyle(dict, 'style', mockLogger);
      expect(result.theme).toBe('Dark');
      expect(result.buttonRadius).toBe(4);
    });

    it('should return defaultStyle when key not present', () => {
      const result = getStyle({}, 'style', mockLogger);
      expect(result.theme).toBe('Light');
      expect(result.buttonRadius).toBe(2);
    });
  });

  describe('getWallets', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract wallets from dict', () => {
      const dict = {
        wallets: {
          walletReturnUrl: 'https://example.com/return',
          applePay: 'auto',
          googlePay: 'auto',
          payPal: 'auto',
          klarna: 'auto',
          paze: 'auto',
          samsungPay: 'auto',
          style: {
            type: 'buy',
            theme: 'dark',
            height: 48,
            buttonRadius: 2,
          },
        },
      };
      const result = getWallets(dict, 'wallets', mockLogger);
      expect(result.walletReturnUrl).toBe('https://example.com/return');
      expect(result.applePay).toBe('Auto');
    });

    it('should return defaultWallets when key not present', () => {
      const result = getWallets({}, 'wallets', mockLogger);
      expect(result.walletReturnUrl).toBe('');
    });
  });

  describe('getBillingAddressPaymentMethod', () => {
    it('should extract billing address from dict', () => {
      const dict = {
        billing: {
          address: {
            line1: '123 Main St',
            city: 'New York',
          },
        },
      };
      const result = getBillingAddressPaymentMethod(dict, 'billing');
      expect(result.address.line1).toBe('123 Main St');
    });

    it('should return default when key not present', () => {
      const result = getBillingAddressPaymentMethod({}, 'billing');
      expect(result.address.line1).toBeUndefined();
    });
  });

  describe('getPaymentMethodType', () => {
    it('should extract payment method type', () => {
      const dict = { payment_method_type: 'card' };
      const result = getPaymentMethodType(dict);
      expect(result).toBeDefined();
    });

    it('should return undefined when key not present', () => {
      const result = getPaymentMethodType({});
      expect(result).toBeUndefined();
    });
  });

  describe('itemToCustomerObjMapper', () => {
    it('should map customer dict to customer objects', () => {
      const customerDict = {
        customer_payment_methods: [
          {
            payment_token: 'tok_123',
            customer_id: 'cust_123',
            payment_method: 'card',
            payment_method_id: 'pm_123',
            card: {
              scheme: 'Visa',
              last4_digits: '4242',
              expiry_month: '12',
              expiry_year: '2025',
              card_token: 'card_tok',
            },
          },
        ],
        is_guest_customer: false,
      };
      const result = itemToCustomerObjMapper(customerDict);
      expect(Array.isArray(result)).toBe(true);
      expect(result[0]).toHaveLength(1);
      expect(result[0][0].paymentToken).toBe('tok_123');
      expect(result[1]).toBe(false);
    });

    it('should handle empty customer_payment_methods', () => {
      const customerDict = {
        customer_payment_methods: [],
        is_guest_customer: true,
      };
      const result = itemToCustomerObjMapper(customerDict);
      expect(result[0]).toHaveLength(0);
      expect(result[1]).toBe(true);
    });
  });

  describe('createCustomerObjArr', () => {
    it('should create customer object array from dict', () => {
      const dict = {
        customerPaymentMethods: {
          customer_payment_methods: [
            {
              payment_token: 'tok_123',
              customer_id: 'cust_123',
              payment_method: 'card',
              payment_method_id: 'pm_123',
            },
          ],
        },
      };
      const result = createCustomerObjArr(dict, 'customerPaymentMethods');
      expect(result.TAG).toBe('LoadedSavedCards');
    });

    it('should return empty array for missing key', () => {
      const result = createCustomerObjArr({}, 'customerPaymentMethods');
      expect(result.TAG).toBe('LoadedSavedCards');
      expect(result._0).toHaveLength(0);
    });
  });

  describe('getCustomerMethods', () => {
    it('should return LoadingSavedCards for empty array', () => {
      const dict = {
        customerPaymentMethods: [],
      };
      const result = getCustomerMethods(dict, 'customerPaymentMethods');
      expect(result).toBe('LoadingSavedCards');
    });

    it('should return LoadedSavedCards for non-empty array', () => {
      const dict = {
        customerPaymentMethods: [
          {
            payment_token: 'tok_123',
            customer_id: 'cust_123',
            payment_method: 'card',
            payment_method_id: 'pm_123',
          },
        ],
      };
      const result = getCustomerMethods(dict, 'customerPaymentMethods');
      expect(typeof result).toBe('object');
      expect((result as any).TAG).toBe('LoadedSavedCards');
    });
  });

  describe('getCustomMethodNames', () => {
    it('should extract custom method names from dict', () => {
      const dict = {
        customMethodNames: [
          { paymentMethodName: 'method1', aliasName: 'Method One' },
          { paymentMethodName: 'method2', aliasName: 'Method Two' },
        ],
      };
      const result = getCustomMethodNames(dict, 'customMethodNames');
      expect(result).toHaveLength(2);
      expect(result[0].paymentMethodName).toBe('method1');
    });

    it('should return empty array for missing key', () => {
      const result = getCustomMethodNames({}, 'customMethodNames');
      expect(result).toHaveLength(0);
    });
  });

  describe('getBillingAddress', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should extract billing address from dict', () => {
      const dict = {
        billingAddress: {
          isUseBillingAddress: true,
          usePrefilledValues: 'auto',
        },
      };
      const result = getBillingAddress(dict, 'billingAddress', mockLogger);
      expect(result.isUseBillingAddress).toBe(true);
      expect(result.usePrefilledValues).toBe('Auto');
    });

    it('should return defaultBillingAddress when key not present', () => {
      const result = getBillingAddress({}, 'billingAddress', mockLogger);
      expect(result.isUseBillingAddress).toBe(false);
    });
  });

  describe('sanitizePaymentElementOptions', () => {
    it('should sanitize payment element options', () => {
      const dict = {
        paymentId: 'pay_123',
        layout: { type: 'tabs' },
      };
      const result = sanitizePaymentElementOptions(dict);
      expect(result).toBeDefined();
    });
  });

  describe('sanitizePreloadSdkParms', () => {
    it('should sanitize preload SDK params', () => {
      const dict = {
        apiKey: 'secret_key',
        merchantId: 'merchant_123',
      };
      const result = sanitizePreloadSdkParms(dict);
      expect(result).toBeDefined();
    });
  });

  describe('itemToObjMapper', () => {
    const mockLogger = {
      setLogInfo: jest.fn(),
      setLogError: jest.fn(),
    };

    it('should map dict to options object', () => {
      const dict = {
        displaySavedPaymentMethodsCheckbox: true,
        displaySavedPaymentMethods: true,
        savedPaymentMethodsCheckboxCheckedByDefault: false,
        readOnly: false,
        hideExpiredPaymentMethods: false,
        displayDefaultSavedPaymentIcon: true,
        hideCardNicknameField: false,
        displayBillingDetails: false,
        customMessageForCardTerms: '',
        showShortSurchargeMessage: false,
      };
      const result = itemToObjMapper(dict, mockLogger);
      expect(result.displaySavedPaymentMethodsCheckbox).toBe(true);
      expect(result.readOnly).toBe(false);
    });
  });

  describe('itemToPayerDetailsObjectMapper', () => {
    it('should map payer details from dict', () => {
      const dict = {
        email_address: 'test@example.com',
        phone: {
          phone_number: {
            national_number: '1234567890',
          },
        },
      };
      const result = itemToPayerDetailsObjectMapper(dict);
      expect(result.email).toBe('test@example.com');
    });

    it('should handle missing fields', () => {
      const result = itemToPayerDetailsObjectMapper({});
      expect(result.email).toBeUndefined();
      expect(result.phone).toBeUndefined();
    });
  });

  describe('convertClickToPayCardToCustomerMethod', () => {
    it('should convert Visa ClickToPay card to customer method', () => {
      const clickToPayCard = {
        srcDigitalCardId: 'card_123',
        panLastFour: '4242',
        panExpirationMonth: '12',
        panExpirationYear: '2025',
        paymentCardDescriptor: 'visa',
        digitalCardData: {
          descriptorName: 'My Visa',
        },
      };
      const result = convertClickToPayCardToCustomerMethod(clickToPayCard, 'VISA');
      expect(result.paymentToken).toBe('card_123');
      expect(result.card.last4Digits).toBe('4242');
      expect(result.card.scheme).toBe('Visa');
      expect(result.paymentMethodType).toBe('click_to_pay');
      expect(result.card.isClickToPayCard).toBe(true);
    });

    it('should convert Mastercard ClickToPay card with Visa descriptor', () => {
      const clickToPayCard = {
        srcDigitalCardId: 'card_456',
        panLastFour: '1234',
        panExpirationMonth: '06',
        panExpirationYear: '2026',
        paymentCardDescriptor: 'mastercard',
        digitalCardData: {
          descriptorName: 'My MC',
        },
      };
      const result = convertClickToPayCardToCustomerMethod(clickToPayCard, 'VISA');
      expect(result.card.scheme).toBe('Mastercard');
    });

    it('should handle Mastercard provider with amex descriptor', () => {
      const clickToPayCard = {
        srcDigitalCardId: 'card_789',
        panLastFour: '3782',
        panExpirationMonth: '01',
        panExpirationYear: '2027',
        paymentCardDescriptor: 'amex',
        digitalCardData: {
          descriptorName: 'My Amex',
        },
      };
      const result = convertClickToPayCardToCustomerMethod(clickToPayCard, 'MASTERCARD');
      expect(result.card.scheme).toBe('AmericanExpress');
    });

    it('should handle Mastercard provider with discover descriptor', () => {
      const clickToPayCard = {
        srcDigitalCardId: 'card_discover',
        panLastFour: '6011',
        panExpirationMonth: '03',
        panExpirationYear: '2028',
        paymentCardDescriptor: 'discover',
        digitalCardData: {
          descriptorName: 'My Discover',
        },
      };
      const result = convertClickToPayCardToCustomerMethod(clickToPayCard, 'MASTERCARD');
      expect(result.card.scheme).toBe('Discover');
    });

    it('should handle Mastercard provider with mastercard descriptor', () => {
      const clickToPayCard = {
        srcDigitalCardId: 'card_mc',
        panLastFour: '5425',
        panExpirationMonth: '05',
        panExpirationYear: '2029',
        paymentCardDescriptor: 'mastercard',
        digitalCardData: {
          descriptorName: 'My MC',
        },
      };
      const result = convertClickToPayCardToCustomerMethod(clickToPayCard, 'MASTERCARD');
      expect(result.card.scheme).toBe('Mastercard');
    });

    it('should handle Mastercard provider with visa descriptor', () => {
      const clickToPayCard = {
        srcDigitalCardId: 'card_visa',
        panLastFour: '4111',
        panExpirationMonth: '07',
        panExpirationYear: '2030',
        paymentCardDescriptor: 'visa',
        digitalCardData: {
          descriptorName: 'My Visa',
        },
      };
      const result = convertClickToPayCardToCustomerMethod(clickToPayCard, 'MASTERCARD');
      expect(result.card.scheme).toBe('Visa');
    });

    it('should handle Mastercard provider with unknown descriptor', () => {
      const clickToPayCard = {
        srcDigitalCardId: 'card_unknown',
        panLastFour: '9999',
        panExpirationMonth: '09',
        panExpirationYear: '2031',
        paymentCardDescriptor: 'unknowncard',
        digitalCardData: {
          descriptorName: 'My Card',
        },
      };
      const result = convertClickToPayCardToCustomerMethod(clickToPayCard, 'MASTERCARD');
      expect(result.card.scheme).toBe('Unknowncard');
    });

    it('should handle NONE provider', () => {
      const clickToPayCard = {
        srcDigitalCardId: 'card_none',
        panLastFour: '0000',
        panExpirationMonth: '11',
        panExpirationYear: '2032',
        paymentCardDescriptor: 'visa',
        digitalCardData: {
          descriptorName: 'My Card',
        },
      };
      const result = convertClickToPayCardToCustomerMethod(clickToPayCard, 'NONE');
      expect(result.card.scheme).toBeUndefined();
    });
  });
});
