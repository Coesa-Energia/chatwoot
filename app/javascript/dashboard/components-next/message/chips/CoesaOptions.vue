<script setup>
// COESA: buttons on a private note from an AgentBot (e.g. the "Agente Comercial" seller helper).
// The bot sends content_attributes.coesa_opcoes = [{ titulo, resposta }]. A click posts `resposta`
// as a private note from the logged-in agent, replying to the bot note (in_reply_to), so the bot
// reads it like a typed answer and the dashboard shows it quoted with the bot's message.
// Once the note has a reply the buttons lock and the chosen one is marked (survives a reload).
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { MESSAGE_STATUS } from '../constants';
import { useMessageContext } from '../provider.js';

const { t } = useI18n();
const store = useStore();
const { id, conversationId, contentAttributes, isPrivate, sender, senderType } =
  useMessageContext();
const currentChat = useMapGetter('getSelectedChat');
const currentUser = useMapGetter('getCurrentUser');
const sending = ref(null);

const normalizeType = type => (type || '').toLowerCase().replace(/[^a-z]/g, '');

const isFromAgentBot = computed(
  () => normalizeType(sender.value?.type ?? senderType.value) === 'agentbot'
);

const options = computed(() => {
  if (!isPrivate.value || !isFromAgentBot.value) return [];
  const raw = contentAttributes.value?.coesaOpcoes;
  if (!Array.isArray(raw)) return [];
  return raw
    .filter(
      option =>
        typeof option?.titulo === 'string' &&
        option.titulo.trim() &&
        typeof option?.resposta === 'string' &&
        option.resposta.trim()
    )
    .map(option => ({
      titulo: option.titulo.trim(),
      resposta: option.resposta.trim(),
    }));
});

// Raw store messages: the server copy uses content_attributes, a pending one contentAttributes.
const replyTarget = message =>
  (message.content_attributes || message.contentAttributes || {}).in_reply_to;

const answer = computed(() => {
  const reply = (currentChat.value?.messages || []).find(
    message =>
      message.private &&
      message.status !== MESSAGE_STATUS.FAILED &&
      Number(replyTarget(message)) === Number(id.value)
  );
  return reply ? (reply.content || '').trim() : null;
});

const isAnswered = computed(() => answer.value !== null || !!sending.value);
const chosen = computed(() => sending.value ?? answer.value);

const choose = async option => {
  if (isAnswered.value) return;
  sending.value = option.resposta;
  try {
    await store.dispatch('createPendingMessageAndSend', {
      conversationId: conversationId.value,
      message: option.resposta,
      private: true,
      sender: {
        name: currentUser.value?.name,
        thumbnail: currentUser.value?.avatar_url,
      },
      contentAttributes: { in_reply_to: id.value },
    });
  } finally {
    sending.value = null;
  }
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div
    v-if="options.length"
    class="flex flex-wrap gap-2"
    role="group"
    :aria-label="t('CONVERSATION.COESA_OPTIONS.LABEL')"
    data-testid="coesa-options"
  >
    <button
      v-for="option in options"
      :key="option.resposta"
      type="button"
      class="skip-context-menu inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-lg outline outline-1 -outline-offset-1 transition-colors focus-visible:outline-2 focus-visible:outline-n-amber-10"
      :class="
        chosen === option.resposta
          ? 'bg-n-amber-9 outline-n-amber-10 text-n-amber-12 dark:text-n-amber-3'
          : isAnswered
            ? 'bg-transparent outline-n-amber-6 text-n-amber-11 opacity-60 cursor-not-allowed'
            : 'bg-n-amber-3 outline-n-amber-7 text-n-amber-12 hover:bg-n-amber-4 cursor-pointer'
      "
      :disabled="isAnswered"
      :aria-pressed="chosen === option.resposta"
      :title="
        chosen === option.resposta ? t('CONVERSATION.COESA_OPTIONS.CHOSEN') : ''
      "
      data-testid="coesa-option"
      @click="choose(option)"
    >
      <span
        v-if="chosen === option.resposta"
        class="i-lucide-check size-4 shrink-0"
      />
      <span class="truncate">{{ option.titulo }}</span>
    </button>
  </div>
</template>
