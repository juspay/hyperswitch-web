import {
  defaultACHCreditTransfer,
  defaultBacsBankInstruction,
  defaultNextAction,
  defaultIntent,
  getAchCreditTransfer,
  getBacsBankInstructions,
  getBankTransferDetails,
  getVoucherDetails,
  getNextAction,
  itemToObjMapper,
} from '../Types/PaymentConfirmTypes.bs.js';

describe('PaymentConfirmTypes', () => {
  describe('defaultACHCreditTransfer', () => {
    it('should have empty default values', () => {
      expect(defaultACHCreditTransfer.account_number).toBe('');
      expect(defaultACHCreditTransfer.bank_name).toBe('');
      expect(defaultACHCreditTransfer.routing_number).toBe('');
      expect(defaultACHCreditTransfer.swift_code).toBe('');
    });
  });

  describe('defaultBacsBankInstruction', () => {
    it('should have empty default values', () => {
      expect(defaultBacsBankInstruction.sort_code).toBe('');
      expect(defaultBacsBankInstruction.account_number).toBe('');
      expect(defaultBacsBankInstruction.account_holder_name).toBe('');
    });
  });

  describe('defaultNextAction', () => {
    it('should have empty default values', () => {
      expect(defaultNextAction.redirectToUrl).toBe('');
      expect(defaultNextAction.popupUrl).toBe('');
      expect(defaultNextAction.redirectResponseUrl).toBe('');
      expect(defaultNextAction.type_).toBe('');
    });
  });

  describe('defaultIntent', () => {
    it('should have empty default values', () => {
      expect(defaultIntent.status).toBe('');
      expect(defaultIntent.paymentId).toBe('');
      expect(defaultIntent.clientSecret).toBe('');
      expect(defaultIntent.error_message).toBe('');
      expect(defaultIntent.payment_method_type).toBe('');
      expect(defaultIntent.manualRetryAllowed).toBe(false);
      expect(defaultIntent.connectorTransactionId).toBe('');
    });
  });

  describe('getAchCreditTransfer', () => {
    it('should extract ACH credit transfer details from dict', () => {
      const dict = {
        ach_credit_transfer: {
          account_number: '123456789',
          bank_name: 'Test Bank',
          routing_number: '987654321',
          swift_code: 'TESTUS33',
        },
      };
      const result = getAchCreditTransfer(dict, 'ach_credit_transfer');
      expect(result.account_number).toBe('123456789');
      expect(result.bank_name).toBe('Test Bank');
      expect(result.routing_number).toBe('987654321');
      expect(result.swift_code).toBe('TESTUS33');
    });

    it('should return default values when key not found', () => {
      const dict = {};
      const result = getAchCreditTransfer(dict, 'ach_credit_transfer');
      expect(result).toEqual(defaultACHCreditTransfer);
    });

    it('should return default values when value is null', () => {
      const dict = { ach_credit_transfer: null };
      const result = getAchCreditTransfer(dict, 'ach_credit_transfer');
      expect(result).toEqual(defaultACHCreditTransfer);
    });
  });

  describe('getBacsBankInstructions', () => {
    it('should extract BACS bank instructions from dict', () => {
      const dict = {
        bacs_bank_instructions: {
          sort_code: '123456',
          account_number: '98765432',
          account_holder_name: 'John Doe',
        },
      };
      const result = getBacsBankInstructions(dict, 'bacs_bank_instructions');
      expect(result.sort_code).toBe('123456');
      expect(result.account_number).toBe('98765432');
      expect(result.account_holder_name).toBe('John Doe');
    });

    it('should return default values when key not found', () => {
      const dict = {};
      const result = getBacsBankInstructions(dict, 'bacs_bank_instructions');
      expect(result).toEqual(defaultBacsBankInstruction);
    });

    it('should handle partial data', () => {
      const dict = {
        bacs_bank_instructions: {
          sort_code: '123456',
        },
      };
      const result = getBacsBankInstructions(dict, 'bacs_bank_instructions');
      expect(result.sort_code).toBe('123456');
      expect(result.account_number).toBe('');
      expect(result.account_holder_name).toBe('');
    });
  });

  describe('getBankTransferDetails', () => {
    it('should extract bank transfer details from dict', () => {
      const dict = {
        bank_transfer_details: {
          ach_credit_transfer: {
            account_number: '123456789',
            bank_name: 'Test Bank',
            routing_number: '987654321',
            swift_code: 'TESTUS33',
          },
        },
      };
      const result = getBankTransferDetails(dict, 'bank_transfer_details');
      expect(result).toBeDefined();
      expect(result?.ach_credit_transfer.account_number).toBe('123456789');
    });

    it('should return undefined when key not found', () => {
      const dict = {};
      const result = getBankTransferDetails(dict, 'bank_transfer_details');
      expect(result).toBeUndefined();
    });

    it('should return undefined when value is null', () => {
      const dict = { bank_transfer_details: null };
      const result = getBankTransferDetails(dict, 'bank_transfer_details');
      expect(result).toBeUndefined();
    });
  });

  describe('getVoucherDetails', () => {
    it('should extract voucher details from json', () => {
      const json = {
        download_url: 'https://example.com/voucher.pdf',
        reference: 'REF123456',
      };
      const result = getVoucherDetails(json);
      expect(result.download_url).toBe('https://example.com/voucher.pdf');
      expect(result.reference).toBe('REF123456');
    });

    it('should return empty strings for missing fields', () => {
      const json = {};
      const result = getVoucherDetails(json);
      expect(result.download_url).toBe('');
      expect(result.reference).toBe('');
    });

    it('should handle partial data', () => {
      const json = {
        download_url: 'https://example.com/voucher.pdf',
      };
      const result = getVoucherDetails(json);
      expect(result.download_url).toBe('https://example.com/voucher.pdf');
      expect(result.reference).toBe('');
    });
  });

  describe('getNextAction', () => {
    it('should extract next action from dict', () => {
      const dict = {
        next_action: {
          redirect_to_url: 'https://example.com/redirect',
          popup_url: 'https://example.com/popup',
          redirect_response_url: 'https://example.com/response',
          type: 'redirect',
        },
      };
      const result = getNextAction(dict, 'next_action');
      expect(result.redirectToUrl).toBe('https://example.com/redirect');
      expect(result.popupUrl).toBe('https://example.com/popup');
      expect(result.redirectResponseUrl).toBe('https://example.com/response');
      expect(result.type_).toBe('redirect');
    });

    it('should return default values when key not found', () => {
      const dict = {};
      const result = getNextAction(dict, 'next_action');
      expect(result).toEqual(defaultNextAction);
    });

    it('should handle voucher_details', () => {
      const dict = {
        next_action: {
          type: 'voucher',
          voucher_details: {
            download_url: 'https://example.com/voucher.pdf',
            reference: 'REF123',
          },
        },
      };
      const result = getNextAction(dict, 'next_action');
      expect(result.type_).toBe('voucher');
      expect(result.voucher_details).toBeDefined();
      expect(result.voucher_details?.download_url).toBe('https://example.com/voucher.pdf');
    });
  });

  describe('itemToObjMapper', () => {
    it('should map dict to intent object', () => {
      const dict = {
        next_action: {
          redirect_to_url: 'https://example.com/redirect',
          type: 'redirect',
        },
        status: 'succeeded',
        payment_id: 'pay_123',
        client_secret: 'secret_123',
        error_message: '',
        payment_method_type: 'card',
        manual_retry_allowed: true,
        connector_transaction_id: 'txn_123',
      };
      const result = itemToObjMapper(dict);
      expect(result.status).toBe('succeeded');
      expect(result.paymentId).toBe('pay_123');
      expect(result.clientSecret).toBe('secret_123');
      expect(result.payment_method_type).toBe('card');
      expect(result.manualRetryAllowed).toBe(true);
      expect(result.connectorTransactionId).toBe('txn_123');
    });

    it('should use default values for missing fields', () => {
      const dict = {};
      const result = itemToObjMapper(dict);
      expect(result.status).toBe('');
      expect(result.paymentId).toBe('');
      expect(result.clientSecret).toBe('');
      expect(result.error_message).toBe('');
      expect(result.payment_method_type).toBe('');
      expect(result.manualRetryAllowed).toBe(false);
      expect(result.connectorTransactionId).toBe('');
    });

    it('should handle error_message field', () => {
      const dict = {
        error_message: 'Payment failed',
      };
      const result = itemToObjMapper(dict);
      expect(result.error_message).toBe('Payment failed');
    });
  });
});
