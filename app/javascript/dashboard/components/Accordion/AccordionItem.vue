<script setup>
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  compact: {
    type: Boolean,
    default: false,
  },
  icon: {
    type: String,
    default: '',
  },
  emoji: {
    type: String,
    default: '',
  },
  isOpen: {
    type: Boolean,
    default: true,
  },
});

const emit = defineEmits(['toggle']);

const onToggle = () => {
  emit('toggle');
};
</script>

<template>
  <div class="text-sm">
    <button
      type="button"
      class="flex items-center gap-2 select-none w-full h-10 rounded-lg bg-n-slate-2 outline outline-1 outline-n-weak m-0 cursor-grab justify-between px-4 drag-handle transition-colors hover:bg-n-slate-3 focus-visible:outline-2 focus-visible:outline-n-brand"
      :class="{ 'rounded-b-none': isOpen }"
      :aria-expanded="isOpen"
      @click.stop="onToggle"
    >
      <div class="flex items-center min-w-0 gap-2">
        <EmojiOrIcon v-if="icon || emoji" :icon="icon" :emoji="emoji" />
        <h5 class="text-n-slate-12 text-sm font-semibold mb-0 truncate">
          {{ title }}
        </h5>
      </div>
      <div class="flex flex-row items-center gap-2">
        <slot name="button" />
        <span
          class="i-lucide-chevron-down size-4 text-n-slate-11 transition-transform duration-150 motion-reduce:transition-none"
          :class="{ 'rotate-180': isOpen }"
        />
      </div>
    </button>
    <div
      v-if="isOpen"
      class="outline outline-1 outline-n-weak -mt-[-1px] border-t-0 rounded-b-lg"
      :class="compact ? 'p-0' : 'px-2 py-4'"
    >
      <slot />
    </div>
  </div>
</template>
