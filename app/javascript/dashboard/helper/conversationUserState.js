// Per-agent state of a conversation (see ConversationUserState in the backend).
//
// Archived conversations stay archived, new messages included, until the agent unarchives them.
export const isConversationArchived = chat => !!chat?.archived_at;

export const isConversationPinned = chat => !!chat?.pinned_at;

// Pinned conversations first (newest pin first), everything else keeps its order.
export const pinnedFirst = conversations => {
  const pinned = conversations
    .filter(isConversationPinned)
    .sort((a, b) => b.pinned_at - a.pinned_at);
  return [...pinned, ...conversations.filter(c => !isConversationPinned(c))];
};
