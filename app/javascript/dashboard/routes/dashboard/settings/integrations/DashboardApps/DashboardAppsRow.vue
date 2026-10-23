<script setup>
import { BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  app: {
    type: Object,
    default: () => ({}),
  },
});

defineEmits(['edit', 'delete']);
const { t } = useI18n();
const inboxes = useMapGetter('inboxes/getInboxes');

const inboxesLabel = computed(() => {
  const ids = props.app.inbox_ids || [];
  if (!ids.length)
    return t('INTEGRATION_SETTINGS.DASHBOARD_APPS.LIST.ALL_INBOXES');
  return inboxes.value
    .filter(inbox => ids.includes(inbox.id))
    .map(inbox => inbox.name)
    .join(', ');
});
</script>

<template>
  <BaseTableRow :item="app">
    <template #default>
      <BaseTableCell>
        <span
          class="text-body-main text-n-slate-12 truncate block"
          :title="app.title"
        >
          {{ app.title }}
        </span>
        <span
          class="block truncate text-label-small text-n-slate-10"
          :title="inboxesLabel"
        >
          {{ inboxesLabel }}
        </span>
      </BaseTableCell>

      <BaseTableCell>
        <span
          class="text-body-main text-n-slate-11 truncate block"
          :title="app.content[0].url"
        >
          {{ app.content[0].url }}
        </span>
      </BaseTableCell>

      <BaseTableCell align="end" class="w-24">
        <div class="flex justify-end gap-3 flex-shrink-0">
          <Button
            v-tooltip.top="
              $t('INTEGRATION_SETTINGS.DASHBOARD_APPS.LIST.EDIT_TOOLTIP')
            "
            icon="i-woot-edit-pen"
            slate
            sm
            @click="$emit('edit', app)"
          />
          <Button
            v-tooltip.top="
              $t('INTEGRATION_SETTINGS.DASHBOARD_APPS.LIST.DELETE_TOOLTIP')
            "
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            @click="$emit('delete', app)"
          />
        </div>
      </BaseTableCell>
    </template>
  </BaseTableRow>
</template>
