import {
  localeTypeToString,
  localeStringToType,
  localeStringToLocaleName,
  defaultLocale,
} from '../../shared-code/sdk-utils/types/LocaleDataType.bs.js';

describe('LocaleDataType', () => {
  describe('localeTypeToString', () => {
    it('should convert English locale type to string', () => {
      expect(localeTypeToString('En')).toBe('en');
    });

    it('should convert Hebrew locale type to string', () => {
      expect(localeTypeToString('He')).toBe('he');
    });

    it('should convert French locale type to string', () => {
      expect(localeTypeToString('Fr')).toBe('fr');
    });

    it('should convert English GB locale type to string', () => {
      expect(localeTypeToString('En_GB')).toBe('en-GB');
    });

    it('should convert Arabic locale type to string', () => {
      expect(localeTypeToString('Ar')).toBe('ar');
    });

    it('should convert Japanese locale type to string', () => {
      expect(localeTypeToString('Ja')).toBe('ja');
    });

    it('should convert German locale type to string', () => {
      expect(localeTypeToString('De')).toBe('de');
    });

    it('should convert French Belgium locale type to string', () => {
      expect(localeTypeToString('Fr_BE')).toBe('fr-BE');
    });

    it('should convert Spanish locale type to string', () => {
      expect(localeTypeToString('Es')).toBe('es');
    });

    it('should convert Catalan locale type to string', () => {
      expect(localeTypeToString('Ca')).toBe('ca');
    });

    it('should convert Portuguese locale type to string', () => {
      expect(localeTypeToString('Pt')).toBe('pt');
    });

    it('should convert Italian locale type to string', () => {
      expect(localeTypeToString('It')).toBe('it');
    });

    it('should convert Polish locale type to string', () => {
      expect(localeTypeToString('Pl')).toBe('pl');
    });

    it('should convert Dutch locale type to string', () => {
      expect(localeTypeToString('Nl')).toBe('nl');
    });

    it('should convert Dutch Belgium locale type to string', () => {
      expect(localeTypeToString('NI_BE')).toBe('nI-BE');
    });

    it('should convert Swedish locale type to string', () => {
      expect(localeTypeToString('Sv')).toBe('sv');
    });

    it('should convert Russian locale type to string', () => {
      expect(localeTypeToString('Ru')).toBe('ru');
    });

    it('should convert Lithuanian locale type to string', () => {
      expect(localeTypeToString('Lt')).toBe('lt');
    });

    it('should convert Czech locale type to string', () => {
      expect(localeTypeToString('Cs')).toBe('cs');
    });

    it('should convert Slovak locale type to string', () => {
      expect(localeTypeToString('Sk')).toBe('sk');
    });

    it('should convert Lesotho locale type to string', () => {
      expect(localeTypeToString('Ls')).toBe('ls');
    });

    it('should convert Welsh locale type to string', () => {
      expect(localeTypeToString('Cy')).toBe('cy');
    });

    it('should convert Greek locale type to string', () => {
      expect(localeTypeToString('El')).toBe('el');
    });

    it('should convert Estonian locale type to string', () => {
      expect(localeTypeToString('Et')).toBe('et');
    });

    it('should convert Finnish locale type to string', () => {
      expect(localeTypeToString('Fi')).toBe('fi');
    });

    it('should convert Norwegian Bokmal locale type to string', () => {
      expect(localeTypeToString('Nb')).toBe('nb');
    });

    it('should convert Bosnian locale type to string', () => {
      expect(localeTypeToString('Bs')).toBe('bs');
    });

    it('should convert Danish locale type to string', () => {
      expect(localeTypeToString('Da')).toBe('da');
    });

    it('should convert Malay locale type to string', () => {
      expect(localeTypeToString('Ms')).toBe('ms');
    });

    it('should convert Turkish Cyprus locale type to string', () => {
      expect(localeTypeToString('Tr_CY')).toBe('tr-CY');
    });

    it('should return "en" for undefined input', () => {
      expect(localeTypeToString(undefined)).toBe('en');
    });
  });

  describe('localeStringToType', () => {
    it('should convert "en" string to En type', () => {
      expect(localeStringToType('en')).toBe('En');
    });

    it('should convert "he" string to He type', () => {
      expect(localeStringToType('he')).toBe('He');
    });

    it('should convert "fr" string to Fr type', () => {
      expect(localeStringToType('fr')).toBe('Fr');
    });

    it('should convert "en-GB" string to En_GB type', () => {
      expect(localeStringToType('en-GB')).toBe('En_GB');
    });

    it('should convert "ar" string to Ar type', () => {
      expect(localeStringToType('ar')).toBe('Ar');
    });

    it('should convert "ja" string to Ja type', () => {
      expect(localeStringToType('ja')).toBe('Ja');
    });

    it('should convert "de" string to De type', () => {
      expect(localeStringToType('de')).toBe('De');
    });

    it('should convert "es" string to Es type', () => {
      expect(localeStringToType('es')).toBe('Es');
    });

    it('should convert "fr-BE" string to Fr_BE type', () => {
      expect(localeStringToType('fr-BE')).toBe('Fr_BE');
    });

    it('should convert "ca" string to Ca type', () => {
      expect(localeStringToType('ca')).toBe('Ca');
    });

    it('should convert "cs" string to Cs type', () => {
      expect(localeStringToType('cs')).toBe('Cs');
    });

    it('should convert "cy" string to Cy type', () => {
      expect(localeStringToType('cy')).toBe('Cy');
    });

    it('should convert "da" string to Da type', () => {
      expect(localeStringToType('da')).toBe('Da');
    });

    it('should convert "el" string to El type', () => {
      expect(localeStringToType('el')).toBe('El');
    });

    it('should convert "et" string to Et type', () => {
      expect(localeStringToType('et')).toBe('Et');
    });

    it('should convert "fi" string to Fi type', () => {
      expect(localeStringToType('fi')).toBe('Fi');
    });

    it('should convert "nI-BE" string to NI_BE type', () => {
      expect(localeStringToType('nI-BE')).toBe('NI_BE');
    });

    it('should convert "nb" string to Nb type', () => {
      expect(localeStringToType('nb')).toBe('Nb');
    });

    it('should convert "bs" string to Bs type', () => {
      expect(localeStringToType('bs')).toBe('Bs');
    });

    it('should convert "ms" string to Ms type', () => {
      expect(localeStringToType('ms')).toBe('Ms');
    });

    it('should convert "lt" string to Lt type', () => {
      expect(localeStringToType('lt')).toBe('Lt');
    });

    it('should convert "ls" string to Ls type', () => {
      expect(localeStringToType('ls')).toBe('Ls');
    });

    it('should convert "nl" string to Nl type', () => {
      expect(localeStringToType('nl')).toBe('Nl');
    });

    it('should convert "pl" string to Pl type', () => {
      expect(localeStringToType('pl')).toBe('Pl');
    });

    it('should convert "pt" string to Pt type', () => {
      expect(localeStringToType('pt')).toBe('Pt');
    });

    it('should convert "ru" string to Ru type', () => {
      expect(localeStringToType('ru')).toBe('Ru');
    });

    it('should convert "sk" string to Sk type', () => {
      expect(localeStringToType('sk')).toBe('Sk');
    });

    it('should convert "sv" string to Sv type', () => {
      expect(localeStringToType('sv')).toBe('Sv');
    });

    it('should convert "tr-CY" to Tr_CY type', () => {
      expect(localeStringToType('tr-CY')).toBe('Tr_CY');
    });

    it('should return "En" for unknown locale string', () => {
      expect(localeStringToType('unknown')).toBe('En');
    });

    it('should return "En" for empty string', () => {
      expect(localeStringToType('')).toBe('En');
    });
  });

  describe('localeStringToLocaleName', () => {
    it('should convert "DE" to German', () => {
      expect(localeStringToLocaleName('DE')).toBe('German');
    });

    it('should convert "DA" to Danish', () => {
      expect(localeStringToLocaleName('DA')).toBe('Danish');
    });

    it('should convert "DA_DK" to Danish', () => {
      expect(localeStringToLocaleName('DA_DK')).toBe('Danish');
    });

    it('should convert "DK" to Danish', () => {
      expect(localeStringToLocaleName('DK')).toBe('Danish');
    });

    it('should convert "EN" to English', () => {
      expect(localeStringToLocaleName('EN')).toBe('English');
    });

    it('should convert "ES" to Spanish', () => {
      expect(localeStringToLocaleName('ES')).toBe('Spanish');
    });

    it('should convert "FI" to Finnish', () => {
      expect(localeStringToLocaleName('FI')).toBe('Finnish');
    });

    it('should convert "FR" to French', () => {
      expect(localeStringToLocaleName('FR')).toBe('French');
    });

    it('should convert "EL" to Greek', () => {
      expect(localeStringToLocaleName('EL')).toBe('Greek');
    });

    it('should convert "EL_GR" to Greek', () => {
      expect(localeStringToLocaleName('EL_GR')).toBe('Greek');
    });

    it('should convert "GR" to Greek', () => {
      expect(localeStringToLocaleName('GR')).toBe('Greek');
    });

    it('should convert "HR" to Croatian', () => {
      expect(localeStringToLocaleName('HR')).toBe('Croatian');
    });

    it('should convert "IT" to Italian', () => {
      expect(localeStringToLocaleName('IT')).toBe('Italian');
    });

    it('should convert "JA" to Japanese', () => {
      expect(localeStringToLocaleName('JA')).toBe('Japanese');
    });

    it('should convert "JA_JP" to Japanese', () => {
      expect(localeStringToLocaleName('JA_JP')).toBe('Japanese');
    });

    it('should convert "JP" to Japanese', () => {
      expect(localeStringToLocaleName('JP')).toBe('Japanese');
    });

    it('should convert "ES_LA" to Spanish (Latin America)', () => {
      expect(localeStringToLocaleName('ES_LA')).toBe('Spanish (Latin America)');
    });

    it('should convert "LA" to Spanish (Latin America)', () => {
      expect(localeStringToLocaleName('LA')).toBe('Spanish (Latin America)');
    });

    it('should convert "NL" to Dutch', () => {
      expect(localeStringToLocaleName('NL')).toBe('Dutch');
    });

    it('should convert "NO" to Norwegian', () => {
      expect(localeStringToLocaleName('NO')).toBe('Norwegian');
    });

    it('should convert "PL" to Polish', () => {
      expect(localeStringToLocaleName('PL')).toBe('Polish');
    });

    it('should convert "PT" to Portuguese', () => {
      expect(localeStringToLocaleName('PT')).toBe('Portuguese');
    });

    it('should convert "BR" to Portuguese (Brazil)', () => {
      expect(localeStringToLocaleName('BR')).toBe('Portuguese (Brazil)');
    });

    it('should convert "PT_BR" to Portuguese (Brazil)', () => {
      expect(localeStringToLocaleName('PT_BR')).toBe('Portuguese (Brazil)');
    });

    it('should convert "RU" to Russian', () => {
      expect(localeStringToLocaleName('RU')).toBe('Russian');
    });

    it('should convert "SE" to Swedish', () => {
      expect(localeStringToLocaleName('SE')).toBe('Swedish');
    });

    it('should convert "SV" to Swedish', () => {
      expect(localeStringToLocaleName('SV')).toBe('Swedish');
    });

    it('should convert "SV_SE" to Swedish', () => {
      expect(localeStringToLocaleName('SV_SE')).toBe('Swedish');
    });

    it('should convert "CN" to Chinese (Simplified)', () => {
      expect(localeStringToLocaleName('CN')).toBe('Chinese (Simplified)');
    });

    it('should convert "ZH_CN" to Chinese (Simplified)', () => {
      expect(localeStringToLocaleName('ZH_CN')).toBe('Chinese (Simplified)');
    });

    it('should convert "TW" to Chinese (Traditional)', () => {
      expect(localeStringToLocaleName('TW')).toBe('Chinese (Traditional)');
    });

    it('should convert "ZH" to Chinese (Traditional)', () => {
      expect(localeStringToLocaleName('ZH')).toBe('Chinese (Traditional)');
    });

    it('should convert "ZH_TW" to Chinese (Traditional)', () => {
      expect(localeStringToLocaleName('ZH_TW')).toBe('Chinese (Traditional)');
    });

    it('should return input string for unknown locale', () => {
      expect(localeStringToLocaleName('UNKNOWN')).toBe('UNKNOWN');
    });

    it('should return input string for empty string', () => {
      expect(localeStringToLocaleName('')).toBe('');
    });
  });

  describe('defaultLocale', () => {
    it('should have locale set to "en"', () => {
      expect(defaultLocale.locale).toBe('en');
    });

    it('should have localeDirection set to "ltr"', () => {
      expect(defaultLocale.localeDirection).toBe('ltr');
    });

    it('should have cardNumberLabel', () => {
      expect(defaultLocale.cardNumberLabel).toBe('Card Number');
    });

    it('should have emailLabel', () => {
      expect(defaultLocale.emailLabel).toBe('Email');
    });

    it('should have payNowButton', () => {
      expect(defaultLocale.payNowButton).toBe('Pay Now');
    });

    it('should have billingDetails', () => {
      expect(defaultLocale.billingDetails).toBe('Billing Details');
    });

    it('should have invalid email error text', () => {
      expect(defaultLocale.emailInvalidText).toBe('Invalid email address');
    });

    it('should have card expiry placeholder', () => {
      expect(defaultLocale.expiryPlaceholder).toBe('MM / YY');
    });

    it('should have cvcTextLabel', () => {
      expect(defaultLocale.cvcTextLabel).toBe('CVC');
    });

    it('should have poweredBy text', () => {
      expect(defaultLocale.poweredBy).toBe('Powered By Hyperswitch');
    });
  });
});
