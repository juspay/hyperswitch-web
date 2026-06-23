import {
  updateCardBody,
  updateCVVBody,
  saveCardBody,
  vgsCardBody,
  hyperswitchVaultBody,
} from '../Utilities/PaymentManagementBody.bs.js';

describe('PaymentManagementBody', () => {
  describe('updateCardBody', () => {
    it('should create update card body with payment method token', () => {
      const result = updateCardBody('pm_token_123', 'My Card', 'John Doe');

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);

      const tokenEntry = result.find((entry: any) => entry[0] === 'payment_method_token');
      expect(tokenEntry).toBeDefined();
      expect(tokenEntry[1]).toBe('pm_token_123');
    });

    it('should include card holder name in payment method data', () => {
      const result = updateCardBody('pm_token_123', 'My Card', 'John Doe');

      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should include nickname in card details', () => {
      const result = updateCardBody('pm_token_123', 'My Card', 'John Doe');

      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should handle empty nickname', () => {
      const result = updateCardBody('pm_token_123', '', 'John Doe');

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should handle empty card holder name', () => {
      const result = updateCardBody('pm_token_123', 'My Card', '');

      expect(result).toBeDefined();
      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });
  });

  describe('updateCVVBody', () => {
    it('should create CVV update body with payment method token', () => {
      const result = updateCVVBody('pm_token_123', '123');

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);

      const tokenEntry = result.find((entry: any) => entry[0] === 'payment_method_token');
      expect(tokenEntry).toBeDefined();
      expect(tokenEntry[1]).toBe('pm_token_123');
    });

    it('should include CVV in card details', () => {
      const result = updateCVVBody('pm_token_123', '123');

      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should handle empty CVV', () => {
      const result = updateCVVBody('pm_token_123', '');

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should handle 4-digit CVV', () => {
      const result = updateCVVBody('pm_token_123', '1234');

      expect(result).toBeDefined();
      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });
  });

  describe('saveCardBody', () => {
    it('should create save card body with card details', () => {
      const result = saveCardBody('4111111111111111', '12', '2025', 'John Doe', '123', [], undefined);

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);

      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry).toBeDefined();
      expect(pmtEntry[1]).toBe('card');
    });

    it('should include payment method subtype', () => {
      const result = saveCardBody('4111111111111111', '12', '2025', 'John Doe', '123', [], undefined);

      const pmsEntry = result.find((entry: any) => entry[0] === 'payment_method_subtype');
      expect(pmsEntry).toBeDefined();
      expect(pmsEntry[1]).toBe('card');
    });

    it('should include card number without spaces', () => {
      const result = saveCardBody('4111 1111 1111 1111', '12', '2025', 'John Doe', '123', [], undefined);

      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should include expiry month and year', () => {
      const result = saveCardBody('4111111111111111', '12', '2025', 'John Doe', '123', [], undefined);

      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should handle missing optional card holder name', () => {
      const result = saveCardBody('4111111111111111', '12', '2025', undefined, '123', [], undefined);

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should include nickname when provided', () => {
      const result = saveCardBody('4111111111111111', '12', '2025', 'John Doe', '123', [], 'My Visa');

      expect(result).toBeDefined();
      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should handle empty nickname', () => {
      const result = saveCardBody('4111111111111111', '12', '2025', 'John Doe', '123', [], '');

      expect(result).toBeDefined();
    });

    it('should include card brand when provided', () => {
      const cardBrand = [['card_issuer', 'visa']];
      const result = saveCardBody('4111111111111111', '12', '2025', 'John Doe', '123', cardBrand, undefined);

      expect(result).toBeDefined();
    });
  });

  describe('vgsCardBody', () => {
    it('should create VGS card body with card details', () => {
      const result = vgsCardBody('4111111111111111', '12', '2025', '123');

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);

      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry).toBeDefined();
      expect(pmtEntry[1]).toBe('card');
    });

    it('should set payment method subtype to debit', () => {
      const result = vgsCardBody('4111111111111111', '12', '2025', '123');

      const pmsEntry = result.find((entry: any) => entry[0] === 'payment_method_subtype');
      expect(pmsEntry).toBeDefined();
      expect(pmsEntry[1]).toBe('debit');
    });

    it('should include vault_data_card in payment method data', () => {
      const result = vgsCardBody('4111111111111111', '12', '2025', '123');

      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should handle empty card number', () => {
      const result = vgsCardBody('', '12', '2025', '123');

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it('should handle empty CVV', () => {
      const result = vgsCardBody('4111111111111111', '12', '2025', '');

      expect(result).toBeDefined();
    });
  });

  describe('hyperswitchVaultBody', () => {
    it('should create Hyperswitch vault body with token', () => {
      const result = hyperswitchVaultBody('vault_token_123');

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);

      const pmtEntry = result.find((entry: any) => entry[0] === 'payment_method_type');
      expect(pmtEntry).toBeDefined();
      expect(pmtEntry[1]).toBe('card');
    });

    it('should set payment method subtype to debit', () => {
      const result = hyperswitchVaultBody('vault_token_123');

      const pmsEntry = result.find((entry: any) => entry[0] === 'payment_method_subtype');
      expect(pmsEntry).toBeDefined();
      expect(pmsEntry[1]).toBe('debit');
    });

    it('should include payment token', () => {
      const result = hyperswitchVaultBody('vault_token_123');

      const tokenEntry = result.find((entry: any) => entry[0] === 'payment_token');
      expect(tokenEntry).toBeDefined();
      expect(tokenEntry[1]).toBe('vault_token_123');
    });

    it('should include card_token in payment method data', () => {
      const result = hyperswitchVaultBody('vault_token_123');

      const pmdEntry = result.find((entry: any) => entry[0] === 'payment_method_data');
      expect(pmdEntry).toBeDefined();
    });

    it('should handle empty token', () => {
      const result = hyperswitchVaultBody('');

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });
});
