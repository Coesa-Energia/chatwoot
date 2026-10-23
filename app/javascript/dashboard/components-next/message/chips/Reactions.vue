<script setup>
import { computed } from 'vue';

// Emoji reactions on a message: at most one from the customer and one from the team.
const props = defineProps({
  reactions: { type: Object, default: () => ({}) },
});

const items = computed(() =>
  ['contact', 'business']
    .filter(side => props.reactions?.[side])
    .map(side => ({ side, emoji: props.reactions[side] }))
);
</script>

<template>
  <div
    v-if="items.length"
    class="flex items-center gap-0.5 px-1.5 py-0.5 -mt-2 mx-2 relative z-10 rounded-full bg-n-solid-2 outline outline-1 outline-n-weak shadow-sm text-sm leading-none"
    data-testid="message-reactions"
  >
    <span v-for="item in items" :key="item.side" :data-side="item.side">
      {{ item.emoji }}
    </span>
  </div>
</template>
