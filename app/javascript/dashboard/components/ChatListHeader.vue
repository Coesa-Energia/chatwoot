<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import VoiceInboxDialer from './widgets/conversation/VoiceInboxDialer.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useSellerMode } from 'dashboard/composables/useSellerMode';

const props = defineProps({
  pageTitle: { type: String, required: true },
  contactFilter: { type: Object, default: null },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
  voiceInboxId: { type: [Number, String], default: null },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
]);

const { uiSettings, updateUISettings } = useUISettings();
const { isSellerMode } = useSellerMode();

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));

// While filters narrow the list, the header names it and the back button exits.
const showFilterScope = computed(
  () => props.hasAppliedFilters && !props.hasActiveFolders
);

// The contact scope is set from the contact panel; it is exited, not edited.
const isContactScoped = computed(
  () => showFilterScope.value && !!props.contactFilter
);

const title = computed(
  () => (isContactScoped.value && props.contactFilter.name) || props.pageTitle
);

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};
</script>

<template>
  <div
    class="flex items-center justify-between gap-2 px-3"
    :class="[
      isContactScoped ? 'h-16' : 'h-[3.25rem]',
      { 'border-b border-n-strong': hasAppliedFiltersOrActiveFolders },
    ]"
  >
    <div class="flex items-center justify-center min-w-0">
      <NextButton
        v-if="showFilterScope"
        v-tooltip.right="
          isContactScoped
            ? $t('CHAT_LIST.CONTACT_SCOPE_BACK')
            : $t('FILTER.CLEAR_BUTTON_LABEL')
        "
        :aria-label="
          isContactScoped
            ? $t('CHAT_LIST.CONTACT_SCOPE_BACK')
            : $t('FILTER.CLEAR_BUTTON_LABEL')
        "
        icon="i-lucide-chevron-left"
        class="shrink-0 -ms-2 !h-6 !w-6 me-1"
        slate
        sm
        ghost
        @click="emit('resetFilters')"
      />
      <div class="flex flex-col min-w-0">
        <p v-if="isContactScoped" class="text-xs truncate text-n-slate-11">
          {{ $t('CHAT_LIST.CONTACT_SCOPE') }}
        </p>
        <h1 class="text-lg font-medium truncate text-n-slate-12" :title="title">
          {{ title }}
        </h1>
      </div>
      <span
        v-if="
          allCount > 0 && hasAppliedFiltersOrActiveFolders && !isListLoading
        "
        class="mx-2 text-sm text-n-slate-11 shrink-0"
        :title="allCount"
      >
        {{ formattedAllCount }}
      </span>
      <span
        v-if="!hasAppliedFiltersOrActiveFolders"
        class="mx-2 text-sm text-n-slate-11 shrink-0"
      >
        {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
      </span>
    </div>
    <div class="flex items-center gap-1">
      <VoiceInboxDialer v-if="voiceInboxId" :inbox-id="voiceInboxId" />
      <template
        v-if="hasAppliedFilters && !hasActiveFolders && !isContactScoped"
      >
        <div class="relative">
          <NextButton
            v-if="!isSellerMode"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
            icon="i-lucide-save"
            slate
            xs
            faded
            @click="emit('addFolders')"
          />
          <div
            id="saveFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
      </template>
      <template v-if="hasActiveFolders">
        <div class="relative">
          <NextButton
            v-if="!isSellerMode"
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
            icon="i-lucide-pen-line"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <NextButton
          v-if="!isSellerMode"
          id="toggleConversationFilterButton"
          v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
          icon="i-lucide-trash-2"
          ruby
          xs
          faded
          @click="emit('deleteFolders')"
        />
      </template>
      <div v-else-if="!isContactScoped" class="relative">
        <NextButton
          v-if="!isSellerMode"
          id="toggleConversationFilterButton"
          v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
          icon="i-lucide-list-filter"
          slate
          xs
          faded
          @click="emit('filtersModal')"
        />
        <div
          id="conversationFilterTeleportTarget"
          class="absolute z-50 mt-2"
          :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
        />
      </div>
      <ConversationBasicFilter
        v-if="!isContactScoped"
        :is-on-expanded-layout="isOnExpandedLayout"
        :show-status-filter="!hasAppliedFiltersOrActiveFolders"
        @change-filter="onBasicFilterChange"
      />
      <SwitchLayout
        :is-on-expanded-layout="isOnExpandedLayout"
        @toggle="toggleConversationLayout"
      />
    </div>
  </div>
</template>
