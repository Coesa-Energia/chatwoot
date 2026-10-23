<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  count: { type: Number, required: true },
  alignBottom: { type: Boolean, default: false },
});

const { t } = useI18n();

const displayCount = computed(() =>
  props.count > 9 ? t('CHAT_LIST.UNREAD_COUNT_OVERFLOW') : props.count
);
</script>

<template>
  <!-- Same look as the sidebar and "Archived" badges; dark text keeps AA on the lighter dark-mode green. -->
  <span
    v-if="count > 0"
    class="bg-n-brand rounded-full h-5 min-w-5 px-1.5 w-fit font-semibold text-xs leading-3 text-white dark:text-n-slate-1 inline-grid place-items-center flex-shrink-0 tabular-nums"
    :class="{
      'mb-0.5': alignBottom,
    }"
  >
    {{ displayCount }}
  </span>
  <span v-else />
</template>
