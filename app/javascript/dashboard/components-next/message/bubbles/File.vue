<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { getFileInfo } from '@chatwoot/utils';
import { formatBytes } from 'shared/helpers/FileHelper';

import BaseBubble from './Base.vue';
import FileIcon from 'next/icon/FileIcon.vue';
import Icon from 'next/icon/Icon.vue';
import { useMessageContext } from '../provider.js';

const { attachments } = useMessageContext();
const { t } = useI18n();

const attachment = computed(() => attachments.value[0]);

const fileDetails = computed(() =>
  getFileInfo(attachment.value?.dataUrl || '')
);

const fileName = computed(() => {
  const { base, type } = fileDetails.value;
  if (!base) return t('CONVERSATION.UNKNOWN_FILE_TYPE');
  return decodeURI(type ? `${base}.${type}` : base);
});

const fileMeta = computed(() =>
  [
    fileDetails.value.type?.toUpperCase(),
    attachment.value?.fileSize ? formatBytes(attachment.value.fileSize) : '',
  ]
    .filter(Boolean)
    .join(' · ')
);
</script>

<template>
  <BaseBubble class="p-2" data-bubble-name="attachment">
    <div class="flex items-center w-64 max-w-full gap-3">
      <span
        class="grid flex-shrink-0 rounded-lg size-10 place-content-center bg-n-alpha-3 dark:bg-n-alpha-white"
      >
        <FileIcon class="size-5" :file-type="fileDetails.type" />
      </span>
      <span class="flex flex-col flex-1 min-w-0">
        <span
          class="text-sm font-medium truncate text-n-slate-12"
          :title="fileName"
        >
          {{ fileName }}
        </span>
        <span v-if="fileMeta" class="text-xs truncate text-n-slate-11">
          {{ fileMeta }}
        </span>
      </span>
      <a
        v-tooltip="t('CONVERSATION.DOWNLOAD')"
        class="grid flex-shrink-0 transition-colors rounded-full cursor-pointer size-9 place-content-center text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-3"
        :href="attachment.dataUrl"
        rel="noreferrer noopener nofollow"
        target="_blank"
      >
        <Icon icon="i-lucide-download" />
      </a>
    </div>
  </BaseBubble>
</template>
