import { mapLocalStringToTypeLocale } from '../LocaleStrings/LocaleStringHelper.bs.js';

describe('LocaleStringHelper', () => {
  describe('mapLocalStringToTypeLocale', () => {
    describe('exact matches', () => {
      it('should return EN for "en"', () => {
        expect(mapLocalStringToTypeLocale('en')).toBe('EN');
      });

      it('should return EN_GB for "en-gb"', () => {
        expect(mapLocalStringToTypeLocale('en-gb')).toBe('EN_GB');
      });

      it('should return ES for "es"', () => {
        expect(mapLocalStringToTypeLocale('es')).toBe('ES');
      });

      it('should return FR for "fr"', () => {
        expect(mapLocalStringToTypeLocale('fr')).toBe('FR');
      });

      it('should return FR_BE for "fr-be"', () => {
        expect(mapLocalStringToTypeLocale('fr-be')).toBe('FR_BE');
      });

      it('should return DE for "de"', () => {
        expect(mapLocalStringToTypeLocale('de')).toBe('DE');
      });

      it('should return IT for "it"', () => {
        expect(mapLocalStringToTypeLocale('it')).toBe('IT');
      });

      it('should return JA for "ja"', () => {
        expect(mapLocalStringToTypeLocale('ja')).toBe('JA');
      });

      it('should return NL for "nl"', () => {
        expect(mapLocalStringToTypeLocale('nl')).toBe('NL');
      });

      it('should return PL for "pl"', () => {
        expect(mapLocalStringToTypeLocale('pl')).toBe('PL');
      });

      it('should return PT for "pt"', () => {
        expect(mapLocalStringToTypeLocale('pt')).toBe('PT');
      });

      it('should return RU for "ru"', () => {
        expect(mapLocalStringToTypeLocale('ru')).toBe('RU');
      });

      it('should return SV for "sv"', () => {
        expect(mapLocalStringToTypeLocale('sv')).toBe('SV');
      });

      it('should return AR for "ar"', () => {
        expect(mapLocalStringToTypeLocale('ar')).toBe('AR');
      });

      it('should return HE for "he"', () => {
        expect(mapLocalStringToTypeLocale('he')).toBe('HE');
      });

      it('should return ZH for "zh"', () => {
        expect(mapLocalStringToTypeLocale('zh')).toBe('ZH');
      });

      it('should return ZH_HANT for "zh-hant"', () => {
        expect(mapLocalStringToTypeLocale('zh-hant')).toBe('ZH_HANT');
      });

      it('should return CA for "ca"', () => {
        expect(mapLocalStringToTypeLocale('ca')).toBe('CA');
      });
    });

    describe('case insensitivity', () => {
      it('should handle uppercase input "EN"', () => {
        expect(mapLocalStringToTypeLocale('EN')).toBe('EN');
      });

      it('should handle mixed case input "En"', () => {
        expect(mapLocalStringToTypeLocale('En')).toBe('EN');
      });

      it('should handle uppercase "EN-GB"', () => {
        expect(mapLocalStringToTypeLocale('EN-GB')).toBe('EN_GB');
      });

      it('should handle mixed case "Fr-Be"', () => {
        expect(mapLocalStringToTypeLocale('Fr-Be')).toBe('FR_BE');
      });
    });

    describe('fallback to base language', () => {
      it('should return ES for "es-MX" (fallback to base language)', () => {
        expect(mapLocalStringToTypeLocale('es-MX')).toBe('ES');
      });

      it('should return FR for "fr-CA" (fallback to base language)', () => {
        expect(mapLocalStringToTypeLocale('fr-CA')).toBe('FR');
      });

      it('should return DE for "de-AT" (fallback to base language)', () => {
        expect(mapLocalStringToTypeLocale('de-AT')).toBe('DE');
      });

      it('should return PT for "pt-BR" (fallback to base language)', () => {
        expect(mapLocalStringToTypeLocale('pt-BR')).toBe('PT');
      });

      it('should return ZH for "zh-CN" (fallback to base language)', () => {
        expect(mapLocalStringToTypeLocale('zh-CN')).toBe('ZH');
      });
    });

    describe('default fallback', () => {
      it('should return EN for unknown locale', () => {
        expect(mapLocalStringToTypeLocale('unknown')).toBe('EN');
      });

      it('should return EN for empty string', () => {
        expect(mapLocalStringToTypeLocale('')).toBe('EN');
      });

      it('should return EN for non-locale string', () => {
        expect(mapLocalStringToTypeLocale('xyz')).toBe('EN');
      });

      it('should return EN for locale-like unknown string', () => {
        expect(mapLocalStringToTypeLocale('xx-YY')).toBe('EN');
      });
    });
  });
});
