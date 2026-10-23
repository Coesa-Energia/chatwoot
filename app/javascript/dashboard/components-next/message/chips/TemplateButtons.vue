<script setup>
// Buttons of a WhatsApp template sent from Chatwoot, shown under the bubble like the WhatsApp app does.
// The message only stores the template name/language, so the buttons come from the inbox's synced
// templates (works for old messages too). Display only: the customer's tap arrives as a normal message.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  COMPONENT_TYPES,
  findComponentByType,
} from 'dashboard/helper/templateHelper';
import { useMessageContext } from '../provider.js';

const BUTTON_ICONS = {
  QUICK_REPLY: 'i-lucide-reply',
  URL: 'i-lucide-external-link',
  PHONE_NUMBER: 'i-lucide-phone',
  COPY_CODE: 'i-lucide-copy',
};
// Like the WhatsApp app: more than 3 buttons shows the first 2 and a "see all options" row.
const MAX_VISIBLE_BUTTONS = 3;
const COLLAPSED_BUTTONS = 2;

const { t } = useI18n();
const { additionalAttributes, inboxId } = useMessageContext();
const getTemplates = useMapGetter('inboxes/getWhatsAppTemplates');
const showAll = ref(false);

const buttons = computed(() => {
  const params = additionalAttributes.value?.templateParams;
  if (!params?.name) return [];
  const templates = getTemplates.value(inboxId.value) || [];
  const template =
    templates.find(
      tpl => tpl.name === params.name && tpl.language === params.language
    ) || templates.find(tpl => tpl.name === params.name);
  // A template deleted at Meta is no longer synced: show the text only.
  if (!template) return [];
  return findComponentByType(template, COMPONENT_TYPES.BUTTONS)?.buttons || [];
});

const isCollapsible = computed(
  () => buttons.value.length > MAX_VISIBLE_BUTTONS
);
const visibleButtons = computed(() =>
  isCollapsible.value && !showAll.value
    ? buttons.value.slice(0, COLLAPSED_BUTTONS)
    : buttons.value
);
</script>

<template>
  <div
    v-if="buttons.length"
    class="flex flex-col -mx-4 -mb-3 border-t border-n-alpha-3 divide-y divide-n-alpha-3"
    data-testid="template-buttons"
  >
    <span
      v-for="(button, index) in visibleButtons"
      :key="index"
      class="flex items-center justify-center gap-1.5 px-4 py-2 text-sm font-medium"
    >
      <span
        :class="BUTTON_ICONS[button.type] || BUTTON_ICONS.QUICK_REPLY"
        class="size-4 shrink-0"
      />
      <span class="truncate">{{ button.text }}</span>
    </span>
    <button
      v-if="isCollapsible"
      type="button"
      class="flex items-center justify-center gap-1.5 px-4 py-2 text-sm font-medium rounded-b-2xl transition-colors hover:bg-n-alpha-1 focus-visible:outline-none focus-visible:bg-n-alpha-2"
      :aria-expanded="showAll"
      data-testid="template-buttons-toggle"
      @click="showAll = !showAll"
    >
      <span
        :class="showAll ? 'i-lucide-chevron-up' : 'i-lucide-list'"
        class="size-4 shrink-0"
      />
      {{
        showAll
          ? t('CONVERSATION.TEMPLATE_BUTTONS.SHOW_LESS')
          : t('CONVERSATION.TEMPLATE_BUTTONS.SHOW_ALL')
      }}
    </button>
  </div>
</template>
