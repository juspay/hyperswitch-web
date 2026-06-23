import {
  getVaultModeFromName,
  getVaultNameFromMode,
  getVaultName,
  getVGSVaultDetails,
  getHyperswitchVaultDetails,
} from '../Utilities/VaultHelpers.bs.js';

describe('VaultHelpers', () => {
  describe('getVaultModeFromName', () => {
    it('should return Hyperswitch for hyperswitch_vault', () => {
      expect(getVaultModeFromName('hyperswitch_vault')).toBe('Hyperswitch');
    });

    it('should return VeryGoodSecurity for vgs', () => {
      expect(getVaultModeFromName('vgs')).toBe('VeryGoodSecurity');
    });

    it('should return None for unknown vault name', () => {
      expect(getVaultModeFromName('unknown_vault')).toBe('None');
    });

    it('should return None for empty string', () => {
      expect(getVaultModeFromName('')).toBe('None');
    });

    it('should be case sensitive', () => {
      expect(getVaultModeFromName('VGS')).toBe('None');
      expect(getVaultModeFromName('HYPERSWITCH_VAULT')).toBe('None');
    });
  });

  describe('getVaultNameFromMode', () => {
    it('should return hyperswitch_vault for Hyperswitch mode', () => {
      expect(getVaultNameFromMode('Hyperswitch')).toBe('hyperswitch_vault');
    });

    it('should return vgs for VeryGoodSecurity mode', () => {
      expect(getVaultNameFromMode('VeryGoodSecurity')).toBe('vgs');
    });

    it('should return empty string for None mode', () => {
      expect(getVaultNameFromMode('None')).toBe('');
    });

    it('should be case sensitive', () => {
      expect(getVaultNameFromMode('hyperswitch')).toBe(undefined);
      expect(getVaultNameFromMode('verygoodsecurity')).toBe(undefined);
    });
  });

  describe('getVaultName', () => {
    it('should extract vault name from Loaded session object', () => {
      const sessionObj = {
        TAG: 'Loaded',
        _0: {
          vault_details: {
            hyperswitch_vault: {
              publishable_key: 'pk_test_123',
            },
          },
        },
      };
      expect(getVaultName(sessionObj)).toBe('hyperswitch_vault');
    });

    it('should return empty string for non-Loaded session', () => {
      const sessionObj = { TAG: 'Loading' };
      expect(getVaultName(sessionObj)).toBe('');
    });

    it('should return empty string for non-object input', () => {
      expect(getVaultName('string')).toBe('');
      expect(getVaultName(123)).toBe('');
    });

    it('should extract vgs vault name when present', () => {
      const sessionObj = {
        TAG: 'Loaded',
        _0: {
          vault_details: {
            vgs: {
              external_vault_id: 'vgs_id_123',
            },
          },
        },
      };
      expect(getVaultName(sessionObj)).toBe('vgs');
    });
  });

  describe('getVGSVaultDetails', () => {
    it('should extract VGS vault details from Loaded session', () => {
      const sessionObj = {
        TAG: 'Loaded',
        _0: {
          vault_details: {
            vgs: {
              external_vault_id: 'vgs_vault_123',
              sdk_env: 'sandbox',
            },
          },
        },
      };
      const result = getVGSVaultDetails(sessionObj, 'vgs');
      expect(result.vaultId).toBe('vgs_vault_123');
      expect(result.vaultEnv).toBe('sandbox');
    });

    it('should return empty strings for non-Loaded session', () => {
      const sessionObj = { TAG: 'Loading' };
      const result = getVGSVaultDetails(sessionObj, 'vgs');
      expect(result.vaultId).toBe('');
      expect(result.vaultEnv).toBe('');
    });

    it('should return empty strings for non-object input', () => {
      const result = getVGSVaultDetails('string', 'vgs');
      expect(result.vaultId).toBe('');
      expect(result.vaultEnv).toBe('');
    });

    it('should return empty strings for missing vault details', () => {
      const sessionObj = {
        TAG: 'Loaded',
        _0: {
          vault_details: {},
        },
      };
      const result = getVGSVaultDetails(sessionObj, 'vgs');
      expect(result.vaultId).toBe('');
      expect(result.vaultEnv).toBe('');
    });

    it('should handle partial vault details', () => {
      const sessionObj = {
        TAG: 'Loaded',
        _0: {
          vault_details: {
            vgs: {
              external_vault_id: 'vgs_vault_123',
            },
          },
        },
      };
      const result = getVGSVaultDetails(sessionObj, 'vgs');
      expect(result.vaultId).toBe('vgs_vault_123');
      expect(result.vaultEnv).toBe('');
    });
  });

  describe('getHyperswitchVaultDetails', () => {
    it('should extract all Hyperswitch vault details from Loaded session', () => {
      const sessionObj = {
        TAG: 'Loaded',
        _0: {
          vault_details: {
            hyperswitch_vault: {
              payment_method_session_id: 'pm_session_123',
              client_secret: 'secret_abc',
              publishable_key: 'pk_test_123',
              profile_id: 'profile_456',
            },
          },
        },
      };
      const result = getHyperswitchVaultDetails(sessionObj);
      expect(result.pmSessionId).toBe('pm_session_123');
      expect(result.pmClientSecret).toBe('secret_abc');
      expect(result.vaultPublishableKey).toBe('pk_test_123');
      expect(result.vaultProfileId).toBe('profile_456');
    });

    it('should return empty strings for non-Loaded session', () => {
      const sessionObj = { TAG: 'Loading' };
      const result = getHyperswitchVaultDetails(sessionObj);
      expect(result.pmSessionId).toBe('');
      expect(result.pmClientSecret).toBe('');
      expect(result.vaultPublishableKey).toBe('');
      expect(result.vaultProfileId).toBe('');
    });

    it('should return empty strings for non-object input', () => {
      const result = getHyperswitchVaultDetails('string');
      expect(result.pmSessionId).toBe('');
      expect(result.pmClientSecret).toBe('');
      expect(result.vaultPublishableKey).toBe('');
      expect(result.vaultProfileId).toBe('');
    });

    it('should handle partial Hyperswitch vault details', () => {
      const sessionObj = {
        TAG: 'Loaded',
        _0: {
          vault_details: {
            hyperswitch_vault: {
              payment_method_session_id: 'pm_session_123',
              publishable_key: 'pk_test_123',
            },
          },
        },
      };
      const result = getHyperswitchVaultDetails(sessionObj);
      expect(result.pmSessionId).toBe('pm_session_123');
      expect(result.pmClientSecret).toBe('');
      expect(result.vaultPublishableKey).toBe('pk_test_123');
      expect(result.vaultProfileId).toBe('');
    });

    it('should handle missing vault_details', () => {
      const sessionObj = {
        TAG: 'Loaded',
        _0: {},
      };
      const result = getHyperswitchVaultDetails(sessionObj);
      expect(result.pmSessionId).toBe('');
      expect(result.pmClientSecret).toBe('');
      expect(result.vaultPublishableKey).toBe('');
      expect(result.vaultProfileId).toBe('');
    });
  });
});
