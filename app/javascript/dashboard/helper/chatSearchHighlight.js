/* global Highlight */
import { ref } from 'vue';

// Search inside a conversation: the matches are highlighted in the messages with the CSS Custom Highlight
// API (no DOM changes), and the message being shown gets a tinted row.

const ALL_MATCHES = 'chat-search';
const ACTIVE_MATCHES = 'chat-search-active';

// Id of the message the search is currently showing; Message.vue tints its row.
export const activeSearchMessageId = ref(null);

const isSupported = () =>
  typeof CSS !== 'undefined' &&
  !!CSS.highlights &&
  typeof Highlight !== 'undefined';

// The time of a message also holds digits and letters, which are not part of what was written.
const isSearchable = node => !node.parentElement?.closest('time');

/**
 * Ranges covering every occurrence of `query` (case-insensitive) in the text of `root`.
 */
export const findMatchRanges = (root, query) => {
  const needle = (query || '').toLowerCase();
  if (!root || !needle) return [];

  const ranges = [];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let node = walker.nextNode();
  while (node) {
    if (isSearchable(node)) {
      const text = node.textContent.toLowerCase();
      let index = text.indexOf(needle);
      while (index !== -1) {
        const range = document.createRange();
        range.setStart(node, index);
        range.setEnd(node, index + needle.length);
        ranges.push(range);
        index = text.indexOf(needle, index + needle.length);
      }
    }
    node = walker.nextNode();
  }
  return ranges;
};

export const clearChatSearchHighlight = () => {
  activeSearchMessageId.value = null;
  if (!isSupported()) return;
  CSS.highlights.delete(ALL_MATCHES);
  CSS.highlights.delete(ACTIVE_MATCHES);
};

/**
 * Highlights `query` in the given messages (the ones the search found that are on screen); the occurrences
 * in `activeId` get a stronger colour.
 */
export const applyChatSearchHighlight = ({ query, messageIds, activeId }) => {
  activeSearchMessageId.value = activeId ?? null;
  if (!isSupported()) return;

  const all = [];
  const active = [];
  messageIds.forEach(id => {
    const element = document.getElementById(`message${id}`);
    const ranges = findMatchRanges(element, query);
    (id === activeId ? active : all).push(...ranges);
  });

  CSS.highlights.set(ALL_MATCHES, new Highlight(...all));
  CSS.highlights.set(ACTIVE_MATCHES, new Highlight(...active));
};
