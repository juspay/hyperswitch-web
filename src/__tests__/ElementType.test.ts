import {
  getIconStyle,
  defaultClasses,
  defaultStyleClass,
  defaultPaymentRequestButton,
  defaultStyle,
  defaultOptions,
  getClasses,
  getStyleObj,
  getTheme,
  getPaymentRequestButton,
  getStyle,
  itemToObjMapper,
} from '../Types/ElementType.bs.js';

const mockLogger = {
  setLogInfo: jest.fn(),
  setLogError: jest.fn(),
};

describe('ElementType', () => {
  describe('getIconStyle', () => {
    it('should return "Default" for "default"', () => {
      expect(getIconStyle('default')).toBe('Default');
    });

    it('should return "Solid" for "solid"', () => {
      expect(getIconStyle('solid')).toBe('Solid');
    });

    it('should return "Default" for unknown value', () => {
      expect(getIconStyle('unknown')).toBe('Default');
    });

    it('should return "Default" for empty string', () => {
      expect(getIconStyle('')).toBe('Default');
    });
  });

  describe('defaultClasses', () => {
    it('should have correct default class names', () => {
      expect(defaultClasses.base).toBe('OrcaElement');
      expect(defaultClasses.complete).toBe('OrcaElement--complete');
      expect(defaultClasses.empty).toBe('OrcaElement--empty');
      expect(defaultClasses.focus).toBe('OrcaElement--focus');
      expect(defaultClasses.invalid).toBe('OrcaElement--invalid');
      expect(defaultClasses.valid).toBe('OrcaElement--valid');
      expect(defaultClasses.webkitAutofill).toBe('OrcaElement--webkit-autofill');
    });
  });

  describe('defaultStyleClass', () => {
    it('should have empty string defaults for style properties', () => {
      expect(defaultStyleClass.backgroundColor).toBe('');
      expect(defaultStyleClass.color).toBe('');
      expect(defaultStyleClass.fontFamily).toBe('');
      expect(defaultStyleClass.fontSize).toBe('');
    });
  });

  describe('defaultPaymentRequestButton', () => {
    it('should have correct default values', () => {
      expect(defaultPaymentRequestButton.type_).toBe('default');
      expect(defaultPaymentRequestButton.theme).toBe('Dark');
      expect(defaultPaymentRequestButton.height).toBe('');
    });
  });

  describe('defaultOptions', () => {
    it('should have correct default values', () => {
      expect(defaultOptions.value).toBe('');
      expect(defaultOptions.hidePostalCode).toBe(false);
      expect(defaultOptions.iconStyle).toBe('Default');
      expect(defaultOptions.hideIcon).toBe(false);
      expect(defaultOptions.showIcon).toBe(false);
      expect(defaultOptions.disabled).toBe(false);
      expect(defaultOptions.placeholder).toBe('');
      expect(defaultOptions.showError).toBe(true);
    });
  });

  describe('getTheme', () => {
    it('should return "Dark" for "dark"', () => {
      expect(getTheme('dark', 'test.key')).toBe('Dark');
    });

    it('should return "Light" for "light"', () => {
      expect(getTheme('light', 'test.key')).toBe('Light');
    });

    it('should return "LightOutline" for "light-outline"', () => {
      expect(getTheme('light-outline', 'test.key')).toBe('LightOutline');
    });

    it('should return "Dark" for unknown value', () => {
      expect(getTheme('unknown', 'test.key')).toBe('Dark');
    });

    it('should return "Dark" for empty string', () => {
      expect(getTheme('', 'test.key')).toBe('Dark');
    });
  });

  describe('getClasses', () => {
    it('should extract classes from dict', () => {
      const dict = {
        classes: {
          base: 'CustomBase',
          complete: 'CustomComplete',
          empty: 'CustomEmpty',
          focus: 'CustomFocus',
          invalid: 'CustomInvalid',
          valid: 'CustomValid',
          webkitAutofill: 'CustomAutofill',
        },
      };
      const result = getClasses('classes', dict, mockLogger);
      expect(result.base).toBe('CustomBase');
      expect(result.complete).toBe('CustomComplete');
      expect(result.empty).toBe('CustomEmpty');
    });

    it('should return default classes when key not found', () => {
      const dict = {};
      const result = getClasses('classes', dict, mockLogger);
      expect(result).toEqual(defaultClasses);
    });

    it('should handle partial class definitions', () => {
      const dict = {
        classes: {
          base: 'MyBase',
        },
      };
      const result = getClasses('classes', dict, mockLogger);
      expect(result.base).toBe('MyBase');
      expect(result.complete).toBe('OrcaElement--complete');
    });
  });

  describe('getStyleObj', () => {
    it('should extract style object from dict', () => {
      const dict = {
        style: {
          backgroundColor: '#fff',
          color: '#000',
          fontSize: '16px',
        },
      };
      const result = getStyleObj(dict, 'style', mockLogger);
      expect(result.backgroundColor).toBe('#fff');
      expect(result.color).toBe('#000');
      expect(result.fontSize).toBe('16px');
    });

    it('should return default style class when key not found', () => {
      const dict = {};
      const result = getStyleObj(dict, 'style', mockLogger);
      expect(result).toEqual(defaultStyleClass);
    });

    it('should handle nested pseudo-selectors', () => {
      const dict = {
        style: {
          color: '#333',
          ':hover': {
            color: '#666',
          },
        },
      };
      const result = getStyleObj(dict, 'style', mockLogger);
      expect(result.color).toBe('#333');
      expect(result.hover?.color).toBe('#666');
    });
  });

  describe('getPaymentRequestButton', () => {
    it('should extract payment request button config from dict', () => {
      const dict = {
        paymentRequestButton: {
          type: 'buy',
          theme: 'light',
          height: '48px',
        },
      };
      const result = getPaymentRequestButton(dict, 'paymentRequestButton', mockLogger);
      expect(result.type_).toBe('buy');
      expect(result.theme).toBe('Light');
      expect(result.height).toBe('48px');
    });

    it('should return default values when key not found', () => {
      const dict = {};
      const result = getPaymentRequestButton(dict, 'paymentRequestButton', mockLogger);
      expect(result).toEqual(defaultPaymentRequestButton);
    });

    it('should convert theme to proper case', () => {
      const dict = {
        paymentRequestButton: {
          theme: 'dark',
        },
      };
      const result = getPaymentRequestButton(dict, 'paymentRequestButton', mockLogger);
      expect(result.theme).toBe('Dark');
    });
  });

  describe('getStyle', () => {
    it('should extract style from dict', () => {
      const dict = {
        style: {
          base: { color: '#000' },
          complete: { color: 'green' },
          empty: { color: 'gray' },
          invalid: { color: 'red' },
        },
      };
      const result = getStyle(dict, 'style', mockLogger);
      expect(result.base).toEqual({ color: '#000' });
      expect(result.complete).toEqual({ color: 'green' });
      expect(result.empty).toEqual({ color: 'gray' });
      expect(result.invalid).toEqual({ color: 'red' });
    });

    it('should return default style when key not found', () => {
      const dict = {};
      const result = getStyle(dict, 'style', mockLogger);
      expect(result).toEqual(defaultStyle);
    });
  });

  describe('itemToObjMapper', () => {
    it('should map dict to options object', () => {
      const dict = {
        classes: {
          base: 'TestBase',
        },
        style: {
          base: { color: '#333' },
        },
        value: 'test value',
        hidePostalCode: true,
        iconStyle: 'solid',
        hideIcon: true,
        showIcon: false,
        disabled: true,
        placeholder: 'Enter value',
        showError: false,
      };
      const result = itemToObjMapper(dict, mockLogger);
      expect(result.classes.base).toBe('TestBase');
      expect(result.value).toBe('test value');
      expect(result.hidePostalCode).toBe(true);
      expect(result.iconStyle).toBe('Solid');
      expect(result.hideIcon).toBe(true);
      expect(result.disabled).toBe(true);
      expect(result.placeholder).toBe('Enter value');
      expect(result.showError).toBe(false);
    });

    it('should use default values for missing fields', () => {
      const dict = {};
      const result = itemToObjMapper(dict, mockLogger);
      expect(result.classes).toEqual(defaultClasses);
      expect(result.value).toBe('');
      expect(result.hidePostalCode).toBe(false);
      expect(result.iconStyle).toBe('Default');
      expect(result.hideIcon).toBe(false);
      expect(result.showIcon).toBe(false);
      expect(result.disabled).toBe(false);
      expect(result.placeholder).toBe('');
      expect(result.showError).toBe(true);
    });

    it('should handle partial options', () => {
      const dict = {
        value: 'partial',
        disabled: true,
      };
      const result = itemToObjMapper(dict, mockLogger);
      expect(result.value).toBe('partial');
      expect(result.disabled).toBe(true);
      expect(result.hidePostalCode).toBe(false);
    });
  });
});
