<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useLoadWithRetry } from 'dashboard/composables/loadWithRetry';
import BaseBubble from './Base.vue';
import Button from 'next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';
import MessageMeta from '../MessageMeta.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';
import { getMediaFrameStyle } from '../helpers/mediaFrame';
import { downloadFile } from '@chatwoot/utils';

import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';

const { t } = useI18n();

const { filteredCurrentChatAttachments, attachments } = useMessageContext();

const attachment = computed(() => {
  return attachments.value[0];
});

const frameStyle = computed(() => getMediaFrameStyle(attachment.value));

const { isLoaded, hasError, loadWithRetry } = useLoadWithRetry();

const showGallery = ref(false);
const isDownloading = ref(false);

onMounted(() => {
  if (attachment.value?.dataUrl) {
    loadWithRetry(attachment.value.dataUrl);
  }
});

const downloadAttachment = async () => {
  const { fileType, dataUrl, extension } = attachment.value;
  try {
    isDownloading.value = true;
    await downloadFile({ url: dataUrl, type: fileType, extension });
  } catch (error) {
    useAlert(t('GALLERY_VIEW.ERROR_DOWNLOADING'));
  } finally {
    isDownloading.value = false;
  }
};

const handleImageError = () => {
  hasError.value = true;
};
</script>

<template>
  <BaseBubble
    class="overflow-hidden p-1.5"
    data-bubble-name="image"
    hide-meta
    @click="showGallery = true"
  >
    <div
      v-if="hasError"
      class="flex items-center gap-2 px-3 py-2 text-center rounded-lg"
    >
      <Icon icon="i-lucide-image-off" class="text-n-slate-11" />
      <p class="mb-0 text-n-slate-11">
        {{ $t('COMPONENTS.MEDIA.IMAGE_UNAVAILABLE') }}
      </p>
    </div>
    <div
      v-else
      class="relative overflow-hidden cursor-pointer group rounded-xl bg-n-alpha-2"
      :style="frameStyle"
    >
      <img
        v-if="isLoaded"
        class="object-cover size-full skip-context-menu"
        :src="attachment.dataUrl"
        :alt="attachment.fileName || ''"
        draggable="false"
      />
      <div v-else class="animate-pulse size-full bg-n-alpha-2" />
      <div
        class="absolute inset-0 hidden pointer-events-none bg-gradient-to-b from-n-slate-12/25 dark:from-n-slate-1/40 via-transparent to-transparent group-hover:block"
      />
      <div class="absolute hidden gap-1.5 right-2 top-2 group-hover:flex">
        <Button xs solid slate icon="i-lucide-expand" class="opacity-70" />
        <Button
          xs
          solid
          slate
          icon="i-lucide-download"
          class="opacity-70"
          :is-loading="isDownloading"
          :disabled="isDownloading"
          @click.stop="downloadAttachment"
        />
      </div>
      <MessageMeta
        class="absolute px-2 py-0.5 text-white rounded-full pointer-events-none right-2 bottom-2 bg-black/50 backdrop-blur-sm"
      />
    </div>
  </BaseBubble>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @error="handleImageError"
    @close="() => (showGallery = false)"
  />
</template>
