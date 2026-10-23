import {
  effectiveWhatsappWebhookUrl,
  isWhatsappWebhookUrlValid,
} from '../whatsappWebhookHelper';

describe('whatsappWebhookHelper', () => {
  describe('isWhatsappWebhookUrlValid', () => {
    const expected =
      'https://chat.example.com/webhooks/whatsapp/+5511999990002';

    it('accepts the exact expected URL', () => {
      expect(isWhatsappWebhookUrlValid(expected, expected)).toBe(true);
    });

    it('accepts a callback shared by another number of the same WABA', () => {
      const shared =
        'https://chat.example.com/webhooks/whatsapp/+5511999990001';
      expect(isWhatsappWebhookUrlValid(shared, expected)).toBe(true);
    });

    it('accepts the endpoint without the number segment', () => {
      expect(
        isWhatsappWebhookUrlValid(
          'https://chat.example.com/webhooks/whatsapp',
          expected
        )
      ).toBe(true);
    });

    it('rejects another host', () => {
      expect(
        isWhatsappWebhookUrlValid(
          'https://old.example.com/webhooks/whatsapp/+5511999990002',
          expected
        )
      ).toBe(false);
    });

    it('rejects a path that is not the WhatsApp endpoint', () => {
      expect(
        isWhatsappWebhookUrlValid(
          'https://chat.example.com/webhooks/instagram/x',
          expected
        )
      ).toBe(false);
      expect(
        isWhatsappWebhookUrlValid(
          'https://chat.example.com/webhooks/whatsappx',
          expected
        )
      ).toBe(false);
    });

    it('rejects missing or malformed URLs', () => {
      expect(isWhatsappWebhookUrlValid(undefined, expected)).toBe(false);
      expect(isWhatsappWebhookUrlValid(expected, undefined)).toBe(false);
      expect(isWhatsappWebhookUrlValid('not a url', expected)).toBe(false);
    });
  });

  describe('effectiveWhatsappWebhookUrl', () => {
    it('prefers the number override over the WABA and the app', () => {
      expect(
        effectiveWhatsappWebhookUrl({
          phone_number: 'a',
          whatsapp_business_account: 'b',
          application: 'c',
        })
      ).toBe('a');
    });

    it('falls back to the WABA, then to the app', () => {
      expect(
        effectiveWhatsappWebhookUrl({
          whatsapp_business_account: 'b',
          application: 'c',
        })
      ).toBe('b');
      expect(effectiveWhatsappWebhookUrl({ application: 'c' })).toBe('c');
    });

    it('returns undefined when nothing is configured', () => {
      expect(effectiveWhatsappWebhookUrl({})).toBeUndefined();
      expect(effectiveWhatsappWebhookUrl(undefined)).toBeUndefined();
    });
  });
});
