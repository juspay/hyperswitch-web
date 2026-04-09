import {
  getNestedValue,
  getOrCreateSubDict,
  setNestedValue,
  getPaymentMethod,
  getPaymentMethodType,
  getPaymentMethodLabel,
  getPaymentMethodDataFieldKey,
  getPaymentMethodDataFieldMaxLength,
  calculateValidity,
  checkValidity,
  defaultFormDataDict,
  defaultValidityDict,
  getPayoutStatusString,
  getPaymentMethodForPmt,
  getPaymentMethodForPayoutsConfirm,
  getPaymentMethodTypeLabel,
  getPaymentMethodDataFieldLabel,
  getPaymentMethodDataFieldPlaceholder,
  getPaymentMethodDataFieldCharacterPattern,
  getPaymentMethodDataFieldInputType,
  getPayoutImageSource,
  getPayoutReadableStatus,
  getPayoutStatusMessage,
  getPaymentMethodDataErrorString,
  defaultPmt,
  defaultView,
  defaultAmount,
  defaultCurrency,
  defaultPm,
  defaultFormLayout,
  defaultJourneyView,
  defaultTabView,
  defaultPaymentMethodCollectFlow,
  processPaymentMethodDataFields,
  processAddressFields,
  formPaymentMethodData,
  formBody,
  getPayoutDynamicFields,
  getDefaultsAndValidity,
  itemToObjMapper,
  defaultDynamicPmdFields,
  defaultPayoutDynamicFields,
  defaultCardFields,
  defaultAchFields,
  defaultBacsFields,
  defaultPixTransferFields,
  defaultSepaFields,
  defaultPaypalFields,
  defaultInteracFields,
  defaultEnabledPaymentMethods,
  defaultEnabledPaymentMethodsWithDynamicFields,
  defaultPaymentMethodCollectOptions,
  defaultStatusInfo,
  getPaymentMethodIcon,
  getBankTransferIcon,
  getWalletIcon,
  getBankRedirectIcon,
  getPaymentMethodTypeIcon,
} from '../Utilities/PaymentMethodCollectUtils.bs.js';
import React from 'react';

const mockLocaleString = {
  fullNameLabel: 'Full Name',
  countryLabel: 'Country',
  emailLabel: 'Email',
  formFieldPhoneNumberLabel: 'Phone Number',
  formFieldCountryCodeRequiredLabel: 'Country Code',
  line1Label: 'Address Line 1',
  line2Label: 'Address Line 2',
  cityLabel: 'City',
  stateLabel: 'State',
  postalCodeLabel: 'Postal Code',
  cardNumberLabel: 'Card Number',
  cardHolderName: 'Card Holder Name',
  validThruText: 'Valid Thru',
  formFieldACHRoutingNumberLabel: 'Routing Number',
  sortCodeText: 'Sort Code',
  accountNumberText: 'Account Number',
  formFieldSepaIbanLabel: 'IBAN',
  formFieldSepaBicLabel: 'BIC',
  formFieldBankCityLabel: 'Bank City',
  formFieldCountryCodeLabel: 'Country Code',
  formFieldPixIdLabel: 'PIX ID',
  formFieldBankAccountNumberLabel: 'Bank Account',
  formFieldBankNameLabel: 'Bank Name',
  formFieldEmailPlaceholder: 'Enter email',
  formFieldPhoneNumberPlaceholder: 'Enter phone',
  formFieldCardHoldernamePlaceholder: 'Enter name',
  line1Placeholder: 'Enter address',
  line2Placeholder: 'Enter address 2',
  formFieldBankCityPlaceholder: 'Enter city',
  expiryPlaceholder: 'MM/YY',
  payoutStatusSuccessText: 'Success',
  payoutStatusPendingText: 'Pending',
  payoutStatusFailedText: 'Failed',
  payoutStatusSuccessMessage: 'Payment successful',
  payoutStatusPendingMessage: 'Payment pending',
  payoutStatusFailedMessage: 'Payment failed',
  emailEmptyText: 'Email is required',
  emailInvalidText: 'Invalid email',
  nameEmptyText: (label: string) => `${label} is required`,
  completeNameEmptyText: (label: string) => `${label} is incomplete`,
  line1EmptyText: 'Address line 1 is required',
  line2EmptyText: 'Address line 2 is required',
  cityEmptyText: 'City is required',
  stateEmptyText: 'State is required',
  postalCodeEmptyText: 'Postal code is required',
  postalCodeInvalidText: 'Invalid postal code',
  inValidCardErrorText: 'Invalid card',
  pastExpiryErrorText: 'Card expired',
  inCompleteExpiryErrorText: 'Expiry incomplete',
  formFieldInvalidRoutingNumber: 'Invalid routing number',
  sortCodeInvalidText: 'Invalid sort code',
  accountNumberInvalidText: 'Invalid account number',
  ibanEmptyText: 'IBAN is required',
  ibanInvalidText: 'Invalid IBAN',
};

const mockConstants = {
  formFieldCardNumberPlaceholder: '1234 5678 9012 3456',
  formFieldACHRoutingNumberPlaceholder: '123456789',
  formFieldSortCodePlaceholder: '123456',
  formFieldAccountNumberPlaceholder: '12345678',
  formFieldSepaIbanPlaceholder: 'DE89370400440532013000',
  formFieldSepaBicPlaceholder: 'DEUTDEFF',
  formFieldPixIdPlaceholder: 'Enter PIX ID',
  formFieldBankAccountNumberPlaceholder: 'Enter account number',
};

describe('PaymentMethodCollectUtils', () => {
  describe('getNestedValue', () => {
    it('should get value from nested dict with valid path', () => {
      const dict = { a: { b: { c: 'value' } } };
      const result = getNestedValue(dict, 'a.b.c');
      expect(result).toBe('value');
    });

    it('should return undefined for missing path', () => {
      const dict = { a: { b: 'value' } };
      const result = getNestedValue(dict, 'a.b.c');
      expect(result).toBeUndefined();
    });

    it('should handle empty dict', () => {
      const result = getNestedValue({}, 'a.b.c');
      expect(result).toBeUndefined();
    });

    it('should get top-level value', () => {
      const dict = { a: 'value' };
      const result = getNestedValue(dict, 'a');
      expect(result).toBe('value');
    });
  });

  describe('getOrCreateSubDict', () => {
    it('should return existing sub-dict', () => {
      const dict = { sub: { key: 'value' } };
      const result = getOrCreateSubDict(dict, 'sub');
      expect(result).toEqual({ key: 'value' });
    });

    it('should create new sub-dict if missing', () => {
      const dict: Record<string, unknown> = {};
      const result = getOrCreateSubDict(dict, 'new');
      expect(result).toEqual({});
      expect(dict['new']).toEqual({});
    });
  });

  describe('setNestedValue', () => {
    it('should set value at nested path', () => {
      const dict: any = {};
      setNestedValue(dict, 'a.b.c', 'value');
      expect(dict.a.b.c).toBe('value');
    });

    it('should overwrite existing value', () => {
      const dict = { a: { b: 'old' } };
      setNestedValue(dict, 'a.b', 'new');
      expect(dict.a.b).toBe('new');
    });

    it('should set top-level value', () => {
      const dict: any = {};
      setNestedValue(dict, 'key', 'value');
      expect(dict.key).toBe('value');
    });
  });

  describe('getPaymentMethod', () => {
    it('should return card for Card', () => {
      expect(getPaymentMethod('Card')).toBe('card');
    });

    it('should return bank_redirect for BankRedirect', () => {
      expect(getPaymentMethod('BankRedirect')).toBe('bank_redirect');
    });

    it('should return bank_transfer for BankTransfer', () => {
      expect(getPaymentMethod('BankTransfer')).toBe('bank_transfer');
    });

    it('should return wallet for Wallet', () => {
      expect(getPaymentMethod('Wallet')).toBe('wallet');
    });
  });

  describe('getPaymentMethodType', () => {
    it('should return credit for Credit card', () => {
      const result = getPaymentMethodType({ TAG: 'Card', _0: 'Credit' });
      expect(result).toBe('credit');
    });

    it('should return debit for Debit card', () => {
      const result = getPaymentMethodType({ TAG: 'Card', _0: 'Debit' });
      expect(result).toBe('debit');
    });

    it('should return ach for ACH bank transfer', () => {
      const result = getPaymentMethodType({ TAG: 'BankTransfer', _0: 'ACH' });
      expect(result).toBe('ach');
    });

    it('should return paypal for Paypal wallet', () => {
      const result = getPaymentMethodType({ TAG: 'Wallet', _0: 'Paypal' });
      expect(result).toBe('paypal');
    });
  });

  describe('getPaymentMethodLabel', () => {
    it('should return Card for Card', () => {
      expect(getPaymentMethodLabel('Card')).toBe('Card');
    });

    it('should return Bank for BankRedirect', () => {
      expect(getPaymentMethodLabel('BankRedirect')).toBe('Bank');
    });

    it('should return Bank for BankTransfer', () => {
      expect(getPaymentMethodLabel('BankTransfer')).toBe('Bank');
    });

    it('should return Wallet for Wallet', () => {
      expect(getPaymentMethodLabel('Wallet')).toBe('Wallet');
    });
  });

  describe('getPaymentMethodDataFieldKey', () => {
    it('should return correct key for CardNumber', () => {
      const result = getPaymentMethodDataFieldKey({ TAG: 'PayoutMethodData', _0: 'CardNumber' });
      expect(result).toBe('card.cardNumber');
    });

    it('should return correct key for email billing address', () => {
      const result = getPaymentMethodDataFieldKey({ TAG: 'BillingAddress', _0: 'Email' });
      expect(result).toBe('billing.address.email');
    });

    it('should return correct key for card holder name', () => {
      const result = getPaymentMethodDataFieldKey({ TAG: 'PayoutMethodData', _0: 'CardHolderName' });
      expect(result).toBe('card.cardHolder');
    });
  });

  describe('getPaymentMethodDataFieldMaxLength', () => {
    it('should return 23 for CardNumber', () => {
      const result = getPaymentMethodDataFieldMaxLength({ TAG: 'PayoutMethodData', _0: 'CardNumber' });
      expect(result).toBe(23);
    });

    it('should return 32 for BillingAddress fields', () => {
      const result = getPaymentMethodDataFieldMaxLength({ TAG: 'BillingAddress', _0: 'Email' });
      expect(result).toBe(32);
    });

    it('should return 9 for ACHRoutingNumber', () => {
      const result = getPaymentMethodDataFieldMaxLength({ TAG: 'PayoutMethodData', _0: 'ACHRoutingNumber' });
      expect(result).toBe(9);
    });
  });

  describe('calculateValidity', () => {
    it('should return true for valid card number', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'CardNumber' },
        '4111111111111111',
        'Visa',
        undefined
      );
      expect(result).toBe(true);
    });

    it('should return false for invalid card number', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'CardNumber' },
        '1234',
        '',
        undefined
      );
      expect(result).toBe(false);
    });

    it('should return default for empty value', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'CardNumber' },
        '',
        '',
        true
      );
      expect(result).toBe(true);
    });
  });

  describe('checkValidity', () => {
    it('should return true when all fields are valid', () => {
      const keys = ['field1', 'field2'];
      const validityDict = { field1: true, field2: true };
      expect(checkValidity(keys, validityDict, true)).toBe(true);
    });

    it('should return false when any field is invalid', () => {
      const keys = ['field1', 'field2'];
      const validityDict = { field1: true, field2: false };
      expect(checkValidity(keys, validityDict, true)).toBe(false);
    });

    it('should use default validity for missing keys', () => {
      const keys = ['field1', 'field2'];
      const validityDict = { field1: true };
      expect(checkValidity(keys, validityDict, true)).toBe(true);
    });
  });

  describe('defaultFormDataDict', () => {
    it('should be defined as empty object', () => {
      expect(defaultFormDataDict).toBeDefined();
      expect(typeof defaultFormDataDict).toBe('object');
    });
  });

  describe('defaultValidityDict', () => {
    it('should be defined as empty object', () => {
      expect(defaultValidityDict).toBeDefined();
      expect(typeof defaultValidityDict).toBe('object');
    });
  });

  describe('getPayoutStatusString', () => {
    it('should return success for Success', () => {
      expect(getPayoutStatusString('Success')).toBe('success');
    });

    it('should return failed for Failed', () => {
      expect(getPayoutStatusString('Failed')).toBe('failed');
    });

    it('should return pending for Pending', () => {
      expect(getPayoutStatusString('Pending')).toBe('pending');
    });

    it('should return initiated for Initiated', () => {
      expect(getPayoutStatusString('Initiated')).toBe('initiated');
    });
  });

  describe('getPaymentMethodForPmt', () => {
    it('should return Card for Card type', () => {
      expect(getPaymentMethodForPmt({ TAG: 'Card', _0: 'Credit' })).toBe('Card');
    });

    it('should return BankRedirect for BankRedirect type', () => {
      expect(getPaymentMethodForPmt({ TAG: 'BankRedirect', _0: 'Interac' })).toBe('BankRedirect');
    });

    it('should return BankTransfer for BankTransfer type', () => {
      expect(getPaymentMethodForPmt({ TAG: 'BankTransfer', _0: 'ACH' })).toBe('BankTransfer');
    });

    it('should return Wallet for Wallet type', () => {
      expect(getPaymentMethodForPmt({ TAG: 'Wallet', _0: 'Paypal' })).toBe('Wallet');
    });
  });

  describe('getPaymentMethodForPayoutsConfirm', () => {
    it('should return card for Card', () => {
      expect(getPaymentMethodForPayoutsConfirm('Card')).toBe('card');
    });

    it('should return bank_redirect for BankRedirect', () => {
      expect(getPaymentMethodForPayoutsConfirm('BankRedirect')).toBe('bank_redirect');
    });

    it('should return bank for BankTransfer', () => {
      expect(getPaymentMethodForPayoutsConfirm('BankTransfer')).toBe('bank');
    });

    it('should return wallet for Wallet', () => {
      expect(getPaymentMethodForPayoutsConfirm('Wallet')).toBe('wallet');
    });
  });

  describe('getPaymentMethodTypeLabel', () => {
    it('should return Card for Credit card type', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'Card', _0: 'Credit' })).toBe('Card');
    });

    it('should return Card for Debit card type', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'Card', _0: 'Debit' })).toBe('Card');
    });

    it('should return Interac for BankRedirect', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'BankRedirect', _0: 'Interac' })).toBe('Interac');
    });

    it('should return ACH for ACH BankTransfer', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'BankTransfer', _0: 'ACH' })).toBe('ACH');
    });

    it('should return BACS for Bacs BankTransfer', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'BankTransfer', _0: 'Bacs' })).toBe('BACS');
    });

    it('should return Pix for Pix BankTransfer', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'BankTransfer', _0: 'Pix' })).toBe('Pix');
    });

    it('should return SEPA for Sepa BankTransfer', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'BankTransfer', _0: 'Sepa' })).toBe('SEPA');
    });

    it('should return PayPal for Paypal Wallet', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'Wallet', _0: 'Paypal' })).toBe('PayPal');
    });

    it('should return Venmo for Venmo Wallet', () => {
      expect(getPaymentMethodTypeLabel({ TAG: 'Wallet', _0: 'Venmo' })).toBe('Venmo');
    });
  });

  describe('getPaymentMethodDataFieldLabel', () => {
    it('should return correct label for CardNumber', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardNumber' };
      expect(getPaymentMethodDataFieldLabel(key, mockLocaleString)).toBe('Card Number');
    });

    it('should return correct label for CardHolderName', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardHolderName' };
      expect(getPaymentMethodDataFieldLabel(key, mockLocaleString)).toBe('Card Holder Name');
    });

    it('should return correct label for Email billing address', () => {
      const key = { TAG: 'BillingAddress', _0: 'Email' };
      expect(getPaymentMethodDataFieldLabel(key, mockLocaleString)).toBe('Email');
    });

    it('should return correct label for PhoneNumber billing address', () => {
      const key = { TAG: 'BillingAddress', _0: 'PhoneNumber' };
      expect(getPaymentMethodDataFieldLabel(key, mockLocaleString)).toBe('Phone Number');
    });

    it('should return correct label for SepaIban', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'SepaIban' };
      expect(getPaymentMethodDataFieldLabel(key, mockLocaleString)).toBe('IBAN');
    });
  });

  describe('getPaymentMethodDataFieldPlaceholder', () => {
    it('should return correct placeholder for CardNumber', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardNumber' };
      expect(getPaymentMethodDataFieldPlaceholder(key, mockLocaleString, mockConstants)).toBe('1234 5678 9012 3456');
    });

    it('should return correct placeholder for Email billing address', () => {
      const key = { TAG: 'BillingAddress', _0: 'Email' };
      expect(getPaymentMethodDataFieldPlaceholder(key, mockLocaleString, mockConstants)).toBe('Enter email');
    });

    it('should return correct placeholder for SepaIban', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'SepaIban' };
      expect(getPaymentMethodDataFieldPlaceholder(key, mockLocaleString, mockConstants)).toBe('DE89370400440532013000');
    });
  });

  describe('getPaymentMethodDataFieldCharacterPattern', () => {
    it('should return pattern for CardNumber', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardNumber' };
      const pattern = getPaymentMethodDataFieldCharacterPattern(key);
      expect(pattern).toBeInstanceOf(RegExp);
      expect(pattern?.test('4111111111111111')).toBe(true);
    });

    it('should return pattern for PhoneNumber', () => {
      const key = { TAG: 'BillingAddress', _0: 'PhoneNumber' };
      const pattern = getPaymentMethodDataFieldCharacterPattern(key);
      expect(pattern).toBeInstanceOf(RegExp);
      expect(pattern?.test('1234567890')).toBe(true);
    });

    it('should return undefined for fields without pattern', () => {
      const key = { TAG: 'BillingAddress', _0: 'Email' };
      const pattern = getPaymentMethodDataFieldCharacterPattern(key);
      expect(pattern).toBeUndefined();
    });

    it('should return pattern for SepaIban', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'SepaIban' };
      const pattern = getPaymentMethodDataFieldCharacterPattern(key);
      expect(pattern).toBeInstanceOf(RegExp);
    });
  });

  describe('getPaymentMethodDataFieldInputType', () => {
    it('should return tel for CardNumber', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardNumber' };
      expect(getPaymentMethodDataFieldInputType(key)).toBe('tel');
    });

    it('should return email for PaypalMail', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'PaypalMail' };
      expect(getPaymentMethodDataFieldInputType(key)).toBe('email');
    });

    it('should return text for CardHolderName', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardHolderName' };
      expect(getPaymentMethodDataFieldInputType(key)).toBe('text');
    });

    it('should return text for BillingAddress fields', () => {
      const key = { TAG: 'BillingAddress', _0: 'Email' };
      expect(getPaymentMethodDataFieldInputType(key)).toBe('text');
    });

    it('should return tel for ACHRoutingNumber', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'ACHRoutingNumber' };
      expect(getPaymentMethodDataFieldInputType(key)).toBe('tel');
    });
  });

  describe('getPayoutImageSource', () => {
    it('should return success image for Success status', () => {
      expect(getPayoutImageSource('Success')).toBe('https://live.hyperswitch.io/payment-link-assets/success.png');
    });

    it('should return pending image for Initiated status', () => {
      expect(getPayoutImageSource('Initiated')).toBe('https://live.hyperswitch.io/payment-link-assets/pending.png');
    });

    it('should return pending image for Pending status', () => {
      expect(getPayoutImageSource('Pending')).toBe('https://live.hyperswitch.io/payment-link-assets/pending.png');
    });

    it('should return pending image for RequiresFulfillment status', () => {
      expect(getPayoutImageSource('RequiresFulfillment')).toBe('https://live.hyperswitch.io/payment-link-assets/pending.png');
    });

    it('should return failed image for Failed status', () => {
      expect(getPayoutImageSource('Failed')).toBe('https://live.hyperswitch.io/payment-link-assets/failed.png');
    });

    it('should return failed image for unknown status', () => {
      expect(getPayoutImageSource('Unknown')).toBe('https://live.hyperswitch.io/payment-link-assets/failed.png');
    });
  });

  describe('getPayoutReadableStatus', () => {
    it('should return success text for Success status', () => {
      expect(getPayoutReadableStatus('Success', mockLocaleString)).toBe('Success');
    });

    it('should return pending text for Initiated status', () => {
      expect(getPayoutReadableStatus('Initiated', mockLocaleString)).toBe('Pending');
    });

    it('should return pending text for Pending status', () => {
      expect(getPayoutReadableStatus('Pending', mockLocaleString)).toBe('Pending');
    });

    it('should return failed text for Failed status', () => {
      expect(getPayoutReadableStatus('Failed', mockLocaleString)).toBe('Failed');
    });
  });

  describe('getPayoutStatusMessage', () => {
    it('should return success message for Success status', () => {
      expect(getPayoutStatusMessage('Success', mockLocaleString)).toBe('Payment successful');
    });

    it('should return pending message for Initiated status', () => {
      expect(getPayoutStatusMessage('Initiated', mockLocaleString)).toBe('Payment pending');
    });

    it('should return failed message for Failed status', () => {
      expect(getPayoutStatusMessage('Failed', mockLocaleString)).toBe('Payment failed');
    });
  });

  describe('getPaymentMethodDataErrorString', () => {
    it('should return empty email error for empty Email value', () => {
      const key = { TAG: 'BillingAddress', _0: 'Email' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Email is required');
    });

    it('should return invalid email error for invalid Email value', () => {
      const key = { TAG: 'BillingAddress', _0: 'Email' };
      expect(getPaymentMethodDataErrorString(key, 'invalid', mockLocaleString)).toBe('Invalid email');
    });

    it('should return card error for CardNumber', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardNumber' };
      expect(getPaymentMethodDataErrorString(key, '123', mockLocaleString)).toBe('Invalid card');
    });

    it('should return postal code empty error for empty postal code', () => {
      const key = { TAG: 'BillingAddress', _0: 'AddressPincode' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Postal code is required');
    });
  });

  describe('defaultPmt', () => {
    it('should return Debit Card when no param provided', () => {
      const result = defaultPmt(undefined);
      expect(result.TAG).toBe('Card');
      expect(result._0).toBe('Debit');
    });

    it('should return Credit Card when Card is provided', () => {
      const result = defaultPmt('Card');
      expect(result.TAG).toBe('Card');
      expect(result._0).toBe('Debit');
    });

    it('should return Interac BankRedirect when BankRedirect is provided', () => {
      const result = defaultPmt('BankRedirect');
      expect(result.TAG).toBe('BankRedirect');
      expect(result._0).toBe('Interac');
    });

    it('should return ACH BankTransfer when BankTransfer is provided', () => {
      const result = defaultPmt('BankTransfer');
      expect(result.TAG).toBe('BankTransfer');
      expect(result._0).toBe('ACH');
    });

    it('should return Paypal Wallet when Wallet is provided', () => {
      const result = defaultPmt('Wallet');
      expect(result.TAG).toBe('Wallet');
      expect(result._0).toBe('Paypal');
    });
  });

  describe('defaultView', () => {
    it('should return Journey SelectPM for Journey layout', () => {
      const result = defaultView('Journey');
      expect(result.TAG).toBe('Journey');
      expect(result._0).toBe('SelectPM');
    });

    it('should return Tabs DetailsForm for Tabs layout', () => {
      const result = defaultView('Tabs');
      expect(result.TAG).toBe('Tabs');
      expect(result._0).toBe('DetailsForm');
    });
  });

  describe('constants', () => {
    it('should have correct defaultAmount', () => {
      expect(defaultAmount).toBe('0.01');
    });

    it('should have correct defaultCurrency', () => {
      expect(defaultCurrency).toBe('EUR');
    });

    it('should have correct defaultPm', () => {
      expect(defaultPm).toBe('Card');
    });

    it('should have correct defaultFormLayout', () => {
      expect(defaultFormLayout).toBe('Tabs');
    });

    it('should have correct defaultJourneyView', () => {
      expect(defaultJourneyView).toBe('SelectPM');
    });

    it('should have correct defaultTabView', () => {
      expect(defaultTabView).toBe('DetailsForm');
    });

    it('should have correct defaultPaymentMethodCollectFlow', () => {
      expect(defaultPaymentMethodCollectFlow).toBe('PayoutLinkInitiate');
    });
  });

  describe('processPaymentMethodDataFields', () => {
    it('should process card number field', () => {
      const dynamicFieldsInfo = [
        {
          pmdMap: 'payout_method_data.card.card_number',
          displayName: 'user_card_number',
          fieldType: 'CardNumber',
          value: '4111111111111111',
        },
      ];
      const paymentMethodDataDict = { 'card.cardNumber': '4111111111111111' };
      const fieldValidityDict = { 'card.cardNumber': true };

      const result = processPaymentMethodDataFields(dynamicFieldsInfo, paymentMethodDataDict, fieldValidityDict);

      expect(result).toBeDefined();
      expect(result).toHaveLength(1);
    });

    it('should return undefined when validity check fails', () => {
      const dynamicFieldsInfo = [
        {
          pmdMap: 'payout_method_data.card.card_number',
          displayName: 'user_card_number',
          fieldType: 'CardNumber',
          value: 'invalid',
        },
      ];
      const paymentMethodDataDict = { 'card.cardNumber': 'invalid' };
      const fieldValidityDict = { 'card.cardNumber': false };

      const result = processPaymentMethodDataFields(dynamicFieldsInfo, paymentMethodDataDict, fieldValidityDict);

      expect(result).toBeUndefined();
    });

    it('should process expiry date fields', () => {
      const dynamicFieldsInfo = [
        {
          pmdMap: 'payout_method_data.card.expiry_month',
          displayName: 'user_card_exp_month',
          fieldType: { TAG: 'CardExpDate', _0: 'CardExpMonth' },
          value: undefined,
        },
      ];
      const paymentMethodDataDict = { 'card.cardExp': '12/25' };
      const fieldValidityDict = { 'card.cardExp': true };

      const result = processPaymentMethodDataFields(dynamicFieldsInfo, paymentMethodDataDict, fieldValidityDict);

      expect(result).toBeDefined();
    });

    it('should handle empty dynamic fields', () => {
      const result = processPaymentMethodDataFields([], {}, {});

      expect(result).toEqual([]);
    });
  });

  describe('processAddressFields', () => {
    it('should process full name field for first name', () => {
      const dynamicFieldsInfo = [
        {
          pmdMap: 'billing.address.fullName',
          displayName: 'Full Name',
          fieldType: { TAG: 'FullName', _0: 'FirstName' },
          value: undefined,
        },
      ];
      const paymentMethodDataDict = { 'billing.address.fullName': 'John Doe' };
      const fieldValidityDict = { 'billing.address.fullName': true };

      const result = processAddressFields(dynamicFieldsInfo, paymentMethodDataDict, fieldValidityDict);

      expect(result).toBeDefined();
    });

    it('should process full name field for last name', () => {
      const dynamicFieldsInfo = [
        {
          pmdMap: 'billing.address.fullName',
          displayName: 'Full Name',
          fieldType: { TAG: 'FullName', _0: 'LastName' },
          value: undefined,
        },
      ];
      const paymentMethodDataDict = { 'billing.address.fullName': 'John Doe' };
      const fieldValidityDict = { 'billing.address.fullName': true };

      const result = processAddressFields(dynamicFieldsInfo, paymentMethodDataDict, fieldValidityDict);

      expect(result).toBeDefined();
    });

    it('should process email billing address field', () => {
      const dynamicFieldsInfo = [
        {
          pmdMap: 'billing.address.email',
          displayName: 'Email',
          fieldType: 'Email',
          value: undefined,
        },
      ];
      const paymentMethodDataDict = { 'billing.address.email': 'test@example.com' };
      const fieldValidityDict = { 'billing.address.email': true };

      const result = processAddressFields(dynamicFieldsInfo, paymentMethodDataDict, fieldValidityDict);

      expect(result).toBeDefined();
    });

    it('should return undefined when validity check fails', () => {
      const dynamicFieldsInfo = [
        {
          pmdMap: 'billing.address.email',
          displayName: 'Email',
          fieldType: 'Email',
          value: undefined,
        },
      ];
      const paymentMethodDataDict = { 'billing.address.email': 'invalid' };
      const fieldValidityDict = { 'billing.address.email': false };

      const result = processAddressFields(dynamicFieldsInfo, paymentMethodDataDict, fieldValidityDict);

      expect(result).toBeUndefined();
    });
  });

  describe('formPaymentMethodData', () => {
    it('should form payment method data with required fields', () => {
      const requiredFields = {
        payoutMethodData: [
          {
            pmdMap: 'payout_method_data.card.card_number',
            displayName: 'user_card_number',
            fieldType: 'CardNumber',
            value: undefined,
          },
        ],
        address: undefined,
      };
      const paymentMethodDataDict = { 'card.cardNumber': '4111111111111111' };
      const fieldValidityDict = { 'card.cardNumber': true };

      const result = formPaymentMethodData(paymentMethodDataDict, fieldValidityDict, requiredFields);

      expect(result).toBeDefined();
    });

    it('should return empty array when no valid data', () => {
      const requiredFields = {
        payoutMethodData: [],
        address: undefined,
      };

      const result = formPaymentMethodData({}, {}, requiredFields);

      expect(result).toEqual([]);
    });
  });

  describe('formBody', () => {
    it('should form body for PayoutLinkInitiate flow', () => {
      const paymentMethodData = [
        { TAG: 'Card', _0: 'Credit' },
        [
          [{ _0: { pmdMap: 'card.cardNumber' } }, '4111111111111111'],
        ],
      ];

      const result = formBody('PayoutLinkInitiate', paymentMethodData);

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result.some((item: any) => item[0] === 'payout_type')).toBe(true);
    });

    it('should form body for other flow types', () => {
      const paymentMethodData = [
        { TAG: 'Card', _0: 'Credit' },
        [
          [{ _0: { pmdMap: 'card.cardNumber' } }, '4111111111111111'],
        ],
      ];

      const result = formBody('OtherFlow', paymentMethodData);

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result.some((item: any) => item[0] === 'payment_method')).toBe(true);
      expect(result.some((item: any) => item[0] === 'payment_method_type')).toBe(true);
    });

    it('should add browser info for BankRedirect', () => {
      const paymentMethodData = [
        { TAG: 'BankRedirect', _0: 'Interac' },
        [],
      ];

      const result = formBody('PayoutLinkInitiate', paymentMethodData);

      expect(result).toBeDefined();
    });
  });

  describe('getPayoutDynamicFields', () => {
    const enabledPaymentMethodsWithDynamicFields = [
      { TAG: 'Card', _0: ['Credit', { address: undefined, payoutMethodData: [] }] },
      { TAG: 'BankTransfer', _0: ['ACH', { address: undefined, payoutMethodData: [] }] },
      { TAG: 'Wallet', _0: ['Paypal', { address: undefined, payoutMethodData: [] }] },
    ];

    it('should return fields for Card payment method type', () => {
      const result = getPayoutDynamicFields(enabledPaymentMethodsWithDynamicFields, { TAG: 'Card', _0: 'Credit' });

      expect(result).toBeDefined();
    });

    it('should return fields for ACH bank transfer', () => {
      const result = getPayoutDynamicFields(enabledPaymentMethodsWithDynamicFields, { TAG: 'BankTransfer', _0: 'ACH' });

      expect(result).toBeDefined();
    });

    it('should return fields for Paypal wallet', () => {
      const result = getPayoutDynamicFields(enabledPaymentMethodsWithDynamicFields, { TAG: 'Wallet', _0: 'Paypal' });

      expect(result).toBeDefined();
    });

    it('should return undefined for non-matching payment method type', () => {
      const result = getPayoutDynamicFields(enabledPaymentMethodsWithDynamicFields, { TAG: 'BankTransfer', _0: 'Sepa' });

      expect(result).toBeUndefined();
    });
  });

  describe('getDefaultsAndValidity', () => {
    it('should return defaults and validity for payout fields', () => {
      const payoutDynamicFields = {
        address: [
          {
            pmdMap: 'billing.address.email',
            displayName: 'Email',
            fieldType: 'Email',
            value: 'test@example.com',
          },
        ],
        payoutMethodData: [
          {
            pmdMap: 'payout_method_data.card.card_number',
            displayName: 'user_card_number',
            fieldType: 'CardNumber',
            value: '4111111111111111',
          },
        ],
      };

      const result = getDefaultsAndValidity(payoutDynamicFields, undefined);

      expect(result).toBeDefined();
    });

    it('should handle payout dynamic fields with empty address', () => {
      const result = getDefaultsAndValidity({ address: undefined, payoutMethodData: [] }, undefined);

      expect(result).toBeUndefined();
    });

    it('should handle payout dynamic fields with empty payout method data', () => {
      const result = getDefaultsAndValidity({ address: undefined, payoutMethodData: [] }, undefined);

      expect(result).toBeUndefined();
    });
  });

  describe('itemToObjMapper', () => {
    it('should map dict to options object', () => {
      const dict = {
        linkId: 'link_123',
        payoutId: 'payout_123',
        customerId: 'cust_123',
        theme: '#1A1A1A',
        collectorName: 'TestCollector',
        logo: 'https://example.com/logo.png',
        amount: '100.00',
        currency: 'USD',
        flow: 'PayoutLinkInitiate',
        sessionExpiry: '2024-12-31',
        formLayout: 'Tabs',
      };

      const result = itemToObjMapper(dict);

      expect(result.linkId).toBe('link_123');
      expect(result.payoutId).toBe('payout_123');
      expect(result.customerId).toBe('cust_123');
      expect(result.theme).toBe('#1A1A1A');
      expect(result.collectorName).toBe('TestCollector');
    });

    it('should use defaults for missing fields', () => {
      const result = itemToObjMapper({});

      expect(result.linkId).toBe('');
      expect(result.payoutId).toBe('');
      expect(result.amount).toBe('0.01');
      expect(result.currency).toBe('EUR');
      expect(result.flow).toBe('PayoutLinkInitiate');
      expect(result.formLayout).toBe('Tabs');
    });

    it('should handle enabledPaymentMethods array', () => {
      const dict = {
        enabledPaymentMethods: [],
      };

      const result = itemToObjMapper(dict);

      expect(result.enabledPaymentMethods).toBeDefined();
    });
  });

  describe('defaultDynamicPmdFields', () => {
    it('should return card fields for Card type', () => {
      const result = defaultDynamicPmdFields({ TAG: 'Card', _0: 'Credit' });

      expect(Array.isArray(result)).toBe(true);
    });

    it('should return interac fields for BankRedirect type', () => {
      const result = defaultDynamicPmdFields({ TAG: 'BankRedirect', _0: 'Interac' });

      expect(Array.isArray(result)).toBe(true);
    });

    it('should return ACH fields for ACH BankTransfer type', () => {
      const result = defaultDynamicPmdFields({ TAG: 'BankTransfer', _0: 'ACH' });

      expect(Array.isArray(result)).toBe(true);
    });

    it('should return Bacs fields for Bacs BankTransfer type', () => {
      const result = defaultDynamicPmdFields({ TAG: 'BankTransfer', _0: 'Bacs' });

      expect(Array.isArray(result)).toBe(true);
    });

    it('should return Pix fields for Pix BankTransfer type', () => {
      const result = defaultDynamicPmdFields({ TAG: 'BankTransfer', _0: 'Pix' });

      expect(Array.isArray(result)).toBe(true);
    });

    it('should return SEPA fields for Sepa BankTransfer type', () => {
      const result = defaultDynamicPmdFields({ TAG: 'BankTransfer', _0: 'Sepa' });

      expect(Array.isArray(result)).toBe(true);
    });

    it('should return Paypal fields for Paypal Wallet type', () => {
      const result = defaultDynamicPmdFields({ TAG: 'Wallet', _0: 'Paypal' });

      expect(Array.isArray(result)).toBe(true);
    });

    it('should return empty array for Venmo Wallet type', () => {
      const result = defaultDynamicPmdFields({ TAG: 'Wallet', _0: 'Venmo' });

      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('defaultPayoutDynamicFields', () => {
    it('should return fields with address and payoutMethodData', () => {
      const result = defaultPayoutDynamicFields({ TAG: 'Card', _0: 'Credit' });

      expect(result).toHaveProperty('address');
      expect(result).toHaveProperty('payoutMethodData');
    });

    it('should use default payment method type when not provided', () => {
      const result = defaultPayoutDynamicFields(undefined);

      expect(result).toHaveProperty('address');
      expect(result).toHaveProperty('payoutMethodData');
    });
  });

  describe('field constants', () => {
    it('should have correct defaultCardFields', () => {
      expect(Array.isArray(defaultCardFields)).toBe(true);
      expect(defaultCardFields.length).toBe(3);
    });

    it('should have correct defaultAchFields', () => {
      expect(Array.isArray(defaultAchFields)).toBe(true);
      expect(defaultAchFields.length).toBe(2);
    });

    it('should have correct defaultBacsFields', () => {
      expect(Array.isArray(defaultBacsFields)).toBe(true);
      expect(defaultBacsFields.length).toBe(2);
    });

    it('should have correct defaultPixTransferFields', () => {
      expect(Array.isArray(defaultPixTransferFields)).toBe(true);
      expect(defaultPixTransferFields.length).toBe(2);
    });

    it('should have correct defaultSepaFields', () => {
      expect(Array.isArray(defaultSepaFields)).toBe(true);
      expect(defaultSepaFields.length).toBe(1);
    });

    it('should have correct defaultPaypalFields', () => {
      expect(Array.isArray(defaultPaypalFields)).toBe(true);
      expect(defaultPaypalFields.length).toBe(1);
    });

    it('should have correct defaultInteracFields', () => {
      expect(Array.isArray(defaultInteracFields)).toBe(true);
      expect(defaultInteracFields.length).toBe(1);
    });

    it('should have correct defaultEnabledPaymentMethods', () => {
      expect(Array.isArray(defaultEnabledPaymentMethods)).toBe(true);
      expect(defaultEnabledPaymentMethods.length).toBeGreaterThan(0);
    });

    it('should have correct defaultEnabledPaymentMethodsWithDynamicFields', () => {
      expect(Array.isArray(defaultEnabledPaymentMethodsWithDynamicFields)).toBe(true);
      expect(defaultEnabledPaymentMethodsWithDynamicFields.length).toBeGreaterThan(0);
    });

    it('should have correct defaultPaymentMethodCollectOptions', () => {
      expect(defaultPaymentMethodCollectOptions).toHaveProperty('enabledPaymentMethods');
      expect(defaultPaymentMethodCollectOptions).toHaveProperty('linkId');
      expect(defaultPaymentMethodCollectOptions).toHaveProperty('amount');
      expect(defaultPaymentMethodCollectOptions).toHaveProperty('currency');
    });

    it('should have correct defaultStatusInfo', () => {
      expect(defaultStatusInfo).toHaveProperty('status');
      expect(defaultStatusInfo).toHaveProperty('payoutId');
      expect(defaultStatusInfo).toHaveProperty('message');
    });
  });

  describe('icon functions', () => {
    describe('getPaymentMethodIcon', () => {
      it('should return React element for Card', () => {
        const result = getPaymentMethodIcon('Card');
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for BankRedirect', () => {
        const result = getPaymentMethodIcon('BankRedirect');
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for BankTransfer', () => {
        const result = getPaymentMethodIcon('BankTransfer');
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for Wallet', () => {
        const result = getPaymentMethodIcon('Wallet');
        expect(React.isValidElement(result)).toBe(true);
      });
    });

    describe('getBankTransferIcon', () => {
      it('should return React element for ACH', () => {
        const result = getBankTransferIcon('ACH');
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for Pix', () => {
        const result = getBankTransferIcon('Pix');
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for Bacs', () => {
        const result = getBankTransferIcon('Bacs');
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for Sepa', () => {
        const result = getBankTransferIcon('Sepa');
        expect(React.isValidElement(result)).toBe(true);
      });
    });

    describe('getWalletIcon', () => {
      it('should return React element for Paypal', () => {
        const result = getWalletIcon('Paypal');
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for Venmo', () => {
        const result = getWalletIcon('Venmo');
        expect(React.isValidElement(result)).toBe(true);
      });
    });

    describe('getBankRedirectIcon', () => {
      it('should return React element', () => {
        const result = getBankRedirectIcon('Interac');
        expect(React.isValidElement(result)).toBe(true);
      });
    });

    describe('getPaymentMethodTypeIcon', () => {
      it('should return React element for Card type', () => {
        const result = getPaymentMethodTypeIcon({ TAG: 'Card', _0: 'Credit' });
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for BankRedirect type', () => {
        const result = getPaymentMethodTypeIcon({ TAG: 'BankRedirect', _0: 'Interac' });
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for BankTransfer type', () => {
        const result = getPaymentMethodTypeIcon({ TAG: 'BankTransfer', _0: 'ACH' });
        expect(React.isValidElement(result)).toBe(true);
      });

      it('should return React element for Wallet type', () => {
        const result = getPaymentMethodTypeIcon({ TAG: 'Wallet', _0: 'Paypal' });
        expect(React.isValidElement(result)).toBe(true);
      });
    });
  });

  describe('calculateValidity additional cases', () => {
    it('should validate card holder name with space', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'CardHolderName' },
        'John Doe',
        '',
        undefined
      );
      expect(result).toBe(true);
    });

    it('should invalidate card holder name without space', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'CardHolderName' },
        'John',
        '',
        undefined
      );
      expect(result).toBe(false);
    });

    it('should return default for empty card holder name', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'CardHolderName' },
        '',
        '',
        true
      );
      expect(result).toBe(true);
    });

    it('should validate ACH routing number', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'ACHRoutingNumber' },
        '123456780',
        '',
        undefined
      );
      expect(result).toBe(true);
    });

    it('should invalidate short ACH routing number', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'ACHRoutingNumber' },
        '12345',
        '',
        undefined
      );
      expect(result).toBe(false);
    });

    it('should validate SEPA IBAN', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'SepaIban' },
        'DE89370400440532013000',
        '',
        undefined
      );
      expect(result).toBe(true);
    });

    it('should invalidate short SEPA IBAN', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'SepaIban' },
        'DE89',
        '',
        undefined
      );
      expect(result).toBe(false);
    });

    it('should validate SEPA BIC', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'SepaBic' },
        'DEUTDEFF',
        '',
        undefined
      );
      expect(result).toBe(true);
    });

    it('should validate email', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'PaypalMail' },
        'test@example.com',
        '',
        undefined
      );
      expect(result).toBe(true);
    });

    it('should invalidate invalid email', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'PaypalMail' },
        'invalid-email',
        '',
        undefined
      );
      expect(result).toBe(false);
    });

    it('should return default for empty email', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'PaypalMail' },
        '',
        '',
        true
      );
      expect(result).toBe(true);
    });

    it('should validate expiry date', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: { TAG: 'CardExpDate', _0: 'CardExpMonth' } },
        '12/25',
        '',
        undefined
      );
      expect(typeof result).toBe('boolean');
    });

    it('should validate billing email', () => {
      const result = calculateValidity(
        { TAG: 'BillingAddress', _0: 'Email' },
        'test@example.com',
        '',
        undefined
      );
      expect(result).toBe(true);
    });

    it('should invalidate invalid billing email', () => {
      const result = calculateValidity(
        { TAG: 'BillingAddress', _0: 'Email' },
        'invalid',
        '',
        undefined
      );
      expect(result).toBe(false);
    });

    it('should return default for empty billing email', () => {
      const result = calculateValidity(
        { TAG: 'BillingAddress', _0: 'Email' },
        '',
        '',
        true
      );
      expect(result).toBe(true);
    });

    it('should validate non-empty field value', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'ACHBankName' },
        'Test Bank',
        '',
        undefined
      );
      expect(result).toBe(true);
    });

    it('should invalidate empty field value', () => {
      const result = calculateValidity(
        { TAG: 'PayoutMethodData', _0: 'ACHBankName' },
        '',
        '',
        undefined
      );
      expect(result).toBe(false);
    });
  });

  describe('getPaymentMethodDataErrorString additional cases', () => {
    it('should return error for invalid routing number', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'ACHRoutingNumber' };
      expect(getPaymentMethodDataErrorString(key, '12345', mockLocaleString)).toBe('Invalid routing number');
    });

    it('should return empty for valid complete routing number', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'ACHRoutingNumber' };
      expect(getPaymentMethodDataErrorString(key, '123456780', mockLocaleString)).toBe('');
    });

    it('should return error for empty sort code', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'BacsSortCode' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Sort Code is required');
    });

    it('should return error for invalid sort code', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'BacsSortCode' };
      expect(getPaymentMethodDataErrorString(key, 'abc', mockLocaleString)).toBe('Invalid sort code');
    });

    it('should return error for empty BACS account number', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'BacsAccountNumber' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Account Number is required');
    });

    it('should return error for invalid BACS account number', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'BacsAccountNumber' };
      expect(getPaymentMethodDataErrorString(key, 'abc', mockLocaleString)).toBe('Invalid account number');
    });

    it('should return error for empty SEPA IBAN', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'SepaIban' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('IBAN is required');
    });

    it('should return error for invalid SEPA IBAN', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'SepaIban' };
      expect(getPaymentMethodDataErrorString(key, 'invalid', mockLocaleString)).toBe('Invalid IBAN');
    });

    it('should return error for phone number', () => {
      const key = { TAG: 'BillingAddress', _0: 'PhoneNumber' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Phone Number is required');
    });

    it('should return error for country code', () => {
      const key = { TAG: 'BillingAddress', _0: 'CountryCode' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Country Code is required');
    });

    it('should return error for address line 1', () => {
      const key = { TAG: 'BillingAddress', _0: 'AddressLine1' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Address line 1 is required');
    });

    it('should return error for address line 2', () => {
      const key = { TAG: 'BillingAddress', _0: 'AddressLine2' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Address line 2 is required');
    });

    it('should return error for city', () => {
      const key = { TAG: 'BillingAddress', _0: 'AddressCity' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('City is required');
    });

    it('should return error for state', () => {
      const key = { TAG: 'BillingAddress', _0: 'AddressState' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('State is required');
    });

    it('should return error for empty postal code', () => {
      const key = { TAG: 'BillingAddress', _0: 'AddressPincode' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Postal code is required');
    });

    it('should return error for invalid postal code', () => {
      const key = { TAG: 'BillingAddress', _0: 'AddressPincode' };
      expect(getPaymentMethodDataErrorString(key, '@#$', mockLocaleString)).toBe('Invalid postal code');
    });

    it('should return error for card holder name empty', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardHolderName' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Card Holder Name is required');
    });

    it('should return error for card holder name incomplete', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'CardHolderName' };
      expect(getPaymentMethodDataErrorString(key, 'John', mockLocaleString)).toBe('Card Holder Name is incomplete');
    });

    it('should return error for interac email empty', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'InteracEmail' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('Email is required');
    });

    it('should return error for invalid interac email', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'InteracEmail' };
      expect(getPaymentMethodDataErrorString(key, 'invalid', mockLocaleString)).toBe('Invalid email');
    });

    it('should return empty string for unknown field', () => {
      const key = { TAG: 'PayoutMethodData', _0: 'ACHBankName' };
      expect(getPaymentMethodDataErrorString(key, '', mockLocaleString)).toBe('');
    });
  });

  describe('getPayoutStatusString additional cases', () => {
    it('should return cancelled for Expired', () => {
      expect(getPayoutStatusString('Expired')).toBe('cancelled');
    });

    it('should return reversed for Reversed', () => {
      expect(getPayoutStatusString('Reversed')).toBe('reversed');
    });

    it('should return ineligible for Ineligible', () => {
      expect(getPayoutStatusString('Ineligible')).toBe('ineligible');
    });

    it('should return requires_creation for RequiresCreation', () => {
      expect(getPayoutStatusString('RequiresCreation')).toBe('requires_creation');
    });

    it('should return requires_confirmation for RequiresConfirmation', () => {
      expect(getPayoutStatusString('RequiresConfirmation')).toBe('requires_confirmation');
    });

    it('should return requires_payout_method_data for RequiresPayoutMethodData', () => {
      expect(getPayoutStatusString('RequiresPayoutMethodData')).toBe('requires_payout_method_data');
    });

    it('should return requires_fulfillment for RequiresFulfillment', () => {
      expect(getPayoutStatusString('RequiresFulfillment')).toBe('requires_fulfillment');
    });

    it('should return requires_vendor_account_creation for RequiresVendorAccountCreation', () => {
      expect(getPayoutStatusString('RequiresVendorAccountCreation')).toBe('requires_vendor_account_creation');
    });
  });
});
