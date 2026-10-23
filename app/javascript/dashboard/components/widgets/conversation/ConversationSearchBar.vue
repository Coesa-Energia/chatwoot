<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import {
  applyChatSearchHighlight,
  clearChatSearchHighlight,
} from 'dashboard/helper/chatSearchHighlight';
import MessageApi from 'dashboard/api/inbox/message';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';

const props = defineProps({
  conversationId: { type: Number, required: true },
});

const emit = defineEmits(['close']);

const MIN_LENGTH = 2;

const { t } = useI18n();
const store = useStore();

const inputRef = ref(null);
const query = ref('');
const results = ref([]); // newest first
const activeIndex = ref(0);
const isLoading = ref(false);
const hasSearched = ref(false);

let searchController = null;
let messagesObserver = null;

const total = computed(() => results.value.length);
const activeResult = computed(() => results.value[activeIndex.value] || null);
const canSearch = computed(() => query.value.trim().length >= MIN_LENGTH);

const counterLabel = computed(() =>
  total.value
    ? t('CONVERSATION.CHAT_SEARCH.COUNT', {
        current: activeIndex.value + 1,
        total: total.value,
      })
    : ''
);

const previewDate = computed(() =>
  activeResult.value
    ? new Date(activeResult.value.created_at * 1000).toLocaleString(undefined, {
        dateStyle: 'short',
        timeStyle: 'short',
      })
    : ''
);

// Highlights the searched text in every found message that is on screen, and tints the row of the one
// being shown. Messages that are not rendered yet get highlighted when they appear (see the observer).
const refreshHighlights = () => {
  if (!canSearch.value || !results.value.length) {
    clearChatSearchHighlight();
    return;
  }
  applyChatSearchHighlight({
    query: query.value.trim(),
    messageIds: results.value.map(result => result.id),
    activeId: activeResult.value?.id,
  });
};

const refreshHighlightsSoon = useDebounceFn(refreshHighlights, 120);

const observeMessages = () => {
  const panel = document.querySelector('.conversation-panel');
  if (!panel || messagesObserver) return;
  messagesObserver = new MutationObserver(refreshHighlightsSoon);
  messagesObserver.observe(panel, { childList: true, subtree: true });
};

// Results older than what is loaded in the timeline need their history fetched first. This is the
// same "load around a message" request the global search uses when it opens an old message.
const jumpTo = async result => {
  if (!result) return;
  if (!document.getElementById(`message${result.id}`)) {
    const chat = store.getters.getSelectedChat;
    const firstLoadedId = chat?.messages?.[0]?.id;
    if (firstLoadedId && result.id < firstLoadedId) {
      try {
        await store.dispatch('fetchPreviousMessages', {
          conversationId: props.conversationId,
          after: result.id,
          before: firstLoadedId,
        });
      } catch (error) {
        // The result stays in the list; the agent can try the next one.
      }
    }
    await nextTick();
  }
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, { messageId: result.id });
  refreshHighlights();
};

const runSearch = async () => {
  searchController?.abort();
  if (!canSearch.value) {
    results.value = [];
    hasSearched.value = false;
    isLoading.value = false;
    return;
  }

  searchController = new AbortController();
  isLoading.value = true;
  try {
    const { data } = await MessageApi.searchInConversation(
      { conversationId: props.conversationId, q: query.value.trim() },
      { signal: searchController.signal }
    );
    results.value = data.payload || [];
    hasSearched.value = true;
    activeIndex.value = 0;
    isLoading.value = false;
    refreshHighlights();
    // Goes straight to the newest match, like the WhatsApp app.
    jumpTo(activeResult.value);
  } catch (error) {
    if (error?.code === 'ERR_CANCELED') return;
    results.value = [];
    hasSearched.value = true;
    isLoading.value = false;
    clearChatSearchHighlight();
  }
};

const debouncedSearch = useDebounceFn(runSearch, 300);

// Older matches are further down the list.
const goToOlder = () => {
  if (!total.value) return;
  activeIndex.value = (activeIndex.value + 1) % total.value;
  jumpTo(activeResult.value);
};

const goToNewer = () => {
  if (!total.value) return;
  activeIndex.value = (activeIndex.value - 1 + total.value) % total.value;
  jumpTo(activeResult.value);
};

const onEnter = event => (event.shiftKey ? goToNewer() : goToOlder());

const close = () => {
  clearChatSearchHighlight();
  emit('close');
};

watch(query, () => {
  if (!canSearch.value) {
    searchController?.abort();
    results.value = [];
    hasSearched.value = false;
    clearChatSearchHighlight();
    return;
  }
  debouncedSearch();
});

// Switching conversation resets the search.
watch(
  () => props.conversationId,
  () => {
    query.value = '';
    results.value = [];
    hasSearched.value = false;
    clearChatSearchHighlight();
  }
);

onMounted(() => {
  nextTick(() => inputRef.value?.focus());
  observeMessages();
});
onBeforeUnmount(() => {
  searchController?.abort();
  messagesObserver?.disconnect();
  messagesObserver = null;
  clearChatSearchHighlight();
});
</script>

<template>
  <div
    class="flex flex-col gap-1 px-3 py-2 border-b border-n-weak bg-n-surface-1"
    role="search"
  >
    <div class="flex items-center gap-2">
      <div class="relative flex items-center flex-1 min-w-0">
        <span
          class="i-lucide-search absolute size-4 pointer-events-none ltr:left-2.5 rtl:right-2.5 text-n-slate-10"
        />
        <input
          ref="inputRef"
          v-model="query"
          type="search"
          autocomplete="off"
          class="w-full h-8 !mb-0 text-sm rounded-lg ltr:!pl-8 rtl:!pr-8"
          :placeholder="$t('CONVERSATION.CHAT_SEARCH.PLACEHOLDER')"
          :aria-label="$t('CONVERSATION.CHAT_SEARCH.PLACEHOLDER')"
          @keydown.enter.prevent="onEnter"
          @keydown.esc.prevent="close"
        />
      </div>
      <span
        v-if="counterLabel"
        class="text-xs tabular-nums whitespace-nowrap text-n-slate-11"
        aria-live="polite"
      >
        {{ counterLabel }}
      </span>
      <div class="flex items-center">
        <button
          type="button"
          class="flex items-center justify-center rounded-md size-7 text-n-slate-11 hover:bg-n-alpha-2 disabled:opacity-40 disabled:hover:bg-transparent"
          :disabled="!total"
          :title="$t('CONVERSATION.CHAT_SEARCH.OLDER')"
          :aria-label="$t('CONVERSATION.CHAT_SEARCH.OLDER')"
          @click="goToOlder"
        >
          <span class="i-lucide-chevron-up size-4" />
        </button>
        <button
          type="button"
          class="flex items-center justify-center rounded-md size-7 text-n-slate-11 hover:bg-n-alpha-2 disabled:opacity-40 disabled:hover:bg-transparent"
          :disabled="!total"
          :title="$t('CONVERSATION.CHAT_SEARCH.NEWER')"
          :aria-label="$t('CONVERSATION.CHAT_SEARCH.NEWER')"
          @click="goToNewer"
        >
          <span class="i-lucide-chevron-down size-4" />
        </button>
        <button
          type="button"
          class="flex items-center justify-center rounded-md size-7 text-n-slate-11 hover:bg-n-alpha-2"
          :title="$t('CONVERSATION.CHAT_SEARCH.CLOSE')"
          :aria-label="$t('CONVERSATION.CHAT_SEARCH.CLOSE')"
          @click="close"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>
    </div>
    <p
      v-if="activeResult"
      class="text-xs truncate text-n-slate-11"
      :title="activeResult.content"
    >
      <span class="font-medium text-n-slate-12">{{ previewDate }}</span>
      <span v-if="activeResult.sender_name">
        · {{ activeResult.sender_name }}
      </span>
      · {{ activeResult.content }}
    </p>
    <p
      v-else-if="hasSearched && !isLoading && canSearch"
      class="text-xs text-n-slate-11"
    >
      {{ $t('CONVERSATION.CHAT_SEARCH.NO_RESULTS') }}
    </p>
  </div>
</template>

<style lang="scss">
// Text found by the search inside a conversation (CSS Custom Highlight API).
::highlight(chat-search) {
  background-color: rgb(255 214 10 / 0.45);
  color: inherit;
}

::highlight(chat-search-active) {
  background-color: rgb(255 170 0 / 0.75);
  color: inherit;
}
</style>
