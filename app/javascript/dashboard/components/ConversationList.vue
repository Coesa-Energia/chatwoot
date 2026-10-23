<script setup>
import { ref, computed, provide } from 'vue';
import { Virtualizer } from 'virtua/vue';
import { useBreakpoints } from '@vueuse/core';
import { useChatListKeyboardEvents } from 'dashboard/composables/chatlist/useChatListKeyboardEvents';
import ConversationItem from './ConversationItem.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import IntersectionObserver from 'dashboard/components/IntersectionObserver.vue';

import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  conversationList: { type: Array, default: () => [] },
  isLoading: { type: Boolean, default: false },
  showEndOfListMessage: { type: Boolean, default: false },
  label: { type: String, default: '' },
  teamId: { type: [String, Number], default: 0 },
  foldersId: { type: [String, Number], default: 0 },
  conversationType: { type: String, default: '' },
  showAssignee: { type: Boolean, default: false },
  isOnExpandedLayout: { type: Boolean, default: false },
});

const emit = defineEmits(['loadMore']);

const conversationListRef = ref(null);
const virtualListRef = ref(null);
const isContextMenuOpen = ref(false);

provide('contextMenuElementTarget', virtualListRef);

const breakpoints = useBreakpoints({
  lg: wootConstants.LARGE_SCREEN_BREAKPOINT,
});
const isLgScreen = breakpoints.greaterOrEqual('lg');
const showExpandedCards = computed(
  () => props.isOnExpandedLayout && isLgScreen.value
);

useChatListKeyboardEvents(conversationListRef);

const intersectionObserverOptions = computed(() => ({
  root: conversationListRef.value,
  rootMargin: '100px 0px 100px 0px',
}));

const onContextMenuToggle = state => {
  isContextMenuOpen.value = state;
};

// Arrow keys move focus between cards once one is focused (Tab); Enter opens it.
const moveCardFocus = (event, step) => {
  const cards = [
    ...conversationListRef.value.querySelectorAll('div.conversation'),
  ];
  const index = cards.indexOf(event.target);
  if (index < 0) return;
  const next = cards[index + step];
  if (!next) return;
  event.preventDefault();
  next.focus();
};

const SKELETON_ROWS = 6;

const loadMoreConversations = () => {
  emit('loadMore');
};

provide('toggleContextMenu', onContextMenuToggle);

defineExpose({ conversationListRef });
</script>

<template>
  <div
    ref="conversationListRef"
    class="flex-1 min-h-0 overflow-y-auto conversations-list"
    :class="{ '!overflow-hidden': isContextMenuOpen }"
    @keydown.down="moveCardFocus($event, 1)"
    @keydown.up="moveCardFocus($event, -1)"
  >
    <Virtualizer
      ref="virtualListRef"
      v-slot="{ item }"
      :data="conversationList"
      class="[&>div:has(+_div_.active)>*]:!border-n-surface-1 [&>div:has(+_div_.selected)>*]:!border-n-surface-1"
    >
      <ConversationItem
        :source="item"
        :label="label"
        :team-id="teamId"
        :folders-id="foldersId"
        :conversation-type="conversationType"
        :show-assignee="showAssignee"
        :show-expanded="showExpandedCards"
      />
    </Virtualizer>
    <!-- First load: placeholder rows shaped like the cards so the layout doesn't jump -->
    <div
      v-if="isLoading && !conversationList.length"
      aria-busy="true"
      :aria-label="$t('CHAT_LIST.LOADING')"
      data-testid="chat-list-skeleton"
    >
      <div
        v-for="row in SKELETON_ROWS"
        :key="row"
        class="flex items-center gap-2 px-3 py-3 border-b border-n-slate-3 animate-pulse motion-reduce:animate-none"
      >
        <div class="size-10 flex-shrink-0 rounded-full bg-n-alpha-2" />
        <div class="flex flex-col flex-1 min-w-0 gap-2 mx-2">
          <div class="h-3 w-1/2 rounded bg-n-alpha-2" />
          <div class="h-3 w-4/5 rounded bg-n-alpha-2" />
        </div>
      </div>
    </div>
    <div v-else-if="isLoading" class="flex justify-center my-4">
      <Spinner class="text-n-brand" />
    </div>
    <p
      v-else-if="showEndOfListMessage"
      class="p-4 text-sm text-center text-n-slate-11"
    >
      {{ $t('CHAT_LIST.EOF') }}
    </p>
    <IntersectionObserver
      v-else
      :options="intersectionObserverOptions"
      @observed="loadMoreConversations"
    />
  </div>
</template>
