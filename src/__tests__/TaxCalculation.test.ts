import * as TaxCalculation from '../Utilities/TaxCalculation.bs.js';

const mockFetchApiWithLogging = jest.fn();
const mockGetNonEmptyOption = jest.fn((val: any) => (val ? val : undefined));
const mockGetDictFromJson = jest.fn((obj: any) => (typeof obj === 'object' && obj !== null ? obj : {}));

jest.mock('../Utilities/Utils.bs.js', () => ({
  getDictFromJson: (obj: any) => mockGetDictFromJson(obj),
  getString: (obj: any, key: string, def: string) => obj?.[key] ?? def,
  getInt: (obj: any, key: string, def: number) => obj?.[key] ?? def,
  getNonEmptyOption: (val: any) => mockGetNonEmptyOption(val),
  fetchApiWithLogging: (...args: any[]) => mockFetchApiWithLogging(...args),
  getJsonFromArrayOfJson: (arr: any) => Object.fromEntries(arr),
}));

jest.mock('../Utilities/APIHelpers/APIUtils.bs.js', () => ({
  generateApiUrlV1: jest.fn((params: any, endpoint: string) => `https://api.test.com/${endpoint}`),
}));

jest.mock('../Utilities/PaymentHelpers.bs.js', () => ({
  calculateTax: jest.fn((...args: any[]) => mockFetchApiWithLogging(...args)),
}));

describe('TaxCalculation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('taxResponseToObjMapper', () => {
    it('should map valid tax response to object', () => {
      const response = {
        payment_id: 'pay_123',
        net_amount: 1000,
        order_tax_amount: 100,
        shipping_cost: 50,
      };
      const result = TaxCalculation.taxResponseToObjMapper(response);
      expect(result).toBeDefined();
      expect(result?.payment_id).toBe('pay_123');
      expect(result?.net_amount).toBe(1000);
      expect(result?.order_tax_amount).toBe(100);
      expect(result?.shipping_cost).toBe(50);
    });

    it('should handle missing fields with defaults', () => {
      const response = {};
      const result = TaxCalculation.taxResponseToObjMapper(response);
      expect(result).toBeDefined();
      expect(result?.payment_id).toBe('');
      expect(result?.net_amount).toBe(0);
      expect(result?.order_tax_amount).toBe(0);
      expect(result?.shipping_cost).toBe(0);
    });

    it('should handle null response', () => {
      const result = TaxCalculation.taxResponseToObjMapper(null);
      expect(result).toBeUndefined();
    });

    it('should handle partial response', () => {
      const response = {
        payment_id: 'pay_456',
        net_amount: 2000,
      };
      const result = TaxCalculation.taxResponseToObjMapper(response);
      expect(result).toBeDefined();
      expect(result?.payment_id).toBe('pay_456');
      expect(result?.net_amount).toBe(2000);
      expect(result?.order_tax_amount).toBe(0);
    });

    it('should handle undefined response', () => {
      const result = TaxCalculation.taxResponseToObjMapper(undefined);
      expect(result).toBeUndefined();
    });

    it('should handle string response (invalid JSON)', () => {
      const result = TaxCalculation.taxResponseToObjMapper('not an object');
      expect(result).toBeUndefined();
    });

    it('should handle array response (invalid)', () => {
      const result = TaxCalculation.taxResponseToObjMapper([1, 2, 3]);
      expect(result).toBeUndefined();
    });

    it('should handle response with zero values', () => {
      const response = {
        payment_id: '',
        net_amount: 0,
        order_tax_amount: 0,
        shipping_cost: 0,
      };
      const result = TaxCalculation.taxResponseToObjMapper(response);
      expect(result).toBeDefined();
      expect(result?.payment_id).toBe('');
      expect(result?.net_amount).toBe(0);
    });

    it('should handle response with extra fields', () => {
      const response = {
        payment_id: 'pay_789',
        net_amount: 5000,
        order_tax_amount: 500,
        shipping_cost: 100,
        extra_field: 'should be ignored',
        another_field: 123,
      };
      const result = TaxCalculation.taxResponseToObjMapper(response);
      expect(result).toBeDefined();
      expect(result?.payment_id).toBe('pay_789');
      expect(result?.net_amount).toBe(5000);
    });
  });

  describe('calculateTax', () => {
    it('should call calculateTax with correct parameters', async () => {
      mockFetchApiWithLogging.mockResolvedValue({
        payment_id: 'pay_123',
        net_amount: 1000,
        order_tax_amount: 100,
        shipping_cost: 50,
      });
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await TaxCalculation.calculateTax(
        { country: 'US', postal_code: '12345' },
        undefined,
        'secret_test',
        'pk_test',
        'card',
        undefined,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('should handle calculateTax with sessionId', async () => {
      mockFetchApiWithLogging.mockResolvedValue({
        payment_id: 'pay_123',
        net_amount: 1000,
        order_tax_amount: 100,
        shipping_cost: 50,
      });
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await TaxCalculation.calculateTax(
        { country: 'US', postal_code: '12345' },
        undefined,
        'secret_test',
        'pk_test',
        'card',
        'session_123',
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('should handle calculateTax with sdkAuthorization', async () => {
      mockFetchApiWithLogging.mockResolvedValue({
        payment_id: 'pay_123',
        net_amount: 1000,
        order_tax_amount: 100,
        shipping_cost: 50,
      });
      mockGetNonEmptyOption.mockReturnValue('auth_token');

      await TaxCalculation.calculateTax(
        { country: 'US', postal_code: '12345' },
        undefined,
        'secret_test',
        'pk_test',
        'card',
        undefined,
        'auth_token'
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('should handle null response from API', async () => {
      mockFetchApiWithLogging.mockResolvedValue(null);
      mockGetNonEmptyOption.mockReturnValue(undefined);

      const result = await TaxCalculation.calculateTax(
        { country: 'US', postal_code: '12345' },
        undefined,
        'secret_test',
        'pk_test',
        'card',
        undefined,
        undefined
      );

      expect(result).toBeNull();
    });

    it('should handle empty shipping address', async () => {
      mockFetchApiWithLogging.mockResolvedValue({
        payment_id: 'pay_123',
        net_amount: 1000,
        order_tax_amount: 0,
        shipping_cost: 0,
      });
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await TaxCalculation.calculateTax(
        {},
        undefined,
        'secret_test',
        'pk_test',
        'card',
        undefined,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });

    it('should handle different payment method types', async () => {
      mockFetchApiWithLogging.mockResolvedValue({
        payment_id: 'pay_123',
        net_amount: 1000,
        order_tax_amount: 100,
        shipping_cost: 50,
      });
      mockGetNonEmptyOption.mockReturnValue(undefined);

      await TaxCalculation.calculateTax(
        { country: 'DE', postal_code: '10115' },
        undefined,
        'secret_test',
        'pk_test',
        'klarna',
        undefined,
        undefined
      );

      expect(mockFetchApiWithLogging).toHaveBeenCalled();
    });
  });
});
