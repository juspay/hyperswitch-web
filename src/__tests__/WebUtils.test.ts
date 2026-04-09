import {
  getOptionString,
  getString,
  getInt,
  getFloat,
  getBool,
  getArray,
  toKebabCase,
  toCamelCase,
  toSnakeCase,
  transformKeys,
  removeDuplicate,
  isVpaIdValid,
  checkEmailValid,
  sortBasedOnPriority,
  onlyDigits,
  snakeToTitleCase,
  formatIBAN,
  formatBSB,
  deepCopyDict,
  flattenObject,
  unflattenObject,
  generateRandomString,
  getPaymentId,
  checkIs18OrAbove,
  getFirstAndLastNameFromFullName,
  minorUnitToString,
  formatAmountWithTwoDecimals,
  isValidHexColor,
  safeParseOpt,
  safeParse,
  getJsonFromArrayOfJson,
  convertDictToArrayOfKeyStringTuples,
  mergeHeadersIntoDict,
  getFloatFromString,
  getFloatFromJson,
  getJsonBoolValue,
  getJsonStringFromDict,
  getJsonArrayFromDict,
  getJsonFromDict,
  getJsonObjFromDict,
  getRequiredString,
  getWarningString,
  getDictFromObj,
  getJsonObjectFromDict,
  getOptionBool,
  getDictFromJson,
  getDictFromDict,
  getNonEmptyOption,
  getOptionsDict,
  getBoolWithWarning,
  getNumberWithWarning,
  getOptionalArrayFromDict,
  getArrayOfObjectsFromDict,
  getStrArray,
  getOptionalStrArray,
  getBoolValue,
  mergeJsons,
  toCamelCaseWithNumberSupport,
  transformKeysWithoutModifyingValue,
  isAllValid,
  getCountryPostal,
  getCountryNames,
  getBankNames,
  getBankKeys,
  getArrofJsonString,
  getOptionalArr,
  checkPriorityList,
  addSize,
  toInt,
  validateRountingNumber,
  getDictIsSome,
  rgbaTorgb,
  findVersion,
  browserDetect,
  formatException,
  arrayJsonToCamelCase,
  getArrayValFromJsonDict,
  isOtherElements,
  canHaveMultipleInstances,
  callbackFuncForExtractingValFromDict,
  getClasses,
  getStringFromOptionalJson,
  getBoolFromOptionalJson,
  getBoolFromJson,
  getOptionalJson,
  setNested,
  mergeTwoFlattenedJsonDicts,
  flattenObjectWithStringifiedJson,
  flatten,
  getWalletPaymentMethod,
  getIsExpressCheckoutComponent,
  getIsComponentTypeForPaymentElementCreate,
  checkIsWalletElement,
  getUniqueArray,
  removeHyphen,
  compareLogic,
  toSpacedUpperCase,
  handleFailureResponse,
  isKeyPresentInDict,
  isDigitLimitExceeded,
  convertKeyValueToJsonStringPair,
  validateName,
  validateNickname,
  setNickNameState,
  getStringFromBool,
  maskStringValuesInJson,
  getSdkAuthorizationData,
} from '../Utilities/Utils.bs.js';

describe('WebUtils', () => {
  describe('getString', () => {
    it('should return value when key exists', () => {
      const dict = { name: 'John' };
      expect(getString(dict, 'name', 'default')).toBe('John');
    });

    it('should return default when key does not exist', () => {
      const dict = { name: 'John' };
      expect(getString(dict, 'age', 'default')).toBe('default');
    });
  });

  describe('getOptionString', () => {
    it('should return value when key exists', () => {
      const dict = { name: 'John' };
      expect(getOptionString(dict, 'name')).toBe('John');
    });

    it('should return undefined when key does not exist', () => {
      const dict = { name: 'John' };
      expect(getOptionString(dict, 'age')).toBeUndefined();
    });
  });

  describe('getInt', () => {
    it('should return integer value when key exists', () => {
      const dict = { age: 25 };
      expect(getInt(dict, 'age', 0)).toBe(25);
    });

    it('should return default when key does not exist', () => {
      const dict = { name: 'John' };
      expect(getInt(dict, 'age', 0)).toBe(0);
    });
  });

  describe('getFloat', () => {
    it('should return float value when key exists', () => {
      const dict = { price: 99.99 };
      expect(getFloat(dict, 'price', 0)).toBe(99.99);
    });

    it('should return default when key does not exist', () => {
      const dict = { name: 'John' };
      expect(getFloat(dict, 'price', 0)).toBe(0);
    });
  });

  describe('getBool', () => {
    it('should return boolean value when key exists', () => {
      const dict = { active: true };
      expect(getBool(dict, 'active', false)).toBe(true);
    });

    it('should return default when key does not exist', () => {
      const dict = { name: 'John' };
      expect(getBool(dict, 'active', false)).toBe(false);
    });
  });

  describe('getArray', () => {
    it('should return array when key exists', () => {
      const dict = { items: [1, 2, 3] };
      expect(getArray(dict, 'items')).toEqual([1, 2, 3]);
    });

    it('should return empty array when key does not exist', () => {
      const dict = { name: 'John' };
      expect(getArray(dict, 'items')).toEqual([]);
    });
  });

  describe('toKebabCase', () => {
    it('should convert camelCase to kebab-case', () => {
      expect(toKebabCase('helloWorld')).toBe('hello-world');
    });

    it('should handle already kebab-case', () => {
      expect(toKebabCase('hello-world')).toBe('hello--world');
    });

    it('should handle empty string', () => {
      expect(toKebabCase('')).toBe('');
    });

    it('should handle PascalCase', () => {
      expect(toKebabCase('HelloWorld')).toBe('hello-world');
    });
  });

  describe('toCamelCase', () => {
    it('should convert snake_case to camelCase', () => {
      expect(toCamelCase('hello_world')).toBe('helloWorld');
    });

    it('should handle already camelCase', () => {
      expect(toCamelCase('helloWorld')).toBe('helloworld');
    });

    it('should handle empty string', () => {
      expect(toCamelCase('')).toBe('');
    });
  });

  describe('toSnakeCase', () => {
    it('should convert camelCase to snake_case', () => {
      expect(toSnakeCase('helloWorld')).toBe('hello_world');
    });

    it('should handle already snake_case', () => {
      expect(toSnakeCase('hello_world')).toBe('hello_world');
    });

    it('should handle empty string', () => {
      expect(toSnakeCase('')).toBe('');
    });
  });

  describe('transformKeys', () => {
    it('should transform keys to snake_case', () => {
      const obj = { helloWorld: 'value' };
      const result = transformKeys(obj, 'SnakeCase');
      expect(result).toHaveProperty('hello_world');
    });

    it('should transform keys to camelCase', () => {
      const obj = { hello_world: 'value' };
      const result = transformKeys(obj, 'CamelCase');
      expect(result).toHaveProperty('helloWorld');
    });
  });

  describe('removeDuplicate', () => {
    it('should remove duplicate items', () => {
      expect(removeDuplicate(['a', 'b', 'a', 'c'])).toEqual(['a', 'b', 'c']);
    });

    it('should handle array without duplicates', () => {
      expect(removeDuplicate(['a', 'b', 'c'])).toEqual(['a', 'b', 'c']);
    });

    it('should handle empty array', () => {
      expect(removeDuplicate([])).toEqual([]);
    });
  });

  describe('isVpaIdValid', () => {
    it('should return true for valid VPA ID', () => {
      expect(isVpaIdValid('user@bank')).toBe(true);
    });

    it('should return false for invalid VPA ID', () => {
      expect(isVpaIdValid('nope')).toBe(false);
    });

    it('should return undefined for empty string', () => {
      expect(isVpaIdValid('')).toBeUndefined();
    });
  });

  describe('checkEmailValid', () => {
    it('should update state for valid email', () => {
      const state = { isValid: undefined, value: '' };
      const emailObj = { value: 'test@example.com' };
      const updateFn = jest.fn((updater) => updater(state));
      
      checkEmailValid(emailObj, updateFn);
      
      expect(updateFn).toHaveBeenCalled();
    });
  });

  describe('sortBasedOnPriority', () => {
    it('should sort array based on priority', () => {
      const arr = ['c', 'a', 'b'];
      const priority = ['a', 'b'];
      expect(sortBasedOnPriority(arr, priority)).toEqual(['a', 'b', 'c']);
    });

    it('should handle empty priority array', () => {
      const arr = ['c', 'a', 'b'];
      expect(sortBasedOnPriority(arr, [])).toEqual(['c', 'a', 'b']);
    });

    it('should handle empty array', () => {
      expect(sortBasedOnPriority([], ['a', 'b'])).toEqual([]);
    });
  });

  describe('onlyDigits', () => {
    it('should extract only digits from string', () => {
      expect(onlyDigits('abc123def456')).toBe('123456');
    });

    it('should return same string if only digits', () => {
      expect(onlyDigits('12345')).toBe('12345');
    });

    it('should return empty string for no digits', () => {
      expect(onlyDigits('abcdef')).toBe('');
    });

    it('should handle empty string', () => {
      expect(onlyDigits('')).toBe('');
    });
  });

  describe('snakeToTitleCase', () => {
    it('should convert snake_case to Title Case', () => {
      expect(snakeToTitleCase('hello_world')).toBe('Hello World');
    });

    it('should handle empty string', () => {
      expect(snakeToTitleCase('')).toBe('');
    });

    it('should handle single word', () => {
      expect(snakeToTitleCase('hello')).toBe('Hello');
    });
  });

  describe('formatIBAN', () => {
    it('should format IBAN with spaces every 4 chars', () => {
      const result = formatIBAN('DE89370400440532013000');
      expect(result).toContain('DE89');
    });

    it('should handle short IBAN', () => {
      const result = formatIBAN('DE');
      expect(result).toBe('DE');
    });

    it('should handle empty string', () => {
      expect(formatIBAN('')).toBe('');
    });

    // Edge case: non-alphanumeric characters are stripped
    it('should strip non-alphanumeric characters', () => {
      const result = formatIBAN('DE89-3704.0044!0532@013#000');
      expect(result).toContain('DE89');
      // After stripping, should be same as clean input
      expect(result).toBe(formatIBAN('DE89370400440532013000'));
    });

    // Edge case: very long input
    it('should handle very long input', () => {
      const longInput = 'GB' + '12' + 'A'.repeat(100);
      const result = formatIBAN(longInput);
      expect(result.startsWith('GB12')).toBe(true);
      // Should contain spaces separating groups of 4
      expect(result).toContain(' ');
    });
  });

  describe('formatBSB', () => {
    it('should format 6-digit BSB with dash', () => {
      expect(formatBSB('123456')).toBe('123-456');
    });

    it('should return first 3 digits for short BSB', () => {
      expect(formatBSB('123')).toBe('123');
    });

    it('should handle empty string', () => {
      expect(formatBSB('')).toBe('');
    });

    // Edge case: non-digit characters are stripped
    it('should strip non-digit characters', () => {
      expect(formatBSB('1a2b3c4d5e6f')).toBe('123-456');
    });

    // Edge case: more than 6 digits — returns raw formatted string
    it('should return raw formatted for more than 6 digits', () => {
      const result = formatBSB('1234567');
      expect(result).toBe('1234567');
    });
  });

  describe('deepCopyDict', () => {
    it('should create a new dict with same values', () => {
      const original = { a: 1, b: { c: 2 } };
      const copy = deepCopyDict(original);
      expect(copy).toEqual(original);
    });

    it('should not be the same reference', () => {
      const original = { a: 1 };
      const copy = deepCopyDict(original);
      expect(copy).not.toBe(original);
    });

    it('should handle empty dict', () => {
      expect(deepCopyDict({})).toEqual({});
    });
  });

  describe('flattenObject', () => {
    it('should flatten nested object', () => {
      const obj = { a: { b: 1 } };
      const result = flattenObject(obj, false);
      expect(result).toEqual({"a.b": 1});
    });

    it('should handle flat object', () => {
      const obj = { a: 1, b: 2 };
      const result = flattenObject(obj, false);
      expect(result).toEqual(obj);
    });
  });

  describe('unflattenObject', () => {
    it('should unflatten flat object with dot notation', () => {
      const obj = { 'a.b': 1 };
      const result = unflattenObject(obj);
      expect(result).toHaveProperty('a');
    });
  });

  describe('generateRandomString', () => {
    it('should return a string', () => {
      const result = generateRandomString(10);
      expect(typeof result).toBe('string');
    });

    it('should return different strings on multiple calls', () => {
      const result1 = generateRandomString(10);
      const result2 = generateRandomString(10);
      expect(result1).not.toBe(result2);
    });

    it('should return string of correct length', () => {
      const result = generateRandomString(10);
      expect(result.length).toBe(10);
    });
  });

  describe('getPaymentId', () => {
    it('should extract payment ID from client secret', () => {
      expect(getPaymentId('pay_abc123_secret_xyz')).toBe('pay_abc123');
    });

    it('should handle invalid format', () => {
      expect(getPaymentId('invalid')).toBe('invalid');
    });

    it('should handle empty string', () => {
      expect(getPaymentId('')).toBe('');
    });
  });

  describe('checkIs18OrAbove', () => {
    it('should return true for date 18+ years ago', () => {
      const date18YearsAgo = new Date();
      date18YearsAgo.setFullYear(date18YearsAgo.getFullYear() - 20);
      expect(checkIs18OrAbove(date18YearsAgo)).toBe(true);
    });

    it('should return false for date less than 18 years ago', () => {
      const date17YearsAgo = new Date();
      date17YearsAgo.setFullYear(date17YearsAgo.getFullYear() - 17);
      expect(checkIs18OrAbove(date17YearsAgo)).toBe(false);
    });

    it('should return false for future date', () => {
      const futureDate = new Date();
      futureDate.setFullYear(futureDate.getFullYear() + 1);
      expect(checkIs18OrAbove(futureDate)).toBe(false);
    });

    // Edge case: exact boundary — born exactly 18 years ago today
    it('should return true for someone born exactly 18 years ago today', () => {
      const now = new Date();
      const exactly18 = new Date(now.getFullYear() - 18, now.getMonth(), now.getDate());
      expect(checkIs18OrAbove(exactly18)).toBe(true);
    });

    // Edge case: one day short of 18 — born 17 years and 364 days ago
    it('should return false for someone one day short of 18', () => {
      const now = new Date();
      const almostEighteen = new Date(now.getFullYear() - 18, now.getMonth(), now.getDate() + 1);
      expect(checkIs18OrAbove(almostEighteen)).toBe(false);
    });

    // Edge case: one day past 18 — born 18 years and 1 day ago
    it('should return true for someone one day past 18', () => {
      const now = new Date();
      const justOver18 = new Date(now.getFullYear() - 18, now.getMonth(), now.getDate() - 1);
      expect(checkIs18OrAbove(justOver18)).toBe(true);
    });
  });

  describe('getFirstAndLastNameFromFullName', () => {
    it('should split full name into first and last', () => {
      const result = getFirstAndLastNameFromFullName('John Doe');
      expect(result[0]).toBe('John');
      expect(result[1]).toBe('Doe');
    });

    it('should handle single name', () => {
      const result = getFirstAndLastNameFromFullName('John');
      expect(result[0]).toBe('John');
    });

    it('should handle empty string', () => {
      const result = getFirstAndLastNameFromFullName('');
      expect(result[0]).toBe('');
    });

    it('should handle multiple words', () => {
      const result = getFirstAndLastNameFromFullName('John Michael Doe');
      expect(result[0]).toBe('John');
      expect(result[1]).toBe('Michael Doe');
    });
  });

  describe('minorUnitToString', () => {
    it('should convert minor unit to string', () => {
      expect(minorUnitToString(1000)).toBe('10');
    });

    it('should handle zero', () => {
      expect(minorUnitToString(0)).toBe('0');
    });

    it('should handle small amounts', () => {
      expect(minorUnitToString(1)).toBe('0.01');
    });

    // Edge case: negative number
    it('should handle negative minor units', () => {
      expect(minorUnitToString(-500)).toBe('-5');
    });

    // Edge case: very large number
    it('should handle very large minor units', () => {
      expect(minorUnitToString(99999999)).toBe('999999.99');
    });
  });

  describe('formatAmountWithTwoDecimals', () => {
    it('should format amount with two decimals', () => {
      expect(formatAmountWithTwoDecimals(10.5)).toBe('10.50');
    });

    it('should handle integer amount', () => {
      expect(formatAmountWithTwoDecimals(10)).toBe('10.00');
    });

    it('should handle amount with more decimals', () => {
      expect(formatAmountWithTwoDecimals(10.123)).toBe('10.12');
    });
  });

  describe('isValidHexColor', () => {
    it('should return true for valid 6-digit hex color', () => {
      expect(isValidHexColor('#ff0000')).toBe(true);
    });

    it('should return true for valid 3-digit hex color', () => {
      expect(isValidHexColor('#fff')).toBe(true);
    });

    it('should return false for non-hex color', () => {
      expect(isValidHexColor('red')).toBe(false);
    });

    it('should return false for empty string', () => {
      expect(isValidHexColor('')).toBe(false);
    });

    it('should return false for invalid hex format', () => {
      expect(isValidHexColor('#gggggg')).toBe(false);
    });
  });

  describe('safeParseOpt', () => {
    it('should parse valid JSON string', () => {
      const result = safeParseOpt('{"a":1}');
      expect(result).toEqual({ a: 1 });
    });

    it('should return undefined for invalid JSON', () => {
      expect(safeParseOpt('invalid')).toBeUndefined();
    });
  });

  describe('safeParse', () => {
    it('should parse valid JSON string', () => {
      const result = safeParse('{"a":1}');
      expect(result).toEqual({ a: 1 });
    });

    it('should return null for invalid JSON', () => {
      expect(safeParse('invalid')).toBeNull();
    });
  });

  describe('getJsonFromArrayOfJson', () => {
    it('should convert array of tuples to object', () => {
      const arr = [['key1', 'value1'], ['key2', 'value2']];
      const result = getJsonFromArrayOfJson(arr);
      expect(result).toEqual({ key1: 'value1', key2: 'value2' });
    });

    it('should handle empty array', () => {
      expect(getJsonFromArrayOfJson([])).toEqual({});
    });

    it('should handle single entry', () => {
      expect(getJsonFromArrayOfJson([['key', 'value']])).toEqual({ key: 'value' });
    });
  });

  describe('convertDictToArrayOfKeyStringTuples', () => {
    it('should convert dict to array of key-string tuples', () => {
      const dict = { name: 'John', age: '25' };
      const result = convertDictToArrayOfKeyStringTuples(dict);
      expect(result).toContainEqual(['name', 'John']);
      expect(result).toContainEqual(['age', '25']);
    });

    it('should handle empty dict', () => {
      expect(convertDictToArrayOfKeyStringTuples({})).toEqual([]);
    });
  });

  describe('mergeHeadersIntoDict', () => {
    it('should merge headers array into dict', () => {
      const dict: any = { existing: 'value' };
      const headers = [['newKey', 'newValue'], ['another', 'value']];
      mergeHeadersIntoDict(dict, headers);
      expect(dict.newKey).toBe('newValue');
      expect(dict.another).toBe('value');
      expect(dict.existing).toBe('value');
    });

    it('should handle empty headers array', () => {
      const dict: any = { existing: 'value' };
      mergeHeadersIntoDict(dict, []);
      expect(dict.existing).toBe('value');
      expect(Object.keys(dict).length).toBe(1);
    });
  });

  describe('getFloatFromString', () => {
    it('should parse valid float string', () => {
      expect(getFloatFromString('3.14', 0)).toBe(3.14);
    });

    it('should return default for invalid string', () => {
      expect(getFloatFromString('invalid', 0)).toBe(0);
    });

    it('should handle integer string', () => {
      expect(getFloatFromString('42', 0)).toBe(42);
    });
  });

  describe('getFloatFromJson', () => {
    it('should extract float from JSON number', () => {
      expect(getFloatFromJson(3.14, 0)).toBe(3.14);
    });

    it('should extract float from JSON string', () => {
      expect(getFloatFromJson('3.14', 0)).toBe(3.14);
    });

    it('should return default for non-numeric value', () => {
      expect(getFloatFromJson('invalid', 0)).toBe(0);
    });

    it('should return default for null', () => {
      expect(getFloatFromJson(null, 5.5)).toBe(5.5);
    });
  });

  describe('getJsonBoolValue', () => {
    it('should return value when key exists', () => {
      expect(getJsonBoolValue({ active: true }, 'active', false)).toBe(true);
    });

    it('should return default when key does not exist', () => {
      expect(getJsonBoolValue({}, 'active', false)).toBe(false);
    });

    it('should handle undefined value', () => {
      expect(getJsonBoolValue({ active: undefined }, 'active', true)).toBe(true);
    });
  });

  describe('getJsonStringFromDict', () => {
    it('should return value when key exists', () => {
      expect(getJsonStringFromDict({ name: 'John' }, 'name', 'default')).toBe('John');
    });

    it('should return default when key does not exist', () => {
      expect(getJsonStringFromDict({}, 'name', 'default')).toBe('default');
    });
  });

  describe('getJsonArrayFromDict', () => {
    it('should return array when key exists', () => {
      expect(getJsonArrayFromDict({ items: [1, 2, 3] }, 'items', [])).toEqual([1, 2, 3]);
    });

    it('should return default when key does not exist', () => {
      expect(getJsonArrayFromDict({}, 'items', [])).toEqual([]);
    });
  });

  describe('getJsonFromDict', () => {
    it('should return value when key exists', () => {
      expect(getJsonFromDict({ data: { a: 1 } }, 'data', {})).toEqual({ a: 1 });
    });

    it('should return default when key does not exist', () => {
      expect(getJsonFromDict({}, 'data', null)).toBe(null);
    });
  });

  describe('getJsonObjFromDict', () => {
    it('should return object when key exists', () => {
      expect(getJsonObjFromDict({ data: { a: 1 } }, 'data', {})).toEqual({ a: 1 });
    });

    it('should return default when key does not exist', () => {
      expect(getJsonObjFromDict({}, 'data', {})).toEqual({});
    });
  });

  describe('getRequiredString', () => {
    it('should return value when key exists with non-empty value', () => {
      const dict = { name: 'John' };
      expect(getRequiredString(dict, 'name', 'default', undefined)).toBe('John');
    });
  });

  describe('getWarningString', () => {
    it('should return string value when key exists', () => {
      expect(getWarningString({ name: 'John' }, 'name', 'default', undefined)).toBe('John');
    });

    it('should return default when key does not exist', () => {
      expect(getWarningString({}, 'name', 'default', undefined)).toBe('default');
    });
  });

  describe('getDictFromObj', () => {
    it('should return dict from JSON object', () => {
      expect(getDictFromObj({ data: { a: 1 } }, 'data')).toEqual({ a: 1 });
    });

    it('should return empty object when key does not exist', () => {
      expect(getDictFromObj({}, 'data')).toEqual({});
    });
  });

  describe('getJsonObjectFromDict', () => {
    it('should return object when key exists', () => {
      expect(getJsonObjectFromDict({ data: { a: 1 } }, 'data')).toEqual({ a: 1 });
    });

    it('should return empty object when key does not exist', () => {
      expect(getJsonObjectFromDict({}, 'data')).toEqual({});
    });
  });

  describe('getOptionBool', () => {
    it('should return boolean when key exists', () => {
      expect(getOptionBool({ active: true }, 'active')).toBe(true);
    });

    it('should return undefined when key does not exist', () => {
      expect(getOptionBool({}, 'active')).toBeUndefined();
    });
  });

  describe('getDictFromJson', () => {
    it('should return dict from JSON', () => {
      expect(getDictFromJson({ a: 1 })).toEqual({ a: 1 });
    });

    it('should return empty object for null', () => {
      expect(getDictFromJson(null)).toEqual({});
    });
  });

  describe('getDictFromDict', () => {
    it('should return nested dict', () => {
      expect(getDictFromDict({ data: { a: 1 } }, 'data')).toEqual({ a: 1 });
    });

    it('should return empty object when key does not exist', () => {
      expect(getDictFromDict({}, 'data')).toEqual({});
    });
  });

  describe('getNonEmptyOption', () => {
    it('should return value for non-empty string', () => {
      expect(getNonEmptyOption('value')).toBe('value');
    });

    it('should return undefined for empty string', () => {
      expect(getNonEmptyOption('')).toBeUndefined();
    });

    it('should return undefined for undefined', () => {
      expect(getNonEmptyOption(undefined)).toBeUndefined();
    });
  });

  describe('getOptionsDict', () => {
    it('should return dict from options', () => {
      expect(getOptionsDict({ a: 1 })).toEqual({ a: 1 });
    });

    it('should return empty object for null', () => {
      expect(getOptionsDict(null)).toEqual({});
    });
  });

  describe('getBoolWithWarning', () => {
    it('should return boolean value when key exists', () => {
      expect(getBoolWithWarning({ active: true }, 'active', false, undefined)).toBe(true);
    });

    it('should return default when key does not exist', () => {
      expect(getBoolWithWarning({}, 'active', false, undefined)).toBe(false);
    });
  });

  describe('getNumberWithWarning', () => {
    it('should return number value when key exists', () => {
      expect(getNumberWithWarning({ count: 5 }, 'count', undefined, 0)).toBe(5);
    });

    it('should return default when key does not exist', () => {
      expect(getNumberWithWarning({}, 'count', undefined, 0)).toBe(0);
    });
  });

  describe('getOptionalArrayFromDict', () => {
    it('should return array when key exists', () => {
      expect(getOptionalArrayFromDict({ items: [1, 2, 3] }, 'items')).toEqual([1, 2, 3]);
    });

    it('should return undefined when key does not exist', () => {
      expect(getOptionalArrayFromDict({}, 'items')).toBeUndefined();
    });
  });

  describe('getArrayOfObjectsFromDict', () => {
    it('should return array of objects when key exists', () => {
      expect(getArrayOfObjectsFromDict({ items: [{ a: 1 }, { b: 2 }] }, 'items')).toEqual([{ a: 1 }, { b: 2 }]);
    });

    it('should return empty array when key does not exist', () => {
      expect(getArrayOfObjectsFromDict({}, 'items')).toEqual([]);
    });
  });

  describe('getStrArray', () => {
    it('should return string array when key exists', () => {
      expect(getStrArray({ items: ['a', 'b', 'c'] }, 'items')).toEqual(['a', 'b', 'c']);
    });

    it('should return empty array when key does not exist', () => {
      expect(getStrArray({}, 'items')).toEqual([]);
    });
  });

  describe('getOptionalStrArray', () => {
    it('should return string array when key exists', () => {
      expect(getOptionalStrArray({ items: ['a', 'b'] }, 'items')).toEqual(['a', 'b']);
    });

    it('should return undefined when key does not exist', () => {
      expect(getOptionalStrArray({}, 'items')).toBeUndefined();
    });
  });

  describe('getBoolValue', () => {
    it('should return boolean value', () => {
      expect(getBoolValue(true)).toBe(true);
      expect(getBoolValue(false)).toBe(false);
    });

    it('should return false for undefined', () => {
      expect(getBoolValue(undefined)).toBe(false);
    });
  });

  describe('mergeJsons', () => {
    it('should merge two JSON objects', () => {
      const json1 = { a: 1, b: { c: 2 } };
      const json2 = { b: { d: 3 }, e: 4 };
      const result = mergeJsons(json1, json2);
      expect(result.a).toBe(1);
      expect(result.e).toBe(4);
    });

    it('should handle empty objects', () => {
      expect(mergeJsons({}, { a: 1 }).a).toBe(1);
      expect(mergeJsons({ a: 1 }, {}).a).toBe(1);
    });
  });

  describe('toCamelCaseWithNumberSupport', () => {
    it('should convert snake_case to camelCase preserving numbers', () => {
      expect(toCamelCaseWithNumberSupport('hello_world123')).toBe('helloWorld123');
    });

    it('should handle strings with colons', () => {
      expect(toCamelCaseWithNumberSupport('hello:world')).toBe('hello:world');
    });

    it('should handle empty string', () => {
      expect(toCamelCaseWithNumberSupport('')).toBe('');
    });
  });

  describe('transformKeysWithoutModifyingValue', () => {
    it('should transform keys without modifying number values', () => {
      const obj = { hello_world: 123 };
      const result = transformKeysWithoutModifyingValue(obj, 'CamelCase');
      expect(result.helloWorld).toBe(123);
    });

    it('should transform nested objects', () => {
      const obj = { outer_key: { inner_key: 'value' } };
      const result = transformKeysWithoutModifyingValue(obj, 'CamelCase');
      expect(result.outerKey.innerKey).toBe('value');
    });
  });

  describe('isAllValid', () => {
    it('should return true when all card fields are valid in payment mode', () => {
      expect(isAllValid(true, true, true, true, true, 'payment')).toBe(true);
    });

    it('should return false when any field is invalid', () => {
      expect(isAllValid(true, true, false, true, true, 'payment')).toBe(false);
    });

    it('should require zip in non-payment mode', () => {
      expect(isAllValid(true, true, true, true, true, 'setup')).toBe(true);
      expect(isAllValid(true, true, true, true, false, 'setup')).toBe(false);
    });

    it('should return false when all false', () => {
      expect(isAllValid(false, false, false, false, false, 'payment')).toBe(false);
    });
  });

  describe('getCountryPostal', () => {
    it('should return postal code info for country', () => {
      const postalCodes = [{ iso: 'US', format: '12345' }, { iso: 'GB', format: 'A1 1AA' }];
      const result = getCountryPostal('US', postalCodes);
      expect(result.iso).toBe('US');
    });

    it('should return default when country not found', () => {
      const result = getCountryPostal('XX', []);
      expect(result).toBeDefined();
    });
  });

  describe('getCountryNames', () => {
    it('should extract country names from list', () => {
      const list = [{ countryName: 'USA' }, { countryName: 'Canada' }];
      expect(getCountryNames(list)).toEqual(['USA', 'Canada']);
    });

    it('should handle empty list', () => {
      expect(getCountryNames([])).toEqual([]);
    });
  });

  describe('getBankNames', () => {
    it('should return bank names that exist in allBanks', () => {
      const list = [{ value: 'bank1', displayName: 'Bank One' }, { value: 'bank2', displayName: 'Bank Two' }];
      expect(getBankNames(list, ['bank1'])).toEqual(['Bank One']);
    });

    it('should return empty array when no matches', () => {
      const list = [{ value: 'bank1', displayName: 'Bank One' }];
      expect(getBankNames(list, ['bank2'])).toEqual([]);
    });
  });

  describe('getBankKeys', () => {
    it('should return bank value for matching displayName', () => {
      const banks = [{ displayName: 'Bank One', value: 'bank1' }];
      expect(getBankKeys('Bank One', banks, 'default')).toBe('bank1');
    });

    it('should return undefined when not found', () => {
      expect(getBankKeys('Unknown', [], 'default')).toBeUndefined();
    });
  });

  describe('getArrofJsonString', () => {
    it('should return the same array', () => {
      expect(getArrofJsonString(['a', 'b', 'c'])).toEqual(['a', 'b', 'c']);
    });

    it('should handle empty array', () => {
      expect(getArrofJsonString([])).toEqual([]);
    });
  });

  describe('getOptionalArr', () => {
    it('should return array when defined', () => {
      expect(getOptionalArr([1, 2, 3])).toEqual([1, 2, 3]);
    });

    it('should return empty array when undefined', () => {
      expect(getOptionalArr(undefined)).toEqual([]);
    });
  });

  describe('checkPriorityList', () => {
    it('should return true when first item is card', () => {
      expect(checkPriorityList(['card', 'bank'])).toBe(true);
    });

    it('should return false when first item is not card', () => {
      expect(checkPriorityList(['bank', 'card'])).toBe(false);
    });

    it('should return false for empty array', () => {
      expect(checkPriorityList(undefined)).toBe(false);
    });
  });

  describe('addSize', () => {
    it('should add to pixel value', () => {
      expect(addSize('10px', 5, 'Pixel')).toBe('15px');
    });

    it('should add to rem value', () => {
      expect(addSize('2rem', 1, 'Rem')).toBe('3rem');
    });

    it('should add to em value', () => {
      expect(addSize('1.5em', 0.5, 'Em')).toBe('2em');
    });

    it('should return original if unit mismatch', () => {
      expect(addSize('10px', 5, 'Rem')).toBe('10px');
    });
  });

  describe('toInt', () => {
    it('should convert string to integer', () => {
      expect(toInt('42')).toBe(42);
    });

    it('should return 0 for invalid string', () => {
      expect(toInt('invalid')).toBe(0);
    });

    it('should handle empty string', () => {
      expect(toInt('')).toBe(0);
    });
  });

  describe('validateRountingNumber', () => {
    it('should return true for valid routing number', () => {
      expect(validateRountingNumber('011000015')).toBe(true);
    });

    it('should return false for invalid routing number', () => {
      expect(validateRountingNumber('123456789')).toBe(false);
    });

    it('should return false for wrong length', () => {
      expect(validateRountingNumber('12345')).toBe(false);
    });

    it('should return false for empty string', () => {
      expect(validateRountingNumber('')).toBe(false);
    });
  });

  describe('getDictIsSome', () => {
    it('should return true when key has Some value', () => {
      expect(getDictIsSome({ key: 'value' }, 'key')).toBe(true);
    });

    it('should return false when key has undefined', () => {
      expect(getDictIsSome({}, 'key')).toBe(false);
    });
  });

  describe('rgbaTorgb', () => {
    it('should convert rgba to rgb format', () => {
      const result = rgbaTorgb('rgba(255, 0, 0, 0.5)');
      expect(result).toMatch(/rgba\(255,\s*0,\s*0\)/);
    });

    it('should return original if already rgb', () => {
      expect(rgbaTorgb('rgb(255, 0, 0)')).toBe('rgb(255, 0, 0)');
    });

    it('should return original if not rgba/rgb', () => {
      expect(rgbaTorgb('#ff0000')).toBe('#ff0000');
    });

    it('should handle whitespace', () => {
      const result = rgbaTorgb('  rgba(255, 0, 0, 0.5)  ');
      expect(result).toMatch(/rgba\(255,\s*0,\s*0\)/);
    });
  });

  describe('findVersion', () => {
    it('should find version in string', () => {
      const re = /Chrome\/([\d.]+)/;
      const result = findVersion(re, 'Chrome/120.0.0');
      expect(result).toContain('120.0.0');
    });

    it('should return empty array when no match', () => {
      const re = /Firefox\/([\d.]+)/;
      expect(findVersion(re, 'Chrome/120.0.0')).toEqual([]);
    });
  });

  describe('browserDetect', () => {
    it('should detect Chrome', () => {
      const result = browserDetect('Mozilla/5.0 Chrome/120.0.0 Safari/537.36');
      expect(result).toContain('Chrome');
    });

    it('should detect Firefox', () => {
      const result = browserDetect('Mozilla/5.0 Firefox/115.0');
      expect(result).toContain('Firefox');
    });

    it('should detect Safari', () => {
      const result = browserDetect('Mozilla/5.0 Safari/605.1.15');
      expect(result).toContain('Safari');
    });

    it('should return Others for unknown browser', () => {
      const result = browserDetect('Unknown Browser');
      expect(result).toContain('Others');
    });
  });

  describe('formatException', () => {
    it('should format error exception with message', () => {
      const error = new Error('Test error');
      const result = formatException(error) as any;
      expect(result.message).toBe('Test error');
    });

    it('should return original for non-Error objects', () => {
      const obj = { custom: 'error' };
      expect(formatException(obj)).toBe(obj);
    });
  });

  describe('arrayJsonToCamelCase', () => {
    it('should transform keys in array of objects', () => {
      const arr = [{ hello_world: 'value' }];
      const result = arrayJsonToCamelCase(arr);
      expect(result[0]).toHaveProperty('helloWorld');
    });

    it('should handle empty array', () => {
      expect(arrayJsonToCamelCase([])).toEqual([]);
    });
  });

  describe('getArrayValFromJsonDict', () => {
    it('should extract array values from nested dict', () => {
      const dict = { 
        outer: { 
          inner: ['a', 'b', 'c'] 
        } 
      };
      const result = getArrayValFromJsonDict(dict, 'outer', 'inner');
      expect(result).toEqual(['a', 'b', 'c']);
    });

    it('should return empty array when path not found', () => {
      expect(getArrayValFromJsonDict({}, 'outer', 'inner')).toEqual([]);
    });
  });

  describe('isOtherElements', () => {
    it('should return true for card types', () => {
      expect(isOtherElements('card')).toBe(true);
      expect(isOtherElements('cardNumber')).toBe(true);
      expect(isOtherElements('cardExpiry')).toBe(true);
      expect(isOtherElements('cardCvc')).toBe(true);
    });

    it('should return false for other types', () => {
      expect(isOtherElements('bank')).toBe(false);
      expect(isOtherElements('wallet')).toBe(false);
    });
  });

  describe('canHaveMultipleInstances', () => {
    it('should return true for card element types', () => {
      expect(canHaveMultipleInstances('cardNumber')).toBe(true);
      expect(canHaveMultipleInstances('cardExpiry')).toBe(true);
      expect(canHaveMultipleInstances('cardCvc')).toBe(true);
    });

    it('should return false for other types', () => {
      expect(canHaveMultipleInstances('card')).toBe(false);
      expect(canHaveMultipleInstances('bank')).toBe(false);
    });
  });

  describe('callbackFuncForExtractingValFromDict', () => {
    it('should return function that extracts value by key', () => {
      const fn = callbackFuncForExtractingValFromDict('name');
      expect(fn({ name: 'John' })).toBe('John');
    });

    it('should return undefined for missing key', () => {
      const fn = callbackFuncForExtractingValFromDict('missing');
      expect(fn({ name: 'John' })).toBeUndefined();
    });
  });

  describe('getClasses', () => {
    it('should extract class from options', () => {
      const options = { classes: { base: 'my-class' } };
      expect(getClasses(options, 'base')).toBe('my-class');
    });

    it('should return empty string when not found', () => {
      expect(getClasses({}, 'base')).toBe('');
    });
  });

  describe('getStringFromOptionalJson', () => {
    it('should extract string from optional JSON', () => {
      expect(getStringFromOptionalJson('value', 'default')).toBe('value');
    });

    it('should return default for undefined', () => {
      expect(getStringFromOptionalJson(undefined, 'default')).toBe('default');
    });
  });

  describe('getBoolFromOptionalJson', () => {
    it('should extract boolean from optional JSON', () => {
      expect(getBoolFromOptionalJson(true, false)).toBe(true);
    });

    it('should return default for undefined', () => {
      expect(getBoolFromOptionalJson(undefined, false)).toBe(false);
    });
  });

  describe('getBoolFromJson', () => {
    it('should extract boolean from JSON', () => {
      expect(getBoolFromJson(true, false)).toBe(true);
    });

    it('should return default for non-boolean', () => {
      expect(getBoolFromJson('not a bool', false)).toBe(false);
    });
  });

  describe('getOptionalJson', () => {
    it('should extract nested value from JSON', () => {
      const json = { data: { key: 'value' } };
      expect(getOptionalJson(json, 'key')).toBe('value');
    });

    it('should return undefined when path not found', () => {
      expect(getOptionalJson({}, 'key')).toBeUndefined();
    });
  });

  describe('setNested', () => {
    it('should set nested value in dict', () => {
      const dict: any = {};
      setNested(dict, ['a', 'b', 'c'], 'value');
      expect(dict.a.b.c).toBe('value');
    });

    it('should set single-level value', () => {
      const dict: any = {};
      setNested(dict, ['key'], 'value');
      expect(dict.key).toBe('value');
    });
  });

  describe('mergeTwoFlattenedJsonDicts', () => {
    it('should merge two flattened dicts', () => {
      const dict1 = { 'a.b': 1 };
      const dict2 = { 'c.d': 2 };
      const result = mergeTwoFlattenedJsonDicts(dict1, dict2);
      expect(result).toHaveProperty('a');
      expect(result).toHaveProperty('c');
    });
  });

  describe('flattenObjectWithStringifiedJson', () => {
    it('should flatten object with stringified JSON values', () => {
      const obj = { outer: '{"inner": "value"}' };
      const result = flattenObjectWithStringifiedJson(obj, false, true);
      expect(result['outer.inner']).toBe('value');
    });

    it('should handle non-string values', () => {
      const obj = { key: 'plain string' };
      const result = flattenObjectWithStringifiedJson(obj, false, true);
      expect(result.key).toBe('plain string');
    });
  });

  describe('flatten', () => {
    it('should flatten nested object with arrays', () => {
      const obj = { items: [{ name: 'a' }, { name: 'b' }] };
      const result = flatten(obj, false);
      expect(result['items[0].name']).toBe('a');
      expect(result['items[1].name']).toBe('b');
    });

    it('should handle string arrays', () => {
      const obj = { tags: ['a', 'b', 'c'] };
      const result = flatten(obj, false);
      expect(result.tags).toEqual(['a', 'b', 'c']);
    });

    it('should handle flat objects', () => {
      const obj = { a: 1, b: 'test' };
      const result = flatten(obj, false);
      expect(result.a).toBe(1);
      expect(result.b).toBe('test');
    });
  });

  describe('getWalletPaymentMethod', () => {
    it('should filter for Google Pay', () => {
      expect(getWalletPaymentMethod(['google_pay', 'paypal'], 'GooglePayElement')).toEqual(['google_pay']);
    });

    it('should filter for Apple Pay', () => {
      expect(getWalletPaymentMethod(['apple_pay', 'google_pay'], 'ApplePayElement')).toEqual(['apple_pay']);
    });

    it('should filter for PayPal', () => {
      expect(getWalletPaymentMethod(['paypal', 'google_pay'], 'PayPalElement')).toEqual(['paypal']);
    });

    it('should return all wallets for unknown type', () => {
      expect(getWalletPaymentMethod(['google_pay', 'paypal'], 'Unknown')).toEqual(['google_pay', 'paypal']);
    });
  });

  describe('getIsExpressCheckoutComponent', () => {
    it('should return true for express checkout components', () => {
      expect(getIsExpressCheckoutComponent('googlePay')).toBe(true);
      expect(getIsExpressCheckoutComponent('applePay')).toBe(true);
      expect(getIsExpressCheckoutComponent('payPal')).toBe(true);
    });

    it('should return false for non-express components', () => {
      expect(getIsExpressCheckoutComponent('card')).toBe(false);
      expect(getIsExpressCheckoutComponent('bank')).toBe(false);
    });
  });

  describe('getIsComponentTypeForPaymentElementCreate', () => {
    it('should return true for valid component types', () => {
      expect(getIsComponentTypeForPaymentElementCreate('payment')).toBe(true);
      expect(getIsComponentTypeForPaymentElementCreate('paymentMethodCollect')).toBe(true);
      expect(getIsComponentTypeForPaymentElementCreate('googlePay')).toBe(true);
    });

    it('should return false for invalid types', () => {
      expect(getIsComponentTypeForPaymentElementCreate('invalid')).toBe(false);
    });
  });

  describe('checkIsWalletElement', () => {
    it('should return true for wallet elements', () => {
      expect(checkIsWalletElement('GooglePayElement')).toBe(true);
      expect(checkIsWalletElement('ApplePayElement')).toBe(true);
      expect(checkIsWalletElement('PayPalElement')).toBe(true);
    });

    it('should return false for non-wallet elements', () => {
      expect(checkIsWalletElement('card')).toBe(false);
    });
  });

  describe('getUniqueArray', () => {
    it('should return array with unique values', () => {
      expect(getUniqueArray(['a', 'b', 'a', 'c'])).toEqual(['a', 'b', 'c']);
    });

    it('should handle empty array', () => {
      expect(getUniqueArray([])).toEqual([]);
    });

    it('should preserve order', () => {
      expect(getUniqueArray(['c', 'a', 'b', 'a'])).toEqual(['c', 'a', 'b']);
    });
  });

  describe('removeHyphen', () => {
    it('should remove all hyphens', () => {
      expect(removeHyphen('123-456-789')).toBe('123456789');
    });

    it('should handle string without hyphens', () => {
      expect(removeHyphen('123456789')).toBe('123456789');
    });

    it('should handle empty string', () => {
      expect(removeHyphen('')).toBe('');
    });
  });

  describe('compareLogic', () => {
    it('should return 0 for equal values', () => {
      expect(compareLogic(5, 5)).toBe(0);
    });

    it('should return -1 when a > b', () => {
      expect(compareLogic(10, 5)).toBe(-1);
    });

    it('should return 1 when a < b', () => {
      expect(compareLogic(5, 10)).toBe(1);
    });
  });

  describe('toSpacedUpperCase', () => {
    it('should convert to uppercase with spaces', () => {
      expect(toSpacedUpperCase('hello_world', '_')).toBe('HELLO WORLD');
    });

    it('should handle empty string', () => {
      expect(toSpacedUpperCase('', '_')).toBe('');
    });

    it('should handle string without delimiter', () => {
      expect(toSpacedUpperCase('hello', '_')).toBe('HELLO');
    });
  });

  describe('handleFailureResponse', () => {
    it('should create error response object', () => {
      const result = handleFailureResponse('Test message', 'TestError') as any;
      expect(result.error.type).toBe('TestError');
      expect(result.error.message).toBe('Test message');
    });
  });

  describe('isKeyPresentInDict', () => {
    it('should return true when key exists', () => {
      expect(isKeyPresentInDict({ key: 'value' }, 'key')).toBe(true);
    });

    it('should return false when key missing', () => {
      expect(isKeyPresentInDict({}, 'key')).toBe(false);
    });
  });

  describe('isDigitLimitExceeded', () => {
    it('should return true when digit limit exceeded', () => {
      expect(isDigitLimitExceeded('12345', 4)).toBe(true);
    });

    it('should return false when within limit', () => {
      expect(isDigitLimitExceeded('123', 4)).toBe(false);
    });

    it('should return false for no digits', () => {
      expect(isDigitLimitExceeded('abc', 1)).toBe(false);
    });
  });

  describe('convertKeyValueToJsonStringPair', () => {
    it('should create key-value pair', () => {
      expect(convertKeyValueToJsonStringPair('key', 'value')).toEqual(['key', 'value']);
    });
  });

  describe('validateName', () => {
    it('should validate non-empty name without digits', () => {
      const result = validateName('John Doe', { value: '', errorString: '', isValid: false }, { invalidCardHolderNameError: 'Invalid name' });
      expect(result.isValid).toBe(true);
      expect(result.value).toBe('John Doe');
    });

    it('should invalidate name with digits', () => {
      const result = validateName('John123', { value: '', errorString: '', isValid: false }, { invalidCardHolderNameError: 'Invalid name' });
      expect(result.isValid).toBe(false);
      expect(result.errorString).toBe('Invalid name');
    });

    it('should handle empty name', () => {
      const result = validateName('', { value: 'prev', errorString: 'prev error', isValid: true }, { invalidCardHolderNameError: 'Invalid name' });
      expect(result.isValid).toBe(false);
      expect(result.errorString).toBe('prev error');
    });
  });

  describe('validateNickname', () => {
    it('should validate nickname without too many digits', () => {
      const [isValid, error] = validateNickname('Card1', { invalidNickNameError: 'Invalid' });
      expect(isValid).toBe(true);
      expect(error).toBe('');
    });

    it('should invalidate nickname with more than 2 digits', () => {
      const [isValid, error] = validateNickname('Card123', { invalidNickNameError: 'Too many digits' });
      expect(isValid).toBe(false);
      expect(error).toBe('Too many digits');
    });

    it('should allow empty nickname', () => {
      const [isValid, error] = validateNickname('', { invalidNickNameError: 'Invalid' });
      expect(isValid).toBe(true);
    });
  });

  describe('setNickNameState', () => {
    it('should set nickname state correctly', () => {
      const result = setNickNameState('Card1', { value: '', errorString: '', isValid: false }, { invalidNickNameError: 'Invalid' });
      expect(result.value).toBe('Card1');
      expect(result.isValid).toBe(true);
    });
  });

  describe('getStringFromBool', () => {
    it('should convert true to "true"', () => {
      expect(getStringFromBool(true)).toBe('true');
    });

    it('should convert false to "false"', () => {
      expect(getStringFromBool(false)).toBe('false');
    });
  });

  describe('maskStringValuesInJson', () => {
    it('should mask string values at specified paths', () => {
      const json = { email: 'test@example.com', name: 'John' };
      const result = maskStringValuesInJson(json, '', 0, (path: string) => path === 'email');
      expect(result.email).toBe('***REDACTED***');
      expect(result.name).toBe('John');
    });

    it('should handle nested objects', () => {
      const json = { user: { email: 'test@example.com' } };
      const result = maskStringValuesInJson(json, '', 0, (path: string) => path.includes('email'));
      expect(result.user.email).toBe('***REDACTED***');
    });

    it('should handle arrays', () => {
      const json = { items: ['a', 'b', 'c'] };
      const result = maskStringValuesInJson(json, '', 0, () => true);
      expect(result.items).toEqual(['***REDACTED***', '***REDACTED***', '***REDACTED***']);
    });

    it('should handle max depth', () => {
      const json = { a: 'test' };
      const result = maskStringValuesInJson(json, '', 11, () => true);
      expect(result).toBe('***MAX_DEPTH_REACHED***');
    });

    it('should mask empty strings', () => {
      const json = { empty: '' };
      const result = maskStringValuesInJson(json, '', 0, () => true);
      expect(result.empty).toBe('***EMPTY***');
    });
  });

  describe('getSdkAuthorizationData', () => {
    beforeEach(() => {
      jest.spyOn(window, 'atob').mockImplementation((str: string) => str);
    });

    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('should parse SDK authorization data', () => {
      const result = getSdkAuthorizationData('publishable_key=pk_test,client_secret=cs_test,customer_id=cust_123,profile_id=prof_123');
      expect(result.publishableKey).toBe('pk_test');
      expect(result.clientSecret).toBe('cs_test');
      expect(result.customerId).toBe('cust_123');
      expect(result.profileId).toBe('prof_123');
    });

    it('should handle missing fields', () => {
      const result = getSdkAuthorizationData('publishable_key=pk_test');
      expect(result.publishableKey).toBe('pk_test');
      expect(result.clientSecret).toBeUndefined();
    });
  });
});
