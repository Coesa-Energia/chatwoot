<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

// For each agent of the inbox: do they take part in the automatic assignment (round robin)?
// Agents left out keep their access to the inbox, they are just never picked automatically.
const props = defineProps({
  agents: { type: Array, default: () => [] },
  modelValue: { type: Array, default: () => [] },
});

const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();

const inRotation = computed(() => new Set(props.modelValue));

const setRotation = (id, value) => {
  const ids = new Set(props.modelValue);
  if (value) ids.add(id);
  else ids.delete(id);
  emit('update:modelValue', [...ids]);
};
</script>

<template>
  <section
    v-if="agents.length"
    class="grid gap-3"
    data-testid="inbox-agent-rotation"
  >
    <header class="grid gap-1">
      <h3 class="m-0 text-sm font-medium text-n-slate-12">
        {{ t('INBOX_MGMT.ROTATION.TITLE') }}
      </h3>
      <p class="m-0 text-sm text-n-slate-11">
        {{ t('INBOX_MGMT.ROTATION.DESC') }}
      </p>
    </header>
    <ul class="m-0 grid list-none gap-2 p-0">
      <li
        v-for="agent in agents"
        :key="agent.id"
        class="flex items-center gap-3 rounded-xl px-3 py-2 outline outline-1 -outline-offset-1 outline-n-weak"
        :data-testid="`agent-rotation-${agent.id}`"
      >
        <Avatar
          :name="agent.name"
          :src="agent.thumbnail || agent.avatar_url || ''"
          :size="28"
        />
        <div class="grid min-w-0 flex-1">
          <span class="truncate text-sm font-medium text-n-slate-12">
            {{ agent.name }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{
              inRotation.has(agent.id)
                ? t('INBOX_MGMT.ROTATION.IN')
                : t('INBOX_MGMT.ROTATION.OUT')
            }}
          </span>
        </div>
        <Switch
          :model-value="inRotation.has(agent.id)"
          :aria-label="t('INBOX_MGMT.ROTATION.TITLE')"
          @update:model-value="value => setRotation(agent.id, value)"
        />
      </li>
    </ul>
    <p class="m-0 text-xs text-n-slate-10">
      {{ t('INBOX_MGMT.ROTATION.NOTE') }}
    </p>
  </section>
</template>
