<script setup>
import { ref, computed } from 'vue';
import BaseBubble from './Base.vue';
import Icon from 'next/icon/Icon.vue';
import MessageMeta from '../MessageMeta.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { useMessageContext } from '../provider.js';
import { getMediaFrameStyle } from '../helpers/mediaFrame';
import GalleryView from 'dashboard/components/widgets/conversation/components/GalleryView.vue';
import { ATTACHMENT_TYPES } from '../constants';

const emit = defineEmits(['error']);
const hasError = ref(false);
const showGallery = ref(false);
const { filteredCurrentChatAttachments, attachments } = useMessageContext();

const handleError = () => {
  hasError.value = true;
  emit('error');
};

const attachment = computed(() => {
  return attachments.value[0];
});

const isReel = computed(() => {
  return attachment.value.fileType === ATTACHMENT_TYPES.IG_REEL;
});

// Videos usually come without dimensions: assume 16:9 and letterbox on black.
const frameStyle = computed(() => getMediaFrameStyle(attachment.value, 16 / 9));
</script>

<template>
  <BaseBubble
    class="overflow-hidden p-1.5"
    data-bubble-name="video"
    hide-meta
    @click="showGallery = true"
  >
    <div
      v-if="hasError"
      class="flex items-center gap-2 px-3 py-2 text-center rounded-lg"
    >
      <Icon icon="i-lucide-video-off" class="text-n-slate-11" />
      <p class="mb-0 text-n-slate-11">
        {{ $t('COMPONENTS.MEDIA.LOADING_FAILED') }}
      </p>
    </div>
    <div
      v-else
      class="relative overflow-hidden bg-black rounded-xl"
      :class="{ 'max-w-48': isReel }"
      :style="frameStyle"
    >
      <div
        v-if="isReel"
        class="absolute right-0 flex items-start justify-end p-2 pointer-events-none"
      >
        <Icon icon="i-lucide-instagram" class="text-white shadow-lg" />
      </div>
      <video
        controls
        playsinline
        preload="metadata"
        class="object-contain size-full skip-context-menu"
        :src="attachment.dataUrl"
        @click.stop
        @error="handleError"
      />
    </div>
    <MessageMeta
      v-if="!hasError"
      class="justify-end px-1.5 pt-1 pb-0.5 text-n-slate-11"
    />
  </BaseBubble>
  <GalleryView
    v-if="showGallery"
    v-model:show="showGallery"
    :attachment="useSnakeCase(attachment)"
    :all-attachments="filteredCurrentChatAttachments"
    @close="() => (showGallery = false)"
  />
</template>
