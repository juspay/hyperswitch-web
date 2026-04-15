import {
  defaultEpsBank,
  defaultIdealBank,
  defaultBank,
  polandBanks,
  czechBanks,
  p24Banks,
  idealBanks,
  epsBanks,
  slovakiaBanks,
  fpxBanks,
  thailandBanks,
  getBanks,
} from '../../src/Bank.bs.js';

describe('Bank', () => {
  describe('constants', () => {
    describe('defaultEpsBank', () => {
      it('should have correct display name', () => {
        expect(defaultEpsBank.displayName).toBe('Ärzte- und Apothekerbank');
      });

      it('should have correct value', () => {
        expect(defaultEpsBank.value).toBe('arzte_und_apotheker_bank');
      });
    });

    describe('defaultIdealBank', () => {
      it('should have correct display name', () => {
        expect(defaultIdealBank.displayName).toBe('ABN AMRO');
      });

      it('should have correct value', () => {
        expect(defaultIdealBank.value).toBe('abn_amro');
      });
    });

    describe('defaultBank', () => {
      it('should have empty display name', () => {
        expect(defaultBank.displayName).toBe('');
      });

      it('should have empty value', () => {
        expect(defaultBank.value).toBe('');
      });
    });
  });

  describe('bank arrays', () => {
    describe('polandBanks', () => {
      it('should have correct length', () => {
        expect(polandBanks.length).toBe(19);
      });

      it('should contain Alior Bank', () => {
        expect(polandBanks.find(b => b.displayName === 'Alior Bank')).toBeDefined();
      });

      it('should have correct structure', () => {
        expect(polandBanks[0]).toHaveProperty('displayName');
        expect(polandBanks[0]).toHaveProperty('value');
      });
    });

    describe('czechBanks', () => {
      it('should have correct length', () => {
        expect(czechBanks.length).toBe(3);
      });

      it('should contain Česká spořitelna', () => {
        expect(czechBanks.find(b => b.displayName === 'Česká spořitelna')).toBeDefined();
      });
    });

    describe('p24Banks', () => {
      it('should have correct length', () => {
        expect(p24Banks.length).toBe(22);
      });

      it('should contain BLIK', () => {
        expect(p24Banks.find(b => b.displayName === 'BLIK')).toBeDefined();
      });
    });

    describe('idealBanks', () => {
      it('should have correct length', () => {
        expect(idealBanks.length).toBe(16);
      });

      it('should contain ABN AMRO', () => {
        expect(idealBanks.find(b => b.displayName === 'ABN AMRO')).toBeDefined();
      });
    });

    describe('epsBanks', () => {
      it('should have correct length', () => {
        expect(epsBanks.length).toBe(31);
      });

      it('should contain Bank Austria', () => {
        expect(epsBanks.find(b => b.displayName === 'Bank Austria')).toBeDefined();
      });
    });

    describe('slovakiaBanks', () => {
      it('should have correct length', () => {
        expect(slovakiaBanks.length).toBe(5);
      });

      it('should contain Tatra Pay', () => {
        expect(slovakiaBanks.find(b => b.displayName === 'Tatra Pay')).toBeDefined();
      });
    });

    describe('fpxBanks', () => {
      it('should have correct length', () => {
        expect(fpxBanks.length).toBe(20);
      });

      it('should contain Maybank', () => {
        expect(fpxBanks.find(b => b.displayName === 'Maybank')).toBeDefined();
      });
    });

    describe('thailandBanks', () => {
      it('should have correct length', () => {
        expect(thailandBanks.length).toBe(5);
      });

      it('should contain Bangkok Bank', () => {
        expect(thailandBanks.find(b => b.displayName === 'Bangkok Bank')).toBeDefined();
      });
    });
  });

  describe('getBanks', () => {
    describe('happy path', () => {
      it('should return epsBanks for "eps"', () => {
        expect(getBanks('eps')).toBe(epsBanks);
      });

      it('should return idealBanks for "ideal"', () => {
        expect(getBanks('ideal')).toBe(idealBanks);
      });

      it('should return czechBanks for "online_banking_czech_republic"', () => {
        expect(getBanks('online_banking_czech_republic')).toBe(czechBanks);
      });

      it('should return fpxBanks for "online_banking_fpx"', () => {
        expect(getBanks('online_banking_fpx')).toBe(fpxBanks);
      });

      it('should return polandBanks for "online_banking_poland"', () => {
        expect(getBanks('online_banking_poland')).toBe(polandBanks);
      });

      it('should return slovakiaBanks for "online_banking_slovakia"', () => {
        expect(getBanks('online_banking_slovakia')).toBe(slovakiaBanks);
      });

      it('should return thailandBanks for "online_banking_thailand"', () => {
        expect(getBanks('online_banking_thailand')).toBe(thailandBanks);
      });

      it('should return p24Banks for "przelewy24"', () => {
        expect(getBanks('przelewy24')).toBe(p24Banks);
      });
    });

    describe('edge cases', () => {
      it('should return empty array for unknown payment method', () => {
        expect(getBanks('unknown')).toEqual([]);
      });

      it('should return empty array for empty string', () => {
        expect(getBanks('')).toEqual([]);
      });
    });

    describe('error/boundary', () => {
      it('should return empty array for null-like values', () => {
        expect(getBanks('random_string')).toEqual([]);
      });

      it('should be case sensitive', () => {
        expect(getBanks('EPS')).toEqual([]);
        expect(getBanks('IDEAL')).toEqual([]);
      });
    });
  });
});
