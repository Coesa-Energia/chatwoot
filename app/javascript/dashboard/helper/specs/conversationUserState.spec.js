import {
  isConversationArchived,
  isConversationPinned,
  pinnedFirst,
} from '../conversationUserState';

describe('conversationUserState', () => {
  describe('isConversationArchived', () => {
    it('is archived once archived_at is set', () => {
      expect(
        isConversationArchived({ archived_at: 2000, last_activity_at: 1500 })
      ).toBe(true);
    });

    it('stays archived when there is activity after archiving', () => {
      expect(
        isConversationArchived({ archived_at: 2000, last_activity_at: 2001 })
      ).toBe(true);
    });

    it('is not archived without archived_at', () => {
      expect(isConversationArchived({ last_activity_at: 1000 })).toBe(false);
      expect(
        isConversationArchived({ archived_at: null, last_activity_at: 1000 })
      ).toBe(false);
      expect(isConversationArchived(undefined)).toBe(false);
    });
  });

  describe('isConversationPinned', () => {
    it('is pinned when pinned_at is set', () => {
      expect(isConversationPinned({ pinned_at: 10 })).toBe(true);
      expect(isConversationPinned({ pinned_at: null })).toBe(false);
      expect(isConversationPinned({})).toBe(false);
    });
  });

  describe('pinnedFirst', () => {
    const chats = [
      { id: 1 },
      { id: 2, pinned_at: 100 },
      { id: 3 },
      { id: 4, pinned_at: 300 },
    ];

    it('puts pinned conversations first, newest pin first, keeping the rest in order', () => {
      expect(pinnedFirst(chats).map(c => c.id)).toEqual([4, 2, 1, 3]);
    });

    it('does not change the input list', () => {
      pinnedFirst(chats);
      expect(chats.map(c => c.id)).toEqual([1, 2, 3, 4]);
    });

    it('returns the same order when nothing is pinned', () => {
      expect(pinnedFirst([{ id: 1 }, { id: 2 }]).map(c => c.id)).toEqual([
        1, 2,
      ]);
    });
  });
});
