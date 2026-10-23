<script setup>
// Dialer: pick a contact and call. With `inboxes` (Calls page "Nova ligação") the agent first
// picks the line; a single line skips that step. Twilio dials the number right away; WhatsApp
// needs the conversation (the permission lives there), so it opens it and the call button starts the call.
import { computed, ref } from 'vue';
import { useDebounceFn } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useCallsStore } from 'dashboard/stores/calls';
import { useContactConversation } from 'dashboard/composables/useContactConversation';
import ContactAPI from 'dashboard/api/contacts';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import {
  getVoiceCallProvider,
  VOICE_CALL_PROVIDERS,
} from 'dashboard/helper/inbox';
import { fetchContactableInboxes } from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';
import { VOICE_CALL_DIRECTION } from 'dashboard/components-next/message/constants';
import NextButton from 'dashboard/components-next/button/Button.vue';
import InboxName from 'dashboard/components-next/Conversation/InboxName.vue';

const props = defineProps({
  inboxId: { type: [Number, String], default: null },
  inboxes: { type: Array, default: () => [] },
  label: { type: String, default: '' },
  solid: { type: Boolean, default: false },
});

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();
const callsStore = useCallsStore();
const getInbox = useMapGetter('inboxes/getInbox');
const { findOrCreateConversationId } = useContactConversation();

const open = ref(false);
const query = ref('');
const results = ref([]);
const searching = ref(false);
const callingId = ref(null);
const selectedInbox = ref(null);

const inboxOptions = computed(() =>
  props.inboxes.length ? props.inboxes : [getInbox.value(props.inboxId)]
);
const hasInboxChoice = computed(() => inboxOptions.value.length > 1);
const isWhatsapp = computed(
  () =>
    getVoiceCallProvider(selectedInbox.value) === VOICE_CALL_PROVIDERS.WHATSAPP
);

const search = useDebounceFn(async () => {
  const term = query.value.trim();
  if (term.length < 2) {
    results.value = [];
    searching.value = false;
    return;
  }
  searching.value = true;
  try {
    const { data } = await ContactAPI.search(term);
    results.value = (data.payload || []).filter(
      contact => contact.phone_number
    );
  } catch {
    results.value = [];
  } finally {
    searching.value = false;
  }
}, 250);

const onInput = event => {
  query.value = event.target.value;
  searching.value = query.value.trim().length >= 2;
  search();
};

const toggle = () => {
  open.value = !open.value;
  if (open.value) {
    selectedInbox.value = hasInboxChoice.value ? null : inboxOptions.value[0];
  }
};

const close = () => {
  open.value = false;
};

const goToConversation = (conversationId, routeQuery = {}) =>
  router.push({
    path: frontendURL(
      conversationUrl({ accountId: route.params.accountId, id: conversationId })
    ),
    query: routeQuery,
  });

const callByPhone = async contact => {
  const inboxId = selectedInbox.value.id;
  const response = await store.dispatch('contacts/initiateCall', {
    contactId: contact.id,
    inboxId,
  });
  callsStore.addCall({
    callSid: response?.call_sid,
    conversationId: response?.conversation_id,
    inboxId: Number(inboxId),
    callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
  });
  useAlert(t('CONTACT_PANEL.CALL_INITIATED'));
  if (response?.conversation_id) goToConversation(response.conversation_id);
};

const callByWhatsapp = async contact => {
  const contactable = (await fetchContactableInboxes(contact.id)).find(
    inbox => inbox.id === selectedInbox.value.id
  );
  if (!contactable) {
    useAlert(t('CHAT_LIST.VOICE_DIAL.NOT_ON_INBOX'));
    return;
  }
  const conversationId = await findOrCreateConversationId(
    contact.id,
    contactable
  );
  // ConversationCallButton starts the WhatsApp call (or the permission request) on arrival.
  goToConversation(conversationId, {
    start_call: VOICE_CALL_PROVIDERS.WHATSAPP,
  });
};

const callContact = async contact => {
  const blocked =
    callingId.value || callsStore.hasActiveCall || callsStore.hasIncomingCall;
  if (blocked) return;
  callingId.value = contact.id;
  try {
    await (isWhatsapp.value ? callByWhatsapp(contact) : callByPhone(contact));
    close();
  } catch (error) {
    useAlert(error?.message || t('CONTACT_PANEL.CALL_FAILED'));
  } finally {
    callingId.value = null;
  }
};
</script>

<template>
  <div class="relative">
    <NextButton
      :label="label || t('CHAT_LIST.VOICE_DIAL.BUTTON')"
      icon="i-lucide-phone"
      :slate="!solid"
      :faded="!solid"
      :xs="!solid"
      :sm="solid"
      data-testid="voice-dialer-button"
      @click="toggle"
    />
    <button
      v-if="open"
      type="button"
      class="fixed inset-0 z-20 cursor-default"
      :aria-label="t('CHAT_LIST.VOICE_DIAL.BUTTON')"
      @click="close"
    />
    <div
      v-if="open"
      class="absolute z-30 mt-2 w-72 rounded-lg border border-n-weak bg-n-solid-2 p-2 shadow-lg ltr:right-0 rtl:left-0"
    >
      <template v-if="!selectedInbox">
        <p class="px-1 pb-1 text-sm font-medium text-n-slate-12">
          {{ t('CHAT_LIST.VOICE_DIAL.CHOOSE_INBOX') }}
        </p>
        <button
          v-for="inbox in inboxOptions"
          :key="inbox.id"
          type="button"
          class="flex w-full items-center rounded-md px-2 py-2 text-start hover:bg-n-alpha-2"
          data-testid="voice-dialer-inbox"
          @click="selectedInbox = inbox"
        >
          <InboxName :inbox="inbox" />
        </button>
      </template>
      <template v-else>
        <div
          v-if="hasInboxChoice"
          class="flex items-center justify-between gap-2 px-1 pb-2"
        >
          <InboxName :inbox="selectedInbox" />
          <button
            type="button"
            class="shrink-0 text-xs text-n-slate-11 hover:text-n-slate-12"
            @click="selectedInbox = null"
          >
            {{ t('CHAT_LIST.VOICE_DIAL.CHANGE_INBOX') }}
          </button>
        </div>
        <input
          :value="query"
          type="search"
          class="w-full rounded-md border border-n-weak bg-n-background px-2 py-1.5 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          :placeholder="t('CHAT_LIST.VOICE_DIAL.PLACEHOLDER')"
          @input="onInput"
        />
        <p v-if="isWhatsapp" class="px-1 pt-1.5 text-xs text-n-slate-11">
          {{ t('CHAT_LIST.VOICE_DIAL.WHATSAPP_HINT') }}
        </p>
        <p
          v-if="query.trim().length >= 2 && !searching && !results.length"
          class="px-1 py-2 text-sm text-n-slate-11"
        >
          {{ t('CHAT_LIST.VOICE_DIAL.EMPTY') }}
        </p>
        <ul v-else class="mt-1 max-h-64 overflow-y-auto">
          <li v-for="contact in results" :key="contact.id">
            <button
              type="button"
              class="flex w-full flex-col rounded-md px-2 py-1.5 text-start hover:bg-n-alpha-2 disabled:opacity-50"
              :disabled="callingId === contact.id"
              @click="callContact(contact)"
            >
              <span class="truncate text-sm text-n-slate-12">{{
                contact.name
              }}</span>
              <span class="truncate text-xs text-n-slate-11">{{
                contact.phone_number
              }}</span>
            </button>
          </li>
        </ul>
      </template>
    </div>
  </div>
</template>
