<script setup>
import { computed } from 'vue';

import MessageMeta from '../MessageMeta.vue';
import CaptainGenerationDetails from '../CaptainGenerationDetails.vue';
import TranslationToggle from '../TranslationToggle.vue';

import { emitter } from 'shared/helpers/mitt';
import { useMessageContext } from '../provider.js';
import { useI18n } from 'vue-i18n';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { MESSAGE_STATUS, MESSAGE_VARIANTS, ORIENTATION } from '../constants';

const props = defineProps({
  hideMeta: { type: Boolean, default: false },
});

const {
  variant,
  orientation,
  inReplyTo,
  id,
  isCaptainMessage,
  showingOriginal,
  sender,
  senderType,
  status,
  additionalAttributes,
} = useMessageContext();
const { t } = useI18n();

const isPrivateNote = computed(
  () => variant.value === MESSAGE_VARIANTS.PRIVATE
);

// A note not typed by a person: AgentBot (incl. automation profiles), Captain or the system
// (no sender; a note still being sent has none yet either, so it is skipped).
const AUTOMATED_SENDER_TYPES = ['agentbot', 'captainassistant'];
const isAutomatedNote = computed(() => {
  if (!isPrivateNote.value) return false;
  if (!sender.value) return status.value !== MESSAGE_STATUS.PROGRESS;
  const type = (sender.value.type ?? senderType.value ?? '')
    .toLowerCase()
    .replace(/[^a-z]/g, '');
  return AUTOMATED_SENDER_TYPES.includes(type);
});

const noteAuthor = computed(
  () => sender.value?.name || additionalAttributes.value?.senderName || ''
);

const metaColorClass = computed(() =>
  variant.value === MESSAGE_VARIANTS.PRIVATE
    ? 'text-n-amber-12/50'
    : 'text-n-slate-11'
);

const emailMetaClass = computed(() =>
  variant.value === MESSAGE_VARIANTS.EMAIL ? 'px-3 pb-3' : ''
);

const varaintBaseMap = {
  [MESSAGE_VARIANTS.AGENT]: 'bg-n-solid-blue text-n-slate-12',
  [MESSAGE_VARIANTS.PRIVATE]:
    'bg-n-solid-amber text-n-amber-12 [&_.prosemirror-mention-node]:font-semibold',
  [MESSAGE_VARIANTS.USER]:
    'bg-n-solid-1 dark:bg-n-solid-3 text-n-slate-12 shadow-[0_1px_2px_rgb(0_0_0/0.06)] outline outline-1 -outline-offset-1 outline-n-weak',
  [MESSAGE_VARIANTS.ACTIVITY]: 'bg-n-alpha-1 text-n-slate-11 text-sm',
  [MESSAGE_VARIANTS.BOT]: 'bg-n-slate-4 text-n-slate-12',
  [MESSAGE_VARIANTS.TEMPLATE]: 'bg-n-slate-4 text-n-slate-12',
  [MESSAGE_VARIANTS.ERROR]: 'bg-n-ruby-4 text-n-ruby-12',
  [MESSAGE_VARIANTS.EMAIL]: 'w-full',
  [MESSAGE_VARIANTS.UNSUPPORTED]:
    'bg-n-solid-amber/70 border border-dashed border-n-amber-12 text-n-amber-12',
};

const orientationMap = {
  [ORIENTATION.LEFT]:
    'left-bubble rounded-2xl ltr:rounded-bl-md rtl:rounded-br-md',
  [ORIENTATION.RIGHT]:
    'right-bubble rounded-2xl ltr:rounded-br-md rtl:rounded-bl-md',
  [ORIENTATION.CENTER]: 'rounded-md',
};

const flexOrientationClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'justify-start',
    [ORIENTATION.RIGHT]: 'justify-end',
    [ORIENTATION.CENTER]: 'justify-center',
  };

  return map[orientation.value];
});

const messageClass = computed(() => {
  const classToApply = [varaintBaseMap[variant.value]];

  // Never confused with a message the customer receives: accent bar + outline, stronger for automations.
  if (isPrivateNote.value) {
    classToApply.push(
      'border-s-4 outline outline-1 -outline-offset-1',
      isAutomatedNote.value
        ? 'border-n-amber-10 outline-n-amber-8'
        : 'border-n-amber-9 outline-n-amber-6'
    );
  }

  if (variant.value !== MESSAGE_VARIANTS.ACTIVITY) {
    classToApply.push(orientationMap[orientation.value]);
  } else {
    classToApply.push('rounded-lg');
  }

  return classToApply;
});

const scrollToMessage = () => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
    messageId: inReplyTo.value.id,
  });
};

// Every message shows its time (the day is on the divider), grouped or not.
const shouldShowMeta = computed(
  () => !props.hideMeta && variant.value !== MESSAGE_VARIANTS.ACTIVITY
);

const replyToPreview = computed(() => {
  if (!inReplyTo) return '';

  const { content, attachments } = inReplyTo.value;

  if (content) return new MessageFormatter(content).formattedMessage;
  if (attachments?.length) {
    const firstAttachment = attachments[0];
    const fileType = firstAttachment.fileType ?? firstAttachment.file_type;

    return t(`CHAT_LIST.ATTACHMENTS.${fileType}.CONTENT`);
  }

  return t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND');
});
</script>

<template>
  <div
    class="text-sm min-w-0"
    :class="[
      messageClass,
      {
        'max-w-lg': variant !== MESSAGE_VARIANTS.EMAIL,
      },
    ]"
  >
    <div
      v-if="isPrivateNote"
      class="flex flex-wrap items-center gap-1.5 mb-1.5 text-xs font-medium text-n-amber-11"
      data-testid="private-note-header"
    >
      <span class="i-lucide-lock size-3.5 shrink-0" />
      <span class="min-w-0 truncate">
        {{
          noteAuthor
            ? t('CONVERSATION.PRIVATE_NOTE_HEADER.TITLE_WITH_AUTHOR', {
                author: noteAuthor,
              })
            : t('CONVERSATION.PRIVATE_NOTE_HEADER.TITLE')
        }}
      </span>
      <span
        v-if="isAutomatedNote"
        class="inline-flex items-center gap-1 px-1.5 rounded-md bg-n-amber-9 text-n-amber-12 dark:text-n-amber-3 font-semibold"
        data-testid="private-note-automation-badge"
      >
        <span class="i-lucide-bot size-3.5 shrink-0" />
        {{ t('CONVERSATION.PRIVATE_NOTE_HEADER.AUTOMATION') }}
      </span>
    </div>
    <div
      v-if="inReplyTo"
      class="p-2 -mx-1 mb-2 rounded-lg cursor-pointer bg-n-alpha-black1"
      @click="scrollToMessage"
    >
      <div
        v-dompurify-html="replyToPreview"
        class="prose prose-bubble line-clamp-2"
      />
    </div>
    <slot />
    <template v-if="shouldShowMeta">
      <CaptainGenerationDetails
        v-if="isCaptainMessage"
        :message-id="id"
        class="mt-2"
      >
        <TranslationToggle
          :icon="false"
          :showing-original="showingOriginal"
          @toggle="showingOriginal = !showingOriginal"
        />
        <template #meta>
          <MessageMeta
            class="shrink-0 whitespace-nowrap"
            :class="[emailMetaClass, metaColorClass]"
          />
        </template>
      </CaptainGenerationDetails>
      <MessageMeta
        v-else
        :class="[flexOrientationClass, emailMetaClass, metaColorClass]"
        class="mt-2"
      />
    </template>
  </div>
</template>
