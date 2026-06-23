import {
  sortFieldsByPriorityOrder,
  removeDuplicateConnectors,
  removeShippingAndDuplicateFields,
  extractFieldValuesFromPML,
  filterFieldsBasedOnMissingData,
  getOrCreateNestedDictionary,
  setValueAtNestedPath,
  removeEmptyObjects,
  convertFlatDictToNestedObject,
  convertConfigurationToRequiredFields,
} from '../../shared-code/sdk-utils/utils/SuperpositionHelper.bs.js';

describe('SuperpositionHelper', () => {
  describe('sortFieldsByPriorityOrder', () => {
    it('should sort fields by priority in ascending order', () => {
      const fields = [
        { name: 'field3', priority: 3 },
        { name: 'field1', priority: 1 },
        { name: 'field2', priority: 2 },
      ];
      const result = sortFieldsByPriorityOrder([...fields]);
      expect(result[0].name).toBe('field1');
      expect(result[1].name).toBe('field2');
      expect(result[2].name).toBe('field3');
    });

    it('should handle empty array', () => {
      const result = sortFieldsByPriorityOrder([]);
      expect(result).toEqual([]);
    });

    it('should handle single element array', () => {
      const fields = [{ name: 'only', priority: 5 }];
      const result = sortFieldsByPriorityOrder([...fields]);
      expect(result).toEqual(fields);
    });

    it('should handle fields with same priority', () => {
      const fields = [
        { name: 'fieldA', priority: 1 },
        { name: 'fieldB', priority: 1 },
      ];
      const result = sortFieldsByPriorityOrder([...fields]);
      expect(result.length).toBe(2);
    });
  });

  describe('removeDuplicateConnectors', () => {
    it('should remove duplicate strings from array', () => {
      const connectors = ['stripe', 'adyen', 'stripe', 'paypal', 'adyen'];
      const result = removeDuplicateConnectors(connectors);
      expect(result).toEqual(['stripe', 'adyen', 'paypal']);
    });

    it('should return empty array for empty input', () => {
      expect(removeDuplicateConnectors([])).toEqual([]);
    });

    it('should handle array with no duplicates', () => {
      const connectors = ['stripe', 'adyen', 'paypal'];
      const result = removeDuplicateConnectors(connectors);
      expect(result).toEqual(['stripe', 'adyen', 'paypal']);
    });

    it('should handle single element array', () => {
      expect(removeDuplicateConnectors(['stripe'])).toEqual(['stripe']);
    });
  });

  describe('removeShippingAndDuplicateFields', () => {
    it('should remove fields with name starting with "shipping."', () => {
      const fields = [
        { name: 'billing.address', outputPath: 'billing.address' },
        { name: 'shipping.address', outputPath: 'shipping.address' },
      ];
      const result = removeShippingAndDuplicateFields(fields);
      expect(result.length).toBe(1);
      expect(result[0].name).toBe('billing.address');
    });

    it('should remove duplicate fields based on outputPath', () => {
      const fields = [
        { name: 'field1', outputPath: 'same.path' },
        { name: 'field2', outputPath: 'same.path' },
      ];
      const result = removeShippingAndDuplicateFields(fields);
      expect(result.length).toBe(1);
    });

    it('should keep all unique non-shipping fields', () => {
      const fields = [
        { name: 'billing.name', outputPath: 'billing.name' },
        { name: 'billing.email', outputPath: 'billing.email' },
      ];
      const result = removeShippingAndDuplicateFields(fields);
      expect(result.length).toBe(2);
    });

    it('should handle empty array', () => {
      expect(removeShippingAndDuplicateFields([])).toEqual([]);
    });
  });

  describe('extractFieldValuesFromPML', () => {
    it('should extract field values from payment method list', () => {
      const requiredFields = {
        field1: { required_field: 'email', value: 'test@example.com' },
        field2: { required_field: 'name', value: 'John Doe' },
      };
      const result = extractFieldValuesFromPML(requiredFields);
      expect(result['email']).toBe('test@example.com');
      expect(result['name']).toBe('John Doe');
    });

    it('should return empty object for empty input', () => {
      expect(extractFieldValuesFromPML({})).toEqual({});
    });

    it('should skip entries without required_field', () => {
      const requiredFields = {
        field1: { value: 'test@example.com' },
      };
      const result = extractFieldValuesFromPML(requiredFields);
      expect(result).toEqual({});
    });

    it('should skip entries without value', () => {
      const requiredFields = {
        field1: { required_field: 'email' },
      };
      const result = extractFieldValuesFromPML(requiredFields);
      expect(result).toEqual({});
    });

    it('should skip entries with empty required_field', () => {
      const requiredFields = {
        field1: { required_field: '', value: 'test@example.com' },
      };
      const result = extractFieldValuesFromPML(requiredFields);
      expect(result).toEqual({});
    });
  });

  describe('filterFieldsBasedOnMissingData', () => {
    it('should filter fields that are missing from PML data', () => {
      const superpositionFields = [
        { name: 'email', outputPath: 'billing.email' },
        { name: 'phone', outputPath: 'billing.phone' },
      ];
      const pmlData = { 'billing.email': 'test@example.com' };
      const result = filterFieldsBasedOnMissingData(superpositionFields, pmlData);
      expect(result.length).toBe(1);
      expect(result[0].name).toBe('phone');
    });

    it('should return all fields when PML data is empty', () => {
      const superpositionFields = [
        { name: 'email', outputPath: 'billing.email' },
      ];
      const result = filterFieldsBasedOnMissingData(superpositionFields, {});
      expect(result.length).toBe(1);
    });

    it('should handle empty fields array', () => {
      expect(filterFieldsBasedOnMissingData([], {})).toEqual([]);
    });

    it('should include name fields together when any name field is missing', () => {
      const superpositionFields = [
        { name: 'first_name', outputPath: 'billing.address.first_name' },
        { name: 'last_name', outputPath: 'billing.address.last_name' },
      ];
      const pmlData = { 'billing.address.first_name': 'John' };
      const result = filterFieldsBasedOnMissingData(superpositionFields, pmlData);
      expect(result.length).toBe(2);
    });
  });

  describe('getOrCreateNestedDictionary', () => {
    it('should return existing nested dictionary', () => {
      const dict = { nested: { key: 'value' } };
      const result = getOrCreateNestedDictionary(dict, 'nested');
      expect(result).toEqual({ key: 'value' });
    });

    it('should create empty dictionary for missing key', () => {
      const dict = { other: 'value' };
      const result = getOrCreateNestedDictionary(dict, 'missing');
      expect(result).toEqual({});
    });

    it('should handle empty dictionary', () => {
      expect(getOrCreateNestedDictionary({}, 'any')).toEqual({});
    });
  });

  describe('setValueAtNestedPath', () => {
    it('should set value at single key path', () => {
      const dict = {};
      const result = setValueAtNestedPath(dict, ['key'], 'value');
      expect(result['key']).toBe('value');
    });

    it('should set value at nested path', () => {
      const dict = {};
      const result = setValueAtNestedPath(dict, ['level1', 'level2'], 'value');
      expect(result['level1']['level2']).toBe('value');
    });

    it('should return original dict for empty keys', () => {
      const dict = { existing: 'value' };
      const result = setValueAtNestedPath(dict, [], 'value');
      expect(result).toEqual(dict);
    });

    it('should not set empty key or value', () => {
      const dict = {};
      const result = setValueAtNestedPath(dict, [''], 'value');
      expect(result).toEqual({});
    });

    it('should not set value if value is empty string', () => {
      const dict = {};
      const result = setValueAtNestedPath(dict, ['key'], '');
      expect(result).toEqual({});
    });

    it('should handle deeply nested paths', () => {
      const dict = {};
      const result = setValueAtNestedPath(dict, ['a', 'b', 'c', 'd'], 'deep');
      expect(result['a']['b']['c']['d']).toBe('deep');
    });
  });

  describe('removeEmptyObjects', () => {
    it('should remove empty nested objects', () => {
      const dict = {
        keep: 'value',
        remove: {},
        nested: { empty: {} },
      };
      const result = removeEmptyObjects(dict);
      expect(result['keep']).toBe('value');
      expect(result['remove']).toBeUndefined();
      expect(result['nested']).toBeUndefined();
    });

    it('should keep non-empty nested objects', () => {
      const dict = {
        nested: { key: 'value' },
      };
      const result = removeEmptyObjects(dict);
      expect(result['nested']).toEqual({ key: 'value' });
    });

    it('should handle empty input', () => {
      expect(removeEmptyObjects({})).toEqual({});
    });

    it('should handle non-object values', () => {
      const dict = {
        string: 'value',
        number: 123,
        boolean: true,
      };
      const result = removeEmptyObjects(dict);
      expect(result).toEqual(dict);
    });
  });

  describe('convertFlatDictToNestedObject', () => {
    it('should convert flat dot-path dict to nested object', () => {
      const flatDict = {
        'billing.name': 'John',
        'billing.email': 'john@example.com',
      };
      const result = convertFlatDictToNestedObject(flatDict);
      expect(result['billing']['name']).toBe('John');
      expect(result['billing']['email']).toBe('john@example.com');
    });

    it('should handle single level keys', () => {
      const flatDict = { name: 'John', email: 'john@example.com' };
      const result = convertFlatDictToNestedObject(flatDict);
      expect(result['name']).toBe('John');
      expect(result['email']).toBe('john@example.com');
    });

    it('should handle empty input', () => {
      expect(convertFlatDictToNestedObject({})).toEqual({});
    });

    it('should handle deeply nested paths', () => {
      const flatDict = {
        'a.b.c.d': 'deep',
      };
      const result = convertFlatDictToNestedObject(flatDict);
      expect(result['a']['b']['c']['d']).toBe('deep');
    });

    it('should skip empty keys', () => {
      const flatDict = {
        '': 'value',
        'valid': 'keep',
      };
      const result = convertFlatDictToNestedObject(flatDict);
      expect(result['valid']).toBe('keep');
      expect(result['']).toBeUndefined();
    });
  });

  describe('convertConfigurationToRequiredFields', () => {
    it('should convert configuration to required fields array', () => {
      const config = {
        'email._required': true,
        'email._display_name': 'Email',
        'email._field_type': 'email_input',
        'email._priority': 1,
        'email._output_path': 'billing.email',
      };
      const result = convertConfigurationToRequiredFields(config);
      expect(result.length).toBe(1);
      expect(result[0].name).toBe('email');
      expect(result[0].displayName).toBe('Email');
      expect(result[0].required).toBe(true);
    });

    it('should skip non-required fields', () => {
      const config = {
        'optional._required': false,
        'optional._display_name': 'Optional',
      };
      const result = convertConfigurationToRequiredFields(config);
      expect(result.length).toBe(0);
    });

    it('should skip entries without proper format', () => {
      const config = {
        'no_underscore': true,
      };
      const result = convertConfigurationToRequiredFields(config);
      expect(result.length).toBe(0);
    });

    it('should handle empty configuration', () => {
      expect(convertConfigurationToRequiredFields({})).toEqual([]);
    });

    it('should use default values for missing metadata', () => {
      const config = {
        'field._required': true,
      };
      const result = convertConfigurationToRequiredFields(config);
      expect(result[0].displayName).toBe('field');
      expect(result[0].priority).toBe(1000);
      expect(result[0].outputPath).toBe('field');
    });

    it('should parse options array', () => {
      const config = {
        'country._required': true,
        'country._options': ['US', 'UK', 'CA'],
      };
      const result = convertConfigurationToRequiredFields(config);
      expect(result[0].options).toEqual(['US', 'UK', 'CA']);
    });

    it('should handle multiple fields', () => {
      const config = {
        'email._required': true,
        'email._display_name': 'Email',
        'email._priority': 1,
        'email._output_path': 'email',
        'phone._required': true,
        'phone._display_name': 'Phone',
        'phone._priority': 2,
        'phone._output_path': 'phone',
      };
      const result = convertConfigurationToRequiredFields(config);
      expect(result.length).toBe(2);
    });
  });
});
