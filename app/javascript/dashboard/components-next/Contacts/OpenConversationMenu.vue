<script setup>
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useContactConversation } from 'dashboard/composables/useContactConversation';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { fetchContactableInboxes } from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';

import Popover from 'dashboard/components-next/popover/Popover.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import InboxName from 'dashboard/components-next/Conversation/InboxName.vue';

// Opens the conversation with a contact without having to write a message first: pick the inbox and
// the existing thread opens, or an empty one is created in that inbox.
const props = defineProps({
  contactId: { type: [String, Number], required: true },
  align: { type: String, default: 'end' },
});

const router = useRouter();
const { t } = useI18n();
const { accountId } = useAccount();
const { findOrCreateConversationId } = useContactConversation();

const popoverRef = ref(null);
const inboxes = ref([]);
const isLoading = ref(false);
const openingInboxId = ref(null);

const stateInbox = useMapGetter('inboxes/getInboxById');

const options = computed(() =>
  inboxes.value.map(inbox => ({
    ...inbox,
    // The store inbox carries the channel details the icon needs.
    display: stateInbox.value(inbox.id) || inbox,
  }))
);

const loadInboxes = async () => {
  isLoading.value = true;
  try {
    inboxes.value = await fetchContactableInboxes(props.contactId);
  } catch (error) {
    inboxes.value = [];
    useAlert(t('CONTACTS_LAYOUT.OPEN_CONVERSATION.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const goToConversation = id =>
  router.push(frontendURL(`accounts/${accountId.value}/conversations/${id}`));

const openIn = async inbox => {
  if (openingInboxId.value) return;
  openingInboxId.value = inbox.id;
  try {
    const conversationId = await findOrCreateConversationId(
      props.contactId,
      inbox
    );
    popoverRef.value?.hide();
    goToConversation(conversationId);
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.OPEN_CONVERSATION.OPEN_ERROR'));
  } finally {
    openingInboxId.value = null;
  }
};
</script>

<template>
  <Popover
    ref="popoverRef"
    :align="align"
    :close-on-scroll="false"
    @show="loadInboxes"
  >
    <template #default="{ isOpen }">
      <slot name="trigger" :is-open="isOpen" />
    </template>
    <template #content>
      <div
        class="flex flex-col w-72 max-w-[calc(100vw-2rem)] gap-1 p-2"
        data-testid="open-conversation-menu"
      >
        <p class="px-2 pt-1 pb-0.5 text-sm font-medium text-n-slate-12">
          {{ t('CONTACTS_LAYOUT.OPEN_CONVERSATION.TITLE') }}
        </p>
        <div v-if="isLoading" class="flex justify-center py-4 text-n-slate-11">
          <Spinner />
        </div>
        <p
          v-else-if="!options.length"
          class="px-2 py-2 text-sm text-n-slate-11"
        >
          {{ t('CONTACTS_LAYOUT.OPEN_CONVERSATION.EMPTY') }}
        </p>
        <template v-else>
          <button
            v-for="inbox in options"
            :key="inbox.id"
            type="button"
            class="flex items-center justify-between gap-2 px-2 py-2 text-start rounded-lg hover:bg-n-alpha-2 disabled:opacity-60"
            :disabled="!!openingInboxId"
            data-testid="open-conversation-inbox"
            @click="openIn(inbox)"
          >
            <InboxName :inbox="inbox.display" />
            <Spinner v-if="openingInboxId === inbox.id" class="size-4" />
          </button>
        </template>
      </div>
    </template>
  </Popover>
</template>
