<script setup>
import { computed, ref, watch } from 'vue';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import {
  getVoiceCallProvider,
  INBOX_TYPES,
  VOICE_CALL_PROVIDERS,
} from 'dashboard/helper/inbox';
import {
  VOICE_CALL_DIRECTION,
  VOICE_CALL_OUTBOUND_INIT_STATUS,
} from 'dashboard/components-next/message/constants';
import { useWhatsappCallSession } from 'dashboard/composables/useWhatsappCallSession';
import { useCallsStore } from 'dashboard/stores/calls';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useAlert } from 'dashboard/composables';
import WhatsappCallsAPI from 'dashboard/api/channel/whatsapp/whatsappCallsAPI';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
  chat: {
    type: Object,
    default: () => ({}),
  },
});

const MODES = { WHATSAPP: 'whatsapp', PHONE: 'phone' };

const { t } = useI18n();
const store = useStore();
const callsStore = useCallsStore();
const whatsappCallSession = useWhatsappCallSession();
const contactsUiFlags = useMapGetter('contacts/getUIFlags');
const inboxesList = useMapGetter('inboxes/getInboxes');
const { isCloudFeatureEnabled } = useAccount();
const [showMenu, toggleMenu] = useToggle(false);

const isVoiceEnabled = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CHANNEL_VOICE)
);
const voiceCallProvider = computed(() => getVoiceCallProvider(props.inbox));
const canWhatsappCall = computed(
  () =>
    isVoiceEnabled.value &&
    voiceCallProvider.value === VOICE_CALL_PROVIDERS.WHATSAPP
);

// A Twilio conversation calls through its own inbox; a WhatsApp one through the first
// Twilio voice inbox the agent can use (the list only holds inboxes they can access).
const phoneInbox = computed(() => {
  if (!isVoiceEnabled.value) return null;
  if (voiceCallProvider.value === VOICE_CALL_PROVIDERS.TWILIO)
    return props.inbox;
  if (props.inbox?.channel_type !== INBOX_TYPES.WHATSAPP) return null;
  return (
    (inboxesList.value || []).find(
      inbox => getVoiceCallProvider(inbox) === VOICE_CALL_PROVIDERS.TWILIO
    ) || null
  );
});
const contactPhone = computed(() => props.chat?.meta?.sender?.phone_number);
const canPhoneCall = computed(() => !!phoneInbox.value && !!contactPhone.value);

const shouldRender = computed(
  () => canWhatsappCall.value || !!phoneInbox.value
);
const hasChoice = computed(() => canWhatsappCall.value && !!phoneInbox.value);

// What the contact allowed us to do, so the agent sees the WhatsApp rules before clicking.
const permission = ref(null);

const loadPermission = async () => {
  if (!canWhatsappCall.value || !props.chat?.id) {
    permission.value = null;
    return;
  }
  try {
    permission.value = await WhatsappCallsAPI.permissionStatus({
      conversationId: props.chat.id,
    });
  } catch (_) {
    permission.value = null;
  }
};

watch(() => [props.chat?.id, props.inbox?.id], loadPermission, {
  immediate: true,
});

// Click without choosing: WhatsApp when the customer already allows it, otherwise the
// phone line; WhatsApp (which asks for permission) when there is no phone option.
const autoMode = computed(() => {
  if (!canWhatsappCall.value) return MODES.PHONE;
  if (!canPhoneCall.value || permission.value?.can_call) return MODES.WHATSAPP;
  return MODES.PHONE;
});

const formatDate = unix => new Date(unix * 1000).toLocaleString();

const whatsappStatusText = computed(() => {
  const info = permission.value;
  if (!info || info.status === 'unknown') return '';
  if (info.can_call) {
    return info.status === 'temporary' && info.expires_at
      ? t('CALL_FLOW.WHATSAPP_STATUS.CAN_CALL_UNTIL', {
          date: formatDate(info.expires_at),
        })
      : t('CALL_FLOW.WHATSAPP_STATUS.CAN_CALL');
  }
  if (['temporary', 'permanent'].includes(info.status)) {
    return t('CALL_FLOW.WHATSAPP_STATUS.CALL_LIMIT');
  }
  if (info.can_request) return t('CALL_FLOW.WHATSAPP_STATUS.WILL_ASK');
  return info.request_limit_reset_at
    ? t('CALL_FLOW.WHATSAPP_STATUS.REQUEST_LIMIT_UNTIL', {
        date: formatDate(info.request_limit_reset_at),
      })
    : t('CALL_FLOW.WHATSAPP_STATUS.REQUEST_LIMIT');
});

const phoneStatusText = computed(() =>
  contactPhone.value
    ? t('CALL_FLOW.PHONE_STATUS.CALLS', { phone: contactPhone.value })
    : t('CALL_FLOW.PHONE_STATUS.NO_PHONE')
);

const isInitiating = computed(
  () =>
    whatsappCallSession.isInitiating.value ||
    !!contactsUiFlags.value?.isInitiatingCall
);
const isBusy = computed(
  () =>
    callsStore.hasActiveCall || callsStore.hasIncomingCall || isInitiating.value
);
const isCallButtonDisabled = computed(
  () => isBusy.value || (autoMode.value === MODES.PHONE && !canPhoneCall.value)
);

const callButtonTooltip = computed(() => {
  if (autoMode.value === MODES.WHATSAPP) {
    const base = t('CALL_FLOW.WHATSAPP');
    return whatsappStatusText.value
      ? `${base}: ${whatsappStatusText.value}`
      : base;
  }
  return `${t('CALL_FLOW.PHONE')}: ${phoneStatusText.value}`;
});

const startWhatsappCall = async () => {
  if (whatsappCallSession.isInitiating.value) return;
  try {
    const response = await whatsappCallSession.initiateOutboundCall({
      conversationId: props.chat.id,
    });

    // Composable returns LOCKED when init is already in flight or a call is
    // active; soft no-op so a parallel click doesn't trigger a banner.
    if (response?.status === VOICE_CALL_OUTBOUND_INIT_STATUS.LOCKED) return;
    // Permission template path returns no call id — show banner, no widget yet.
    if (!response?.id) {
      const status = response?.status;
      const messageKey =
        status === VOICE_CALL_OUTBOUND_INIT_STATUS.PERMISSION_PENDING
          ? 'CONVERSATION.HEADER.WHATSAPP_CALL_PERMISSION_PENDING'
          : 'CONVERSATION.HEADER.WHATSAPP_CALL_PERMISSION_REQUESTED';
      useAlert(t(messageKey));
      loadPermission();
      return;
    }

    // Stay non-active until Meta delivers the connect webhook (sdp_answer);
    // flipping to active here would start the duration timer before pickup.
    callsStore.addCall({
      callSid: response.call_id,
      callId: response.id,
      conversationId: props.chat.id,
      inboxId: props.inbox?.id,
      callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
      provider: VOICE_CALL_PROVIDERS.WHATSAPP,
    });
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('CONVERSATION.HEADER.WHATSAPP_CALL_FAILED')
    );
    loadPermission();
  }
};

// The server logs the call in this conversation (Twilio or the contact's open WhatsApp
// thread), so the agent stays here; the Call itself keeps the voice inbox.
const startPhoneCall = async () => {
  if (contactsUiFlags.value?.isInitiatingCall) return;
  try {
    const response = await store.dispatch('contacts/initiateCall', {
      contactId: props.chat?.meta?.sender?.id,
      inboxId: phoneInbox.value.id,
      conversationId: props.chat.id,
    });

    callsStore.addCall({
      callSid: response?.call_sid,
      conversationId: response?.conversation_id ?? props.chat.id,
      inboxId: phoneInbox.value.id,
      callDirection: VOICE_CALL_DIRECTION.OUTBOUND,
    });
  } catch (error) {
    useAlert(error?.message || t('CONVERSATION.HEADER.VOICE_CALL_FAILED'));
  }
};

// "Nova ligação" on the Calls page opens the WhatsApp thread with ?start_call=whatsapp: dial on arrival.
const route = useRoute();
const router = useRouter();
watch(
  () => [route.query.start_call, props.chat?.id, canWhatsappCall.value],
  ([mode, chatId, canCall]) => {
    const isThisConversation =
      chatId && String(route.params.conversation_id) === String(chatId);
    if (mode !== MODES.WHATSAPP || !canCall || !isThisConversation) return;
    router.replace({ query: { ...route.query, start_call: undefined } });
    startWhatsappCall();
  },
  { immediate: true }
);

const startCall = mode => {
  showMenu.value = false;
  if (mode === MODES.WHATSAPP) return startWhatsappCall();
  return startPhoneCall();
};
</script>

<template>
  <span
    v-if="shouldRender"
    v-on-click-outside="() => (showMenu = false)"
    class="relative inline-flex items-center"
  >
    <NextButton
      v-tooltip.bottom="callButtonTooltip"
      sm
      ghost
      slate
      icon="i-lucide-phone"
      :label="t('CALL_FLOW.CALL')"
      :is-loading="isInitiating"
      :disabled="isCallButtonDisabled"
      @click="startCall(autoMode)"
    />
    <NextButton
      v-if="hasChoice"
      v-tooltip.bottom="t('CALL_FLOW.CHOOSE')"
      sm
      ghost
      slate
      icon="i-lucide-chevron-down"
      :aria-label="t('CALL_FLOW.CHOOSE')"
      :aria-expanded="showMenu"
      :disabled="isBusy"
      @click="toggleMenu()"
    />
    <div
      v-if="showMenu"
      class="absolute top-full mt-1 ltr:right-0 rtl:left-0 z-50 flex flex-col gap-1 p-2 w-72 rounded-xl bg-n-alpha-3 backdrop-blur-[100px] outline outline-1 outline-n-container shadow-lg"
    >
      <button
        type="button"
        class="flex items-start gap-2 w-full px-2 py-1.5 text-start rounded-lg hover:bg-n-alpha-2"
        @click="startCall(MODES.WHATSAPP)"
      >
        <span
          class="i-ri-whatsapp-line size-4 mt-0.5 shrink-0 text-n-slate-11"
        />
        <span class="flex flex-col min-w-0">
          <span class="text-sm text-n-slate-12">{{
            t('CALL_FLOW.WHATSAPP')
          }}</span>
          <span v-if="whatsappStatusText" class="text-xs text-n-slate-11">
            {{ whatsappStatusText }}
          </span>
        </span>
      </button>
      <button
        type="button"
        class="flex items-start gap-2 w-full px-2 py-1.5 text-start rounded-lg hover:bg-n-alpha-2 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent"
        :disabled="!canPhoneCall"
        @click="startCall(MODES.PHONE)"
      >
        <span class="i-lucide-phone size-4 mt-0.5 shrink-0 text-n-slate-11" />
        <span class="flex flex-col min-w-0">
          <span class="text-sm text-n-slate-12">{{
            t('CALL_FLOW.PHONE')
          }}</span>
          <span class="text-xs text-n-slate-11">{{ phoneStatusText }}</span>
        </span>
      </button>
    </div>
  </span>
  <template v-else />
</template>
