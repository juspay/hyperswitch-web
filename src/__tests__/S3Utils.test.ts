import {
  decodeCountryArray,
  decodeJsonTocountryStateData,
  getNormalizedLocale,
  fetchCountryStateFromS3,
  getCountryStateData,
  initializeCountryData,
} from '../Utilities/S3Utils.bs.js';

const mockFetchApi = jest.fn();
const mockGetStrArray = jest.fn((obj: any, key: string) => obj?.[key] || []);
const mockGetString = jest.fn((obj: any, key: string, def: string) => obj?.[key] ?? def);
const mockGetArray = jest.fn((obj: any, key: string) => obj?.[key] || []);

jest.mock('../Utilities/Utils.bs.js', () => ({
  getStrArray: (obj: any, key: string) => mockGetStrArray(obj, key),
  getString: (obj: any, key: string, def: string) => mockGetString(obj, key, def),
  getArray: (obj: any, key: string) => mockGetArray(obj, key),
  getJsonFromDict: jest.fn((obj: any, key: string, def: any) => obj?.[key] ?? def),
  fetchApi: (url: string, body: any, headers: any, method: string, ...rest: any[]) => mockFetchApi(url, body, headers, method, ...rest),
}));

jest.mock('../Country.bs.js', () => ({
  country: [
    { timeZones: [], countryName: 'Default Country', isoAlpha2: 'XX' },
  ],
  defaultTimeZone: {
    timeZones: [],
    countryName: '-',
    isoAlpha2: '',
    isoAlpha3: '',
  },
}));

jest.mock('../CountryStateDataRefs.bs.js', () => ({
  countryDataRef: { contents: [] },
  stateDataRef: { contents: null },
}));

jest.mock('../hyper-log-catcher/HyperLogger.bs.js', () => ({
  make: jest.fn(() => ({
    setLogError: jest.fn(),
  })),
}));

const originalDateNow = Date.now;

describe('S3Utils', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    Date.now = () => 1234567890000;
  });

  afterEach(() => {
    Date.now = originalDateNow;
  });
  describe('decodeCountryArray', () => {
    describe('happy path', () => {
      it('should decode array of valid country objects', () => {
        const input = [
          { value: 'United States', isoAlpha2: 'US', timeZones: ['America/New_York'] },
          { value: 'Canada', isoAlpha2: 'CA', timeZones: ['America/Toronto'] },
        ];
        const result = decodeCountryArray(input);
        expect(result).toHaveLength(2);
        expect(result[0]).toEqual({
          countryName: 'United States',
          isoAlpha2: 'US',
          timeZones: ['America/New_York'],
        });
        expect(result[1]).toEqual({
          countryName: 'Canada',
          isoAlpha2: 'CA',
          timeZones: ['America/Toronto'],
        });
      });

      it('should handle country with multiple time zones', () => {
        const input = [
          { value: 'Australia', isoAlpha2: 'AU', timeZones: ['Australia/Sydney', 'Australia/Perth'] },
        ];
        const result = decodeCountryArray(input);
        expect(result[0].timeZones).toEqual(['Australia/Sydney', 'Australia/Perth']);
      });

      it('should handle empty time zones array', () => {
        const input = [
          { value: 'Test Country', isoAlpha2: 'TC', timeZones: [] },
        ];
        const result = decodeCountryArray(input);
        expect(result[0].timeZones).toEqual([]);
      });
    });

    describe('edge cases', () => {
      it('should return defaultTimeZone for invalid JSON object', () => {
        const input = ['not an object'];
        const result = decodeCountryArray(input);
        expect(result[0]).toEqual({
          timeZones: [],
          countryName: '-',
          isoAlpha2: '',
          isoAlpha3: '',
        });
      });

      it('should handle empty array', () => {
        const result = decodeCountryArray([]);
        expect(result).toEqual([]);
      });

      it('should handle missing optional fields with defaults', () => {
        const input = [{}];
        const result = decodeCountryArray(input);
        expect(result[0]).toEqual({
          timeZones: [],
          countryName: '',
          isoAlpha2: '',
        });
      });
    });

    describe('error/boundary', () => {
      it('should handle null values in array', () => {
        const input = [null, { value: 'Valid', isoAlpha2: 'VV', timeZones: [] }];
        const result = decodeCountryArray(input);
        expect(result).toHaveLength(2);
        expect(result[0]).toEqual({
          timeZones: [],
          countryName: '-',
          isoAlpha2: '',
          isoAlpha3: '',
        });
        expect(result[1].countryName).toBe('Valid');
      });

      it('should handle mixed valid and invalid items', () => {
        const input = [
          { value: 'United States', isoAlpha2: 'US', timeZones: ['America/New_York'] },
          'invalid',
          { value: 'Canada', isoAlpha2: 'CA', timeZones: ['America/Toronto'] },
        ];
        const result = decodeCountryArray(input);
        expect(result).toHaveLength(3);
        expect(result[0].countryName).toBe('United States');
        expect(result[1].countryName).toBe('-');
        expect(result[2].countryName).toBe('Canada');
      });
    });
  });

  describe('decodeJsonTocountryStateData', () => {
    describe('happy path', () => {
      it('should decode valid JSON with country and states', () => {
        const input = {
          country: [
            { value: 'United States', isoAlpha2: 'US', timeZones: ['America/New_York'] },
          ],
          states: { US: ['California', 'New York'] },
        };
        const result = decodeJsonTocountryStateData(input);
        expect(result).toBeDefined();
        expect(result!.countries).toHaveLength(1);
        expect(result!.countries[0].countryName).toBe('United States');
        expect(result!.states).toEqual({ US: ['California', 'New York'] });
      });

      it('should handle null states', () => {
        const input = {
          country: [
            { value: 'United States', isoAlpha2: 'US', timeZones: [] },
          ],
          states: null,
        };
        const result = decodeJsonTocountryStateData(input);
        expect(result!.states).toBeNull();
      });
    });

    describe('edge cases', () => {
      it('should return undefined for invalid JSON', () => {
        const result = decodeJsonTocountryStateData('not an object');
        expect(result).toBeUndefined();
      });

      it('should return undefined for null input', () => {
        const result = decodeJsonTocountryStateData(null);
        expect(result).toBeUndefined();
      });

      it('should handle empty country array', () => {
        const input = { country: [], states: {} };
        const result = decodeJsonTocountryStateData(input);
        expect(result!.countries).toEqual([]);
      });

      it('should handle missing states field', () => {
        const input = { country: [] };
        const result = decodeJsonTocountryStateData(input);
        expect(result!.states).toBeNull();
      });
    });

    describe('error/boundary', () => {
      it('should handle missing country field', () => {
        const input = { states: { US: ['CA'] } };
        const result = decodeJsonTocountryStateData(input);
        expect(result!.countries).toEqual([]);
      });

      it('should handle array input', () => {
        const result = decodeJsonTocountryStateData([]);
        expect(result).toBeUndefined();
      });

      it('should handle primitive input', () => {
        const result = decodeJsonTocountryStateData(42);
        expect(result).toBeUndefined();
      });
    });
  });

  describe('getNormalizedLocale', () => {
    const originalNavigator = globalThis.navigator;

    beforeEach(() => {
      Object.defineProperty(globalThis, 'navigator', {
        value: { language: 'en-US' },
        writable: true,
        configurable: true,
      });
    });

    afterEach(() => {
      Object.defineProperty(globalThis, 'navigator', {
        value: originalNavigator,
        writable: true,
        configurable: true,
      });
    });

    describe('happy path', () => {
      it('returns "en" for empty string', () => {
        expect(getNormalizedLocale('')).toBe('en');
      });

      it('returns browser locale for "auto"', () => {
        expect(getNormalizedLocale('auto')).toBe('en-US');
      });

      it('returns the locale as-is for any other value', () => {
        expect(getNormalizedLocale('fr')).toBe('fr');
        expect(getNormalizedLocale('de-DE')).toBe('de-DE');
        expect(getNormalizedLocale('ja-JP')).toBe('ja-JP');
      });
    });

    describe('edge cases', () => {
      it('handles navigator.language being undefined', () => {
        Object.defineProperty(globalThis, 'navigator', {
          value: {},
          writable: true,
          configurable: true,
        });
        expect(getNormalizedLocale('auto')).toBeUndefined();
      });

      it('handles different browser locales', () => {
        Object.defineProperty(globalThis, 'navigator', {
          value: { language: 'fr-FR' },
          writable: true,
          configurable: true,
        });
        expect(getNormalizedLocale('auto')).toBe('fr-FR');
      });
    });

    describe('error/boundary', () => {
      it('handles navigator being undefined', () => {
      Object.defineProperty(globalThis, 'navigator', {
        value: undefined,
        writable: true,
        configurable: true,
      });
      expect(() => getNormalizedLocale('auto')).toThrow();
    });
  });

  describe('fetchCountryStateFromS3', () => {
    describe('happy path', () => {
      it('should fetch and return country state data', async () => {
        const mockResponse = {
          country: [
            { value: 'United States', isoAlpha2: 'US', timeZones: ['America/New_York'] },
          ],
          states: { US: ['California', 'New York'] },
        };
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve(mockResponse),
        });
        mockGetStrArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
        mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
        mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);

        const result = await fetchCountryStateFromS3('https://test.com/data.json');

        expect(mockFetchApi).toHaveBeenCalledWith(
          'https://test.com/data.json',
          undefined,
          { 'Accept-Encoding': 'br, gzip' },
          'GET',
          undefined,
          undefined,
          undefined
        );
        expect(result).toBeDefined();
        expect(result!.countries).toHaveLength(1);
      });

      it('should include Accept-Encoding header', async () => {
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve({ country: [], states: {} }),
        });
        mockGetArray.mockReturnValue([]);

        await fetchCountryStateFromS3('https://test.com/data.json');

        expect(mockFetchApi).toHaveBeenCalledWith(
          expect.any(String),
          undefined,
          { 'Accept-Encoding': 'br, gzip' },
          'GET',
          undefined,
          undefined,
          undefined
        );
      });
    });

    describe('edge cases', () => {
      it('should reject for invalid JSON response', async () => {
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve('not an object'),
        });

        await expect(fetchCountryStateFromS3('https://test.com/invalid.json')).rejects.toBeDefined();
      });

      it('should reject for null response', async () => {
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve(null),
        });

        await expect(fetchCountryStateFromS3('https://test.com/null.json')).rejects.toBeDefined();
      });
    });

    describe('error/boundary', () => {
      it('should reject on fetch error', async () => {
        mockFetchApi.mockRejectedValue(new Error('Network error'));

        await expect(fetchCountryStateFromS3('https://test.com/error.json')).rejects.toBeDefined();
      });

      it('should reject on JSON parse error', async () => {
        mockFetchApi.mockResolvedValue({
          json: () => Promise.reject(new Error('JSON parse error')),
        });

        await expect(fetchCountryStateFromS3('https://test.com/invalid.json')).rejects.toBeDefined();
      });
    });
  });

  describe('getCountryStateData', () => {
    const originalWindow = globalThis.window;

    beforeEach(() => {
      jest.clearAllMocks();
      mockFetchApi.mockReset();
    });

    afterEach(() => {
      if (originalWindow) {
        Object.defineProperty(globalThis, 'window', {
          value: originalWindow,
          writable: true,
          configurable: true,
        });
      }
    });

    describe('happy path', () => {
      it('should fetch country state data for given locale', async () => {
        const mockResponse = {
          country: [
            { value: 'France', isoAlpha2: 'FR', timeZones: ['Europe/Paris'] },
          ],
          states: { FR: ['Paris', 'Lyon'] },
        };
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve(mockResponse),
        });
        mockGetStrArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
        mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
        mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);

        const result = await getCountryStateData('fr');

        expect(result).toBeDefined();
        expect(result!.countries).toHaveLength(1);
      });

      it('should use default locale when not provided', async () => {
        const mockResponse = { country: [], states: {} };
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve(mockResponse),
        });
        mockGetArray.mockReturnValue([]);

        await getCountryStateData();

        expect(mockFetchApi).toHaveBeenCalled();
      });
    });

    describe('edge cases', () => {
      it('should handle "auto" locale by using navigator language', async () => {
        Object.defineProperty(globalThis, 'navigator', {
          value: { language: 'en-GB' },
          writable: true,
          configurable: true,
        });

        const mockResponse = { country: [], states: {} };
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve(mockResponse),
        });
        mockGetArray.mockReturnValue([]);

        await getCountryStateData('auto');

        expect(mockFetchApi).toHaveBeenCalledWith(
          expect.stringContaining('en-GB'),
          undefined,
          expect.any(Object),
          'GET',
          undefined,
          undefined,
          undefined
        );
      });

      it('should fallback to "en" locale on first fetch failure', async () => {
        mockFetchApi
          .mockRejectedValueOnce(new Error('First fetch failed'))
          .mockResolvedValueOnce({
            json: () => Promise.resolve({
              country: [{ value: 'United States', isoAlpha2: 'US', timeZones: [] }],
              states: {},
            }),
          });
        mockGetStrArray.mockReturnValue([]);
        mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
        mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);

        const result = await getCountryStateData('fr');

        expect(mockFetchApi).toHaveBeenCalledTimes(2);
        expect(result).toBeDefined();
      });
    });

    describe('error/boundary', () => {
      it('should return fallback data when all fetches fail', async () => {
        mockFetchApi.mockRejectedValue(new Error('All fetches failed'));

        const result = await getCountryStateData('en');

        expect(result).toBeDefined();
        expect(result!.countries).toBeDefined();
        expect(result!.states).toBeDefined();
      });

      it('should return fallback data without states when import fails', async () => {
        mockFetchApi.mockRejectedValue(new Error('Fetch failed'));

        const result = await getCountryStateData('en');

        expect(result).toBeDefined();
        expect(result!.countries).toBeDefined();
      });
    });
  });

  describe('initializeCountryData', () => {
    describe('happy path', () => {
      it('should initialize country and state data refs', async () => {
        const mockResponse = {
          country: [
            { value: 'Germany', isoAlpha2: 'DE', timeZones: ['Europe/Berlin'] },
          ],
          states: { DE: ['Bavaria', 'Berlin'] },
        };
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve(mockResponse),
        });
        mockGetStrArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);
        mockGetString.mockImplementation((obj: any, key: string, def: string) => obj?.[key] ?? def);
        mockGetArray.mockImplementation((obj: any, key: string) => obj?.[key] || []);

        const result = await initializeCountryData('de');

        expect(result).toBeDefined();
        expect(result!.countries).toHaveLength(1);
        expect(result!.states).toEqual({ DE: ['Bavaria', 'Berlin'] });
      });

      it('should use default locale when not provided', async () => {
        const mockResponse = { country: [], states: {} };
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve(mockResponse),
        });
        mockGetArray.mockReturnValue([]);

        await initializeCountryData();

        expect(mockFetchApi).toHaveBeenCalled();
      });
    });

    describe('edge cases', () => {
      it('should handle locale with country code', async () => {
        const mockResponse = { country: [], states: {} };
        mockFetchApi.mockResolvedValue({
          json: () => Promise.resolve(mockResponse),
        });
        mockGetArray.mockReturnValue([]);

        await initializeCountryData('en-US');

        expect(mockFetchApi).toHaveBeenCalledWith(
          expect.stringContaining('en-US'),
          undefined,
          expect.any(Object),
          'GET',
          undefined,
          undefined,
          undefined
        );
      });
    });

    describe('error/boundary', () => {
      it('should return fallback data on fetch failure', async () => {
        mockFetchApi.mockRejectedValue(new Error('Fetch failed'));

        const result = await initializeCountryData('en');

        expect(result).toBeDefined();
        expect(result!.countries).toBeDefined();
      });

      it('should return fallback data with null states on complete failure', async () => {
        mockFetchApi.mockRejectedValue(new Error('Fetch failed'));

        const result = await initializeCountryData('en');

        expect(result).toBeDefined();
        expect(result!.states).toBeDefined();
      });
    });
  });
});
});
