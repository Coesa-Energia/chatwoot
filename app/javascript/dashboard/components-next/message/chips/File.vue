<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { getFileInfo } from '@chatwoot/utils';
import { formatBytes } from 'shared/helpers/FileHelper';

import FileIcon from 'next/icon/FileIcon.vue';
import Icon from 'next/icon/Icon.vue';

const { attachment } = defineProps({
  attachment: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();

const fileDetails = computed(() => {
  return getFileInfo(attachment?.dataUrl || '');
});

const displayFileName = computed(() => {
  const { base, type } = fileDetails.value;
  return type ? `${base}.${type}` : base;
});

const fileMeta = computed(() =>
  [
    fileDetails.value.type?.toUpperCase(),
    attachment?.fileSize ? formatBytes(attachment.fileSize) : '',
  ]
    .filter(Boolean)
    .join(' · ')
);

const textColorClass = computed(() => {
  const colorMap = {
    '7z': 'dark:text-[#EDEEF0] text-[#2F265F]',
    csv: 'text-n-amber-12',
    doc: 'dark:text-[#D6E1FF] text-[#1F2D5C]', // indigo-12
    docx: 'dark:text-[#D6E1FF] text-[#1F2D5C]', // indigo-12
    json: 'text-n-slate-12',
    odt: 'dark:text-[#D6E1FF] text-[#1F2D5C]', // indigo-12
    pdf: 'text-n-slate-12',
    ppt: 'dark:text-[#FFE0C2] text-[#582D1D]',
    pptx: 'dark:text-[#FFE0C2] text-[#582D1D]',
    rar: 'dark:text-[#EDEEF0] text-[#2F265F]',
    rtf: 'dark:text-[#D6E1FF] text-[#1F2D5C]', // indigo-12
    tar: 'dark:text-[#EDEEF0] text-[#2F265F]',
    txt: 'text-n-slate-12',
    xls: 'text-n-teal-12',
    xlsx: 'text-n-teal-12',
    zip: 'dark:text-[#EDEEF0] text-[#2F265F]',
  };

  return colorMap[fileDetails.value.type] || 'text-n-slate-12';
});
</script>

<template>
  <div
    class="flex items-center w-64 max-w-full gap-3 px-3 py-2 overflow-hidden border rounded-xl bg-n-alpha-white border-n-container"
  >
    <span
      class="grid flex-shrink-0 rounded-lg size-9 place-content-center bg-n-alpha-2"
    >
      <FileIcon class="size-5" :file-type="fileDetails.type" />
    </span>
    <span class="flex flex-col flex-1 min-w-0">
      <span
        class="text-sm font-medium truncate"
        :title="fileDetails.name"
        :class="textColorClass"
      >
        {{ displayFileName }}
      </span>
      <span v-if="fileMeta" class="text-xs truncate text-n-slate-11">
        {{ fileMeta }}
      </span>
    </span>
    <a
      v-tooltip="t('CONVERSATION.DOWNLOAD')"
      class="grid flex-shrink-0 transition-colors rounded-full cursor-pointer size-8 place-content-center text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2"
      :href="attachment.dataUrl"
      rel="noreferrer noopener nofollow"
      target="_blank"
    >
      <Icon icon="i-lucide-download" />
    </a>
  </div>
</template>
