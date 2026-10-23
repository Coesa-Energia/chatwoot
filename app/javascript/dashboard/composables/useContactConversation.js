import { useStore, useMapGetter } from 'dashboard/composables/store';

/**
 * Finds the contact's conversation in an inbox, or creates an empty one assigned to the current user.
 * Used to open a WhatsApp thread without writing a message first (contacts page, "Nova ligação").
 */
export function useContactConversation() {
  const store = useStore();
  const currentUser = useMapGetter('getCurrentUser');
  const conversationsByContactId = useMapGetter(
    'contactConversations/getAllConversationsByContactId'
  );

  // Most recent thread of this contact in the inbox, whatever its status, so the history stays in one place.
  const findExistingConversation = async (contactId, inboxId) => {
    await store.dispatch('contactConversations/get', contactId);
    return [...(conversationsByContactId.value(contactId) || [])]
      .filter(conversation => conversation.inboxId === inboxId)
      .sort((a, b) => (b.lastActivityAt || 0) - (a.lastActivityAt || 0))[0];
  };

  // `inbox` is a contactable inbox (id + sourceId), as returned by fetchContactableInboxes.
  const findOrCreateConversationId = async (contactId, inbox) => {
    const existing = await findExistingConversation(contactId, inbox.id);
    if (existing) return existing.id;
    const created = await store.dispatch('contactConversations/create', {
      params: {
        inboxId: inbox.id,
        sourceId: inbox.sourceId,
        contactId,
        assigneeId: currentUser.value?.id,
      },
    });
    return created.id;
  };

  return { findOrCreateConversationId };
}
