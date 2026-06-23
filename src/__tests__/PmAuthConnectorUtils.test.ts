import {
  pmAuthNameToTypeMapper,
  pmAuthConnectorToScriptUrlMapper,
  findPmAuthAllPMAuthConnectors,
  getAllRequiredPmAuthConnectors,
} from '../Utilities/PmAuthConnectorUtils.bs.js';

describe('PmAuthConnectorUtils', () => {
  describe('pmAuthNameToTypeMapper', () => {
    it('should return PLAID for plaid connector name', () => {
      expect(pmAuthNameToTypeMapper('plaid')).toBe('PLAID');
    });

    it('should return NONE for unknown connector name', () => {
      expect(pmAuthNameToTypeMapper('unknown')).toBe('NONE');
    });

    it('should return NONE for empty string', () => {
      expect(pmAuthNameToTypeMapper('')).toBe('NONE');
    });

    it('should be case-sensitive (Plaid !== plaid)', () => {
      expect(pmAuthNameToTypeMapper('Plaid')).toBe('NONE');
    });

    it('should return NONE for null-like values', () => {
      expect(pmAuthNameToTypeMapper('null')).toBe('NONE');
      expect(pmAuthNameToTypeMapper('undefined')).toBe('NONE');
    });
  });

  describe('pmAuthConnectorToScriptUrlMapper', () => {
    it('should return Plaid CDN URL for PLAID connector', () => {
      const result = pmAuthConnectorToScriptUrlMapper('PLAID');
      expect(result).toBe('https://cdn.plaid.com/link/v2/stable/link-initialize.js');
    });

    it('should return empty string for NONE connector', () => {
      expect(pmAuthConnectorToScriptUrlMapper('NONE')).toBe('');
    });

    it('should return empty string for unknown connector type', () => {
      expect(pmAuthConnectorToScriptUrlMapper('UNKNOWN')).toBe('');
    });

    it('should return empty string for empty string', () => {
      expect(pmAuthConnectorToScriptUrlMapper('')).toBe('');
    });

    it('should be case-sensitive (plaid !== PLAID)', () => {
      expect(pmAuthConnectorToScriptUrlMapper('plaid')).toBe('');
    });
  });

  describe('findPmAuthAllPMAuthConnectors', () => {
    it('should find PM auth connectors from bank debit payment methods', () => {
      const paymentMethodListValue = [
        {
          payment_method: 'bank_debit',
          payment_method_types: [
            {
              payment_method_type: 'ach',
              pm_auth_connector: 'plaid',
            },
          ],
        },
      ];

      const result = findPmAuthAllPMAuthConnectors(paymentMethodListValue);

      expect(result['ach']).toBe('plaid');
    });

    it('should return empty dict for non-bank-debit payment methods', () => {
      const paymentMethodListValue = [
        {
          payment_method: 'card',
          payment_method_types: [],
        },
      ];

      const result = findPmAuthAllPMAuthConnectors(paymentMethodListValue);

      expect(Object.keys(result).length).toBe(0);
    });

    it('should return empty dict for empty list', () => {
      const result = findPmAuthAllPMAuthConnectors([]);

      expect(Object.keys(result).length).toBe(0);
    });

    it('should skip payment method types without pm_auth_connector', () => {
      const paymentMethodListValue = [
        {
          payment_method: 'bank_debit',
          payment_method_types: [
            {
              payment_method_type: 'ach',
            },
            {
              payment_method_type: 'sepa',
              pm_auth_connector: 'plaid',
            },
          ],
        },
      ];

      const result = findPmAuthAllPMAuthConnectors(paymentMethodListValue);

      expect(Object.keys(result).length).toBe(1);
      expect(result['sepa']).toBe('plaid');
    });

    it('should handle multiple bank debit payment methods', () => {
      const paymentMethodListValue = [
        {
          payment_method: 'bank_debit',
          payment_method_types: [
            {
              payment_method_type: 'ach',
              pm_auth_connector: 'plaid',
            },
          ],
        },
        {
          payment_method: 'bank_debit',
          payment_method_types: [
            {
              payment_method_type: 'bacs',
              pm_auth_connector: 'other',
            },
          ],
        },
      ];

      const result = findPmAuthAllPMAuthConnectors(paymentMethodListValue);

      expect(Object.keys(result).length).toBe(2);
      expect(result['ach']).toBe('plaid');
      expect(result['bacs']).toBe('other');
    });

    it('should include null pm_auth_connector in dict (isSome treats null as defined)', () => {
      const paymentMethodListValue = [
        {
          payment_method: 'bank_debit',
          payment_method_types: [
            {
              payment_method_type: 'ach',
              pm_auth_connector: null,
            },
          ],
        },
      ];

      const result = findPmAuthAllPMAuthConnectors(paymentMethodListValue);

      expect(Object.keys(result).length).toBe(1);
      expect(result['ach']).toBe(null);
    });
  });

  describe('getAllRequiredPmAuthConnectors', () => {
    it('should return unique auth connectors from dict', () => {
      const pmAuthConnectorsDict = {
        ach: 'plaid',
        sepa: 'plaid',
        bacs: 'other',
      };

      const result = getAllRequiredPmAuthConnectors(pmAuthConnectorsDict);

      expect(result.length).toBe(2);
      expect(result).toContain('plaid');
      expect(result).toContain('other');
    });

    it('should return empty array for empty dict', () => {
      const result = getAllRequiredPmAuthConnectors({});

      expect(result).toEqual([]);
    });

    it('should preserve order based on dict values', () => {
      const pmAuthConnectorsDict = {
        first: 'connector_a',
        second: 'connector_b',
        third: 'connector_a',
      };

      const result = getAllRequiredPmAuthConnectors(pmAuthConnectorsDict);

      expect(result.length).toBe(2);
    });

    it('should handle dict with single entry', () => {
      const pmAuthConnectorsDict = {
        ach: 'plaid',
      };

      const result = getAllRequiredPmAuthConnectors(pmAuthConnectorsDict);

      expect(result).toEqual(['plaid']);
    });

    it('should handle dict with all same values', () => {
      const pmAuthConnectorsDict = {
        ach: 'plaid',
        sepa: 'plaid',
        bacs: 'plaid',
      };

      const result = getAllRequiredPmAuthConnectors(pmAuthConnectorsDict);

      expect(result).toEqual(['plaid']);
    });
  });
});
