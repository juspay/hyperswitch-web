import {
  cardPaymentBody,
  savedCardBody,
  gpayBody,
  applePayBody,
  cryptoBody,
  achBankDebitBody,
  sofortBody,
  iDealBody,
  blikBody,
  getPaymentMethodType,
  billingDetailsTuple,
  mandateBody,
  bankDebitsCommonBody,
  bacsBankDebitBody,
  becsBankDebitBody,
  installmentBody,
  bancontactBody,
  boletoBody,
  savedPaymentMethodBody,
  paymentTypeBody,
  confirmPayloadForSDKButton,
  klarnaSDKbody,
  klarnaCheckoutBody,
  paypalSdkBody,
  samsungPayBody,
  gpayRedirectBody,
  gPayThirdPartySdkBody,
  applePayRedirectBody,
  applePayThirdPartySdkBody,
  afterpayRedirectionBody,
  giroPayBody,
  trustlyBody,
  polandOB,
  czechOB,
  slovakiaOB,
  mbWayBody,
  rewardBody,
  fpxOBBody,
  thailandOBBody,
  pazeBody,
  revolutPayBody,
  eftBody,
  getPaymentMethodSuffix,
  appendPaymentMethodExperience,
  dynamicPaymentBody,
  getPaymentBody,
  appendRedirectPaymentMethods,
  appendBankeDebitMethods,
  appendBankTransferMethods,
  paymentExperiencePaymentMethods,
  appendPaymentExperience,
} from '../Utilities/PaymentBody.bs.js';

describe('PaymentBody', () => {
  describe('cardPaymentBody', () => {
    it('should create card payment body with valid card data', () => {
      const result = cardPaymentBody('4111111111111111', '12', '2025', 'John Doe', '123', [], undefined);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry).toBeDefined();
      expect(paymentMethodEntry[1]).toBe('card');
    });

    it('should include card details in payment_method_data', () => {
      const result = cardPaymentBody('4111111111111111', '12', '2025', 'John Doe', '123', [], undefined);
      
      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should handle missing optional parameters', () => {
      const result = cardPaymentBody('4111111111111111', '12', '2025', undefined, '123', [], undefined);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    // Edge case: empty string card number
    it('should handle empty string card number', () => {
      const result = cardPaymentBody('', '12', '2025', undefined, '123', [], undefined);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    // Edge case: empty month and year
    it('should handle empty month and year strings', () => {
      const result = cardPaymentBody('4111111111111111', '', '', undefined, '123', [], undefined);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('savedCardBody', () => {
    it('should create saved card body with token and customer ID', () => {
      const result = savedCardBody('token123', 'customer456', '123', true, false);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('card');
      
      const tokenEntry = result.find((entry: any) => entry[0] === 'payment_token');
      expect(tokenEntry[1]).toBe('token123');
    });

    it('should include CVC when requiresCvv is true', () => {
      const result = savedCardBody('token123', 'customer456', '123', true, false);
      const cvcEntry = result.find((entry: any) => entry[0] === 'card_cvc');
      expect(cvcEntry).toBeDefined();
      expect(cvcEntry[1]).toBe('123');
    });

    it('should not include CVC when requiresCvv is false', () => {
      const result = savedCardBody('token123', 'customer456', '123', false, false);
      const cvcEntry = result.find((entry: any) => entry[0] === 'card_cvc');
      expect(cvcEntry).toBeUndefined();
    });
  });

  describe('gpayBody', () => {
    it('should create Google Pay body with payment data', () => {
      const payObj = {
        paymentMethodData: {
          type: 'CARD',
          description: 'Visa 1234',
          info: { cardNetwork: 'VISA', cardDetails: '1234' },
          tokenizationData: { type: 'PAYMENT_GATEWAY', token: 'test-token' },
        },
      };
      const result = gpayBody(payObj, []);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('google_pay');
    });

    it('should include connectors when provided', () => {
      const payObj = {
        paymentMethodData: {
          type: 'CARD',
          description: 'Visa 1234',
          info: { cardNetwork: 'VISA' },
          tokenizationData: { type: 'PAYMENT_GATEWAY', token: 'test' },
        },
      };
      const result = gpayBody(payObj, ['stripe', 'adyen']);
      const connectorEntry = result.find((entry: any) => entry[0] === 'connector');
      expect(connectorEntry).toBeDefined();
    });
  });

  describe('applePayBody', () => {
    it('should create Apple Pay body with token', () => {
      const token = { paymentData: { data: 'test' }, transactionIdentifier: 'abc123' };
      const result = applePayBody(token, []);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('apple_pay');
    });
  });

  describe('cryptoBody', () => {
    it('should create crypto payment body', () => {
      const result = cryptoBody();
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('crypto');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('crypto_currency');
    });
  });

  describe('achBankDebitBody', () => {
    it('should create ACH bank debit body with bank details', () => {
      const bank = {
        accountNumber: '123456789',
        accountHolderName: 'John Doe',
        routingNumber: '021000021',
        accountType: 'checking',
      };
      const result = achBankDebitBody(
        'test@email.com',
        bank,
        'John Doe',
        '123 Main St',
        'Apt 4',
        'US',
        'New York',
        '10001',
        'NY'
      );
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('bank_debit');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('ach');
    });
  });

  describe('sofortBody', () => {
    it('should create Sofort payment body', () => {
      const result = sofortBody('DE', 'John Doe', 'test@email.com');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('bank_redirect');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('sofort');
    });

    it('should use default country when empty', () => {
      const result = sofortBody('', 'John Doe', 'test@email.com');
      expect(result).toBeDefined();
    });
  });

  describe('iDealBody', () => {
    it('should create iDeal payment body', () => {
      const result = iDealBody('John Doe', 'INGBNL2A');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('bank_redirect');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('ideal');
    });
  });

  describe('blikBody', () => {
    it('should create BLIK payment body with code', () => {
      const result = blikBody('123456');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('bank_redirect');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('blik');
    });
  });

  describe('getPaymentMethodType', () => {
    it('should return payment method type unchanged for most methods', () => {
      expect(getPaymentMethodType('card', 'credit')).toBe('credit');
      expect(getPaymentMethodType('wallet', 'google_pay')).toBe('google_pay');
    });

    it('should remove _debit suffix for bank_debit', () => {
      expect(getPaymentMethodType('bank_debit', 'ach_debit')).toBe('ach');
      expect(getPaymentMethodType('bank_debit', 'sepa_debit')).toBe('sepa');
    });

    it('should handle bank_transfer correctly', () => {
      expect(getPaymentMethodType('bank_transfer', 'ach')).toBe('ach');
    });
  });

  describe('billingDetailsTuple', () => {
    it('should create billing details tuple', () => {
      const result = billingDetailsTuple(
        'John Doe',
        'test@email.com',
        '123 Main St',
        'Apt 4',
        'New York',
        'NY',
        '10001',
        'US'
      );
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result[0]).toBe('billing');
    });
  });

  describe('mandateBody', () => {
    it('should create mandate body with payment type', () => {
      const result = mandateBody('recurring');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const setupEntry = result.find((entry: any) => entry[0] === 'setup_future_usage');
      expect(setupEntry).toBeDefined();
      expect(setupEntry[1]).toBe('off_session');
    });

    it('should handle empty payment type', () => {
      const result = mandateBody('');
      expect(result).toBeDefined();
    });
  });

  describe('bankDebitsCommonBody', () => {
    it('should create common bank debits body', () => {
      const result = bankDebitsCommonBody('ach');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const paymentMethodEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(paymentMethodEntry[1]).toBe('bank_debit');
    });
  });

  describe('bacsBankDebitBody', () => {
    it('should create BACS bank debit body', () => {
      const result = bacsBankDebitBody(
        'test@email.com',
        '12345678',
        '123456',
        '123 Main St',
        'Apt 4',
        'London',
        'SW1A 1AA',
        '',
        'GB',
        'John Doe'
      );
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('bacs');
    });
  });

  describe('becsBankDebitBody', () => {
    it('should create BECS bank debit body', () => {
      const data = {
        sortCode: '123456',
        accountNumber: '12345678',
        accountHolderName: 'John Doe',
      };
      const result = becsBankDebitBody(
        'John Doe',
        'test@email.com',
        data,
        '123 Main St',
        'Apt 4',
        'AU',
        'Sydney',
        '2000',
        'NSW'
      );
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('becs');
    });
  });

  describe('installmentBody', () => {
    it('should create installment body with plan', () => {
      const plan = { number_of_installments: 3, billing_frequency: 'monthly' };
      const result = installmentBody(plan);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(1);
      expect(result[0][0]).toBe('installment_data');
    });

    it('should return empty array when no plan', () => {
      expect(installmentBody(undefined)).toEqual([]);
    });
  });

  describe('bancontactBody', () => {
    it('should create bancontact payment body', () => {
      const result = bancontactBody();
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('bank_redirect');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('bancontact_card');
    });
  });

  describe('boletoBody', () => {
    it('should create boleto payment body', () => {
      const result = boletoBody('123.456.789-00');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('voucher');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('boleto');
    });
  });

  describe('savedPaymentMethodBody', () => {
    it('should create saved payment method body', () => {
      const result = savedPaymentMethodBody('token123', 'cust456', 'card', 'credit', false);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const tokenEntry = result.find((entry: any) => entry[0] === 'payment_token');
      expect(tokenEntry[1]).toBe('token123');
    });

    it('should include customer acceptance when required', () => {
      const result = savedPaymentMethodBody('token123', 'cust456', 'card', 'credit', true);
      const caEntry = result.find((entry: any) => entry[0] === 'customer_acceptance');
      expect(caEntry).toBeDefined();
    });
  });

  describe('paymentTypeBody', () => {
    it('should return payment type when not empty', () => {
      const result = paymentTypeBody('recurring');
      expect(result).toEqual([['payment_type', 'recurring']]);
    });

    it('should return empty array for empty string', () => {
      expect(paymentTypeBody('')).toEqual([]);
    });
  });

  describe('confirmPayloadForSDKButton', () => {
    it('should create confirm payload for SDK button', () => {
      const sdkHandle = {
        confirmParams: { return_url: 'https://example.com/return' },
      };
      const result = confirmPayloadForSDKButton(sdkHandle);
      expect(result).toBeDefined();
      expect(result.confirmParams).toBeDefined();
      expect(result.confirmParams.return_url).toBe('https://example.com/return');
      expect(result.confirmParams.redirect).toBe('always');
    });
  });

  describe('klarnaSDKbody', () => {
    it('should create Klarna SDK body', () => {
      const result = klarnaSDKbody('klarna_token_123', ['connector1', 'connector2']);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('pay_later');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('klarna');
    });
  });

  describe('klarnaCheckoutBody', () => {
    it('should create Klarna checkout body', () => {
      const result = klarnaCheckoutBody(['connector1']);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('pay_later');
      
      const peEntry = result.find((entry: any) => entry[0] === 'payment_experience');
      expect(peEntry[1]).toBe('redirect_to_url');
    });
  });

  describe('paypalSdkBody', () => {
    it('should create PayPal SDK body', () => {
      const result = paypalSdkBody('paypal_token_123', ['connector1']);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('paypal');
    });
  });

  describe('samsungPayBody', () => {
    it('should create Samsung Pay body', () => {
      const result = samsungPayBody({ token: 'samsung_token' });
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('samsung_pay');
    });
  });

  describe('gpayRedirectBody', () => {
    it('should create Google Pay redirect body', () => {
      const result = gpayRedirectBody(['connector1']);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('google_pay');
    });
  });

  describe('gPayThirdPartySdkBody', () => {
    it('should create Google Pay third party SDK body', () => {
      const result = gPayThirdPartySdkBody(['connector1']);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('google_pay');
    });
  });

  describe('applePayRedirectBody', () => {
    it('should create Apple Pay redirect body', () => {
      const result = applePayRedirectBody(['connector1']);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('apple_pay');
    });
  });

  describe('applePayThirdPartySdkBody', () => {
    it('should create Apple Pay third party SDK body with token', () => {
      const result = applePayThirdPartySdkBody(['connector1'], 'apple_token');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
    });

    it('should create Apple Pay third party SDK body without token', () => {
      const result = applePayThirdPartySdkBody(['connector1'], undefined);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('afterpayRedirectionBody', () => {
    it('should create Afterpay redirect body', () => {
      const result = afterpayRedirectionBody();
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('pay_later');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('afterpay_clearpay');
    });
  });

  describe('giroPayBody', () => {
    it('should create Giropay body with IBAN', () => {
      const result = giroPayBody('John Doe', 'DE89370400440532013000');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('bank_redirect');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('giropay');
    });

    it('should create Giropay body without IBAN', () => {
      const result = giroPayBody('John Doe', undefined);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('trustlyBody', () => {
    it('should create Trustly body', () => {
      const result = trustlyBody('US');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('bank_redirect');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('trustly');
    });
  });

  describe('polandOB', () => {
    it('should create Poland online banking body', () => {
      const result = polandOB('bank_xyz');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('online_banking_poland');
    });
  });

  describe('czechOB', () => {
    it('should create Czech online banking body', () => {
      const result = czechOB('bank_abc');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('online_banking_czech_republic');
    });
  });

  describe('slovakiaOB', () => {
    it('should create Slovakia online banking body', () => {
      const result = slovakiaOB('bank_def');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('online_banking_slovakia');
    });
  });

  describe('mbWayBody', () => {
    it('should create MB Way body', () => {
      const result = mbWayBody('+351912345678');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('mb_way');
    });
  });

  describe('rewardBody', () => {
    it('should create reward payment body', () => {
      const result = rewardBody('classic');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('reward');
    });
  });

  describe('fpxOBBody', () => {
    it('should create FPX online banking body', () => {
      const result = fpxOBBody('maybank');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('online_banking_fpx');
    });
  });

  describe('thailandOBBody', () => {
    it('should create Thailand online banking body', () => {
      const result = thailandOBBody('kbank');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('online_banking_thailand');
    });
  });

  describe('pazeBody', () => {
    it('should create Paze wallet body', () => {
      const result = pazeBody({ token: 'paze_token' });
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('paze');
    });
  });

  describe('revolutPayBody', () => {
    it('should create Revolut Pay body', () => {
      const result = revolutPayBody();
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('wallet');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('revolut_pay');
    });
  });

  describe('eftBody', () => {
    it('should create EFT body', () => {
      const result = eftBody();
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('bank_redirect');
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('eft');
    });
  });

  describe('getPaymentMethodSuffix', () => {
    it('should return "qr" for QR payment method', () => {
      expect(getPaymentMethodSuffix('any_pm', 'card', true)).toBe('qr');
    });

    it('should return "redirect" for redirect payment methods', () => {
      expect(getPaymentMethodSuffix('paypal', 'wallet', false)).toBe('redirect');
    });

    it('should return "bank_debit" for bank debit methods', () => {
      expect(getPaymentMethodSuffix('sepa', 'bank_debit', false)).toBe('bank_debit');
    });

    it('should return "bank_transfer" for bank transfer methods', () => {
      expect(getPaymentMethodSuffix('ach', 'bank_transfer', false)).toBe('bank_transfer');
    });

    it('should return undefined for other payment methods', () => {
      expect(getPaymentMethodSuffix('credit', 'card', false)).toBeUndefined();
    });
  });

  describe('appendPaymentMethodExperience', () => {
    it('should append suffix for redirect methods', () => {
      expect(appendPaymentMethodExperience('wallet', 'paypal', false)).toBe('paypal_redirect');
    });

    it('should append suffix for QR methods', () => {
      expect(appendPaymentMethodExperience('wallet', 'any_qr', true)).toBe('any_qr_qr');
    });

    it('should return original when no suffix', () => {
      expect(appendPaymentMethodExperience('card', 'credit', false)).toBe('credit');
    });
  });

  describe('dynamicPaymentBody', () => {
    it('should create dynamic payment body', () => {
      const result = dynamicPaymentBody('card', 'credit', false);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmEntry = result.find((entry: any) => entry[0] === 'payment_method');
      expect(pmEntry[1]).toBe('card');
    });

    it('should handle QR payment method', () => {
      const result = dynamicPaymentBody('wallet', 'any_pm', true);
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('getPaymentBody', () => {
    it('should return crypto body for crypto_currency', () => {
      const result = getPaymentBody('crypto', 'crypto_currency', '', '', '', '', '', undefined, '');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      
      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry[1]).toBe('crypto_currency');
    });

    it('should return blik body for blik', () => {
      const result = getPaymentBody('bank_redirect', 'blik', '', '', '', '', '123456', undefined, '');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should return revolut_pay body', () => {
      const result = getPaymentBody('wallet', 'revolut_pay', '', '', '', '', '', undefined, '');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should return eft body', () => {
      const result = getPaymentBody('bank_redirect', 'eft', '', '', '', '', '', undefined, '');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should return afterpay body', () => {
      const result = getPaymentBody('pay_later', 'afterpay_clearplay', '', '', '', '', '', undefined, '');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should return reward body for classic', () => {
      const result = getPaymentBody('reward', 'classic', '', '', '', '', '', undefined, '');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should return dynamic body for unknown payment method', () => {
      const result = getPaymentBody('unknown', 'unknown_type', '', '', '', '', '', undefined, '');
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });

  describe('appendRedirectPaymentMethods', () => {
    it('should contain common redirect methods', () => {
      expect(appendRedirectPaymentMethods).toContain('paypal');
      expect(appendRedirectPaymentMethods).toContain('klarna');
      expect(appendRedirectPaymentMethods).toContain('affirm');
    });
  });

  describe('appendBankeDebitMethods', () => {
    it('should contain bank debit methods', () => {
      expect(appendBankeDebitMethods).toContain('sepa');
    });
  });

  describe('appendBankTransferMethods', () => {
    it('should contain bank transfer methods', () => {
      expect(appendBankTransferMethods).toContain('ach');
      expect(appendBankTransferMethods).toContain('bacs');
      expect(appendBankTransferMethods).toContain('multibanco');
    });
  });

  describe('paymentExperiencePaymentMethods', () => {
    it('should contain payment experience methods', () => {
      expect(paymentExperiencePaymentMethods).toContain('paypal');
      expect(paymentExperiencePaymentMethods).toContain('klarna');
      expect(paymentExperiencePaymentMethods).toContain('affirm');
    });
  });

  describe('appendPaymentExperience', () => {
    it('should append payment experience for paypal', () => {
      const body = [['payment_method', 'wallet']];
      const result = appendPaymentExperience(body, 'paypal');
      const peEntry = result.find((entry: any) => entry[0] === 'payment_experience');
      expect(peEntry).toBeDefined();
      expect(peEntry[1]).toBe('redirect_to_url');
    });

    it('should not append for non-payment-experience methods', () => {
      const body = [['payment_method', 'card']];
      const result = appendPaymentExperience(body, 'credit');
      const peEntry = result.find((entry: any) => entry[0] === 'payment_experience');
      expect(peEntry).toBeUndefined();
    });
  });
});
