<script setup>
import { computed, reactive } from 'vue';
import { useI18n } from 'vue-i18n';
import Message from './Message.vue';
import CampaignMessage from './CampaignMessage.vue';
import DateDivider from './DateDivider.vue';
import {
  dayKey,
  daySeparatorLabel,
  withDaySeparators,
} from './helpers/daySeparator.js';
import { MESSAGE_TYPES } from './constants.js';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import { useMapGetter } from 'dashboard/composables/store.js';
import MessageApi from 'dashboard/api/inbox/message.js';

/**
 * Props definition for the component
 * @typedef {Object} Props
 * @property {Array} readMessages - Array of read messages
 * @property {Array} unReadMessages - Array of unread messages
 * @property {Number} currentUserId - ID of the current user
 * @property {Boolean} isAnEmailChannel - Whether this is an email channel
 * @property {Object} inboxSupportsReplyTo - Inbox reply support configuration
 * @property {Array} messages - Array of all messages [These are not in camelcase]
 */
const props = defineProps({
  currentUserId: {
    type: Number,
    required: true,
  },
  firstUnreadId: {
    type: Number,
    default: null,
  },
  isAnEmailChannel: {
    type: Boolean,
    default: false,
  },
  inboxSupportsReplyTo: {
    type: Object,
    default: () => ({ incoming: false, outgoing: false }),
  },
  messages: {
    type: Array,
    default: () => [],
  },
  campaignHistory: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['retry']);

const allMessages = computed(() => {
  return useCamelCase(props.messages, {
    deep: true,
    stopPaths: [
      'content_attributes.translations',
      'content_attributes.whatsapp_flow_response.response_json',
    ],
  });
});

const currentChat = useMapGetter('getSelectedChat');
const { t, locale } = useI18n();

const dateLabel = timestamp =>
  daySeparatorLabel(timestamp, {
    locale: locale.value,
    todayLabel: t('CONVERSATION.DAY_TODAY'),
    yesterdayLabel: t('CONVERSATION.DAY_YESTERDAY'),
  });

const entries = computed(() => {
  const messages = allMessages.value.map(message => ({
    key: `message-${message.id}`,
    createdAt: message.createdAt,
    message,
  }));
  if (!props.campaignHistory.length) return messages;

  return [
    ...messages,
    ...props.campaignHistory.map(recipient => ({
      key: `campaign-${recipient.id}`,
      createdAt: recipient.sent_at,
      recipient,
    })),
  ].sort((a, b) => a.createdAt - b.createdAt);
});

// Messages and campaign entries in order, with a small divider before the first one of each day.
const timeline = computed(() => withDaySeparators(entries.value));

// Cache for fetched reply messages to avoid duplicate API calls
const fetchedReplyMessages = reactive(new Map());

/**
 * Fetches a specific message from the API by trying to get messages around it
 * @param {number} messageId - The ID of the message to fetch
 * @param {number} conversationId - The ID of the conversation
 * @returns {Promise<Object|null>} - The fetched message or null if not found/error
 */
const fetchReplyMessage = async (messageId, conversationId) => {
  // Return cached result if already fetched
  if (fetchedReplyMessages.has(messageId)) {
    return fetchedReplyMessages.get(messageId);
  }

  try {
    const response = await MessageApi.getPreviousMessages({
      conversationId,
      before: messageId + 100,
      after: messageId - 100,
    });

    const messages = response.data?.payload || [];
    const targetMessage = messages.find(msg => msg.id === messageId);

    if (targetMessage) {
      const camelCaseMessage = useCamelCase(targetMessage);
      fetchedReplyMessages.set(messageId, camelCaseMessage);
      return camelCaseMessage;
    }

    // Cache null result to avoid repeated API calls
    fetchedReplyMessages.set(messageId, null);
    return null;
  } catch (error) {
    fetchedReplyMessages.set(messageId, null);
    return null;
  }
};

// Template messages are shown like outgoing ones.
const messageSide = messageType =>
  messageType === MESSAGE_TYPES.TEMPLATE ? MESSAGE_TYPES.OUTGOING : messageType;

// Messages from the same sender further apart than this start a new group.
const MAX_GROUP_GAP_SECONDS = 10 * 60;

/**
 * Determines if a message should be grouped with the next message
 * @param {Object} current - Current message
 * @param {Object} next - Next message, absent at a campaign entry or the end
 * @returns {Boolean} - Whether the message should be grouped with next
 */
const shouldGroupWithNext = (current, next) => {
  if (!next || next.status === 'failed') return false;

  const nextSenderId = next.senderId ?? next.sender?.id;
  const currentSenderId = current.senderId ?? current.sender?.id;
  if (nextSenderId !== currentSenderId) return false;

  // Automated messages (bot replies, forms, cards...) come as outgoing or template messages and are drawn on
  // the same side with the same colour, so they group together; a person's messages never mix with them
  // because the sender differs.
  if (messageSide(current.messageType) !== messageSide(next.messageType)) {
    return false;
  }

  // Same sender, same day and no long pause in between: they read as one block.
  if (dayKey(next.createdAt) !== dayKey(current.createdAt)) return false;
  return next.createdAt - current.createdAt <= MAX_GROUP_GAP_SECONDS;
};

/**
 * Gets the message that was replied to
 * @param {Object} parentMessage - The message containing the reply reference
 * @returns {Object|null} - The message being replied to, or null if not found
 */
const getInReplyToMessage = parentMessage => {
  if (!parentMessage) return null;

  const inReplyToMessageId =
    parentMessage.contentAttributes?.inReplyTo ??
    parentMessage.content_attributes?.in_reply_to;

  if (!inReplyToMessageId) return null;

  // Try to find in current messages first
  let replyMessage = props.messages?.find(msg => msg.id === inReplyToMessageId);

  // Then try store messages
  if (!replyMessage && currentChat.value?.messages) {
    replyMessage = currentChat.value.messages.find(
      msg => msg.id === inReplyToMessageId
    );
  }

  // Then check fetch cache
  if (!replyMessage && fetchedReplyMessages.has(inReplyToMessageId)) {
    replyMessage = fetchedReplyMessages.get(inReplyToMessageId);
  }

  // If still not found and we have conversation context, fetch it
  if (!replyMessage && currentChat.value?.id) {
    fetchReplyMessage(inReplyToMessageId, currentChat.value.id);
    return null; // Let UI handle loading state
  }

  return replyMessage ? useCamelCase(replyMessage) : null;
};
</script>

<template>
  <ul class="px-4 bg-n-surface-1">
    <slot name="beforeAll" />
    <template v-for="(entry, index) in timeline" :key="entry.key">
      <slot
        v-if="firstUnreadId && entry.message?.id === firstUnreadId"
        name="unreadBadge"
      />
      <DateDivider v-if="entry.date" :label="dateLabel(entry.date)" />
      <CampaignMessage
        v-else-if="entry.recipient"
        :recipient="entry.recipient"
      />
      <Message
        v-else
        v-bind="entry.message"
        :is-email-inbox="isAnEmailChannel"
        :in-reply-to="getInReplyToMessage(entry.message)"
        :group-with-next="
          shouldGroupWithNext(entry.message, timeline[index + 1]?.message)
        "
        :inbox-supports-reply-to="inboxSupportsReplyTo"
        :current-user-id="currentUserId"
        data-clarity-mask="True"
        @retry="emit('retry', entry.message)"
      />
    </template>
    <slot name="after" />
  </ul>
</template>
