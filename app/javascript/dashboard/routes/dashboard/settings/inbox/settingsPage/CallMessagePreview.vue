<script setup>
// How a call-permission message looks on the customer's WhatsApp: the text plus the button WhatsApp adds.
defineProps({
  body: { type: String, default: '' },
  buttonLabel: { type: String, required: true },
  label: { type: String, required: true },
});
</script>

<template>
  <div class="flex flex-col gap-1.5">
    <span class="text-xs font-medium text-n-slate-10">
      {{ label }}
    </span>
    <div class="p-3 rounded-lg bg-n-alpha-2">
      <div
        class="flex flex-col max-w-xs overflow-hidden rounded-xl rounded-tl-sm bg-n-solid-1 shadow-sm"
      >
        <p
          class="px-3 py-2 text-sm whitespace-pre-wrap break-words text-n-slate-12"
        >
          {{ body }}
        </p>
        <div
          class="flex items-center justify-center gap-1.5 px-3 py-2 text-sm font-medium border-t border-n-weak text-n-brand"
        >
          <span class="i-lucide-phone size-3.5" />
          {{ buttonLabel }}
        </div>
      </div>
    </div>
  </div>
</template>
