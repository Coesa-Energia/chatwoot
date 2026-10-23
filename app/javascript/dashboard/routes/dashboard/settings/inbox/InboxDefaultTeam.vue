<script setup>
import { computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import Select from 'dashboard/components-next/select/Select.vue';

// Optional team that every new conversation of the inbox starts with.
const props = defineProps({
  modelValue: { type: [Number, String], default: null },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);
const store = useStore();
const { t } = useI18n();

const teams = computed(() => store.getters['teams/getTeams']);

const options = computed(() => [
  { value: '', label: t('INBOX_MGMT.DEFAULT_TEAM.NONE') },
  ...teams.value.map(({ id, name }) => ({ value: id, label: name })),
]);

const selected = computed({
  get: () => props.modelValue || '',
  set: value => emit('update:modelValue', value === '' ? null : Number(value)),
});

onMounted(() => {
  if (!teams.value.length) store.dispatch('teams/get');
});
</script>

<template>
  <section class="grid gap-2" data-testid="inbox-default-team">
    <header class="grid gap-1">
      <h3 class="m-0 text-sm font-medium text-n-slate-12">
        {{ t('INBOX_MGMT.DEFAULT_TEAM.TITLE') }}
      </h3>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.DEFAULT_TEAM.DESC') }}
      </p>
    </header>
    <Select
      v-model="selected"
      :options="options"
      :disabled="disabled"
      :aria-label="t('INBOX_MGMT.DEFAULT_TEAM.TITLE')"
    />
  </section>
</template>
