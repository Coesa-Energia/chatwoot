<script setup>
import { computed, useAttrs } from 'vue';

import ImageChip from 'next/message/chips/Image.vue';
import VideoChip from 'next/message/chips/Video.vue';
import AudioChip from 'next/message/chips/Audio.vue';
import FileChip from 'next/message/chips/File.vue';
import { useMessageContext } from '../provider.js';

import { ATTACHMENT_TYPES } from '../constants';
import {
  ALBUM_MAX_TILES,
  MEDIA_MAX_WIDTH,
  getMediaFrameStyle,
} from '../helpers/mediaFrame';

/**
 * @typedef {Object} Attachment
 * @property {number} id - Unique identifier for the attachment
 * @property {number} messageId - ID of the associated message
 * @property {'image'|'audio'|'video'|'file'|'location'|'fallback'|'share'|'story_mention'|'contact'|'ig_reel'} fileType - Type of the attachment (file or image)
 * @property {number} accountId - ID of the associated account
 * @property {string|null} extension - File extension
 * @property {string} dataUrl - URL to access the full attachment data
 * @property {string} thumbUrl - URL to access the thumbnail version
 * @property {number} fileSize - Size of the file in bytes
 * @property {number|null} width - Width of the image if applicable
 * @property {number|null} height - Height of the image if applicable
 */
const props = defineProps({
  attachments: {
    type: Array,
    default: () => [],
  },
  // Show photos/videos as a WhatsApp-style grid instead of small thumbnails.
  grid: {
    type: Boolean,
    default: false,
  },
  // Render only one group: 'media' (photos and videos) or 'other' (audio and files).
  only: {
    type: String,
    default: '',
    validator: value => ['', 'media', 'other'].includes(value),
  },
});

defineOptions({
  inheritAttrs: false,
});

const attrs = useAttrs();
const { orientation } = useMessageContext();

const classToApply = computed(() => {
  const baseClasses = [attrs.class, 'flex', 'flex-wrap'];

  if (orientation.value === 'right') {
    baseClasses.push('justify-end');
  }

  return baseClasses;
});

const allAttachments = computed(() => {
  return Array.isArray(props.attachments) ? props.attachments : [];
});

const mediaAttachments = computed(() => {
  const allowedTypes = [ATTACHMENT_TYPES.IMAGE, ATTACHMENT_TYPES.VIDEO];
  const mediaTypes = allAttachments.value.filter(attachment =>
    allowedTypes.includes(attachment.fileType)
  );

  return mediaTypes.sort(
    (a, b) =>
      allowedTypes.indexOf(a.fileType) - allowedTypes.indexOf(b.fileType)
  );
});

const recordings = computed(() => {
  return allAttachments.value.filter(
    attachment => attachment.fileType === ATTACHMENT_TYPES.AUDIO
  );
});

const showMedia = computed(() => props.only !== 'other');
const showOther = computed(() => props.only !== 'media');

const albumTiles = computed(() =>
  mediaAttachments.value.slice(0, ALBUM_MAX_TILES)
);
const hiddenMediaCount = computed(
  () => mediaAttachments.value.length - albumTiles.value.length
);
const isSingleMedia = computed(() => mediaAttachments.value.length === 1);

const albumStyle = computed(() => {
  if (isSingleMedia.value) {
    const { width, maxWidth } = getMediaFrameStyle(mediaAttachments.value[0]);
    return { width, maxWidth };
  }
  return { width: `${MEDIA_MAX_WIDTH}px`, maxWidth: '100%' };
});

const tileClass = index => {
  const total = mediaAttachments.value.length;
  if (total === 1) return '';
  if (total === 3 && index === 0) return 'col-span-2 aspect-[2/1]';
  return 'aspect-square';
};

const tileStyle = attachment =>
  isSingleMedia.value ? getMediaFrameStyle(attachment) : undefined;

const files = computed(() => {
  return allAttachments.value.filter(
    attachment => attachment.fileType === ATTACHMENT_TYPES.FILE
  );
});
</script>

<template>
  <div
    v-if="showMedia && grid && mediaAttachments.length"
    class="grid gap-1"
    :class="[
      isSingleMedia ? 'grid-cols-1' : 'grid-cols-2',
      orientation === 'right' ? 'ml-auto' : '',
    ]"
    :style="albumStyle"
  >
    <div
      v-for="(attachment, index) in albumTiles"
      :key="attachment.id"
      class="relative overflow-hidden rounded-xl bg-n-alpha-2"
      :class="tileClass(index)"
      :style="tileStyle(attachment)"
    >
      <ImageChip
        v-if="attachment.fileType === ATTACHMENT_TYPES.IMAGE"
        :attachment="attachment"
        fill
      />
      <VideoChip v-else :attachment="attachment" fill />
      <div
        v-if="hiddenMediaCount > 0 && index === albumTiles.length - 1"
        class="absolute inset-0 flex items-center justify-center text-xl font-medium text-white pointer-events-none bg-black/50"
      >
        {{ `+${hiddenMediaCount + 1}` }}
      </div>
    </div>
  </div>
  <div v-else-if="showMedia && mediaAttachments.length" :class="classToApply">
    <template v-for="attachment in mediaAttachments" :key="attachment.id">
      <ImageChip
        v-if="attachment.fileType === ATTACHMENT_TYPES.IMAGE"
        :attachment="attachment"
      />
      <VideoChip
        v-else-if="attachment.fileType === ATTACHMENT_TYPES.VIDEO"
        :attachment="attachment"
      />
    </template>
  </div>
  <div v-if="showOther && recordings.length" :class="classToApply">
    <div v-for="attachment in recordings" :key="attachment.id">
      <AudioChip
        class="bg-n-alpha-3 dark:bg-n-alpha-2 text-n-slate-12"
        :attachment="attachment"
      />
    </div>
  </div>
  <div v-if="showOther && files.length" :class="classToApply">
    <FileChip
      v-for="attachment in files"
      :key="attachment.id"
      :attachment="attachment"
    />
  </div>
</template>
