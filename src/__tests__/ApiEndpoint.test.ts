import { switchToInteg, isLocal, sdkDomainUrl } from '../Utilities/ApiEndpoint.bs.js';

describe('ApiEndpoint', () => {
  describe('switchToInteg', () => {
    it('should be a boolean', () => {
      expect(typeof switchToInteg).toBe('boolean');
    });

    it('should be false by default', () => {
      expect(switchToInteg).toBe(false);
    });
  });

  describe('isLocal', () => {
    it('should be a boolean', () => {
      expect(typeof isLocal).toBe('boolean');
    });

    it('should be false by default', () => {
      expect(isLocal).toBe(false);
    });
  });

  describe('sdkDomainUrl', () => {
    it('should be a string', () => {
      expect(typeof sdkDomainUrl).toBe('string');
    });

    it('should be a valid URL', () => {
      expect(sdkDomainUrl.length).toBeGreaterThan(0);
    });
  });
});
