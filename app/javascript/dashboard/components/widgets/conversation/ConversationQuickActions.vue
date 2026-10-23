<script setup>
// Seller mode: the two things a salesperson does on every lead (take the conversation and tag it),
// at the top of the conversation instead of a collapsed accordion in the contact panel.
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useConversationLabels } from 'dashboard/composables/useConversationLabels';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  chat: { type: Object, required: true },
});

const { t } = useI18n();
const store = useStore();
const currentUser = useMapGetter('getCurrentUser');
const { accountLabels, savedLabels, onUpdateLabels } = useConversationLabels();
const [showLabels, toggleLabels] = useToggle(false);

const isAssignedToMe = computed(() => {
  const { assignee, assignee_type: assigneeType } = props.chat.meta || {};
  return (
    assignee?.id === currentUser.value.id && (assigneeType || 'User') === 'User'
  );
});

const takeOver = async () => {
  const { id, name, available_name, avatar_url, email, role } =
    currentUser.value;
  const assignee = {
    id,
    name,
    available_name,
    email,
    role,
    thumbnail: avatar_url,
  };
  store.dispatch('setCurrentChatAssignee', {
    conversationId: props.chat.id,
    assignee,
    assigneeType: 'User',
  });
  await store.dispatch('assignAgent', {
    conversationId: props.chat.id,
    agentId: id,
    assigneeType: 'User',
  });
  useAlert(t('CONVERSATION.QUICK_ACTIONS.TAKE_OVER_SUCCESS'));
};

const isLabelActive = title => savedLabels.value.includes(title);

const toggleLabel = title => {
  const labels = isLabelActive(title)
    ? savedLabels.value.filter(label => label !== title)
    : [...savedLabels.value, title];
  onUpdateLabels(labels);
};
</script>

<template>
  <div class="flex items-center gap-2">
    <Button
      v-if="!isAssignedToMe"
      :label="t('CONVERSATION.QUICK_ACTIONS.TAKE_OVER')"
      icon="i-lucide-user-check"
      size="sm"
      color="blue"
      data-testid="take-over-conversation"
      @click="takeOver"
    />
    <div v-on-clickaway="() => toggleLabels(false)" class="relative">
      <Button
        v-tooltip.bottom="t('CONVERSATION.QUICK_ACTIONS.LABELS')"
        icon="i-lucide-tag"
        size="sm"
        variant="ghost"
        color="slate"
        :label="savedLabels.length ? String(savedLabels.length) : ''"
        :class="{ 'bg-n-alpha-2': showLabels }"
        :aria-label="t('CONVERSATION.QUICK_ACTIONS.LABELS')"
        :aria-expanded="showLabels"
        data-testid="conversation-labels-button"
        @click="toggleLabels()"
      />
      <div
        v-if="showLabels"
        class="absolute z-20 mt-1 start-0 xl:start-auto xl:end-0 top-full w-56 max-h-72 overflow-y-auto rounded-xl border border-n-weak bg-n-alpha-3 backdrop-blur-[100px] shadow-lg p-1"
      >
        <p class="px-2 py-1.5 text-xs font-medium text-n-slate-11">
          {{ t('CONVERSATION.QUICK_ACTIONS.LABELS') }}
        </p>
        <p
          v-if="!accountLabels.length"
          class="px-2 py-2 text-sm text-n-slate-11"
        >
          {{ t('CONVERSATION.QUICK_ACTIONS.NO_LABELS') }}
        </p>
        <button
          v-for="label in accountLabels"
          :key="label.id"
          type="button"
          class="flex items-center w-full h-8 gap-2 px-2 text-sm text-start rounded-lg text-n-slate-12 hover:bg-n-alpha-2 focus-visible:outline-none focus-visible:bg-n-alpha-2"
          :aria-pressed="isLabelActive(label.title)"
          @click="toggleLabel(label.title)"
        >
          <span
            class="rounded-full size-2.5 shrink-0"
            :style="{ backgroundColor: label.color }"
          />
          <span class="flex-1 min-w-0 truncate">{{ label.title }}</span>
          <span
            v-if="isLabelActive(label.title)"
            class="i-lucide-check size-4 text-n-brand shrink-0"
          />
        </button>
      </div>
    </div>
  </div>
</template>
