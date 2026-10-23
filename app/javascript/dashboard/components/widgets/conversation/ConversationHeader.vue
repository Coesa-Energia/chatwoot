<script setup>
import { computed, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useElementSize } from '@vueuse/core';
import BackButton from '../BackButton.vue';
import InboxName from '../InboxName.vue';
import MoreActions from './MoreActions.vue';
import Avatar from 'next/avatar/Avatar.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SLACardLabel from './components/SLACardLabel.vue';
import ConversationCallButton from './ConversationCallButton.vue';
import ConversationQuickActions from './ConversationQuickActions.vue';
import { useSellerMode } from 'dashboard/composables/useSellerMode';
import wootConstants from 'dashboard/constants/globals';
import { conversationListPageURL } from 'dashboard/helper/URLHelper';
import { snoozedReopenTime } from 'dashboard/helper/snoozeHelpers';
import { useInbox } from 'dashboard/composables/useInbox';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { copyTextToClipboard } from 'shared/helpers/clipboard';

const props = defineProps({
  chat: {
    type: Object,
    default: () => ({}),
  },
  showBackButton: {
    type: Boolean,
    default: false,
  },
  isSearchOpen: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['toggleSearch']);

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const conversationHeader = ref(null);
const { width } = useElementSize(conversationHeader);
const { isAWebWidgetInbox, isAnEmailChannel } = useInbox();
const { uiSettings, updateUISettings } = useUISettings();
const { isSellerMode } = useSellerMode();

// Like the WhatsApp app: clicking the contact in the header opens (or closes) the contact panel.
const isContactPanelOpen = computed(
  () => !!uiSettings.value.is_contact_sidebar_open
);
const toggleContactPanel = () =>
  updateUISettings({
    is_contact_sidebar_open: !isContactPanelOpen.value,
    is_copilot_panel_open: false,
  });

const currentChat = computed(() => store.getters.getSelectedChat);
const accountId = computed(() => store.getters.getCurrentAccountId);

const chatMetadata = computed(() => props.chat.meta);

const backButtonUrl = computed(() => {
  const {
    params: { inbox_id: inboxId, label, teamId, id: customViewId },
    name,
  } = route;

  const conversationTypeMap = {
    conversation_through_mentions: 'mention',
    conversation_through_participating: 'participating',
    conversation_through_unattended: 'unattended',
  };
  return conversationListPageURL({
    accountId: accountId.value,
    inboxId,
    label,
    teamId,
    conversationType: conversationTypeMap[name],
    customViewId,
  });
});

const isHMACVerified = computed(() => {
  if (!isAWebWidgetInbox.value) {
    return true;
  }
  return chatMetadata.value.hmac_verified;
});

const mailSubject = computed(() => {
  if (!isAnEmailChannel.value) return '';
  return props.chat.additional_attributes?.mail_subject;
});

const currentContact = computed(() =>
  store.getters['contacts/getContact'](props.chat.meta.sender.id)
);

const isSnoozed = computed(
  () => currentChat.value.status === wootConstants.STATUS_TYPE.SNOOZED
);

const snoozedDisplayText = computed(() => {
  const { snoozed_until: snoozedUntil } = currentChat.value;
  if (snoozedUntil) {
    return `${t('CONVERSATION.HEADER.SNOOZED_UNTIL')} ${snoozedReopenTime(snoozedUntil)}`;
  }
  return t('CONVERSATION.HEADER.SNOOZED_UNTIL_NEXT_REPLY');
});

const inbox = computed(() => {
  const { inbox_id: inboxId } = props.chat;
  return store.getters['inboxes/getInbox'](inboxId);
});

const hasMultipleInboxes = computed(
  () => store.getters['inboxes/getInboxes'].length > 1
);

const hasSlaPolicyId = computed(
  () =>
    !isSellerMode.value &&
    props.chat?.applied_sla?.id &&
    !currentContact.value?.blocked
);

// Seller mode hides the "#123" id; keep the "•" separators consistent with what is shown.
const showConversationId = computed(() => !isSellerMode.value);

const copyConversationId = async () => {
  try {
    await copyTextToClipboard(String(props.chat.id));
    useAlert(t('CONVERSATION.HEADER.COPY_ID_SUCCESS'));
  } catch (error) {
    // error
  }
};
</script>

<template>
  <div
    ref="conversationHeader"
    class="flex flex-col gap-2 items-center justify-between flex-1 w-full min-w-0 xl:flex-row px-3 pt-3 pb-2 min-h-24 xl:min-h-12"
  >
    <div
      class="flex items-center justify-start w-full xl:w-auto max-w-full min-w-0 xl:flex-1"
    >
      <BackButton
        v-if="showBackButton"
        :back-url="backButtonUrl"
        class="me-2"
      />
      <div
        role="button"
        tabindex="0"
        class="flex items-center min-w-0 flex-1 rounded-lg cursor-pointer -mx-1 px-1 py-0.5 transition-colors hover:bg-n-alpha-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
        :class="{ 'bg-n-alpha-1': isContactPanelOpen }"
        :title="t('CONVERSATION.SIDEBAR.CONTACT')"
        :aria-label="t('CONVERSATION.SIDEBAR.CONTACT')"
        :aria-expanded="isContactPanelOpen"
        data-testid="contact-panel-toggle"
        @click="toggleContactPanel"
        @keydown.enter.prevent="toggleContactPanel"
        @keydown.space.prevent="toggleContactPanel"
      >
        <Avatar
          :name="currentContact.name"
          :src="currentContact.thumbnail"
          :size="32"
          :status="currentContact.availability_status"
          hide-offline-status
        />
        <div class="flex flex-col items-start min-w-0 ms-2 overflow-hidden">
          <div class="flex flex-row items-center max-w-full gap-1 p-0 m-0">
            <span
              class="text-sm font-medium truncate leading-tight text-n-slate-12"
            >
              {{ currentContact.name }}
            </span>
            <fluent-icon
              v-if="!isHMACVerified"
              v-tooltip="$t('CONVERSATION.UNVERIFIED_SESSION')"
              size="14"
              class="text-n-amber-10 my-0 mx-0 min-w-[14px] flex-shrink-0"
              icon="warning"
            />
          </div>

          <div
            class="flex items-center max-w-full gap-1 overflow-hidden text-xs conversation--header--actions text-n-slate-11 text-ellipsis whitespace-nowrap"
          >
            <button
              v-if="showConversationId"
              type="button"
              class="truncate shrink-0 text-label-small text-n-slate-11 hover:text-n-slate-12 !p-0 cursor-pointer"
              @click.stop="copyConversationId"
            >
              {{ `#${chat.id}` }}
            </button>
            <span v-if="showConversationId && hasMultipleInboxes">•</span>
            <InboxName v-if="hasMultipleInboxes" :inbox="inbox" class="!mx-0" />
            <span v-if="mailSubject">•</span>
            <span
              v-if="mailSubject"
              v-tooltip="mailSubject"
              class="flex-1 min-w-16 truncate text-label-small text-n-slate-11"
            >
              {{ mailSubject }}
            </span>
            <span v-if="isSnoozed">•</span>
            <span
              v-if="isSnoozed"
              class="min-w-0 truncate font-medium text-n-amber-10 shrink-0"
            >
              {{ snoozedDisplayText }}
            </span>
          </div>
        </div>
      </div>
    </div>
    <div
      class="flex flex-row flex-wrap items-center justify-start xl:justify-end flex-shrink-0 gap-2 w-full xl:w-auto header-actions-wrap"
    >
      <SLACardLabel
        v-if="hasSlaPolicyId"
        :chat="chat"
        show-extended-info
        :parent-width="width"
        class="hidden md:flex"
      />
      <ConversationQuickActions :chat="currentChat" />
      <NextButton
        v-tooltip.bottom="t('CONVERSATION.CHAT_SEARCH.OPEN')"
        icon="i-lucide-search"
        size="sm"
        variant="ghost"
        color="slate"
        :class="{ 'bg-n-alpha-2 text-n-slate-12': isSearchOpen }"
        :aria-label="t('CONVERSATION.CHAT_SEARCH.OPEN')"
        :aria-pressed="isSearchOpen"
        data-testid="conversation-search-toggle"
        @click="emit('toggleSearch')"
      />
      <ConversationCallButton :inbox="inbox" :chat="currentChat" />
      <MoreActions :conversation-id="currentChat.id" />
    </div>
  </div>
</template>
