import { extractVaultMetadata } from '../Utilities/HyperVaultHelpers.bs.js';

describe('HyperVaultHelpers', () => {
  describe('extractVaultMetadata', () => {
    it('should extract all vault metadata fields from dict', () => {
      const metadataDict = {
        pmSessionId: 'session-123',
        pmClientSecret: 'secret-abc',
        vaultPublishableKey: 'pk_test_123',
        vaultProfileId: 'profile-456',
        endpoint: 'https://api.example.com',
        customPodUri: 'https://custom.pod.com',
        config: { timeout: 30000 },
      };

      const result = extractVaultMetadata(metadataDict);

      expect(result.pmSessionId).toBe('session-123');
      expect(result.pmClientSecret).toBe('secret-abc');
      expect(result.vaultPublishableKey).toBe('pk_test_123');
      expect(result.vaultProfileId).toBe('profile-456');
      expect(result.endpoint).toBe('https://api.example.com');
      expect(result.customPodUri).toBe('https://custom.pod.com');
      expect(result.config).toEqual({ timeout: 30000 });
    });

    it('should return empty strings for missing fields', () => {
      const metadataDict = {
        config: {},
      };

      const result = extractVaultMetadata(metadataDict);

      expect(result.pmSessionId).toBe('');
      expect(result.pmClientSecret).toBe('');
      expect(result.vaultPublishableKey).toBe('');
      expect(result.vaultProfileId).toBe('');
      expect(result.endpoint).toBe('');
      expect(result.customPodUri).toBe('');
    });

    it('should handle empty dict', () => {
      const metadataDict = {};

      const result = extractVaultMetadata(metadataDict);

      expect(result.pmSessionId).toBe('');
      expect(result.config).toEqual({});
    });

    it('should handle partial metadata', () => {
      const metadataDict = {
        pmSessionId: 'session-123',
        vaultPublishableKey: 'pk_test_123',
      };

      const result = extractVaultMetadata(metadataDict);

      expect(result.pmSessionId).toBe('session-123');
      expect(result.vaultPublishableKey).toBe('pk_test_123');
      expect(result.pmClientSecret).toBe('');
      expect(result.vaultProfileId).toBe('');
    });

    it('should preserve config object', () => {
      const configObj = {
        timeout: 30000,
        retries: 3,
        headers: { 'X-Custom': 'value' },
      };
      const metadataDict = {
        config: configObj,
      };

      const result = extractVaultMetadata(metadataDict);

      expect(result.config).toEqual(configObj);
    });
  });
});
