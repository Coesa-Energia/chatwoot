<script setup>
// A small, quiet pill with the day, shown above the first message of each day (like the WhatsApp app).
defineProps({
  label: { type: String, required: true },
});
</script>

<template>
  <li
    class="flex justify-center py-2"
    :aria-label="label"
    data-testid="date-divider"
  >
    <span
      class="rounded-lg bg-n-solid-1 px-3 py-1 text-xs font-medium text-n-slate-11 shadow-[0_1px_1px_rgb(0_0_0/0.06)] outline outline-1 -outline-offset-1 outline-n-weak dark:bg-n-solid-3"
    >
      {{ label }}
    </span>
  </li>
</template>
