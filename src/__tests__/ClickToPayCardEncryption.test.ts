import * as ClickToPayCardEncryption from '../Utilities/ClickToPayCardEncryption.bs.js';

jest.mock('../Utilities/ClickToPayCardEncryptionHelpers', () => ({
  encryptMessage: jest.fn(),
}));

import { encryptMessage } from '../Utilities/ClickToPayCardEncryptionHelpers';

const mockEncryptMessage = encryptMessage as jest.MockedFunction<typeof encryptMessage>;

describe('ClickToPayCardEncryption', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getEncryptedCard', () => {
    it('returns encrypted card data on successful encryption', async () => {
      mockEncryptMessage.mockResolvedValue('encrypted-data-123');

      const cardPayloadJson = JSON.stringify({
        cardNumber: '4111111111111111',
        expiryMonth: '12',
        expiryYear: '2025',
      });

      const result = await ClickToPayCardEncryption.getEncryptedCard(cardPayloadJson);

      expect(result).toBe('encrypted-data-123');
      expect(mockEncryptMessage).toHaveBeenCalledWith(cardPayloadJson);
    });

    it('returns encrypted data for valid card payload', async () => {
      mockEncryptMessage.mockResolvedValue('encrypted-payload-xyz');

      const cardPayloadJson = JSON.stringify({
        cardNumber: '4242424242424242',
        expiryMonth: '01',
        expiryYear: '2026',
        cvv: '123',
      });

      const result = await ClickToPayCardEncryption.getEncryptedCard(cardPayloadJson);

      expect(result).toBe('encrypted-payload-xyz');
    });

    it('returns empty string when encryption helper throws an error', async () => {
      mockEncryptMessage.mockRejectedValue(new Error('Encryption failed'));

      const cardPayloadJson = JSON.stringify({
        cardNumber: 'invalid',
        expiryMonth: '12',
        expiryYear: '2025',
      });

      const result = await ClickToPayCardEncryption.getEncryptedCard(cardPayloadJson);

      expect(result).toBe('');
    });

    it('returns empty string when dynamic import fails', async () => {
      mockEncryptMessage.mockRejectedValue(new Error('Import failed'));

      const result = await ClickToPayCardEncryption.getEncryptedCard(null);

      expect(result).toBe('');
    });

    it('handles empty card payload', async () => {
      mockEncryptMessage.mockResolvedValue('');

      const result = await ClickToPayCardEncryption.getEncryptedCard('');

      expect(typeof result).toBe('string');
    });

    it('handles undefined payload gracefully', async () => {
      mockEncryptMessage.mockRejectedValue(new Error('Invalid payload'));

      const result = await ClickToPayCardEncryption.getEncryptedCard(undefined as any);

      expect(result).toBe('');
    });

    it('handles malformed JSON payload', async () => {
      mockEncryptMessage.mockRejectedValue(new Error('Invalid JSON'));

      const result = await ClickToPayCardEncryption.getEncryptedCard('not valid json');

      expect(result).toBe('');
    });

    it('handles empty object payload', async () => {
      mockEncryptMessage.mockResolvedValue('empty-encrypted');

      const result = await ClickToPayCardEncryption.getEncryptedCard('{}');

      expect(result).toBe('empty-encrypted');
    });
  });
});
