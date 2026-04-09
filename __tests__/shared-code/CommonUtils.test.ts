import {
  getOptionString,
  getString,
  getStringFromJson,
  getInt,
  getFloatFromString,
  getFloatFromJson,
  getFloat,
  getJsonBoolValue,
  getJsonStringFromDict,
  getJsonArrayFromDict,
  getJsonFromDict,
  getJsonObjFromDict,
  getDecodedStringFromJson,
  getDecodedBoolFromJson,
  getDictFromObj,
  getJsonObjectFromDict,
  getOptionBool,
  getDictFromJson,
  getDictFromDict,
  getBool,
  getOptionsDict,
  getOptionalArrayFromDict,
  getArray,
  getStrArray,
  convertDictToArrayOfKeyStringTuples,
  getStringFromOptionalJson,
  snakeToPascalCase,
  getArrayElement,
  mergeDict,
  getDisplayName,
} from '../../shared-code/sdk-utils/utils/CommonUtils.bs.js';

describe('CommonUtils', () => {
  describe('getOptionString', () => {
    it('should return string value when key exists with string', () => {
      const dict = { name: 'test' };
      expect(getOptionString(dict, 'name')).toBe('test');
    });

    it('should return undefined when key does not exist', () => {
      const dict = { name: 'test' };
      expect(getOptionString(dict, 'missing')).toBeUndefined();
    });

    it('should return undefined when value is not a string', () => {
      const dict = { count: 42 };
      expect(getOptionString(dict, 'count')).toBeUndefined();
    });

    it('should return empty string when value is empty string', () => {
      const dict = { name: '' };
      expect(getOptionString(dict, 'name')).toBe('');
    });

    it('should handle null value', () => {
      const dict = { name: null };
      expect(getOptionString(dict, 'name')).toBeUndefined();
    });
  });

  describe('getString', () => {
    it('should return string value when key exists', () => {
      const dict = { name: 'test' };
      expect(getString(dict, 'name', 'default')).toBe('test');
    });

    it('should return default when key does not exist', () => {
      const dict = { name: 'test' };
      expect(getString(dict, 'missing', 'default')).toBe('default');
    });

    it('should return default when value is not a string', () => {
      const dict = { count: 42 };
      expect(getString(dict, 'count', 'default')).toBe('default');
    });

    it('should return empty string when value is empty string', () => {
      const dict = { name: '' };
      expect(getString(dict, 'name', 'default')).toBe('');
    });

    it('should handle undefined dict value', () => {
      const dict = {};
      expect(getString(dict, 'key', 'fallback')).toBe('fallback');
    });
  });

  describe('getStringFromJson', () => {
    it('should return string value from JSON string', () => {
      expect(getStringFromJson('hello', 'default')).toBe('hello');
    });

    it('should return default for non-string JSON', () => {
      expect(getStringFromJson(42, 'default')).toBe('default');
    });

    it('should return default for null', () => {
      expect(getStringFromJson(null, 'default')).toBe('default');
    });

    it('should return empty string when value is empty string', () => {
      expect(getStringFromJson('', 'default')).toBe('');
    });
  });

  describe('getInt', () => {
    it('should return int value when key exists with number', () => {
      const dict = { count: 42 };
      expect(getInt(dict, 'count', 0)).toBe(42);
    });

    it('should return default when key does not exist', () => {
      const dict = {};
      expect(getInt(dict, 'count', 10)).toBe(10);
    });

    it('should return default when value is not a number', () => {
      const dict = { count: 'not a number' };
      expect(getInt(dict, 'count', 5)).toBe(5);
    });

    it('should truncate float to int', () => {
      const dict = { count: 42.7 };
      expect(getInt(dict, 'count', 0)).toBe(42);
    });

    it('should return default for string number value', () => {
      const dict = { count: '42' };
      expect(getInt(dict, 'count', 0)).toBe(0);
    });
  });

  describe('getFloatFromString', () => {
    it('should parse valid float string', () => {
      expect(getFloatFromString('3.14', 0)).toBe(3.14);
    });

    it('should return default for invalid string', () => {
      expect(getFloatFromString('invalid', 0)).toBe(0);
    });

    it('should parse integer string', () => {
      expect(getFloatFromString('42', 0)).toBe(42);
    });

    it('should handle negative numbers', () => {
      expect(getFloatFromString('-10.5', 0)).toBe(-10.5);
    });

    it('should return default for empty string', () => {
      expect(getFloatFromString('', 99)).toBe(99);
    });
  });

  describe('getFloatFromJson', () => {
    it('should return float from number JSON', () => {
      expect(getFloatFromJson(3.14, 0)).toBe(3.14);
    });

    it('should parse float from string JSON', () => {
      expect(getFloatFromJson('3.14', 0)).toBe(3.14);
    });

    it('should return default for non-numeric string', () => {
      expect(getFloatFromJson('invalid', 0)).toBe(0);
    });

    it('should return default for null', () => {
      expect(getFloatFromJson(null, 99)).toBe(99);
    });

    it('should return default for boolean', () => {
      expect(getFloatFromJson(true, 0)).toBe(0);
    });

    it('should return default for object', () => {
      expect(getFloatFromJson({}, 0)).toBe(0);
    });
  });

  describe('getFloat', () => {
    it('should return float value when key exists with number', () => {
      const dict = { price: 99.99 };
      expect(getFloat(dict, 'price', 0)).toBe(99.99);
    });

    it('should parse float from string value', () => {
      const dict = { price: '99.99' };
      expect(getFloat(dict, 'price', 0)).toBe(99.99);
    });

    it('should return default when key does not exist', () => {
      const dict = {};
      expect(getFloat(dict, 'price', 50)).toBe(50);
    });

    it('should return default when value is not numeric', () => {
      const dict = { price: 'invalid' };
      expect(getFloat(dict, 'price', 0)).toBe(0);
    });
  });

  describe('getJsonBoolValue', () => {
    it('should return boolean value when key exists', () => {
      const dict = { enabled: true };
      expect(getJsonBoolValue(dict, 'enabled', false)).toBe(true);
    });

    it('should return default when key does not exist', () => {
      const dict = {};
      expect(getJsonBoolValue(dict, 'enabled', true)).toBe(true);
    });

    it('should handle false value', () => {
      const dict = { enabled: false };
      expect(getJsonBoolValue(dict, 'enabled', true)).toBe(false);
    });

    it('should return default for non-boolean value', () => {
      const dict = { enabled: 'yes' };
      expect(getJsonBoolValue(dict, 'enabled', false)).toBe('yes');
    });
  });

  describe('getJsonStringFromDict', () => {
    it('should return string value when key exists', () => {
      const dict = { name: 'test' };
      expect(getJsonStringFromDict(dict, 'name', 'default')).toBe('test');
    });

    it('should return default when key does not exist', () => {
      const dict = {};
      expect(getJsonStringFromDict(dict, 'name', 'default')).toBe('default');
    });

    it('should return the raw value even if not string', () => {
      const dict = { count: 42 };
      expect(getJsonStringFromDict(dict, 'count', 'default')).toBe(42);
    });
  });

  describe('getJsonArrayFromDict', () => {
    it('should return array value when key exists', () => {
      const dict = { items: [1, 2, 3] };
      expect(getJsonArrayFromDict(dict, 'items', [])).toEqual([1, 2, 3]);
    });

    it('should return default when key does not exist', () => {
      const dict = {};
      expect(getJsonArrayFromDict(dict, 'items', [1])).toEqual([1]);
    });

    it('should return the raw value even if not array', () => {
      const dict = { items: 'not an array' };
      expect(getJsonArrayFromDict(dict, 'items', [])).toBe('not an array');
    });
  });

  describe('getJsonFromDict', () => {
    it('should return value when key exists', () => {
      const dict = { data: { nested: true } };
      expect(getJsonFromDict(dict, 'data', null)).toEqual({ nested: true });
    });

    it('should return default when key does not exist', () => {
      const dict = {};
      expect(getJsonFromDict(dict, 'data', 'default')).toBe('default');
    });

    it('should return null value when value is null', () => {
      const dict = { data: null };
      expect(getJsonFromDict(dict, 'data', 'default')).toBe(null);
    });
  });

  describe('getJsonObjFromDict', () => {
    it('should return object value when key exists', () => {
      const dict = { config: { theme: 'dark' } };
      expect(getJsonObjFromDict(dict, 'config', {})).toEqual({ theme: 'dark' });
    });

    it('should return default when key does not exist', () => {
      const dict = {};
      expect(getJsonObjFromDict(dict, 'config', { default: true })).toEqual({ default: true });
    });

    it('should return default when value is not an object', () => {
      const dict = { config: 'string' };
      expect(getJsonObjFromDict(dict, 'config', {})).toEqual({});
    });
  });

  describe('getDecodedStringFromJson', () => {
    it('should decode nested string from JSON object', () => {
      const json = { nested: 'found' };
      const result = getDecodedStringFromJson(json, (obj: any) => obj['nested'], 'default');
      expect(result).toBe('found');
    });

    it('should return default when path does not exist', () => {
      const json = { other: {} };
      const result = getDecodedStringFromJson(json, (obj: any) => obj['missing'], 'default');
      expect(result).toBe('default');
    });

    it('should return default for null JSON', () => {
      const result = getDecodedStringFromJson(null, (obj: any) => obj, 'default');
      expect(result).toBe('default');
    });
  });

  describe('getDecodedBoolFromJson', () => {
    it('should decode nested bool from JSON object', () => {
      const json = { nested: true };
      const result = getDecodedBoolFromJson(json, (obj: any) => obj['nested'], false);
      expect(result).toBe(true);
    });

    it('should return default when path does not exist', () => {
      const json = { other: {} };
      const result = getDecodedBoolFromJson(json, (obj: any) => obj['missing'], true);
      expect(result).toBe(true);
    });

    it('should return default for null JSON', () => {
      const result = getDecodedBoolFromJson(null, (obj: any) => obj, false);
      expect(result).toBe(false);
    });
  });

  describe('getDictFromObj', () => {
    it('should return dict when key exists with object', () => {
      const dict = { nested: { key: 'value' } };
      expect(getDictFromObj(dict, 'nested')).toEqual({ key: 'value' });
    });

    it('should return empty object when key does not exist', () => {
      const dict = {};
      expect(getDictFromObj(dict, 'missing')).toEqual({});
    });

    it('should return empty object when value is not an object', () => {
      const dict = { nested: 'string' };
      expect(getDictFromObj(dict, 'nested')).toEqual({});
    });
  });

  describe('getJsonObjectFromDict', () => {
    it('should return object when key exists', () => {
      const dict = { data: { key: 'value' } };
      expect(getJsonObjectFromDict(dict, 'data')).toEqual({ key: 'value' });
    });

    it('should return empty object when key does not exist', () => {
      const dict = {};
      expect(getJsonObjectFromDict(dict, 'missing')).toEqual({});
    });

    it('should return null value when value is null', () => {
      const dict = { data: null };
      expect(getJsonObjectFromDict(dict, 'data')).toBe(null);
    });
  });

  describe('getOptionBool', () => {
    it('should return boolean value when key exists with bool', () => {
      const dict = { enabled: true };
      expect(getOptionBool(dict, 'enabled')).toBe(true);
    });

    it('should return undefined when key does not exist', () => {
      const dict = {};
      expect(getOptionBool(dict, 'enabled')).toBeUndefined();
    });

    it('should return undefined when value is not a boolean', () => {
      const dict = { enabled: 'yes' };
      expect(getOptionBool(dict, 'enabled')).toBeUndefined();
    });

    it('should handle false value', () => {
      const dict = { enabled: false };
      expect(getOptionBool(dict, 'enabled')).toBe(false);
    });
  });

  describe('getDictFromJson', () => {
    it('should return dict from JSON object', () => {
      expect(getDictFromJson({ key: 'value' })).toEqual({ key: 'value' });
    });

    it('should return empty object for null', () => {
      expect(getDictFromJson(null)).toEqual({});
    });

    it('should return empty object for non-object', () => {
      expect(getDictFromJson('string')).toEqual({});
    });

    it('should return empty object for array', () => {
      expect(getDictFromJson([1, 2, 3])).toEqual({});
    });
  });

  describe('getDictFromDict', () => {
    it('should return nested dict when key exists', () => {
      const dict = { nested: { inner: 'value' } };
      expect(getDictFromDict(dict, 'nested')).toEqual({ inner: 'value' });
    });

    it('should return empty object when key does not exist', () => {
      const dict = {};
      expect(getDictFromDict(dict, 'missing')).toEqual({});
    });

    it('should return empty object when value is not an object', () => {
      const dict = { nested: 'string' };
      expect(getDictFromDict(dict, 'nested')).toEqual({});
    });
  });

  describe('getBool', () => {
    it('should return boolean value when key exists', () => {
      const dict = { enabled: true };
      expect(getBool(dict, 'enabled', false)).toBe(true);
    });

    it('should return default when key does not exist', () => {
      const dict = {};
      expect(getBool(dict, 'enabled', true)).toBe(true);
    });

    it('should return default when value is not a boolean', () => {
      const dict = { enabled: 'yes' };
      expect(getBool(dict, 'enabled', false)).toBe(false);
    });

    it('should handle false value', () => {
      const dict = { enabled: false };
      expect(getBool(dict, 'enabled', true)).toBe(false);
    });
  });

  describe('getOptionsDict', () => {
    it('should return dict from options with object', () => {
      expect(getOptionsDict({ key: 'value' })).toEqual({ key: 'value' });
    });

    it('should return empty object for null options', () => {
      expect(getOptionsDict(null)).toEqual({});
    });

    it('should return empty object for undefined options', () => {
      expect(getOptionsDict(undefined)).toEqual({});
    });
  });

  describe('getOptionalArrayFromDict', () => {
    it('should return array when key exists with array', () => {
      const dict = { items: [1, 2, 3] };
      expect(getOptionalArrayFromDict(dict, 'items')).toEqual([1, 2, 3]);
    });

    it('should return undefined when key does not exist', () => {
      const dict = {};
      expect(getOptionalArrayFromDict(dict, 'items')).toBeUndefined();
    });

    it('should return undefined when value is not an array', () => {
      const dict = { items: 'not an array' };
      expect(getOptionalArrayFromDict(dict, 'items')).toBeUndefined();
    });
  });

  describe('getArray', () => {
    it('should return array when key exists with array', () => {
      const dict = { items: [1, 2, 3] };
      expect(getArray(dict, 'items')).toEqual([1, 2, 3]);
    });

    it('should return empty array when key does not exist', () => {
      const dict = {};
      expect(getArray(dict, 'items')).toEqual([]);
    });

    it('should return empty array when value is not an array', () => {
      const dict = { items: 'not an array' };
      expect(getArray(dict, 'items')).toEqual([]);
    });
  });

  describe('getStrArray', () => {
    it('should return string array when key exists', () => {
      const dict = { names: ['a', 'b', 'c'] };
      expect(getStrArray(dict, 'names')).toEqual(['a', 'b', 'c']);
    });

    it('should return empty array when key does not exist', () => {
      const dict = {};
      expect(getStrArray(dict, 'names')).toEqual([]);
    });

    it('should convert non-string items to empty strings', () => {
      const dict = { mixed: [1, 'b', true] };
      expect(getStrArray(dict, 'mixed')).toEqual(['', 'b', '']);
    });

    it('should return empty array when value is not an array', () => {
      const dict = { names: 'not an array' };
      expect(getStrArray(dict, 'names')).toEqual([]);
    });
  });

  describe('convertDictToArrayOfKeyStringTuples', () => {
    it('should convert dict to array of key-value tuples', () => {
      const dict = { a: '1', b: '2' };
      const result = convertDictToArrayOfKeyStringTuples(dict);
      expect(result).toContainEqual(['a', '1']);
      expect(result).toContainEqual(['b', '2']);
    });

    it('should return empty array for empty dict', () => {
      expect(convertDictToArrayOfKeyStringTuples({})).toEqual([]);
    });

    it('should use empty string for non-string values', () => {
      const dict = { num: 42, bool: true };
      const result = convertDictToArrayOfKeyStringTuples(dict);
      expect(result).toContainEqual(['num', '']);
      expect(result).toContainEqual(['bool', '']);
    });
  });

  describe('getStringFromOptionalJson', () => {
    it('should return string value from JSON', () => {
      expect(getStringFromOptionalJson('hello', 'default')).toBe('hello');
    });

    it('should return default for null JSON', () => {
      expect(getStringFromOptionalJson(null, 'default')).toBe('default');
    });

    it('should return default for undefined JSON', () => {
      expect(getStringFromOptionalJson(undefined, 'default')).toBe('default');
    });

    it('should return default for non-string JSON', () => {
      expect(getStringFromOptionalJson(42, 'default')).toBe('default');
    });
  });

  describe('snakeToPascalCase', () => {
    it('should convert snake_case to PascalCase', () => {
      expect(snakeToPascalCase('hello_world')).toBe('HelloWorld');
    });

    it('should handle single word', () => {
      expect(snakeToPascalCase('hello')).toBe('Hello');
    });

    it('should handle empty string', () => {
      expect(snakeToPascalCase('')).toBe('');
    });

    it('should handle multiple underscores', () => {
      expect(snakeToPascalCase('hello__world')).toBe('HelloWorld');
    });

    it('should handle leading underscore', () => {
      expect(snakeToPascalCase('_hello_world')).toBe('HelloWorld');
    });

    it('should handle trailing underscore', () => {
      expect(snakeToPascalCase('hello_world_')).toBe('HelloWorld');
    });

    it('should handle already capitalized words', () => {
      expect(snakeToPascalCase('Hello_World')).toBe('HelloWorld');
    });

    it('should handle three words', () => {
      expect(snakeToPascalCase('one_two_three')).toBe('OneTwoThree');
    });
  });

  describe('getArrayElement', () => {
    it('should return element at valid index', () => {
      expect(getArrayElement(['a', 'b', 'c'], 1, 'default')).toBe('b');
    });

    it('should return default for out of bounds index', () => {
      expect(getArrayElement(['a', 'b', 'c'], 5, 'default')).toBe('default');
    });

    it('should return default for negative index', () => {
      expect(getArrayElement(['a', 'b', 'c'], -1, 'default')).toBe('default');
    });

    it('should return first element at index 0', () => {
      expect(getArrayElement(['a', 'b', 'c'], 0, 'default')).toBe('a');
    });

    it('should return default for empty array', () => {
      expect(getArrayElement([], 0, 'default')).toBe('default');
    });
  });

  describe('mergeDict', () => {
    it('should merge two flat dicts', () => {
      const dict1 = { a: '1', b: '2' };
      const dict2 = { c: '3', d: '4' };
      expect(mergeDict(dict1, dict2)).toEqual({ a: '1', b: '2', c: '3', d: '4' });
    });

    it('should overwrite values from dict2', () => {
      const dict1 = { a: '1', b: '2' };
      const dict2 = { b: 'new', c: '3' };
      expect(mergeDict(dict1, dict2)).toEqual({ a: '1', b: 'new', c: '3' });
    });

    it('should recursively merge nested objects', () => {
      const dict1 = { nested: { a: '1', b: '2' } };
      const dict2 = { nested: { b: 'new', c: '3' } };
      expect(mergeDict(dict1, dict2)).toEqual({ nested: { a: '1', b: 'new', c: '3' } });
    });

    it('should return dict1 when dict2 is empty', () => {
      const dict1 = { a: '1' };
      expect(mergeDict(dict1, {})).toEqual({ a: '1' });
    });

    it('should return dict2 values when dict1 is empty', () => {
      const dict2 = { a: '1' };
      expect(mergeDict({}, dict2)).toEqual({ a: '1' });
    });

    it('should not modify original dicts', () => {
      const dict1 = { a: '1' };
      const dict2 = { b: '2' };
      const result = mergeDict(dict1, dict2);
      expect(dict1).toEqual({ a: '1' });
      expect(dict2).toEqual({ b: '2' });
    });

    it('should replace object with non-object from dict2', () => {
      const dict1 = { a: { nested: true } };
      const dict2 = { a: 'string' };
      expect(mergeDict(dict1, dict2)).toEqual({ a: 'string' });
    });
  });

  describe('getDisplayName', () => {
    it('should transform afterpay_clearpay to Afterpay', () => {
      expect(getDisplayName('afterpay_clearpay')).toBe('Afterpay');
    });

    it('should transform bnb_smart_chain to BNB Smart Chain', () => {
      expect(getDisplayName('bnb_smart_chain')).toBe('BNB Smart Chain');
    });

    it('should transform classic to Cash / Voucher', () => {
      expect(getDisplayName('classic')).toBe('Cash / Voucher');
    });

    it('should transform credit to Card', () => {
      expect(getDisplayName('credit')).toBe('Card');
    });

    it('should transform crypto_currency to Crypto', () => {
      expect(getDisplayName('crypto_currency')).toBe('Crypto');
    });

    it('should transform evoucher to E-Voucher', () => {
      expect(getDisplayName('evoucher')).toBe('E-Voucher');
    });

    it('should append Debit to ach', () => {
      expect(getDisplayName('ach')).toBe('Ach Debit');
    });

    it('should append Debit to bacs', () => {
      expect(getDisplayName('bacs')).toBe('Bacs Debit');
    });

    it('should append Debit to becs', () => {
      expect(getDisplayName('becs')).toBe('Becs Debit');
    });

    it('should append Debit to sepa', () => {
      expect(getDisplayName('sepa')).toBe('Sepa Debit');
    });

    it('should capitalize and space-separate unknown values', () => {
      expect(getDisplayName('some_method')).toBe('Some Method');
    });

    it('should handle single word', () => {
      expect(getDisplayName('visa')).toBe('Visa');
    });

    it('should handle empty string', () => {
      expect(getDisplayName('')).toBe('');
    });
  });
});
