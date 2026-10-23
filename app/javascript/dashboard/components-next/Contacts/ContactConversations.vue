<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ConversationCard from 'dashboard/components-next/Conversation/ConversationCard/ConversationCard.vue';

// The conversations of a contact, most recent first, on the contact page itself: no need to dig into
// the sidebar tabs to find where the lead was last talked to.
const props = defineProps({
  contactId: { type: [String, Number], required: true },
  limit: { type: Number, default: 5 },
});

const { t } = useI18n();

const conversationsByContactId = useMapGetter(
  'contactConversations/getAllConversationsByContactId'
);
const contactsById = useMapGetter('contacts/getContactById');
const stateInbox = useMapGetter('inboxes/getInboxById');
const accountLabels = useMapGetter('labels/getLabels');
const uiFlags = useMapGetter('contactConversations/getUIFlags');

const isFetching = computed(() => uiFlags.value?.isFetching);

const sortedConversations = computed(() =>
  [...(conversationsByContactId.value(props.contactId) || [])].sort(
    (a, b) => (b.lastActivityAt || 0) - (a.lastActivityAt || 0)
  )
);
const visibleConversations = computed(() =>
  sortedConversations.value.slice(0, props.limit)
);
const hiddenCount = computed(() =>
  Math.max(sortedConversations.value.length - props.limit, 0)
);
</script>

<template>
  <section
    class="flex flex-col w-full gap-3"
    data-testid="contact-conversations"
  >
    <header class="flex items-center gap-2">
      <h4 class="text-base font-medium text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.DETAILS.CONVERSATIONS.TITLE') }}
      </h4>
      <span
        v-if="sortedConversations.length"
        class="px-1.5 text-xs rounded-full bg-n-alpha-2 text-n-slate-11"
      >
        {{ sortedConversations.length }}
      </span>
    </header>
    <div v-if="isFetching" class="flex justify-center py-4 text-n-slate-11">
      <Spinner />
    </div>
    <div
      v-else-if="visibleConversations.length"
      class="overflow-hidden border divide-y rounded-xl border-n-strong divide-n-strong"
    >
      <ConversationCard
        v-for="conversation in visibleConversations"
        :key="conversation.id"
        :conversation="conversation"
        :contact="contactsById(conversation.meta?.sender?.id)"
        :state-inbox="stateInbox(conversation.inboxId)"
        :account-labels="accountLabels"
        class="rounded-none hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3"
      />
    </div>
    <p v-else class="text-sm text-n-slate-11">
      {{ t('CONTACTS_LAYOUT.DETAILS.CONVERSATIONS.EMPTY_STATE') }}
    </p>
    <p v-if="hiddenCount" class="text-xs text-n-slate-10">
      {{
        t('CONTACTS_LAYOUT.DETAILS.CONVERSATIONS.MORE', { count: hiddenCount })
      }}
    </p>
  </section>
</template>
