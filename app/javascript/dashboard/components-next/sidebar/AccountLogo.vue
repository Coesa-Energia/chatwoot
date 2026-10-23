<script setup>
import { computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import Logo from 'next/icon/Logo.vue';
import { resolveBrandImage } from './brandImages';

// The account's own image, falling back to the installation logo. `variant` is main, collapsed or text
// (see brandImages.js). Sized by height so a wide logo keeps its proportions instead of shrinking into a
// square; `maxWidth` stops it from outgrowing the sidebar.
const props = defineProps({
  height: { type: String, default: 'h-7' },
  maxWidth: { type: String, default: 'max-w-[8.5rem]' },
  variant: { type: String, default: 'main' },
});

const { currentAccount } = useAccount();
const imageUrl = computed(() =>
  resolveBrandImage(currentAccount.value, props.variant)
);
// The installation logo is a square icon.
const squareSize = computed(() => props.height.replace(/^h-/, 'size-'));
</script>

<template>
  <img
    v-if="imageUrl"
    :src="imageUrl"
    :alt="currentAccount?.name"
    class="w-auto flex-shrink-0 rounded-lg object-contain"
    :class="[height, maxWidth]"
  />
  <Logo v-else class="flex-shrink-0" :class="squareSize" />
</template>
