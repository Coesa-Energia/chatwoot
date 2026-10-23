import { conversationListPageURL } from 'dashboard/helper/URLHelper';

// Anything that is drawn on top of the conversation owns the Escape key: the key must close it
// first, not the conversation underneath.
const OVERLAY_SELECTOR =
  'dialog[open], [role="dialog"], [aria-modal="true"], .modal-mask, .modal-container, .emoji-dialog, [data-escape-owner]';

const hasOpenOverlay = () => {
  if (document.querySelector(OVERLAY_SELECTOR)) return true;
  // The command bar is a web component whose open state is a property, not a DOM node.
  return !!document.querySelector('ninja-keys')?.visible;
};

// Esc closes the open conversation (like WhatsApp Web) unless something else already used the key.
// The message editor does not count: ProseMirror always marks its Escape as handled, and closing the
// chat while typing is what WhatsApp Web does too (drafts are kept per conversation). Any other field
// (search boxes, form inputs) keeps Escape for itself.
export const shouldCloseConversationOnEscape = event => {
  const target = event.target;
  const inEditor = !!target?.closest?.('.ProseMirror');
  const inOtherField =
    !inEditor &&
    !!target?.closest?.('input, textarea, select, [contenteditable]');
  if (inOtherField) return false;
  if (!inEditor && event.defaultPrevented) return false;
  return !hasOpenOverlay();
};

const CONVERSATION_TYPE_BY_ROUTE = {
  conversation_through_mentions: 'mention',
  conversation_through_participating: 'participating',
  conversation_through_unattended: 'unattended',
};

// Same destination as the back button in the conversation header.
export const conversationListUrlForRoute = (route, accountId) => {
  const { inbox_id: inboxId, label, teamId, id: customViewId } = route.params;
  return conversationListPageURL({
    accountId,
    inboxId,
    label,
    teamId,
    customViewId,
    conversationType: CONVERSATION_TYPE_BY_ROUTE[route.name],
  });
};
