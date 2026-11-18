import { isOwnPrivateNote } from '../privateNote';

const ME = 5;
const note = overrides => ({
  isPrivate: true,
  status: 'sent',
  sender: { id: ME, type: 'user' },
  senderType: 'User',
  senderId: ME,
  currentUserId: ME,
  ...overrides,
});

describe('isOwnPrivateNote', () => {
  it('is true for a note the logged-in agent wrote', () => {
    expect(isOwnPrivateNote(note())).toBe(true);
    expect(isOwnPrivateNote(note({ sender: null, senderId: String(ME) }))).toBe(
      true
    );
  });

  it('is true for a note still being sent from this dashboard', () => {
    expect(
      isOwnPrivateNote(
        note({ status: 'progress', sender: { name: 'Ana' }, senderId: null })
      )
    ).toBe(true);
  });

  it('is false for notes received from the bot, the system or another agent', () => {
    expect(
      isOwnPrivateNote(
        note({
          sender: { id: ME, type: 'agent_bot' },
          senderType: 'AgentBot',
        })
      )
    ).toBe(false);
    expect(
      isOwnPrivateNote(note({ sender: null, senderType: null, senderId: null }))
    ).toBe(false);
    expect(
      isOwnPrivateNote(note({ sender: { id: 9, type: 'user' }, senderId: 9 }))
    ).toBe(false);
  });

  it('is false for a message that is not a private note', () => {
    expect(isOwnPrivateNote(note({ isPrivate: false }))).toBe(false);
  });
});
