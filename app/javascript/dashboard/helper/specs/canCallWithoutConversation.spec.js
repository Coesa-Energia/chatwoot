import { INBOX_TYPES, canCallWithoutConversation } from '../inbox';

describe('canCallWithoutConversation', () => {
  it('leaves WhatsApp out: its calls only start inside a conversation', () => {
    expect(
      canCallWithoutConversation({
        channel_type: INBOX_TYPES.WHATSAPP,
        voice_enabled: true,
      })
    ).toBe(false);
  });

  it('keeps Twilio voice inboxes, which dial a bare phone number', () => {
    expect(
      canCallWithoutConversation({
        channel_type: INBOX_TYPES.TWILIO,
        voice_enabled: true,
      })
    ).toBe(true);
  });

  it('accepts the camelCase shape', () => {
    expect(
      canCallWithoutConversation({
        channelType: INBOX_TYPES.TWILIO,
        voiceEnabled: true,
      })
    ).toBe(true);
  });

  it('rejects inboxes without voice', () => {
    expect(
      canCallWithoutConversation({
        channel_type: INBOX_TYPES.TWILIO,
        voice_enabled: false,
      })
    ).toBe(false);
    expect(canCallWithoutConversation(null)).toBe(false);
  });
});
