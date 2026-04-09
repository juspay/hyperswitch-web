import * as BrowserSpec from '../BrowserSpec.bs.js';

describe('BrowserSpec', () => {
  describe('checkIsSafari', () => {
    const originalNavigator = navigator;

    beforeEach(() => {
      jest.clearAllMocks();
    });

    afterEach(() => {
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        configurable: true,
        writable: true,
      });
    });

    it('returns true when Safari is present but Chrome is not', () => {
      Object.defineProperty(globalThis, 'navigator', {
        value: { userAgent: 'Mozilla/5.0 Safari/605.1.15' },
        configurable: true,
        writable: true,
      });

      expect(BrowserSpec.checkIsSafari()).toBe(true);
    });

    it('returns false when Chrome is present even if Safari is also present', () => {
      Object.defineProperty(globalThis, 'navigator', {
        value: { userAgent: 'Mozilla/5.0 Chrome/91.0 Safari/537.36' },
        configurable: true,
        writable: true,
      });

      expect(BrowserSpec.checkIsSafari()).toBe(false);
    });

    it('returns false when neither Safari nor Chrome is present', () => {
      Object.defineProperty(globalThis, 'navigator', {
        value: { userAgent: 'Mozilla/5.0 Firefox/89.0' },
        configurable: true,
        writable: true,
      });

      expect(BrowserSpec.checkIsSafari()).toBe(false);
    });

    it('returns false for empty user agent', () => {
      Object.defineProperty(globalThis, 'navigator', {
        value: { userAgent: '' },
        configurable: true,
        writable: true,
      });

      expect(BrowserSpec.checkIsSafari()).toBe(false);
    });

    it('handles Chrome-only user agent', () => {
      Object.defineProperty(globalThis, 'navigator', {
        value: { userAgent: 'Mozilla/5.0 Chrome/91.0.4472.124' },
        configurable: true,
        writable: true,
      });

      expect(BrowserSpec.checkIsSafari()).toBe(false);
    });
  });

  describe('date', () => {
    it('is a Date object', () => {
      expect(BrowserSpec.date).toBeInstanceOf(Date);
    });

    it('has getTimezoneOffset method', () => {
      expect(typeof BrowserSpec.date.getTimezoneOffset).toBe('function');
    });

    it('returns a number from getTimezoneOffset', () => {
      const offset = BrowserSpec.date.getTimezoneOffset();
      expect(typeof offset).toBe('number');
    });
  });

  describe('broswerInfo', () => {
    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('returns an array with browser_info key', () => {
      const result = BrowserSpec.broswerInfo();

      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(1);
      expect(result[0][0]).toBe('browser_info');
    });

    it('includes user_agent in browser info', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(browserInfo).toHaveProperty('user_agent');
    });

    it('includes accept_header in browser info', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(browserInfo.accept_header).toContain('text/html');
    });

    it('includes language from navigator', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(typeof browserInfo.language).toBe('string');
    });

    it('includes color_depth from screen', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(typeof browserInfo.color_depth).toBe('number');
    });

    it('includes screen dimensions', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(typeof browserInfo.screen_height).toBe('number');
      expect(typeof browserInfo.screen_width).toBe('number');
    });

    it('includes java_enabled as true', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(browserInfo.java_enabled).toBe(true);
    });

    it('includes java_script_enabled as true', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(browserInfo.java_script_enabled).toBe(true);
    });

    it('includes time_zone offset', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(typeof browserInfo.time_zone).toBe('number');
    });

    it('includes device_model', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(browserInfo).toHaveProperty('device_model');
    });

    it('includes os_type', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(browserInfo).toHaveProperty('os_type');
    });

    it('includes os_version', () => {
      const result = BrowserSpec.broswerInfo();
      const browserInfo = result[0][1] as Record<string, unknown>;

      expect(browserInfo).toHaveProperty('os_version');
    });
  });
});
