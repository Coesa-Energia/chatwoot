<script setup>
import { computed } from 'vue';
import { REPLY_EDITOR_MODES } from './constants';

const props = defineProps({
  mode: {
    type: String,
    default: REPLY_EDITOR_MODES.REPLY,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  isReplyRestricted: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['toggleMode']);

/**
 * Whether the editor is in private note mode.
 * When replies are restricted the editor is forced into a private note.
 */
const isPrivate = computed(() => {
  if (props.isReplyRestricted) return true;
  return props.mode === REPLY_EDITOR_MODES.NOTE;
});

const isLocked = computed(() => props.disabled || props.isReplyRestricted);

// Clicking the tab that is already active does nothing.
const select = privateNote => {
  if (isLocked.value || privateNote === isPrivate.value) return;
  emit('toggleMode');
};
</script>

<template>
  <!-- Two underlined tabs, like the other tabs of the system (no pill) -->
  <div
    role="tablist"
    class="flex items-center gap-5 h-8"
    :class="{ 'cursor-not-allowed': isLocked }"
  >
    <button
      type="button"
      role="tab"
      :aria-selected="!isPrivate"
      :aria-disabled="isLocked"
      class="relative h-8 text-sm font-medium transition-colors after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:rounded-full after:transition-opacity after:duration-200"
      :class="
        !isPrivate
          ? 'text-n-slate-12 after:bg-n-brand after:opacity-100'
          : 'text-n-slate-11 hover:text-n-slate-12 after:bg-n-brand after:opacity-0'
      "
      data-testid="editor-mode-reply"
      @click="select(false)"
    >
      {{ $t('CONVERSATION.REPLYBOX.REPLY') }}
    </button>
    <button
      type="button"
      role="tab"
      :aria-selected="isPrivate"
      :aria-disabled="isLocked"
      class="relative h-8 text-sm font-medium transition-colors after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:rounded-full after:transition-opacity after:duration-200"
      :class="
        isPrivate
          ? 'text-n-amber-11 after:bg-n-amber-9 after:opacity-100'
          : 'text-n-slate-11 hover:text-n-slate-12 after:bg-n-amber-9 after:opacity-0'
      "
      data-testid="editor-mode-note"
      @click="select(true)"
    >
      {{ $t('CONVERSATION.REPLYBOX.PRIVATE_NOTE') }}
    </button>
  </div>
</template>
