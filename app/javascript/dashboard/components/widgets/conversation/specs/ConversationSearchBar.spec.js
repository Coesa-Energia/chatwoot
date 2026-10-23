import { flushPromises, mount } from '@vue/test-utils';
import { activeSearchMessageId } from 'dashboard/helper/chatSearchHighlight';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { withFullI18n } from 'test-i18n';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createStore } from 'vuex';
import MessageApi from 'dashboard/api/inbox/message';
import ConversationSearchBar from '../ConversationSearchBar.vue';

withFullI18n();

vi.mock('dashboard/api/inbox/message', () => ({
  default: { searchInConversation: vi.fn() },
}));

const fetchPreviousMessages = vi.fn();
let firstLoadedMessageId = 100;

const store = createStore({
  actions: {
    fetchPreviousMessages: (_, payload) => fetchPreviousMessages(payload),
  },
  getters: {
    getSelectedChat: () => ({ messages: [{ id: firstLoadedMessageId }] }),
  },
});

// Newest first, like the API returns them.
const results = [
  { id: 130, content: 'orçamento revisado', created_at: 1_760_000_300 },
  { id: 120, content: 'quero um orçamento', created_at: 1_760_000_200 },
  { id: 50, content: 'orçamento antigo', created_at: 1_750_000_000 },
];

let wrapper = null;
const addedElements = [];

const addMessageElement = id => {
  const element = document.createElement('div');
  element.id = `message${id}`;
  document.body.appendChild(element);
  addedElements.push(element);
  return element;
};

const mountBar = () => {
  wrapper = mount(ConversationSearchBar, {
    props: { conversationId: 7 },
    global: { plugins: [store] },
    attachTo: document.body,
  });
  return wrapper;
};

const type = async text => {
  await wrapper.find('input').setValue(text);
  await vi.advanceTimersByTimeAsync(350);
  await flushPromises();
};

const scrollTargets = emitSpy =>
  emitSpy.mock.calls
    .filter(([event]) => event === BUS_EVENTS.SCROLL_TO_MESSAGE)
    .map(([, payload]) => payload.messageId);

describe('ConversationSearchBar', () => {
  let emitSpy;

  beforeEach(() => {
    vi.useFakeTimers();
    firstLoadedMessageId = 100;
    MessageApi.searchInConversation.mockReset();
    MessageApi.searchInConversation.mockResolvedValue({
      data: { payload: results },
    });
    fetchPreviousMessages.mockReset();
    emitSpy = vi.spyOn(emitter, 'emit');
    addMessageElement(130);
    addMessageElement(120);
    mountBar();
  });

  afterEach(() => {
    wrapper.unmount();
    addedElements.splice(0).forEach(element => element.remove());
    emitSpy.mockRestore();
    vi.useRealTimers();
  });

  it('focuses the input when opened', () => {
    expect(document.activeElement).toBe(wrapper.find('input').element);
  });

  it('does not search for fewer than two characters', async () => {
    await type('o');

    expect(MessageApi.searchInConversation).not.toHaveBeenCalled();
  });

  it('searches the conversation after a short pause and shows the result count', async () => {
    await type('orçamento');

    expect(MessageApi.searchInConversation).toHaveBeenCalledTimes(1);
    expect(MessageApi.searchInConversation.mock.calls[0][0]).toEqual({
      conversationId: 7,
      q: 'orçamento',
    });
    expect(wrapper.text()).toContain('1 of 3');
  });

  it('debounces typing into a single request', async () => {
    await wrapper.find('input').setValue('orç');
    await vi.advanceTimersByTimeAsync(100);
    await wrapper.find('input').setValue('orçamento');
    await vi.advanceTimersByTimeAsync(350);
    await flushPromises();

    expect(MessageApi.searchInConversation).toHaveBeenCalledTimes(1);
  });

  it('jumps to the newest match first', async () => {
    await type('orçamento');

    expect(scrollTargets(emitSpy)).toEqual([130]);
  });

  it('goes to older and newer matches, wrapping around', async () => {
    await type('orçamento');
    const [olderButton, newerButton] = wrapper.findAll('button');

    await olderButton.trigger('click');
    expect(wrapper.text()).toContain('2 of 3');
    await newerButton.trigger('click');
    expect(wrapper.text()).toContain('1 of 3');
    await newerButton.trigger('click');
    expect(wrapper.text()).toContain('3 of 3');
  });

  it('moves to the next older match with Enter and back with Shift+Enter', async () => {
    await type('orçamento');

    await wrapper.find('input').trigger('keydown', { key: 'Enter' });
    expect(wrapper.text()).toContain('2 of 3');
    await wrapper
      .find('input')
      .trigger('keydown', { key: 'Enter', shiftKey: true });
    expect(wrapper.text()).toContain('1 of 3');
  });

  it('loads the history around a match that is older than the loaded messages', async () => {
    await type('orçamento');
    const olderButton = wrapper.findAll('button')[0];

    await olderButton.trigger('click'); // id 120, already in the DOM
    expect(fetchPreviousMessages).not.toHaveBeenCalled();

    await olderButton.trigger('click'); // id 50, not in the DOM
    await flushPromises();

    expect(fetchPreviousMessages).toHaveBeenCalledWith({
      conversationId: 7,
      after: 50,
      before: 100,
    });
    expect(scrollTargets(emitSpy)).toContain(50);
  });

  it('keeps the message it jumps to highlighted while searching and clears it on close', async () => {
    await type('orçamento');
    await vi.advanceTimersByTimeAsync(500);

    expect(activeSearchMessageId.value).toBe(130);

    await wrapper.findAll('button').at(-1).trigger('click');
    expect(activeSearchMessageId.value).toBeNull();
  });

  it('shows a message when nothing matches', async () => {
    MessageApi.searchInConversation.mockResolvedValue({
      data: { payload: [] },
    });

    await type('inexistente');

    expect(wrapper.text()).toContain('No messages found');
    expect(scrollTargets(emitSpy)).toEqual([]);
  });

  it('emits close on Escape and when the close button is clicked', async () => {
    await wrapper.find('input').trigger('keydown', { key: 'Escape' });
    await wrapper.findAll('button').at(-1).trigger('click');

    expect(wrapper.emitted('close')).toHaveLength(2);
  });

  it('clears the results when the conversation changes', async () => {
    await type('orçamento');
    expect(wrapper.text()).toContain('1 of 3');

    await wrapper.setProps({ conversationId: 8 });

    expect(wrapper.find('input').element.value).toBe('');
    expect(wrapper.text()).not.toContain('of 3');
  });
});
